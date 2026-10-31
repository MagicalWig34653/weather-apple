import CoreGraphics
import Foundation

/// Class of one pixel of the EUMETView cloud mask (`msg_fes:clm`, SEVIRI cloud mask).
///
/// Colour meaning (checked 31 Oct 2026, see docs/research/sonnenradar.md "clm-Farben"):
/// the official legend (GetLegendGraphic) names blue = "Clear sky over water", green = "Clear sky over land",
/// "Cloud" = the remaining class; the layer abstract names a fourth class "not processed (off Earth disc)",
/// which GetMap delivers fully transparent. White = cloud was confirmed by comparing with the visible channel
/// (`msg_fes:vis006`, same slot): white pixels were about three times brighter than green ones.
/// Everything that is not close to one of these colours (resampling edge pixels) is `unknown` and stays neutral.
enum CloudMaskClass: UInt8, Equatable, Sendable {
    case unknown, cloud, clearLand, clearWater

    var isClear: Bool { self == .clearLand || self == .clearWater }

    /// Reference colours of the layer (RGB). Land green varies by one level (0/1, 192), so a tolerance is used.
    static let cloudRGB: (UInt8, UInt8, UInt8) = (255, 255, 255)
    static let landRGB: (UInt8, UInt8, UInt8) = (0, 192, 0)
    static let waterRGB: (UInt8, UInt8, UInt8) = (0, 0, 255)
    /// Maximum Euclidean RGB distance to a reference colour (5.6 % of the cube diagonal). Measured: 91.8 to
    /// 98.5 % of the pixels of real slots are within 10 of a reference colour, the rest are resampling mixes.
    static let tolerance = 60

    static func classify(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) -> CloudMaskClass {
        guard alpha >= 200 else { return .unknown }
        let r = Int(red), g = Int(green), b = Int(blue)
        func distance(_ c: (UInt8, UInt8, UInt8)) -> Int {
            let dr = r - Int(c.0), dg = g - Int(c.1), db = b - Int(c.2)
            return dr * dr + dg * dg + db * db
        }
        let limit = tolerance * tolerance
        let cloudDistance = distance(cloudRGB), landDistance = distance(landRGB), waterDistance = distance(waterRGB)
        var best = CloudMaskClass.cloud, bestDistance = cloudDistance
        if landDistance < bestDistance { best = .clearLand; bestDistance = landDistance }
        if waterDistance < bestDistance { best = .clearWater; bestDistance = waterDistance }
        return bestDistance <= limit ? best : .unknown
    }
}

/// Web-Mercator helpers for the fixed whole-image grid (EPSG:3857, bbox of the manifest).
enum SunGeometry {
    static let earthRadius = 6_378_137.0

    static func longitude(x: Double) -> Double { x / earthRadius * 180 / .pi }
    static func latitude(y: Double) -> Double { (2 * atan(exp(y / earthRadius)) - .pi / 2) * 180 / .pi }
    static func mercatorX(longitude: Double) -> Double { longitude * .pi / 180 * earthRadius }
    static func mercatorY(latitude: Double) -> Double {
        earthRadius * log(tan(.pi / 4 + latitude * .pi / 360))
    }

    /// Pixel (column, row) of a coordinate in an image of `width` x `height`, `nil` outside the image.
    static func pixel(latitude: Double, longitude: Double, bounds: RadarBounds, width: Int, height: Int) -> (x: Int, y: Int)? {
        guard latitude.isFinite, longitude.isFinite, abs(latitude) < 85 else { return nil }
        let fx = (mercatorX(longitude: longitude) - bounds.minX) / (bounds.maxX - bounds.minX)
        let fy = (bounds.maxY - mercatorY(latitude: latitude)) / (bounds.maxY - bounds.minY)
        guard (0..<1).contains(fx), (0..<1).contains(fy) else { return nil }
        return (Int(fx * Double(width)), Int(fy * Double(height)))
    }
}

/// Builds the sun overlay from a cloud mask image and the sun position of the slot time.
///
/// Result (RGBA, premultiplied, same size as the mask):
/// - day (sun height >= 0): clear = warm yellow ("sonnig"), cloud = grey, unknown = transparent;
/// - below the horizon: dark blue shade that grows with depth (civil, nautical, astronomical twilight, night);
///   the cloud mask is not tinted there, because without sunlight it says nothing about sun;
/// - a thin line at the terminator (geometric sun height -0.833 degrees, sunrise definition of `SolarPosition`).
enum SunOverlay {
    /// Premultiplied output colours: (r, g, b) straight, alpha 0...1.
    struct Colour { let r: Double, g: Double, b: Double, a: Double }
    static let sunny = Colour(r: 255, g: 196, b: 0, a: 0.55)
    static let cloudy = Colour(r: 92, g: 102, b: 118, a: 0.38)
    static let shade = (r: 8.0, g: 14.0, b: 42.0)
    static let terminatorLine = Colour(r: 255, g: 236, b: 190, a: 0.9)
    /// Half width of the terminator line in degrees of sun height (about 3 px at the 1024 px image).
    static let terminatorHalfWidth = 0.02

