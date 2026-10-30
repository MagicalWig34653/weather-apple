import MapKit
import SwiftUI

struct RadarMap: UIViewRepresentable {
    let place: SavedPlace
    let date: Date?
    let referenceTime: Date?
    let centerRevision: Int
    let reloadRevision: Int
    let timeline: RadarTimeline?
    let prefetchActive: Bool
    let bottomInset: CGFloat
    let onSelect: (CLLocationCoordinate2D) -> Void
    /// Called when a backend image failed; the argument is the number of images loaded so far.
    var onBackendFailure: @MainActor (Int) -> Void = { _ in }
    let onLoadState: @MainActor @Sendable (RadarLoadState) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.preferredConfiguration = MKStandardMapConfiguration(elevationStyle: .flat)
        map.pointOfInterestFilter = .excludingAll
        map.showsCompass = false
        map.isRotateEnabled = false
        map.showsScale = true
        map.accessibilityIdentifier = "radar-map"
        let press = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.selectPoint(_:)))
        press.minimumPressDuration = 0.6
        map.addGestureRecognizer(press)
        context.coordinator.map = map
        center(map, animated: false)
        context.coordinator.lastCenterRevision = centerRevision
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        let contextMoved = coordinator.lastCenterRevision != centerRevision || coordinator.placeID != place.id
        // Keep MapKit attribution/controls above the forecast panel, including larger text sizes.
        map.layoutMargins = UIEdgeInsets(top: 96, left: 12, bottom: bottomInset + 12, right: 12)
        if coordinator.lastCenterRevision != centerRevision {
            center(map)
            coordinator.lastCenterRevision = centerRevision
        }
        if coordinator.placeID != place.id {
            map.removeAnnotations(map.annotations)
            let pin = MKPointAnnotation()
            pin.coordinate = CLLocationCoordinate2D(latitude: place.coordinate.latitude, longitude: place.coordinate.longitude)
            pin.title = place.name
            map.addAnnotation(pin)
            coordinator.placeID = place.id
        }
        if let manifest = timeline?.backend {
            // Cache backend: one whole-image overlay; DWD tile overlay and prefetch stay off.
            coordinator.updateBackend(map: map, manifest: manifest)
            return
        } else if coordinator.backendOverlay != nil {
            coordinator.tearDownBackend(map: map)
        }
        coordinator.updatePrefetch()
        let frameChanged = coordinator.date != date || coordinator.referenceTime != referenceTime
        guard frameChanged || coordinator.reloadRevision != reloadRevision else { return }
        // Reserve only an exactly matching speculative frame for MapKit's next
        // demand. Other frames are cancelled as before; reservation expires in 2 s.
        if frameChanged, !contextMoved, prefetchActive {
            RadarPrefetchFlight.shared.prepareHandoff(date: date, referenceTime: referenceTime)
        } else {
            RadarPrefetchFlight.shared.cancelHandoff()
        }
        coordinator.prefetcher.cancel()
        coordinator.date = date
        coordinator.referenceTime = referenceTime
        coordinator.reloadRevision = reloadRevision
        // Refreshing the same frame preserves the existing overlay/renderer. Successful
        // tiles remain memory hits; only missing tiles need the network again.
        if !frameChanged, let overlay = coordinator.overlay {
            coordinator.beginViewport(overlay, reloadRevision: reloadRevision)
            (map.renderer(for: overlay) as? MKTileOverlayRenderer)?.reloadData()
            return
        }
        coordinator.overlay?.cancelLoading()
        map.removeOverlays(map.overlays)
        coordinator.overlay = nil
        coordinator.activeContextID = nil
        if let date, let referenceTime {
            let overlay = RadarTileOverlay(date: date, referenceTime: referenceTime,
                                           reloadRevision: reloadRevision) { [weak coordinator] state in
                coordinator?.receive(state)
            }
            coordinator.overlay = overlay
            coordinator.beginViewport(overlay, reloadRevision: reloadRevision)
            map.addOverlay(overlay, level: .aboveRoads)
        }
    }

    static func dismantleUIView(_ map: MKMapView, coordinator: Coordinator) {
        RadarPrefetchFlight.shared.cancelHandoff()
        coordinator.prefetcher.cancel()
        coordinator.overlay?.cancelLoading()
        coordinator.backendOverlay?.loader.cancelPrefetch()
        map.delegate = nil
    }

    private func center(_ map: MKMapView, animated: Bool = true) {
        map.setRegion(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: place.coordinate.latitude,
                                                                       longitude: place.coordinate.longitude),
                                        latitudinalMeters: 180_000, longitudinalMeters: 180_000), animated: animated)
    }

    @MainActor final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: RadarMap
        weak var map: MKMapView?
        var date: Date?
        var referenceTime: Date?
        var reloadRevision = -1
        var lastCenterRevision = -1
        var placeID: UUID?
        var overlay: RadarTileOverlay?
        var activeContextID: UUID?
        var backendOverlay: RadarImageOverlay?
        private var backendContextID = UUID()
        private var backendSequence = 0
        private let pathGate = RadarPathGate()
        private var lastSequence = -1
        let prefetcher = RadarPrefetcher()
        private var currentState: RadarLoadState?
        private var prefetchBytes: Int64 = 0

        func tearDownBackend(map: MKMapView) {
            backendOverlay?.loader.cancelPrefetch()
            if let old = backendOverlay { map.removeOverlay(old) }
            backendOverlay = nil
            date = nil; referenceTime = nil
        }

        /// Shows the selected slot from the cache backend. Slot changes only redraw the same
        /// overlay (from memory when preloaded); a new run swaps the overlay.
        func updateBackend(map: MKMapView, manifest: RadarManifest) {
            if overlay != nil {
                prefetcher.cancel()
                RadarPrefetchFlight.shared.cancelHandoff()
                overlay?.cancelLoading()
                map.removeOverlays(map.overlays.filter { $0 is MKTileOverlay })
                overlay = nil; activeContextID = nil; currentState = nil
            }
            var replaced = false
            if backendOverlay?.loader.manifest != manifest {
                let created = RadarImageOverlay(loader: BackendRadarLoader(manifest: manifest))
                map.addOverlay(created, level: .aboveRoads)
                if let old = backendOverlay { old.loader.cancelPrefetch(); map.removeOverlay(old) }
                backendOverlay = created
                replaced = true
            }
            guard let backendOverlay, let date = parent.date, let reference = parent.referenceTime else { return }
            let changed = replaced || self.date != date || reloadRevision != parent.reloadRevision
            self.date = date; referenceTime = reference; reloadRevision = parent.reloadRevision
            guard let slot = manifest.slot(at: date), let index = manifest.slots.firstIndex(of: slot) else {
                reportBackend(.failed, date: date, reference: reference, loader: backendOverlay.loader)
                return
            }
            let loader = backendOverlay.loader
            if changed {
                backendOverlay.slotURL = slot.url
                map.renderer(for: backendOverlay)?.setNeedsDisplay()
                if loader.image(for: slot.url) != nil {
                    reportBackend(.ready, date: date, reference: reference, loader: loader)
                } else {
                    reportBackend(.pending, date: date, reference: reference, loader: loader)
                    let revision = reloadRevision
                    Task { @MainActor [weak self, weak backendOverlay, weak map] in
                        let ok = await loader.demand(slot.url)
                        guard let self, let backendOverlay, self.backendOverlay === backendOverlay,
                              self.date == date, self.reloadRevision == revision else { return }
                        if ok { map?.renderer(for: backendOverlay)?.setNeedsDisplay() }
                        self.reportBackend(ok ? .ready : .failed, date: date, reference: reference, loader: loader)
                        if !ok { self.parent.onBackendFailure(loader.successCount) }
                    }
                }
            }
            startBackendPrefetch(loader: loader, selected: index)
        }

        private func startBackendPrefetch(loader: BackendRadarLoader, selected: Int) {
            let active = parent.prefetchActive
            let gate = pathGate
            guard active, !ProcessInfo.processInfo.isLowPowerModeEnabled, !gate.isConstrained else {
                loader.cancelPrefetch(); return
            }
            loader.prefetch(selected: selected) {
                !ProcessInfo.processInfo.isLowPowerModeEnabled && !gate.isConstrained
            }
        }

        private enum BackendStatus { case pending, ready, failed }
        private func reportBackend(_ status: BackendStatus, date: Date, reference: Date, loader: BackendRadarLoader) {
            backendSequence += 1
            var state = RadarLoadState(contextID: backendContextID, frameDate: date, referenceTime: reference,
                                       reloadRevision: parent.reloadRevision)
            state.sequence = backendSequence
            state.requested = 1
            state.pending = status == .pending ? 1 : 0
            state.succeeded = status == .ready ? 1 : 0
            state.failed = status == .failed ? 1 : 0
            state.receivedBodyBytes = loader.receivedBytes
            state.isViewportIdle = true
            // Never publish while SwiftUI is updating the view.
            Task { @MainActor [weak self] in self?.parent.onLoadState(state) }
        }

        func updatePrefetch() {
            if backendOverlay != nil { return }
            if !parent.prefetchActive { RadarPrefetchFlight.shared.cancelHandoff() }
            prefetcher.update(timeline: parent.timeline, selected: date, paths: overlay?.observedPaths ?? [],
                              state: currentState, active: parent.prefetchActive, revision: reloadRevision,
                              cache: RadarTileOverlay.cache) { [weak self] count in
                guard let self else { return }
                self.prefetchBytes += Int64(count)
                if var state = self.currentState {
                    state.prefetchedBodyBytes = self.prefetchBytes
                    self.parent.onLoadState(state)
                }
            }
        }

        func beginViewport(_ overlay: RadarTileOverlay, reloadRevision: Int) {
            // A new viewport must not carry a frame-only handoff into another area.
            // Frame replacement calls this before addOverlay, so retain that brief
            // handoff only while the region itself has not begun changing.
            prefetcher.cancel()
            currentState = nil
            let state = overlay.beginViewport(reloadRevision: reloadRevision)
            activeContextID = state.contextID
            lastSequence = -1
            Task { @MainActor [weak self] in self?.receive(state) }
            Task { @MainActor [weak self, weak overlay] in
                try? await Task.sleep(for: .milliseconds(800))
                guard let self, let overlay, self.activeContextID == state.contextID else { return }
                overlay.endViewportDemand(contextID: state.contextID)
            }
        }

        func receive(_ state: RadarLoadState) {
            guard state.contextID == activeContextID, state.sequence >= lastSequence else { return }
            lastSequence = state.sequence
            currentState = state
            var display = state
            display.prefetchedBodyBytes = prefetchBytes
            parent.onLoadState(display)
            updatePrefetch()
        }

        func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
            guard let overlay else { return }
            // Start before MapKit asks for the new zoom/region. Resetting in didChange
            // would discard requests which already finished during the gesture.
            RadarPrefetchFlight.shared.cancelHandoff()
            beginViewport(overlay, reloadRevision: reloadRevision)
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            guard let overlay, let activeContextID else { return }
            overlay.endViewportDemand(contextID: activeContextID)
        }

        init(parent: RadarMap) { self.parent = parent }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if overlay is RadarImageOverlay {
                let renderer = RadarImageRenderer(overlay: overlay)
                renderer.alpha = 0.72
                return renderer
            }
            guard let tiles = overlay as? MKTileOverlay else { return MKOverlayRenderer(overlay: overlay) }
            let renderer = MKTileOverlayRenderer(tileOverlay: tiles)
            renderer.alpha = 0.72
            return renderer
        }

        @objc func selectPoint(_ recognizer: UILongPressGestureRecognizer) {
            guard recognizer.state == .began, let map else { return }
            parent.onSelect(map.convert(recognizer.location(in: map), toCoordinateFrom: map))
        }
    }
}

