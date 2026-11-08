import ImageIO
import MapKit
import UIKit

/// Metadata of the bundled forest image (`forest-de-v1.json`, tool `tools/forest_overlay.py`).
struct ForestInfo: Equatable, Sendable {
    let bounds: RadarBounds
    let width: Int, height: Int
    let attribution: String
    let modificationNotice: String

    private struct Raw: Decodable {
        let schema: Int
        let boundsEpsg3857: [Double]
        let width: Int, height: Int
        let attribution: String, modificationNotice: String
    }

    static func parse(_ data: Data) -> ForestInfo? {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard data.count <= 20_000, let raw = try? decoder.decode(Raw.self, from: data), raw.schema == 1,
              raw.boundsEpsg3857.count == 4, raw.boundsEpsg3857.allSatisfy({ $0.isFinite && abs($0) <= RadarBounds.halfWorld + 1 }),
              raw.boundsEpsg3857[0] < raw.boundsEpsg3857[2], raw.boundsEpsg3857[1] < raw.boundsEpsg3857[3],
              (1...4096).contains(raw.width), (1...4096).contains(raw.height),
              !raw.attribution.trimmingCharacters(in: .whitespaces).isEmpty,
              !raw.modificationNotice.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        let b = raw.boundsEpsg3857
        return ForestInfo(bounds: RadarBounds(minX: b[0], minY: b[1], maxX: b[2], maxY: b[3]), width: raw.width, height: raw.height,
                          attribution: raw.attribution, modificationNotice: raw.modificationNotice)
    }

    static let bundled: ForestInfo? = {
        guard let url = Bundle.main.url(forResource: "forest-de-v1", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return parse(data)
    }()

    /// Source line shown only while the forest is visible.
    var sourceLine: String { "\(attribution). \(modificationNotice)." }
}

/// User setting of the forest layer (device only, default off). Offered for the 2 m fields only.
enum ForestPreference {
    static let key = "radar.forest.visible"
    static func isVisible(_ defaults: UserDefaults = .standard) -> Bool { defaults.bool(forKey: key) }
    static func set(_ visible: Bool, _ defaults: UserDefaults = .standard) { defaults.set(visible, forKey: key) }
    /// Forest is drawn only with the switch on, over a 2 m field, and when the bundled data is intact.
    static func isShown(layer: RadarLayer, visible: Bool, info: ForestInfo?) -> Bool { layer.isAirField && visible && info != nil }

    /// Bottom source line: the layer's own line, extended by the forest source only while the forest is shown.
    static func sourceLine(base: String?, layer: RadarLayer, visible: Bool, info: ForestInfo?) -> String? {
        guard let base else { return nil }
        guard isShown(layer: layer, visible: visible, info: info), let info else { return base }
        return "\(base) · \(info.sourceLine)"
    }
}

/// Decoded forest image (about 21.5 MB RGBA): decoded on first draw, released on memory warning or when the
/// overlay goes away; the next draw decodes it again.
final class ForestImageStore: @unchecked Sendable {
    static let shared = ForestImageStore()
    private let lock = NSLock()
    private var image: CGImage?
    private var observer: NSObjectProtocol?

    init(observeMemoryWarnings: Bool = true) {
        if observeMemoryWarnings {
            observer = NotificationCenter.default.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification,
                                                              object: nil, queue: nil) { [weak self] _ in self?.release() }
        }
    }
    deinit { if let observer { NotificationCenter.default.removeObserver(observer) } }

    var isLoaded: Bool { lock.withLock { image != nil } }

    func release() { lock.withLock { image = nil } }

    func current(info: ForestInfo, url: URL? = Bundle.main.url(forResource: "forest-de-v1", withExtension: "webp")) -> CGImage? {
        lock.withLock {
            if let image { return image }
            guard let url, let source = CGImageSourceCreateWithURL(url as CFURL, nil), CGImageSourceGetCount(source) == 1,
                  let decoded = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary),
                  decoded.width == info.width, decoded.height == info.height else { return nil }
            image = decoded
            return decoded
        }
    }
}

final class ForestOverlay: NSObject, MKOverlay, @unchecked Sendable {
    let info: ForestInfo
    let store: ForestImageStore
    let boundingMapRect: MKMapRect
    let coordinate: CLLocationCoordinate2D
    /// App-side opacity: the image alpha is the forest share (4 steps), this keeps the field readable below it.
    static let opacity: CGFloat = 0.55

    init(info: ForestInfo, store: ForestImageStore = .shared) {
        self.info = info
        self.store = store
        let rect = RadarImageGeometry.mapRect(for: info.bounds)
        boundingMapRect = MKMapRect(x: rect.x, y: rect.y, width: rect.width, height: rect.height)
        coordinate = MKMapPoint(x: rect.x + rect.width / 2, y: rect.y + rect.height / 2).coordinate
    }
}

final class ForestOverlayRenderer: MKOverlayRenderer {
    override func canDraw(_ mapRect: MKMapRect, zoomScale: MKZoomScale) -> Bool { true }

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        guard let overlay = overlay as? ForestOverlay, let image = overlay.store.current(info: overlay.info) else { return }
        // Nearest neighbour while zoomed in (blocks of about 550 m stay crisp); smoothing when zoomed out.
        let imagePixelOnScreen = overlay.boundingMapRect.width / Double(image.width) * Double(zoomScale)
        drawCropped(image, imageBounds: overlay.boundingMapRect, mapRect: mapRect, in: context,
                    quality: imagePixelOnScreen >= 1 ? .none : .medium)
    }
}

extension MKOverlayRenderer {
    /// Draws only the part of `image` (covering `imageBounds`) that `mapRect` needs, with a 1 px margin.
    /// Never the whole image scaled to the full overlay size (MapKit's texture limit).
    func drawCropped(_ image: CGImage, imageBounds bounds: MKMapRect, mapRect: MKMapRect, in context: CGContext,
                     quality: CGInterpolationQuality) {
        let visible = mapRect.intersection(bounds)
        guard !visible.isNull, visible.width > 0, visible.height > 0 else { return }
        let scale = Double(image.width) / bounds.width
        var source = CGRect(x: (visible.minX - bounds.minX) * scale, y: (visible.minY - bounds.minY) * scale,
                            width: visible.width * scale, height: visible.height * scale)
            .insetBy(dx: -1, dy: -1).integral
            .intersection(CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard !source.isNull, source.width >= 1, source.height >= 1, let part = image.cropping(to: source) else { return }
        source = CGRect(x: source.minX, y: source.minY, width: CGFloat(part.width), height: CGFloat(part.height))
        let destination = rect(for: MKMapRect(x: bounds.minX + source.minX / scale, y: bounds.minY + source.minY / scale,
                                              width: source.width / scale, height: source.height / scale))
        context.saveGState()
        context.interpolationQuality = quality
        // Renderer contexts are flipped (y down); CGImage needs an upright drawing space.
        context.translateBy(x: destination.minX, y: destination.maxY)
        context.scaleBy(x: 1, y: -1)
        context.draw(part, in: CGRect(x: 0, y: 0, width: destination.width, height: destination.height))
        context.restoreGState()
    }
}
