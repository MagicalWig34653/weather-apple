import Foundation
import Combine
import CoreGraphics

/// Fixed Crown axis from latest.json only. Missing/shifted slots are a contract error.
enum WatchRadarSlots {
    static let count = 37
    static let currentIndex = 12
    static let step: TimeInterval = 300

    static func dates(reference: Date) -> [Date] {
        (0..<count).map { reference.addingTimeInterval(Double($0 - currentIndex) * step) }
    }

    static func index(for date: Date, reference: Date) -> Int {
        let offset = date.timeIntervalSince(reference) / step + Double(currentIndex)
        guard offset.isFinite else { return currentIndex }
        return Int(min(Double(count - 1), max(0, offset.rounded())))
    }

    /// Slots placed on the fixed axis; a gap (DWD occasionally lacks an analysis) stays nil.
    /// nil result = contract error: wrong step/size, off-grid or duplicate time, missing reference slot.
    static func axis(for manifest: RadarManifest) -> [RadarManifest.Slot?]? {
        guard manifest.stepMinutes == 5, manifest.imageWidth == 1024, manifest.imageHeight == 1311 else { return nil }
        let dates = dates(reference: manifest.referenceTime)
        var result = [RadarManifest.Slot?](repeating: nil, count: count)
        for slot in manifest.slots {
            guard let index = dates.firstIndex(of: slot.time), result[index] == nil,
                  index == currentIndex || slot.kind == (index < currentIndex ? .analysis : .forecast) else { return nil }
            result[index] = slot
        }
        return result[currentIndex] == nil ? nil : result
    }

    static func validate(_ manifest: RadarManifest) -> Bool { axis(for: manifest) != nil }

    static func priority(selected: Int, lowPower: Bool) -> [Int] {
        let center = min(count - 1, max(0, selected))
        return (0..<count).filter { !lowPower || abs($0 - center) <= 2 }.sorted {
            let a = abs($0 - center), b = abs($1 - center)
            return a == b ? $0 < $1 : a < b
        }
    }

    static func isStale(_ manifest: RadarManifest, at now: Date) -> Bool {
        !manifest.isFresh(at: now) || now.timeIntervalSince(manifest.referenceTime) >= RadarBackendConfig.maximumDataAge
    }
}

/// One location/zoom only. The cost is the real decoded row stride, not compressed bytes.
struct WatchRadarFrameCache {
    static let defaultBudget = 4_000_000
    let budget: Int
    private(set) var bytes = 0
    private var images: [Int: CGImage] = [:]
    private var recency: [Int] = []
    var indices: Set<Int> { Set(images.keys) }

    init(budget: Int = defaultBudget) { self.budget = max(0, budget) }

    mutating func image(at index: Int) -> CGImage? {
        guard let image = images[index] else { return nil }
        recency.removeAll { $0 == index }
        recency.append(index)
        return image
    }

    @discardableResult
    mutating func insert(_ image: CGImage, at index: Int, protecting selected: Int) -> Bool {
        let (cost, overflow) = image.bytesPerRow.multipliedReportingOverflow(by: image.height)
        guard !overflow, cost <= budget else { return false }
        remove(index)
        while bytes + cost > budget {
            guard let victim = recency.first(where: { $0 != selected }) else { return false }
            remove(victim)
        }
        images[index] = image
        recency.append(index)
        bytes += cost
        return true
    }

    private mutating func remove(_ index: Int) {
        if let image = images.removeValue(forKey: index) { bytes -= image.bytesPerRow * image.height }
        recency.removeAll { $0 == index }
    }
}

/// Own this store for the radar screen's lifetime. Call stop() when inactive/disappearing.
/// No polling, persistence, history.json or DWD tile fallback. All coordinates stay local.
@MainActor
final class WatchRadarStore: ObservableObject {
    enum Failure: Error, Equatable, Sendable {
        case backend(RadarBackendError)
        case invalidManifest, outsideCoverage, invalidImage, memoryBudget
    }
    enum State: Equatable, Sendable { case idle, loading, ready, failed(Failure) }
    typealias Decode = @Sendable (Data, RadarCrop.Layout, Int, Int) async throws -> CGImage

    @Published private(set) var state: State = .idle
    @Published private(set) var manifest: RadarManifest?
    @Published private(set) var layout: RadarCrop.Layout?
    @Published private(set) var selectedIndex = WatchRadarSlots.currentIndex
    @Published private(set) var loadedSlotIndices: Set<Int> = []
    @Published private(set) var slotFailures: [Int: Failure] = [:]
    @Published private(set) var isLoadingSlots = false
    @Published private(set) var isStale = true
    @Published private(set) var placeID: UUID?
    @Published private(set) var zoom: RadarCrop.Zoom = .local

    /// Always 37 entries once a manifest is loaded; nil marks a gap in the backend data.
    var slots: [RadarManifest.Slot?] { manifest.flatMap(WatchRadarSlots.axis(for:)) ?? [] }
    var selectedTime: Date? { referenceTime.map { WatchRadarSlots.dates(reference: $0)[selectedIndex] } }
    var referenceTime: Date? { manifest?.referenceTime }
    var cachedBytes: Int { cache.bytes }
    var selectedImage: CGImage? { image(at: selectedIndex) }