// A snapshot of demand observed from MapKit, not a percentage of an unbounded cache.
// MapKit may request more tiles later; isSettled means only the observed requests settled.
struct RadarLoadState: Equatable, Sendable {
    let contextID: UUID
    let frameDate: Date
    let referenceTime: Date
    let reloadRevision: Int
    var sequence = 0
    var requested = 0
    var succeeded = 0
    var failed = 0
    var pending = 0
    var cacheHits = 0
    var runUnavailable = 0
    var receivedBodyBytes: Int64 = 0
    var prefetchedBodyBytes: Int64 = 0
    var isViewportIdle = false
    var hasUnknownVisibleTileTotal: Bool { true }
    var isSettled: Bool { pending == 0 && (requested > 0 || isViewportIdle) }
}

// Mutable counters are lock protected. Every callback carries its viewport identity;
// superseded callbacks neither change the counters nor produce errors for the new view.
final class RadarLoadTracker: @unchecked Sendable {
    private enum Status { case pending, succeeded, cached, failed, runUnavailable }
    private let lock = NSLock()
    private var state: RadarLoadState
    private var tiles: [URL: Status] = [:]
    private var receivedTransports: Set<UUID> = []
    private let notify: @MainActor @Sendable (RadarLoadState) -> Void

    init(date: Date, referenceTime: Date, reloadRevision: Int,
         notify: @escaping @MainActor @Sendable (RadarLoadState) -> Void) {
        state = RadarLoadState(contextID: UUID(), frameDate: date,
                               referenceTime: referenceTime, reloadRevision: reloadRevision)
        self.notify = notify
    }