    private static let shadeStops: [(Double, Double)] = [(SolarPosition.sunriseElevation, 0), (-6, 0.30), (-12, 0.50), (-18, 0.62), (-24, 0.68)]

    /// Shade opacity by sun height (degrees): 0 at sunrise height, 0.30 civil, 0.50 nautical, 0.62 astronomical,
    /// 0.68 night (linear in between).
    static func shadeAlpha(elevation h: Double) -> Double {
        if h >= SolarPosition.sunriseElevation { return 0 }
        for i in 1..<shadeStops.count where h >= shadeStops[i].0 {
            let (h0, a0) = shadeStops[i - 1], (h1, a1) = shadeStops[i]
            return a0 + (a1 - a0) * (h - h0) / (h1 - h0)
        }
        return shadeStops[shadeStops.count - 1].1
    }

    /// Core: `rgba` is the premultiplied RGBA mask (4 bytes per pixel, row 0 = north).
    static func render(rgba: [UInt8], width: Int, height: Int, bounds: RadarBounds, date: Date) -> [UInt8] {
        precondition(width >= 1 && height >= 1 && rgba.count == width * height * 4)
        let p = SolarPosition.Parameters(date: date)
        let deltaRad = p.declination * .pi / 180
        let sinD = sin(deltaRad), cosD = cos(deltaRad)
        var cosH = [Double](repeating: 0, count: width)
        for c in 0..<width {
            let x = bounds.minX + (bounds.maxX - bounds.minX) * (Double(c) + 0.5) / Double(width)
            cosH[c] = cos((SunGeometry.longitude(x: x) - p.subsolarLongitude) * .pi / 180)
        }
        var out = [UInt8](repeating: 0, count: rgba.count)
        let top = SolarPosition.sunriseElevation
        rgba.withUnsafeBufferPointer { src in
            out.withUnsafeMutableBufferPointer { dst in
                for r in 0..<height {
                    let y = bounds.maxY - (bounds.maxY - bounds.minY) * (Double(r) + 0.5) / Double(height)
                    let latRad = SunGeometry.latitude(y: y) * .pi / 180
                    let a = sin(latRad) * sinD, b = cos(latRad) * cosD
                    for c in 0..<width {
                        let i = (r * width + c) * 4
                        let h = asin(min(1, max(-1, a + b * cosH[c]))) * 180 / .pi
                        // Straight colour and alpha of the pixel before the shade.
                        var cr = 0.0, cg = 0.0, cb = 0.0, ca = 0.0
                        if h >= 0 {
                            switch CloudMaskClass.classify(red: src[i], green: src[i + 1], blue: src[i + 2], alpha: src[i + 3]) {
                            case .clearLand, .clearWater: (cr, cg, cb, ca) = (sunny.r, sunny.g, sunny.b, sunny.a)
                            case .cloud: (cr, cg, cb, ca) = (cloudy.r, cloudy.g, cloudy.b, cloudy.a)
                            case .unknown: break
                            }
                        }
                        // Premultiplied composition: shade over tint, then the terminator line over both.
                        var pr = cr * ca, pg = cg * ca, pb = cb * ca, pa = ca
                        let sa = shadeAlpha(elevation: h)
                        if sa > 0 {
                            pr = shade.r * sa + pr * (1 - sa)
                            pg = shade.g * sa + pg * (1 - sa)
                            pb = shade.b * sa + pb * (1 - sa)
                            pa = sa + pa * (1 - sa)
                        }
                        if abs(h - top) < terminatorHalfWidth {
                            let la = terminatorLine.a
                            pr = terminatorLine.r * la + pr * (1 - la)
                            pg = terminatorLine.g * la + pg * (1 - la)
                            pb = terminatorLine.b * la + pb * (1 - la)
                            pa = la + pa * (1 - la)
                        }
                        dst[i] = UInt8(min(255, pr.rounded()))
                        dst[i + 1] = UInt8(min(255, pg.rounded()))
                        dst[i + 2] = UInt8(min(255, pb.rounded()))
                        dst[i + 3] = UInt8(min(255, (pa * 255).rounded()))
                    }
                }
            }
        }
        return out
    }

    // MARK: CGImage in, CGImage out

    /// Premultiplied RGBA bytes of an image (any source format), `nil` for degenerate sizes.
    static func pixels(of image: CGImage) -> [UInt8]? {
        let width = image.width, height = image.height
        guard width >= 1, height >= 1, width <= 4096, height <= 4096 else { return nil }
        var data = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = data.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                          bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.interpolationQuality = .none
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        return drawn ? data : nil
    }

