import ImageIO
import MapKit
import Network

enum RadarBackendPolicy {
    /// A handful of parallel requests; every image is only a few KB.
    static let prefetchParallelism = 4
    /// Decoded 1024 x 1311 RGBA images are about 5 MB each, so only a few stay decoded.
    static let decodedImageLimit = 8
    /// A failed image is not requested again for this long (draw callbacks must not hammer).
    static let failureCooldown: TimeInterval = 5
}

enum RadarImageDecoder {
    /// Decodes a complete WebP/PNG with exactly the manifest's dimensions.
    static func decode(_ data: Data, width: Int, height: Int) -> CGImage? {
        guard !data.isEmpty, data.count <= RadarBackendConfig.maximumImageBytes,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) == 1,
              let image = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary),
              image.width == width, image.height == height,
              CGImageSourceGetStatusAtIndex(source, 0) == .statusComplete else { return nil }
        return image
    }
}

/// Small LRU of decoded images (memory only).
final class DecodedImageCache: @unchecked Sendable {
    private let lock = NSLock()
    private let limit: Int
    private var entries: [(url: URL, image: CGImage)] = []
    init(limit: Int = RadarBackendPolicy.decodedImageLimit) { self.limit = max(1, limit) }
    func image(for url: URL) -> CGImage? {
        lock.withLock {
            guard let index = entries.firstIndex(where: { $0.url == url }) else { return nil }
            let entry = entries.remove(at: index)
            entries.append(entry)
            return entry.image
        }
    }
    func insert(_ image: CGImage, for url: URL) {
        lock.withLock {
            entries.removeAll { $0.url == url }
            entries.append((url, image))
            if entries.count > limit { entries.removeFirst(entries.count - limit) }
        }
    }
    var count: Int { lock.withLock { entries.count } }
}

/// Loads, validates and caches the whole-Germany slot images of one backend manifest.
/// Image URLs are immutable (run + slot), so cached entries never go stale; a new run
/// simply stops referencing old ones (`retain`) and the byte-limited cache evicts them.
final class BackendRadarLoader: @unchecked Sendable {
    typealias Fetch = @Sendable (URL) async throws -> Data
    typealias Decode = @Sendable (Data) -> CGImage?
    static let sharedCache = TileMemoryCache()

    let manifest: RadarManifest
    private let cache: TileMemoryCache
    private let decoded = DecodedImageCache()
    private let fetch: Fetch
    private let decode: Decode
    private let lock = NSLock()
    private var inflight: [URL: Task<Bool, Never>] = [:]
    private var failedAt: [URL: Date] = [:]
    private var prefetchTask: Task<Void, Never>?
    private var bytes: Int64 = 0
    private var successes = 0
    private var failures = 0

    init(manifest: RadarManifest, cache: TileMemoryCache = BackendRadarLoader.sharedCache,
         fetch: Fetch? = nil, decode: Decode? = nil) {
        self.manifest = manifest
        self.cache = cache
        self.fetch = fetch ?? BackendRadarLoader.makeFetch()
        let width = manifest.imageWidth, height = manifest.imageHeight
        self.decode = decode ?? { RadarImageDecoder.decode($0, width: width, height: height) }
        cache.retain(Set(manifest.slots.map(\.url)))
    }

    deinit { prefetchTask?.cancel() }

    var receivedBytes: Int64 { lock.withLock { bytes } }
    var successCount: Int { lock.withLock { successes } }
    var failureCount: Int { lock.withLock { failures } }

    func hasImage(for url: URL) -> Bool { cache.contains(url) || decoded.image(for: url) != nil }

    /// Synchronous lookup for drawing; re-decodes from the compressed cache if needed.
    func image(for url: URL) -> CGImage? {
        if let image = decoded.image(for: url) { return image }
        guard let data = cache.data(for: url), let image = decode(data) else { return nil }
        decoded.insert(image, for: url)
        return image
    }

    /// Loads one image (sharing an in-flight request) and reports whether it is usable.
    func demand(_ url: URL) async -> Bool {
        if image(for: url) != nil { return true }
        let task: Task<Bool, Never> = lock.withLock {
            if let existing = inflight[url] { return existing }
            if let failed = failedAt[url], Date().timeIntervalSince(failed) < RadarBackendPolicy.failureCooldown {
                return Task { false }
            }
            let created = Task { [self] in
                let ok = await load(url)
                lock.withLock { inflight[url] = nil }
                return ok
            }
            inflight[url] = created
            return created
        }
        return await task.value
    }

    private func load(_ url: URL) async -> Bool {
        do {
            let data = try await fetch(url)
            guard let image = decode(data) else { throw RadarBackendError.invalid }
            cache.insertTrusted(data, for: url)
            decoded.insert(image, for: url)
            lock.withLock { bytes += Int64(data.count); successes += 1; failedAt[url] = nil }
            return true
        } catch {
            lock.withLock { failures += 1; failedAt[url] = Date() }
            return false
        }
    }