    var snapshot: RadarLoadState { lock.withLock { state } }

    func reset(reloadRevision: Int) -> RadarLoadState {
        lock.withLock {
            state = RadarLoadState(contextID: UUID(), frameDate: state.frameDate,
                                   referenceTime: state.referenceTime, reloadRevision: reloadRevision)
            tiles.removeAll()
            receivedTransports.removeAll()
            return state
        }
    }

    func endViewportDemand(contextID: UUID) {
        let value: RadarLoadState? = lock.withLock {
            guard state.contextID == contextID else { return nil }
            state.isViewportIdle = true
            return update()
        }
        if let value { publish(value) }
    }

    func began(_ url: URL) -> UUID {
        let snapshot = lock.withLock {
            if tiles[url] == nil { tiles[url] = .pending }
            return update()
        }
        publish(snapshot)
        return snapshot.contextID
    }

    func received(_ count: Int, for url: URL) {
        let value: RadarLoadState? = lock.withLock {
            guard tiles[url] != nil else { return nil }
            state.receivedBodyBytes += Int64(count)
            return update()
        }
        if let value { publish(value) }
    }

    func receivedOnce(_ count: Int, for url: URL, contextID: UUID, transportID: UUID) {
        let value: RadarLoadState? = lock.withLock {
            guard state.contextID == contextID, tiles[url] != nil,
                  receivedTransports.insert(transportID).inserted else { return nil }
            state.receivedBodyBytes += Int64(count)
            return update()
        }
        if let value { publish(value) }
    }

