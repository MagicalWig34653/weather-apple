import Foundation
import Network

// Compressed, validated weather PNG payloads only. The hard limit concerns retained
// payload bytes; MapKit's decoded images and active URLSession buffers are separate.
final class TileMemoryCache: @unchecked Sendable {
    private struct Entry { let data: Data; var access: UInt64 }
    private let lock = NSLock()
    private let limit: Int
    private var entries: [URL: Entry] = [:]
    private var bytes = 0
    private var clock: UInt64 = 0
    init(limit: Int = 50_000_000) { self.limit = max(0, limit) }
    var byteCount: Int { lock.withLock { bytes } }
    var count: Int { lock.withLock { entries.count } }
    func data(for url: URL) -> Data? {
        lock.withLock {
            guard var entry = entries[url] else { return nil }
            clock += 1; entry.access = clock; entries[url] = entry
            return entry.data
        }
    }
    func insert(_ data: Data, for url: URL) {
        guard data.count <= limit, (try? DWDResponse.radarImage(from: data)) != nil else { return }
        lock.withLock {
            if let old = entries.removeValue(forKey: url) { bytes -= old.data.count }
            while bytes + data.count > limit,
                  let oldest = entries.min(by: { $0.value.access < $1.value.access })?.key {
                bytes -= entries.removeValue(forKey: oldest)!.data.count
            }
            clock += 1; entries[url] = Entry(data: data, access: clock); bytes += data.count
        }
    }
}

enum RadarPrefetchPolicy {
    static func order(selected: Int, count: Int) -> [Int] {
        guard (0..<count).contains(selected) else { return [] }
        var result = [selected]
        for distance in 1..<max(1, count) {
            if selected - distance >= 0 { result.append(selected - distance) }
            if selected + distance < count { result.append(selected + distance) }
        }
        return result
    }
    static func isAllowed(isActive: Bool, lowPower: Bool, constrained: Bool, expensive _: Bool) -> Bool {
        // Normal cellular/hotspot access is allowed; Low Data Mode remains a stop.
        isActive && !lowPower && !constrained
    }
}

// App-selected fixed-window ceiling, not a published provider quota. Shared across
// scrubs/viewports; cancellation does not refund a request which may reach the source.
final class RadarPrefetchBudget: @unchecked Sendable {
    private let lock = NSLock()
    private let maxRequests: Int
    private let interval: TimeInterval
    private let maxBytes: Int
    private var start: Date?
    private var requests = 0
    private var bytes = 0
    init(maxRequests: Int = 120, interval: TimeInterval = 60, maxBytes: Int = 8_000_000) {
        self.maxRequests = maxRequests; self.interval = interval; self.maxBytes = maxBytes
    }
    private func reset(_ now: Date) {
        if start == nil || now.timeIntervalSince(start!) >= interval {
            start = now; requests = 0; bytes = 0
        }
    }
    func claim(now: Date = Date()) -> Bool {
        lock.withLock {
            reset(now)
            guard requests < maxRequests, bytes < maxBytes else { return false }
            requests += 1; return true
        }
    }
    func received(_ count: Int) { lock.withLock { bytes += max(0, count) } }
    func retryAfter(now: Date = Date()) -> TimeInterval {
        lock.withLock {
            reset(now)
            return requests >= maxRequests || bytes >= maxBytes ? max(0, interval - now.timeIntervalSince(start!)) : 0
        }
    }
}

// Demand preempts immediately, including calls arriving outside the main actor.
final class RadarNetworkPriority: @unchecked Sendable {
    static let shared = RadarNetworkPriority()
    private let lock = NSLock()
    private var demands = 0
    private var cancellation: (@Sendable () -> Void)?
    func beginDemand(cancelPrefetch: Bool = true) {
        let cancel = lock.withLock { demands += 1; return cancelPrefetch ? cancellation : nil }
        cancel?()
    }
    func endDemand() { lock.withLock { demands = max(0, demands - 1) } }
    func register(_ cancel: @escaping @Sendable () -> Void) -> Bool {
        lock.withLock {
            guard demands == 0 else { return false }
            cancellation = cancel; return true
        }
    }
    func clear() { lock.withLock { cancellation = nil } }
}