    /// Alternating left/right from the selected slot with a few parallel requests.
    func prefetch(selected: Int, allowed: @escaping @Sendable () -> Bool) {
        let urls = RadarPrefetchPolicy.order(selected: selected, count: manifest.slots.count).map { manifest.slots[$0].url }
        let queue = PrefetchQueue(urls)
        let task = Task { [self] in
            await withTaskGroup(of: Void.self) { group in
                for _ in 0..<RadarBackendPolicy.prefetchParallelism {
                    group.addTask { [self] in
                        while !Task.isCancelled, allowed(), let url = queue.next() {
                            if hasImage(for: url) { continue }
                            _ = await demand(url)
                        }
                    }
                }
            }
        }
        lock.withLock { prefetchTask?.cancel(); prefetchTask = task }
    }

    func cancelPrefetch() {
        lock.withLock { prefetchTask?.cancel(); prefetchTask = nil }
    }

    private final class PrefetchQueue: @unchecked Sendable {
        private let lock = NSLock()
        private var items: [URL]
        init(_ items: [URL]) { self.items = items }
        func next() -> URL? { lock.withLock { items.isEmpty ? nil : items.removeFirst() } }
    }

    private static func makeFetch() -> Fetch {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCredentialStorage = nil
        configuration.timeoutIntervalForRequest = 8
        configuration.timeoutIntervalForResource = 15
        configuration.httpMaximumConnectionsPerHost = RadarBackendPolicy.prefetchParallelism + 2
        let session = URLSession(configuration: configuration)
        return { url in
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 8)
            request.httpShouldHandleCookies = false
            let (data, response) = try await session.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  !data.isEmpty, data.count <= RadarBackendConfig.maximumImageBytes else { throw RadarBackendError.invalid }
            return data
        }
    }
}

/// Reports Low Data Mode for the optional prefetch (demand for the visible slot stays allowed).
final class RadarPathGate: @unchecked Sendable {
    private let monitor = NWPathMonitor()
    private let lock = NSLock()
    private var constrained = false
    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            lock.withLock { constrained = path.isConstrained || path.status != .satisfied }
        }
        monitor.start(queue: DispatchQueue(label: "weather.backend.path"))
    }
    deinit { monitor.cancel() }
    var isConstrained: Bool { lock.withLock { constrained } }
}

/// One overlay per manifest; the shown slot changes without replacing the overlay, so
/// scrubbing redraws from memory instead of swapping map layers.
final class RadarImageOverlay: NSObject, MKOverlay, @unchecked Sendable {
    let loader: BackendRadarLoader
    let boundingMapRect: MKMapRect
    let coordinate: CLLocationCoordinate2D
    private let lock = NSLock()
    private var shownURL: URL?

    init(loader: BackendRadarLoader) {
        self.loader = loader
        let rect = RadarImageGeometry.mapRect(for: loader.manifest.bounds)
        boundingMapRect = MKMapRect(x: rect.x, y: rect.y, width: rect.width, height: rect.height)
        coordinate = MKMapPoint(x: rect.x + rect.width / 2, y: rect.y + rect.height / 2).coordinate
        super.init()
    }

    var slotURL: URL? {
        get { lock.withLock { shownURL } }
        set { lock.withLock { shownURL = newValue } }
    }

    func currentImage() -> CGImage? {
        guard let url = slotURL else { return nil }
        return loader.image(for: url)
    }
}

final class RadarImageRenderer: MKOverlayRenderer {
    override func canDraw(_ mapRect: MKMapRect, zoomScale: MKZoomScale) -> Bool {
        (overlay as? RadarImageOverlay)?.currentImage() != nil
    }

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        guard let overlay = overlay as? RadarImageOverlay, let image = overlay.currentImage() else { return }
        let bounds = overlay.boundingMapRect
        let visible = mapRect.intersection(bounds)
        guard !visible.isNull, visible.width > 0, visible.height > 0 else { return }
        // Draw only the part of the image this tile chunk needs (1 px margin for interpolation),
        // never the whole image scaled to the full overlay size.
        let scale = Double(image.width) / bounds.width
        var source = CGRect(x: (visible.minX - bounds.minX) * scale, y: (visible.minY - bounds.minY) * scale,
                            width: visible.width * scale, height: visible.height * scale)
            .insetBy(dx: -1, dy: -1).integral
            .intersection(CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard !source.isNull, source.width >= 1, source.height >= 1, let part = image.cropping(to: source) else { return }
        source = CGRect(x: source.minX, y: source.minY, width: CGFloat(part.width), height: CGFloat(part.height))
        let destination = self.rect(for: MKMapRect(x: bounds.minX + source.minX / scale, y: bounds.minY + source.minY / scale,
                                                   width: source.width / scale, height: source.height / scale))
        context.saveGState()
        context.interpolationQuality = .medium
        // Renderer contexts are flipped (y down); CGImage needs an upright drawing space.
        context.translateBy(x: destination.minX, y: destination.maxY)
        context.scaleBy(x: 1, y: -1)
        context.draw(part, in: CGRect(x: 0, y: 0, width: destination.width, height: destination.height))
        context.restoreGState()
    }
}