    func finished(_ url: URL, contextID: UUID, error: Error?, cached: Bool = false) {
        let value: RadarLoadState? = lock.withLock {
            guard state.contextID == contextID, tiles[url] != nil else { return nil }
            if (error as? URLError)?.code == .cancelled || error is CancellationError {
                // Cancellation is neither an incomplete image nor a successful one.
                tiles[url] = nil
            } else if let error {
                tiles[url] = (error as? DWDDataError) == .runUnavailable ? .runUnavailable : .failed
            } else { tiles[url] = cached ? .cached : .succeeded }
            return update()
        }
        if let value { publish(value) }
    }

    private func update() -> RadarLoadState {
        state.sequence += 1
        state.requested = tiles.count
        state.pending = tiles.values.filter { $0 == .pending }.count
        state.cacheHits = tiles.values.filter { $0 == .cached }.count
        state.succeeded = tiles.values.filter { $0 == .succeeded || $0 == .cached }.count
        state.runUnavailable = tiles.values.filter { $0 == .runUnavailable }.count
        state.failed = tiles.values.filter { $0 == .failed || $0 == .runUnavailable }.count
        return state
    }

    private func publish(_ value: RadarLoadState) {
        Task { @MainActor in notify(value) }
    }
}

// A run-level ceiling across overlays/frames: a temporarily unavailable source must
// not turn 32 requested tiles into 32 additional probes on every animation frame.
final class RadarAvailabilityRetryBudget: @unchecked Sendable {
    private struct Key: Hashable { let referenceTime: Date; let reloadRevision: Int }
    private struct Entry { let createdAt: Date; var used: Int }
    private let lock = NSLock()
    private var entries: [Key: Entry] = [:]
    private let limit: Int

