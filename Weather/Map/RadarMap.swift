import MapKit
import SwiftUI

struct RadarMap: UIViewRepresentable {
    let place: SavedPlace
    let date: Date?
    let referenceTime: Date?
    let centerRevision: Int
    let reloadRevision: Int
    let bottomInset: CGFloat
    let onSelect: (CLLocationCoordinate2D) -> Void
    let onTileError: @MainActor @Sendable () -> Void

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
        center(map)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
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
        guard coordinator.date != date || coordinator.referenceTime != referenceTime
                || coordinator.reloadRevision != reloadRevision else { return }
        coordinator.date = date
        coordinator.referenceTime = referenceTime
        coordinator.reloadRevision = reloadRevision
        for case let overlay as RadarTileOverlay in map.overlays { overlay.cancelLoading() }
        map.removeOverlays(map.overlays)
        if let date, let referenceTime {
            let overlay = RadarTileOverlay(date: date, referenceTime: referenceTime, onError: onTileError)
            map.addOverlay(overlay, level: .aboveRoads)
        }
    }

    private func center(_ map: MKMapView) {
        map.setRegion(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: place.coordinate.latitude,
                                                                       longitude: place.coordinate.longitude),
                                        latitudinalMeters: 180_000, longitudinalMeters: 180_000), animated: true)
    }

    @MainActor final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: RadarMap
        weak var map: MKMapView?
        var date: Date?
        var referenceTime: Date?
        var reloadRevision = -1
        var lastCenterRevision = -1
        var placeID: UUID?

        init(parent: RadarMap) { self.parent = parent }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
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

// Public weather images only; tile cache is in memory and never stores point-query URLs on disk.
final class RadarTileOverlay: MKTileOverlay, @unchecked Sendable {
    private let date: Date
    private let referenceTime: Date
    private let onError: @MainActor @Sendable () -> Void
    private let requests = TileRequests()
    private static let cache = TileMemoryCache()
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 20
        configuration.httpMaximumConnectionsPerHost = 4
        return URLSession(configuration: configuration)
    }()

    init(date: Date, referenceTime: Date, onError: @escaping @MainActor @Sendable () -> Void) {
        self.date = date
        self.referenceTime = referenceTime
        self.onError = onError
        super.init(urlTemplate: nil)
        canReplaceMapContent = false
        minimumZ = 4
        maximumZ = 11
        tileSize = CGSize(width: 256, height: 256)
    }

    override func url(forTilePath path: MKTileOverlayPath) -> URL {
        DWDRequest.tileURL(x: path.x, y: path.y, z: path.z, date: date, referenceTime: referenceTime)
    }

    func cancelLoading() { requests.cancelAll() }

    override func loadTile(at path: MKTileOverlayPath, result: @escaping @Sendable (Data?, Error?) -> Void) {
        let url = url(forTilePath: path)
        if let cached = Self.cache.data(for: url) {
            result(cached, nil)
            return
        }
        let notify = onError
        let registry = requests
        let id = UUID()
        let task = Self.session.dataTask(with: url) { data, response, error in
            let callbacks = registry.finished(url: url, id: id)
            guard !callbacks.isEmpty else { return }
            if let error {
                callbacks.forEach { $0(nil, error) }
                if (error as? URLError)?.code != .cancelled {
                    Task { @MainActor in notify() }
                }
                return
            }
            guard let response = response as? HTTPURLResponse, response.statusCode == 200,
                  let data, data.starts(with: [137, 80, 78, 71, 13, 10, 26, 10]) else {
                callbacks.forEach { $0(nil, URLError(.cannotDecodeContentData)) }
                Task { @MainActor in notify() }
                return
            }
            Self.cache.insert(data, for: url)
            callbacks.forEach { $0(data, nil) }
        }
        switch registry.add(task, url: url, id: id, result: result) {
        case .start: task.resume()
        case .joined: task.cancel()
        case .cancelled:
            task.cancel()
            result(nil, URLError(.cancelled))
        }
    }
}

// NSCache is thread-safe; the immutable wrapper exposes no other mutable state.
private final class TileMemoryCache: @unchecked Sendable {
    private let cache = NSCache<NSURL, NSData>()
    init() { cache.totalCostLimit = 48 * 1_024 * 1_024 }
    func data(for url: URL) -> Data? { cache.object(forKey: url as NSURL).map { $0 as Data } }
    func insert(_ data: Data, for url: URL) { cache.setObject(data as NSData, forKey: url as NSURL, cost: data.count) }
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
