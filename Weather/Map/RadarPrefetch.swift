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
    func contains(_ url: URL) -> Bool { lock.withLock { entries[url] != nil } }
    /// Drops everything except the given keys (a new backend run replaces the old one).
    func retain(_ keep: Set<URL>) {
        lock.withLock {
            for key in entries.keys where !keep.contains(key) { bytes -= entries.removeValue(forKey: key)!.data.count }
        }
    }
    func insert(_ data: Data, for url: URL) {
        guard (try? DWDResponse.radarImage(from: data)) != nil else { return }
        insertTrusted(data, for: url)
    }
    /// For payloads the caller has already validated (backend images are decoded first).
    func insertTrusted(_ data: Data, for url: URL) {
        guard data.count <= limit else { return }
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
    struct Item: Equatable, Sendable { let slot: Int; let path: RadarTileCoordinate }
    // Slot-major plan: the viewport's tile coordinates are identical for every time
    // slot, so slots never visited still get the full coordinate set.
    static func plan(selected: Int, count: Int, paths: [RadarTileCoordinate]) -> [Item] {
        order(selected: selected, count: count).flatMap { slot in paths.map { Item(slot: slot, path: $0) } }
    }
    static let parallelism = 3
    static let maxConsecutiveFailures = 3
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
    init(maxRequests: Int = 240, interval: TimeInterval = 60, maxBytes: Int = 8_000_000) {
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
    func resetForTesting() { lock.withLock { demands = 0; cancellation = nil } }
}

// Speculative transports (a few in parallel, one per URL). A matching foreground
// subscriber promotes one and survives detachment/cancellation of the speculative waiter.
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
        var isIdle: Bool { demands.isEmpty && speculative == nil && !handoff }
    }
    private let lock = NSLock()
    private var entries: [UUID: Entry] = [:]
    var activeCount: Int { lock.withLock { entries.count } }
    func prepareHandoff(date: Date?, referenceTime: Date?) {
        let outcome: ([UUID], [URLSessionDataTask]) = lock.withLock {
            var reserved: [UUID] = [], dropped: [URLSessionDataTask] = []
            for (id, var current) in entries {
                let items = URLComponents(url: current.url, resolvingAgainstBaseURL: false)?.queryItems ?? []
                let matches: Bool
                if let date, let referenceTime {
                    matches = items.contains { $0.name == "TIME" && $0.value == DWDRequest.timestamp(date) }
                        && items.contains { $0.name == "DIM_REFERENCE_TIME" && $0.value == DWDRequest.timestamp(referenceTime) }
                } else { matches = false }
                current.handoff = matches
                if !matches && current.demands.isEmpty && current.speculative == nil {
                    entries[id] = nil; dropped.append(current.task)
                } else {
                    entries[id] = current
                    if matches { reserved.append(id) }
                }
            }
            return (reserved, dropped)
        }
        outcome.1.forEach { $0.cancel() }
        if !outcome.0.isEmpty {
            DispatchQueue.global().asyncAfter(deadline: .now() + 2) { [self] in
                let tasks: [URLSessionDataTask] = lock.withLock {
                    var cancelled: [URLSessionDataTask] = []
                    for id in outcome.0 {
                        guard var current = entries[id] else { continue }
                        current.handoff = false
                        if current.isIdle { entries[id] = nil; cancelled.append(current.task) } else { entries[id] = current }
                    }
                    return cancelled
                }
                tasks.forEach { $0.cancel() }
            }
        }
    }
    func cancelHandoff() {
        let tasks: [URLSessionDataTask] = lock.withLock {
            var cancelled: [URLSessionDataTask] = []
            for (id, var current) in entries {
                current.handoff = false
                if current.isIdle { entries[id] = nil; cancelled.append(current.task) } else { entries[id] = current }
            }
            return cancelled
        }
        tasks.forEach { $0.cancel() }
    }
    func join(url: URL, owner: UUID = UUID(), result: @escaping Handler) -> Bool {
        lock.withLock {
            guard let id = entries.first(where: { $0.value.url == url })?.key else { return false }
            RadarNetworkPriority.shared.beginDemand(cancelPrefetch: false)
            entries[id]?.demands.append((owner, result))
            entries[id]?.handoff = false
            return true
        }
    }
    func cancelDemands(owner: UUID) {
        let cancelled: ([Handler], [URLSessionDataTask]) = lock.withLock {
            var callbacks: [Handler] = [], tasks: [URLSessionDataTask] = []
            for (id, var current) in entries {
                callbacks += current.demands.filter { $0.0 == owner }.map { $0.1 }
                current.demands.removeAll { $0.0 == owner }
                if current.isIdle { entries[id] = nil; tasks.append(current.task) } else { entries[id] = current }
            }
            return (callbacks, tasks)
        }
        cancelled.1.forEach { $0.cancel() }
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
                    let finished: Entry? = lock.withLock { entries.removeValue(forKey: id) }
                    guard let finished else { return }
                    if let data { finished.received(data.count) }
                    let value = Response(data: data, response: response, error: error)
                    finished.speculative?(value)
                    finished.demands.forEach { $0.1(value) }
                }
                let accepted = lock.withLock {
                    guard !entries.values.contains(where: { $0.url == url }) else { return false }
                    entries[id] = Entry(id: id, url: url, task: task,
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
            guard var current = entries[id] else { return (nil, nil) }
            let callback = current.speculative; current.speculative = nil
            if current.demands.isEmpty && !current.handoff {
                entries[id] = nil; return (callback, current.task)
            }
            entries[id] = current; return (callback, nil)
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
    private let parallelism: Int
    private let priority: RadarNetworkPriority
    private let retryDelay: @Sendable (Int) -> TimeInterval
    private let budget: RadarPrefetchBudget
    private static var failedURLs: Set<URL> = []
    init(session: URLSession? = nil, networkAllowed: Bool? = nil,
         quiescence: Duration = .seconds(1), spacing: Duration = .milliseconds(250),
         parallelism: Int = RadarPrefetchPolicy.parallelism,
         priority: RadarNetworkPriority = .shared,
         budget: RadarPrefetchBudget? = nil,
         retryDelay: @escaping @Sendable (Int) -> TimeInterval = { RadarRetryPolicy.delay(afterAttempt: $0) }) {
        self.priority = priority
        self.retryDelay = retryDelay
        self.budget = budget ?? Self.budget
        self.quiescence = quiescence; self.spacing = spacing
        self.parallelism = max(1, parallelism)
        self.pathAllowed = networkAllowed ?? false
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.httpMaximumConnectionsPerHost = max(1, parallelism)
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
    static func resetSharedStateForTesting() {
        cooldown = [:]; failedURLs = []; RadarNetworkPriority.shared.resetForTesting()
    }
    func cancel() {
        generation = UUID(); work?.cancel(); work = nil; signature = nil
        priority.clear()
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
        let plan = RadarPrefetchPolicy.plan(selected: index, count: timeline.dates.count, paths: paths)
        let sweep = Sweep(plan: plan)
        work = Task { [weak self] in
            guard let self else { return }
            // Quiescence after MapKit has finished its observed selected demand.
            do {
                try await Task.sleep(for: self.quiescence)
                let workers = (0..<self.parallelism).map { _ in
                    Task { @MainActor in
                        try await self.runWorker(sweep: sweep, token: token, timeline: timeline,
                                                 revision: revision, cache: cache, received: received)
                    }
                }
                try await withTaskCancellationHandler {
                    var failure: Error?
                    for worker in workers {
                        do { try await worker.value } catch {
                            if failure == nil { failure = error; workers.forEach { $0.cancel() } }
                        }
                    }
                    if let failure { throw failure }
                } onCancel: { workers.forEach { $0.cancel() } }
            } catch {
                if !(error is CancellationError), (error as? URLError)?.code != .cancelled {
                    // Repeated source failures stop this sweep; no retry or per-frame flood.
                    Self.cooldown = Self.cooldown.filter { $0.value > Date() }
                    Self.cooldown[timeline.referenceTime] = Date().addingTimeInterval(120)
                }
            }
            if self.generation == token { priority.clear() }
        }
    }
    @MainActor private final class Sweep {
        let plan: [RadarPrefetchPolicy.Item]
        var next = 0
        var consecutiveFailures = 0
        init(plan: [RadarPrefetchPolicy.Item]) { self.plan = plan }
        func take() -> RadarPrefetchPolicy.Item? {
            guard next < plan.count else { return nil }
            defer { next += 1 }
            return plan[next]
        }
    }
    private func mayContinue(token: UUID, timeline: RadarTimeline) -> Bool {
        generation == token && pathAllowed && !ProcessInfo.processInfo.isLowPowerModeEnabled
            && !RainForecast(referenceTime: timeline.referenceTime, samples: []).isStale
    }
    private func runWorker(sweep: Sweep, token: UUID, timeline: RadarTimeline, revision: Int, cache: TileMemoryCache,
                           received: @escaping @MainActor @Sendable (Int) -> Void) async throws {
        while let item = sweep.take() {
            try Task.checkCancellation()
            guard mayContinue(token: token, timeline: timeline) else { return }
            let date = timeline.dates[item.slot]
            let reference = min(date, timeline.referenceTime)
            if let until = Self.cooldown[reference], until > Date() { continue }
            let url = DWDRequest.tileURL(x: item.path.x, y: item.path.y, z: item.path.z, date: date, referenceTime: reference)
            if cache.data(for: url) != nil || Self.failedURLs.contains(url)
                || RadarTileOverlay.hasFailure(url: url, revision: revision) { continue }
            // The DWD service answers about every third GetMap request with an HTTP-200
            // InvalidDimensionValue XML. Retry exactly that case a bounded number of times
            // with jittered backoff; every attempt claims the shared request budget.
            var attempt = 1
            attemptLoop: while true {
                while true {
                    let wait = budget.retryAfter()
                    if wait > 0 { try await Task.sleep(for: .seconds(wait)) }
                    try Task.checkCancellation()
                    guard mayContinue(token: token, timeline: timeline) else { return }
                    if budget.claim() { break }
                }
                let currentWork = self.work
                guard priority.register({ currentWork?.cancel() }) else { return }
                try Task.checkCancellation()
                let response = await RadarPrefetchFlight.shared.load(url: url, session: session, cache: cache) { count in
                    self.budget.received(count)
                    Task { @MainActor in received(count) }
                }
                if let error = response.error {
                    if (error as? URLError)?.code == .cancelled { throw CancellationError() }
                    try recordFailure(url: url, sweep: sweep, error: error)
                    break attemptLoop
                }
                try Task.checkCancellation()
                guard generation == token else { return }
                var failure: Error = DWDDataError.unavailable
                if (response.response as? HTTPURLResponse)?.statusCode == 200, let data = response.data {
                    do {
                        let image = try DWDResponse.radarImage(from: data)
                        cache.insert(image, for: url)
                        sweep.consecutiveFailures = 0
                        break attemptLoop
                    } catch { failure = error }
                }
                if RadarRetryPolicy.shouldRetry(failure, attempt: attempt) {
                    try await Task.sleep(for: .seconds(retryDelay(attempt)))
                    try Task.checkCancellation()
                    // Demand may have loaded or failed this tile while we backed off.
                    if cache.data(for: url) != nil || Self.failedURLs.contains(url)
                        || RadarTileOverlay.hasFailure(url: url, revision: revision) { break attemptLoop }
                    attempt += 1
                    continue attemptLoop
                }
                try recordFailure(url: url, sweep: sweep, error: failure)
                break attemptLoop
            }
            try await Task.sleep(for: spacing)
        }
    }
    // An isolated bad tile is skipped (and not requested again); several in a row
    // indicate a source problem and end the sweep with a cooldown.
    private func recordFailure(url: URL, sweep: Sweep, error: Error) throws {
        if Self.failedURLs.count > 4096 { Self.failedURLs.removeAll() }
        Self.failedURLs.insert(url)
        sweep.consecutiveFailures += 1
        if sweep.consecutiveFailures >= RadarPrefetchPolicy.maxConsecutiveFailures { throw error }
    }
    isolated deinit {
        work?.cancel(); monitor.cancel()
        if let powerObserver { NotificationCenter.default.removeObserver(powerObserver) }
    }
}