    // Per (reference time, reload revision). ~1/3 InvalidDimensionValue rate and 32 visible
    // tiles cost ~14 retries per newly shown frame; each tile still retries at most twice.
    static let defaultLimit = 160
    init(limit: Int = RadarAvailabilityRetryBudget.defaultLimit) { self.limit = limit }

    func claim(referenceTime: Date, reloadRevision: Int, now: Date = Date()) -> Bool {
        lock.withLock {
            entries = entries.filter { now.timeIntervalSince($0.value.createdAt) < 1200 }
            let key = Key(referenceTime: referenceTime, reloadRevision: reloadRevision)
            if var entry = entries[key] {
                guard entry.used < limit else { return false }
                entry.used += 1
                entries[key] = entry
            } else {
                guard limit > 0 else { return false }
                if entries.count >= 16, let oldest = entries.min(by: { $0.value.createdAt < $1.value.createdAt })?.key {
                    entries[oldest] = nil
                }
                entries[key] = Entry(createdAt: now, used: 1)
            }
            return true
        }
    }
}

// Public weather images only; memory cache never persists coordinate-bearing URLs.
final class RadarTileOverlay: MKTileOverlay, @unchecked Sendable {
    private let date: Date
    private let referenceTime: Date
    private let requests = TileRequests()
    private let progress: RadarLoadTracker
    static let cache = TileMemoryCache()
    private let promotedOwner = UUID()
    private let pathLock = NSLock()
    private var paths: Set<RadarTileCoordinate> = []
    var observedPaths: [RadarTileCoordinate] {
        pathLock.withLock { paths.sorted { ($0.z, $0.x, $0.y) < ($1.z, $1.x, $1.y) } }
    }
    private static let availabilityRetries = RadarAvailabilityRetryBudget()
    private static let failures = RadarTileFailures()
    static func hasFailure(url: URL, revision: Int) -> Bool {
        failures.error(for: url, reloadRevision: revision) != nil
    }
    private let session: URLSession
    private let retryDelay: @Sendable (Int) -> TimeInterval
    private static let sharedSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 8
        configuration.timeoutIntervalForResource = 12
        configuration.httpMaximumConnectionsPerHost = 4
        return URLSession(configuration: configuration)
    }()

    init(date: Date, referenceTime: Date, reloadRevision: Int = 0,
         session: URLSession? = nil,
         retryDelay: @escaping @Sendable (Int) -> TimeInterval = { RadarRetryPolicy.delay(afterAttempt: $0) },
         onLoadState: @escaping @MainActor @Sendable (RadarLoadState) -> Void) {
        self.retryDelay = retryDelay
        self.date = date
        self.referenceTime = referenceTime
        self.session = session ?? Self.sharedSession
        self.progress = RadarLoadTracker(date: date, referenceTime: referenceTime,
                                         reloadRevision: reloadRevision, notify: onLoadState)
        super.init(urlTemplate: nil)
        canReplaceMapContent = false
        minimumZ = 4
        maximumZ = 11
        tileSize = CGSize(width: 256, height: 256)
    }

    override func url(forTilePath path: MKTileOverlayPath) -> URL {
        DWDRequest.tileURL(x: path.x, y: path.y, z: path.z, date: date, referenceTime: referenceTime)
    }

    func beginViewport(reloadRevision: Int) -> RadarLoadState {
        pathLock.withLock { paths.removeAll() }
        return progress.reset(reloadRevision: reloadRevision)
    }
    func endViewportDemand(contextID: UUID) { progress.endViewportDemand(contextID: contextID) }
    func cancelLoading() {
        requests.cancelAll()
        RadarPrefetchFlight.shared.cancelDemands(owner: promotedOwner)
    }

    override func loadTile(at path: MKTileOverlayPath, result: @escaping @Sendable (Data?, Error?) -> Void) {
        pathLock.withLock { paths.insert(RadarTileCoordinate(x: path.x, y: path.y, z: path.z)) }
        let url = url(forTilePath: path)
        let contextID = progress.began(url)
        let revision = progress.snapshot.reloadRevision
        let completion: TileRequests.ResultHandler = { [progress] data, error in
            RadarNetworkPriority.shared.endDemand()
            progress.finished(url, contextID: contextID, error: error)
            result(data, error)
        }
        if let cached = Self.cache.data(for: url) {
            progress.finished(url, contextID: contextID, error: nil, cached: true)
            result(cached, nil)
            return
        }
        // A same-key speculative request becomes foreground demand without a
        // second transport. Detaching speculative work cannot cancel this waiter.
        if RadarPrefetchFlight.shared.join(url: url, owner: promotedOwner, result: { [progress] response in
            if let data = response.data {
                progress.receivedOnce(data.count, for: url, contextID: contextID, transportID: response.transportID)
            }
            var failure = response.error
            var image: Data?
            if failure == nil {
                do {
                    guard (response.response as? HTTPURLResponse)?.statusCode == 200,
                          let data = response.data else { throw DWDDataError.unavailable }
                    image = try DWDResponse.radarImage(from: data)
                } catch { failure = error }
            }
            if let image { Self.cache.insert(image, for: url) }
            if let failure { Self.failures.record(failure, for: url, reloadRevision: revision) }
            completion(image, failure)
        }) { return }
        RadarNetworkPriority.shared.beginDemand()
        // MapKit automatically repeats failed requests. A viewport change must not
        // silently re-arm the network; only a new explicit refresh/run/frame may.
        if let error = Self.failures.error(for: url, reloadRevision: revision) {
            completion(nil, error)
            return
        }
        let id = UUID()
        let task = makeTask(url: url, id: id, attempt: 1)
        switch requests.add(task, url: url, id: id, result: completion) {
        case .start: task.resume()
        case .joined: task.cancel()
        case .cancelled:
            task.cancel()
            completion(nil, URLError(.cancelled))
        }
    }

    private func makeTask(url: URL, id: UUID, attempt: Int) -> URLSessionDataTask {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 8)
        request.setValue("ShowerNow/0.1 (native iOS rain radar)", forHTTPHeaderField: "User-Agent")
        let revision = progress.snapshot.reloadRevision
        return session.dataTask(with: request) { [self] data, response, error in
            guard requests.contains(url: url, id: id) else { return }
            if let data { progress.received(data.count, for: url) }
            var failure: Error? = error
            var image: Data?
            if failure == nil {
                do {
                    guard let response = response as? HTTPURLResponse, response.statusCode == 200,
                          let data else { throw DWDDataError.unavailable }
                    image = try DWDResponse.radarImage(from: data)
                } catch { failure = error }
            }
            if RadarRetryPolicy.shouldRetry(failure, attempt: attempt),
               Self.availabilityRetries.claim(referenceTime: referenceTime, reloadRevision: revision) {
                // At most two retries per request (jittered backoff) AND 160 extra requests
                // per run/reload across frames/overlays. Never retry arbitrary network or image errors.
                let retry = makeTask(url: url, id: id, attempt: attempt + 1)
                if requests.replace(retry, url: url, id: id) {
                    DispatchQueue.global().asyncAfter(deadline: .now() + retryDelay(attempt)) { retry.resume() }
                }
                else { retry.cancel() }
                return
            }
            if let failure {
                Self.failures.record(failure, for: url, reloadRevision: revision)
            }
            let callbacks = requests.finished(url: url, id: id)
            guard !callbacks.isEmpty else { return }
            if let image { Self.cache.insert(image, for: url) }
            callbacks.forEach { $0(image, failure) }
        }
    }
}