    private static let decoder = WatchRadarDecoder()
    private let client: RadarBackendClient
    private let transport: RadarBackendClient.Transport
    private let decode: Decode
    private let clock: @Sendable () -> Date
    private var cache: WatchRadarFrameCache
    private var coordinate: WeatherCoordinate?
    private var lastFetch: Date?
    private var generation = UUID()
    private var task: Task<Void, Never>?
    private var active = false
    private var lowPower = false
    private var terminalFailure: Failure?

    init(baseURL: URL = RadarBackendConfig.baseURL(), transport: RadarBackendClient.Transport? = nil,
         decode: Decode? = nil, budget: Int = WatchRadarFrameCache.defaultBudget,
         clock: @escaping @Sendable () -> Date = { Date() }) {
        let transport = transport ?? RadarBackendClient.makeTransport()
        self.transport = transport
        self.client = RadarBackendClient(baseURL: baseURL, transport: transport, clock: clock)
        self.decode = decode ?? { data, layout, width, height in
            try await Self.decoder.decode(data, layout: layout, width: width, height: height)
        }
        self.clock = clock
        self.cache = WatchRadarFrameCache(budget: budget)
    }

    /// Open/reopen, change location/zoom, or refresh. One generation may publish results.
    /// Same place/run reopens within five minutes reuse RAM frames; forceRefresh checks latest.
    func load(place: SavedPlace, zoom: RadarCrop.Zoom = .local, forceRefresh: Bool = false,
              lowPower: Bool = ProcessInfo.processInfo.isLowPowerModeEnabled) {
        let same = placeID == place.id && coordinate == place.coordinate && self.zoom == zoom
        let reusable = same && !forceRefresh && terminalFailure == nil && manifest.map { !WatchRadarSlots.isStale($0, at: clock()) } == true
            && lastFetch.map { (0..<300).contains(clock().timeIntervalSince($0)) } == true
        if reusable && active && task != nil && self.lowPower == lowPower { return }
        stop()
        active = true
        terminalFailure = nil
        self.lowPower = lowPower
        placeID = place.id
        coordinate = place.coordinate
        self.zoom = zoom
        if !same { clearFrames(); manifest = nil; layout = nil; lastFetch = nil; selectedIndex = WatchRadarSlots.currentIndex }
        slotFailures = [:]
        state = .loading
        isLoadingSlots = true
        let token = generation
        task = Task { [weak self] in
            guard let self else { return }
            await self.run(coordinate: place.coordinate, zoom: zoom, reuse: reusable, token: token)
            if self.generation == token { self.task = nil; self.isLoadingSlots = false }
        }
    }

    /// Cancel all requests and prevent late completions from publishing; retain only this place's RAM cache.
    func stop() {
        generation = UUID()
        task?.cancel()
        task = nil
        active = false
        isLoadingSlots = false
        state = .idle
    }

    func select(index: Int) {
        selectedIndex = min(WatchRadarSlots.count - 1, max(0, index))
        if let terminalFailure {
            if active { state = .failed(terminalFailure) }
            return
        }
        updateFreshness()
        if active { updateState() }
        // At most two already-running requests finish before the new priority takes effect.
        // Resume after a completed batch for a low-power neighborhood or an evicted selection.
        if active, task == nil, lowPower || (!loadedSlotIndices.contains(selectedIndex) && slotFailures[selectedIndex] == nil),
           let coordinate, let placeID {
            load(place: SavedPlace(id: placeID, name: "", coordinate: coordinate), zoom: zoom, lowPower: lowPower)
        }
    }

    func select(time: Date) {
        guard let referenceTime else { return }
        select(index: WatchRadarSlots.index(for: time, reference: referenceTime))
    }

    func image(at index: Int) -> CGImage? { cache.image(at: index) }

    /// Invoke on the UI's local clock tick; this does not cause a network request.
    func updateFreshness(at date: Date? = nil) {
        isStale = manifest.map { WatchRadarSlots.isStale($0, at: date ?? clock()) } ?? true
        if active, terminalFailure == nil, isStale, manifest != nil { state = .failed(.backend(.stale)) }
    }

    /// Deterministic synchronization point for the portable tests, also useful for explicit refresh UI.
    func waitUntilFinished() async { await task?.value }

    private func clearFrames() {
        cache = WatchRadarFrameCache(budget: cache.budget)
        loadedSlotIndices = []
    }

    private func updateState() {
        if let terminalFailure { state = .failed(terminalFailure) }
        else if isStale { state = .failed(.backend(.stale)) }
        else if loadedSlotIndices.contains(selectedIndex) { state = .ready }
        else if let failure = slotFailures[selectedIndex] { state = .failed(failure) }
        else { state = .loading }
    }