// One speculative transport. A matching foreground subscriber promotes it and
// survives detachment/cancellation of the speculative waiter.
final class RadarPrefetchFlight: @unchecked Sendable {
    struct Response: @unchecked Sendable {
        let data: Data?; let response: URLResponse?; let error: Error?
        var transportID = UUID()
    }
    typealias Handler = @Sendable (Response) -> Void
    static let shared = RadarPrefetchFlight()
    private struct Entry {
        let id: UUID; let url: URL; let task: URLSessionDataTask
        var speculative: Handler?; var demands: [(UUID, Handler)]
        let received: @Sendable (Int) -> Void
        var handoff = false
    }
    private let lock = NSLock()
    private var entry: Entry?
    func prepareHandoff(date: Date?, referenceTime: Date?) {
        let outcome: (UUID?, URLSessionDataTask?) = lock.withLock {
            guard var current = entry else { return (nil, nil) }
            let items = URLComponents(url: current.url, resolvingAgainstBaseURL: false)?.queryItems ?? []
            let matches: Bool
            if let date, let referenceTime {
                matches = items.contains { $0.name == "TIME" && $0.value == DWDRequest.timestamp(date) }
                    && items.contains { $0.name == "DIM_REFERENCE_TIME" && $0.value == DWDRequest.timestamp(referenceTime) }
            } else { matches = false }
            current.handoff = matches
            if !matches && current.demands.isEmpty && current.speculative == nil {
                entry = nil; return (nil, current.task)
            }
            entry = current
            return (matches ? current.id : nil, nil)
        }
        outcome.1?.cancel()
        if let reserved = outcome.0 {
            DispatchQueue.global().asyncAfter(deadline: .now() + 2) { [self] in
                let task: URLSessionDataTask? = lock.withLock {
                    guard var current = entry, current.id == reserved else { return nil }
                    current.handoff = false
                    if current.demands.isEmpty && current.speculative == nil { entry = nil; return current.task }
                    entry = current; return nil
                }
                task?.cancel()
            }
        }
    }
    func cancelHandoff() {
        let task: URLSessionDataTask? = lock.withLock {
            guard var current = entry else { return nil }
            current.handoff = false
            if current.demands.isEmpty && current.speculative == nil && !current.handoff { entry = nil; return current.task }
            entry = current; return nil
        }
        task?.cancel()
    }
    func join(url: URL, owner: UUID = UUID(), result: @escaping Handler) -> Bool {
        lock.withLock {
            guard entry?.url == url else { return false }
            RadarNetworkPriority.shared.beginDemand(cancelPrefetch: false)
            entry?.demands.append((owner, result))
            entry?.handoff = false
            return true
        }
    }
    func cancelDemands(owner: UUID) {
        let cancelled: ([Handler], URLSessionDataTask?) = lock.withLock {
            guard var current = entry else { return ([], nil) }
            let callbacks = current.demands.filter { $0.0 == owner }.map { $0.1 }
            current.demands.removeAll { $0.0 == owner }
            if current.demands.isEmpty && current.speculative == nil && !current.handoff {
                entry = nil; return (callbacks, current.task)
            }
            entry = current; return (callbacks, nil)
        }
        cancelled.1?.cancel()
        cancelled.0.forEach { $0(Response(data: nil, response: nil, error: URLError(.cancelled))) }
    }
    func load(url: URL, session: URLSession, cache: TileMemoryCache? = nil, received: @escaping @Sendable (Int) -> Void) async -> Response {
        let id = UUID()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
                request.setValue("ShowerNow/0.1 (native iOS rain radar)", forHTTPHeaderField: "User-Agent")
                let task = session.dataTask(with: request) { [self] data, response, error in
                    // Publish a valid completed image before the slot disappears, so
                    // a new demand cannot fall into a response/cache handoff gap.
                    if error == nil, (response as? HTTPURLResponse)?.statusCode == 200,
                       let data, let image = try? DWDResponse.radarImage(from: data) { cache?.insert(image, for: url) }
                    let finished: Entry? = lock.withLock {
                        guard entry?.id == id else { return nil }
                        let finished = entry; entry = nil; return finished
                    }
                    guard let finished else { return }
                    if let data { finished.received(data.count) }
                    let value = Response(data: data, response: response, error: error)
                    finished.speculative?(value)
                    finished.demands.forEach { $0.1(value) }
                }
                let accepted = lock.withLock {
                    guard entry == nil else { return false }
                    entry = Entry(id: id, url: url, task: task,
                                  speculative: { continuation.resume(returning: $0) },
                                  demands: [], received: received)
                    return true
                }
                if accepted {
                    if Task.isCancelled { cancel(id: id) } else { task.resume() }
                } else {
                    continuation.resume(returning: Response(data: nil, response: nil, error: URLError(.cancelled)))
                }
            }
        } onCancel: { [self] in cancel(id: id) }
    }
    private func cancel(id: UUID) {
        let cancelled: (Handler?, URLSessionDataTask?) = lock.withLock {
            guard var current = entry, current.id == id else { return (nil, nil) }
            let callback = current.speculative; current.speculative = nil
            if current.demands.isEmpty && !current.handoff {
                entry = nil; return (callback, current.task)
            }
            entry = current; return (callback, nil)
        }
        cancelled.1?.cancel()
        cancelled.0?(Response(data: nil, response: nil, error: URLError(.cancelled)))
    }
}