// Failed outcomes are not images. Keep them only in bounded memory, keyed by
// the full run/frame/tile URL and explicit refresh revision, across viewport/overlay
// recreation. 4096 entries covers >3 complete 32-tile × 37-frame animations; stale
// runs are discarded after the existing 20-minute freshness window. No URL is logged.
final class RadarTileFailures: @unchecked Sendable {
    private struct Key: Hashable { let url: URL; let reloadRevision: Int }
    private struct Entry { let error: Error; let createdAt: Date }
    private let lock = NSLock()
    private var entries: [Key: Entry] = [:]

    func error(for url: URL, reloadRevision: Int, now: Date = Date()) -> Error? {
        lock.withLock {
            entries = entries.filter { now.timeIntervalSince($0.value.createdAt) < 1200 }
            return entries[Key(url: url, reloadRevision: reloadRevision)]?.error
        }
    }

    func record(_ error: Error, for url: URL, reloadRevision: Int, now: Date = Date()) {
        guard (error as? URLError)?.code != .cancelled, !(error is CancellationError) else { return }
        lock.withLock {
            let key = Key(url: url, reloadRevision: reloadRevision)
            guard entries[key] == nil else { return }
            if entries.count >= 4096, let oldest = entries.min(by: { $0.value.createdAt < $1.value.createdAt })?.key {
                entries[oldest] = nil
            }
            entries[key] = Entry(error: error, createdAt: now)
        }
    }
}