    static func compose(mask: CGImage, bounds: RadarBounds, date: Date) -> CGImage? {
        guard let rgba = pixels(of: mask) else { return nil }
        let out = render(rgba: rgba, width: mask.width, height: mask.height, bounds: bounds, date: date)
        return image(rgba: out, width: mask.width, height: mask.height)
    }

    static func image(rgba: [UInt8], width: Int, height: Int) -> CGImage? {
        guard let provider = CGDataProvider(data: Data(rgba) as CFData) else { return nil }
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                       space: CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }
}

/// Composes and caches sun overlay images per mask slot (a few images of about 5 MB). Called from the
/// map renderer's drawing thread, never from the main thread; the lock makes a slot compose only once.
final class SunOverlayComposer: @unchecked Sendable {
    let bounds: RadarBounds
    private let limit: Int
    private let lock = NSLock()
    private var entries: [(url: URL, image: CGImage)] = []
    private(set) var composeCount = 0
    private(set) var lastDuration: TimeInterval = 0

    init(bounds: RadarBounds, limit: Int = 4) {
        self.bounds = bounds
        self.limit = max(1, limit)
    }

    func image(for url: URL, time: Date, mask: () -> CGImage?) -> CGImage? {
        lock.lock(); defer { lock.unlock() }
        if let index = entries.firstIndex(where: { $0.url == url }) {
            let entry = entries.remove(at: index)
            entries.append(entry)
            return entry.image
        }
        guard let maskImage = mask() else { return nil }
        let start = Date()
        guard let composed = SunOverlay.compose(mask: maskImage, bounds: bounds, date: time) else { return nil }
        lastDuration = Date().timeIntervalSince(start)
        composeCount += 1
        entries.append((url, composed))
        if entries.count > limit { entries.removeFirst(entries.count - limit) }
        return composed
    }
}

// MARK: - Place line

/// Text lines of the place view: sun times (always from the sun position) and, only when the cloud mask is
/// unambiguous at the place, the current cloud state.
enum SunPlace {
    /// All maps of the app cover Germany and its neighbours (bbox 5.5 to 15.6 degrees east): one time zone.
    static let regionTimeZone = TimeZone(identifier: "Europe/Berlin") ?? .current

    static func sunLine(at date: Date, latitude: Double, longitude: Double, timeZone: TimeZone = regionTimeZone) -> String {
        SolarPosition.sunLabel(at: date, latitude: latitude, longitude: longitude, timeZone: timeZone)
    }

    /// Cloud class at the place: the 3 x 3 pixels around it must all be clear or all cloud, otherwise `nil`
    /// (mixed, unknown, off the image or outside the mask's data).
    static func cloudClass(in mask: CGImage, bounds: RadarBounds, latitude: Double, longitude: Double) -> CloudMaskClass? {
        guard let pixel = SunGeometry.pixel(latitude: latitude, longitude: longitude, bounds: bounds,
                                            width: mask.width, height: mask.height),
              let rgba = pixels(around: pixel, in: mask) else { return nil }
        return unambiguous(rgba: rgba)
    }

    static func unambiguous(rgba: [UInt8]) -> CloudMaskClass? {
        var clear = 0, cloud = 0, total = 0
        var i = 0
        while i + 3 < rgba.count {
            total += 1
            switch CloudMaskClass.classify(red: rgba[i], green: rgba[i + 1], blue: rgba[i + 2], alpha: rgba[i + 3]) {
            case .clearLand, .clearWater: clear += 1
            case .cloud: cloud += 1
            case .unknown: return nil
            }
            i += 4
        }
        if total > 0, clear == total { return .clearLand }
        if total > 0, cloud == total { return .cloud }
        return nil
    }

    private static func pixels(around pixel: (x: Int, y: Int), in image: CGImage) -> [UInt8]? {
        let x0 = max(0, pixel.x - 1), y0 = max(0, pixel.y - 1)
        let x1 = min(image.width - 1, pixel.x + 1), y1 = min(image.height - 1, pixel.y + 1)
        guard let part = image.cropping(to: CGRect(x: x0, y: y0, width: x1 - x0 + 1, height: y1 - y0 + 1)) else { return nil }
        return SunOverlay.pixels(of: part)
    }

    /// "Aktuell klar (Satellit, vor 32 min)" / "Aktuell bewölkt (...)". `nil` without an unambiguous class.
    static func cloudLine(_ cloudClass: CloudMaskClass?, slotTime: Date, now: Date) -> String? {
        guard let cloudClass, cloudClass != .unknown else { return nil }
        let minutes = max(0, Int((now.timeIntervalSince(slotTime) / 60).rounded(.down)))
        return "Aktuell \(cloudClass.isClear ? "klar" : "bewölkt") (Satellit, vor \(minutes) min)"
    }
}