    private func run(coordinate: WeatherCoordinate, zoom: RadarCrop.Zoom, reuse: Bool, token: UUID) async {
        do {
            if !reuse {
                let outcome = await client.latest()
                try check(token)
                guard case let .fresh(value, _) = outcome else {
                    if case let .fallback(error) = outcome { throw Failure.backend(error) }
                    throw Failure.invalidManifest
                }
                guard WatchRadarSlots.validate(value) else { throw Failure.invalidManifest }
                let newLayout: RadarCrop.Layout
                do { newLayout = try RadarCrop.layout(coordinate: coordinate, zoom: zoom, bounds: value.bounds) }
                catch { throw Failure.outsideCoverage }
                let newIndex = RadarTimelineSelection.index(previous: selectedTime, previousReference: referenceTime,
                                                           dates: WatchRadarSlots.dates(reference: value.referenceTime), reference: value.referenceTime)
                if manifest != value || layout != newLayout { clearFrames() }
                manifest = value
                layout = newLayout
                selectedIndex = newIndex
                lastFetch = clock()
            }
            guard let manifest, let layout else { throw Failure.invalidManifest }
            updateFreshness()
            guard !isStale else { throw Failure.backend(.stale) }
            // Always finish the run's current frame before starting the rest of the pipeline.
            if !loadedSlotIndices.contains(WatchRadarSlots.currentIndex) {
                guard let currentSlot = WatchRadarSlots.axis(for: manifest)?[WatchRadarSlots.currentIndex] else { throw Failure.invalidManifest }
                let image = try await Self.fetch(slot: currentSlot,
                                                 manifest: manifest, layout: layout, transport: transport, decode: decode)
                try check(token)
                try accept(image, index: WatchRadarSlots.currentIndex)
            }
            updateState()
            await prefetch(manifest: manifest, layout: layout, token: token)
        } catch {
            guard generation == token, !Task.isCancelled else { return }
            clearFrames()
            isStale = true
            let failure = error as? Failure ?? .invalidImage
            terminalFailure = failure
            state = .failed(failure)
        }
    }

    private func check(_ token: UUID) throws {
        try Task.checkCancellation()
        guard generation == token else { throw CancellationError() }
    }

    private func accept(_ image: CGImage, index: Int) throws {
        guard cache.insert(image, at: index, protecting: selectedIndex) else { throw Failure.memoryBudget }
        loadedSlotIndices = cache.indices
        slotFailures[index] = nil
    }

    private func prefetch(manifest: RadarManifest, layout: RadarCrop.Layout, token: UUID) async {
        let transport = self.transport, decode = self.decode
        let axis = WatchRadarSlots.axis(for: manifest) ?? []
        await withTaskGroup(of: (Int, Result<CGImage, Failure>).self) { group in
            var pending: Set<Int> = []
            // Attempt every slot only once per opening (including slots evicted by a smaller test budget).
            var attempted = loadedSlotIndices
            while generation == token && !Task.isCancelled {
                for index in WatchRadarSlots.priority(selected: selectedIndex, lowPower: lowPower)
                    where !attempted.contains(index) && pending.count < 2 {
                    attempted.insert(index)
                    guard axis.indices.contains(index), let slot = axis[index] else {
                        slotFailures[index] = .invalidManifest // gap in the backend data: shown as "frame unavailable"
                        continue
                    }
                    pending.insert(index)
                    group.addTask {
                        do {
                            let image = try await Self.fetch(slot: slot, manifest: manifest,
                                                             layout: layout, transport: transport, decode: decode)
                            return (index, .success(image))
                        } catch { return (index, .failure(error as? Failure ?? .invalidImage)) }
                    }
                }
                guard !pending.isEmpty, let (index, result) = await group.next() else { break }
                guard generation == token && !Task.isCancelled else { break }
                pending.remove(index)
                do {
                    switch result {
                    case let .success(image): try accept(image, index: index)
                    case let .failure(error): slotFailures[index] = error
                    }
                } catch { slotFailures[index] = error as? Failure ?? .memoryBudget }
                updateFreshness()
                updateState()
                if isStale { break }
            }
            group.cancelAll()
        }
    }

    nonisolated private static func fetch(slot: RadarManifest.Slot, manifest: RadarManifest, layout: RadarCrop.Layout,
                                          transport: RadarBackendClient.Transport, decode: Decode) async throws -> CGImage {
        try Task.checkCancellation()
        // slot.url comes from RadarManifest's safe, relative immutable path. No coordinate, name or ID headers.
        var request = URLRequest(url: slot.url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 6)
        request.httpShouldHandleCookies = false
        request.setValue("image/webp", forHTTPHeaderField: "Accept")
        let data: Data, response: HTTPURLResponse
        do { (data, response) = try await transport(request) }
        catch { try Task.checkCancellation(); throw Failure.backend(.unreachable) }
        try Task.checkCancellation()
        guard response.statusCode == 200 else {
            throw Failure.backend(response.statusCode == 404 ? .notPublished : .unreachable)
        }
        guard !data.isEmpty, data.count <= RadarBackendConfig.maximumImageBytes else { throw Failure.invalidImage }
        do { return try await decode(data, layout, manifest.imageWidth, manifest.imageHeight) }
        catch { try Task.checkCancellation(); throw Failure.invalidImage }
    }
}