// Every mutable field is protected by lock; callbacks and cancellation run outside it.
// Coalesce MapKit requests for the same tile while retaining per-overlay cancellation.
final class TileRequests: @unchecked Sendable {
    typealias ResultHandler = @Sendable (Data?, Error?) -> Void
    enum Registration: Equatable { case start, joined, cancelled }
    private struct Entry {
        let id: UUID
        let task: URLSessionDataTask
        var callbacks: [ResultHandler]
    }
    private let lock = NSLock()
    private var tasks: [URL: Entry] = [:]
    private var cancelled = false

    func add(_ task: URLSessionDataTask, url: URL, id: UUID,
             result: @escaping ResultHandler) -> Registration {
        lock.withLock {
            guard !cancelled else { return .cancelled }
            if tasks[url] != nil {
                tasks[url]?.callbacks.append(result)
                return .joined
            }
            tasks[url] = Entry(id: id, task: task, callbacks: [result])
            return .start
        }
    }

    func contains(url: URL, id: UUID) -> Bool {
        lock.withLock { tasks[url]?.id == id }
    }

    func replace(_ task: URLSessionDataTask, url: URL, id: UUID) -> Bool {
        lock.withLock {
            guard let entry = tasks[url], entry.id == id, !cancelled else { return false }
            tasks[url] = Entry(id: id, task: task, callbacks: entry.callbacks)
            return true
        }
    }

    func finished(url: URL, id: UUID) -> [ResultHandler] {
        lock.withLock {
            guard let entry = tasks[url], entry.id == id else { return [] }
            tasks[url] = nil
            return entry.callbacks
        }
    }

    func cancelAll() {
        let pending = lock.withLock {
            cancelled = true
            let pending = Array(tasks.values)
            tasks.removeAll()
            return pending
        }
        for entry in pending {
            entry.task.cancel()
            entry.callbacks.forEach { $0(nil, URLError(.cancelled)) }
        }
    }
    deinit { cancelAll() }
}