struct RadarTileCoordinate: Hashable, Sendable { let x: Int; let y: Int; let z: Int }

@MainActor final class RadarPrefetcher {
    nonisolated private static let budget = RadarPrefetchBudget()
    private static var cooldown: [Date: Date] = [:]
    private let monitor = NWPathMonitor()
    private var pathAllowed = false
    private var work: Task<Void, Never>?
    private var generation = UUID()
    private var signature: String?
    private var restart: (() -> Void)?
    private var powerObserver: NSObjectProtocol?
    private let session: URLSession
    private let quiescence: Duration
    private let spacing: Duration
    init(session: URLSession? = nil, networkAllowed: Bool? = nil,
         quiescence: Duration = .seconds(1), spacing: Duration = .milliseconds(500)) {
        self.quiescence = quiescence; self.spacing = spacing
        self.pathAllowed = networkAllowed ?? false
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.httpMaximumConnectionsPerHost = 1
        configuration.timeoutIntervalForRequest = 8
        configuration.timeoutIntervalForResource = 12
        configuration.allowsConstrainedNetworkAccess = false
        configuration.allowsExpensiveNetworkAccess = true
        configuration.allowsCellularAccess = true
        configuration.waitsForConnectivity = false
        self.session = session ?? URLSession(configuration: configuration)
        monitor.pathUpdateHandler = { [weak self] path in
            let allowed = path.status == .satisfied && RadarPrefetchPolicy.isAllowed(
                isActive: true, lowPower: false, constrained: path.isConstrained, expensive: path.isExpensive)
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.pathAllowed = allowed
                if allowed { self.restart?() } else { self.cancel() }
            }
        }
        if networkAllowed == nil { monitor.start(queue: DispatchQueue(label: "weather.prefetch.path")) }
        powerObserver = NotificationCenter.default.addObserver(forName: .NSProcessInfoPowerStateDidChange,
                                                               object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.restart?() }
        }
    }
    func cancel() {
        generation = UUID(); work?.cancel(); work = nil; signature = nil
        RadarNetworkPriority.shared.clear()
    }
    func update(timeline: RadarTimeline?, selected: Date?, paths: [RadarTileCoordinate],
                state: RadarLoadState?, active: Bool, revision: Int,
                cache: TileMemoryCache,
                received: @escaping @MainActor @Sendable (Int) -> Void) {
        restart = { [weak self] in
            self?.update(timeline: timeline, selected: selected, paths: paths, state: state,
                         active: active, revision: revision, cache: cache, received: received)
        }
        guard RadarPrefetchPolicy.isAllowed(isActive: active, lowPower: ProcessInfo.processInfo.isLowPowerModeEnabled,
                                             constrained: !pathAllowed, expensive: false),
              let timeline, let selected, let state,
              state.isViewportIdle, state.isSettled, state.failed == 0, state.succeeded > 0,
              (Self.cooldown[timeline.referenceTime] ?? .distantPast) <= Date(),
              !paths.isEmpty, let index = timeline.dates.firstIndex(of: selected),
              !RainForecast(referenceTime: timeline.referenceTime, samples: []).isStale else {
            cancel(); return
        }
        let key = "\(state.contextID)-\(revision)-\(paths.count)"
        guard signature != key else { return }
        cancel(); signature = key
        let token = generation
        work = Task { [weak self] in
            guard let self else { return }
            // Quiescence after MapKit has finished its observed selected demand.
            do {
                try await Task.sleep(for: self.quiescence)
                for slot in RadarPrefetchPolicy.order(selected: index, count: timeline.dates.count) {
                    let date = timeline.dates[slot]
                    let reference = min(date, timeline.referenceTime)
                    if let until = Self.cooldown[reference], until > Date() { continue }
                    for path in paths {
                        try Task.checkCancellation()
                        guard self.generation == token,
                              !ProcessInfo.processInfo.isLowPowerModeEnabled,
                              !RainForecast(referenceTime: timeline.referenceTime, samples: []).isStale else { return }
                        let url = DWDRequest.tileURL(x: path.x, y: path.y, z: path.z, date: date, referenceTime: reference)
                        if cache.data(for: url) != nil || RadarTileOverlay.hasFailure(url: url, revision: revision) { continue }
                        let wait = Self.budget.retryAfter()
                        if wait > 0 { try await Task.sleep(for: .seconds(wait)) }
                        try Task.checkCancellation()
                        guard self.generation == token, self.pathAllowed,
                              !ProcessInfo.processInfo.isLowPowerModeEnabled,
                              !RainForecast(referenceTime: timeline.referenceTime, samples: []).isStale,
                              Self.budget.claim() else { return }
                        let currentWork = self.work
                        guard RadarNetworkPriority.shared.register({ currentWork?.cancel() }) else { return }
                        try Task.checkCancellation()
                        let response = await RadarPrefetchFlight.shared.load(url: url, session: self.session, cache: cache) { count in
                            Self.budget.received(count)
                            Task { @MainActor in received(count) }
                        }
                        if let error = response.error { throw error }
                        guard let data = response.data else { throw DWDDataError.unavailable }
                        try Task.checkCancellation()
                        guard self.generation == token else { return }
                        guard (response.response as? HTTPURLResponse)?.statusCode == 200 else { throw DWDDataError.unavailable }
                        let image = try DWDResponse.radarImage(from: data)
                        cache.insert(image, for: url)
                        RadarNetworkPriority.shared.clear()
                        try await Task.sleep(for: self.spacing)
                    }
                }
            } catch {
                if !(error is CancellationError), (error as? URLError)?.code != .cancelled {
                    // Any source failure stops this sweep; no retry or per-frame flood.
                    Self.cooldown = Self.cooldown.filter { $0.value > Date() }
                    Self.cooldown[timeline.referenceTime] = Date().addingTimeInterval(120)
                }
            }
            if self.generation == token { RadarNetworkPriority.shared.clear() }
        }
    }
    isolated deinit {
        work?.cancel(); monitor.cancel()
        if let powerObserver { NotificationCenter.default.removeObserver(powerObserver) }
    }
}
