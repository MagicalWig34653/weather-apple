import CoreGraphics
import MapKit

enum WatchMapZoom: Int, CaseIterable, Sendable {
    case near, regional, wide

    // Widths equal the diameters of RadarCrop.Zoom (40/70/100 km radius) so map and radar crop cover the same area.
    /// Ground width at the selected latitude, not EPSG:3857 metres.
    var widthMeters: Double {
        switch self {
        case .near: 80_000
        case .regional: 140_000
        case .wide: 200_000
        }
    }
}

enum WatchMapAppearance: Sendable {
    case light, dark
}

/// Use the actual radar view's size in points and the watch's display scale.
/// This supports Series and Ultra layouts without a device-model table.
struct WatchMapBackdropRequest {
    let coordinate: CLLocationCoordinate2D
    let zoom: WatchMapZoom
    let size: CGSize
    let scale: CGFloat
    let appearance: WatchMapAppearance
}

/// EPSG:3857 metres (east/north) to image pixels (right/down, top-left origin).
/// RadarCrop owns cropping; apply this mapping to its Mercator corners to align the image.
struct WatchMapProjection: Sendable {
    let originMercator: CGPoint
    let originPixel: CGPoint
    let eastPixelsPerMeter: CGPoint
    let northPixelsPerMeter: CGPoint

    func pixelPoint(forMercator point: CGPoint) -> CGPoint {
        let east = point.x - originMercator.x
        let north = point.y - originMercator.y
        return CGPoint(
            x: originPixel.x + east * eastPixelsPerMeter.x + north * northPixelsPerMeter.x,
            y: originPixel.y + east * eastPixelsPerMeter.y + north * northPixelsPerMeter.y
        )
    }
}

struct WatchMapBackdropResult: Sendable {
    let image: CGImage
    let markerPixel: CGPoint
    let projection: WatchMapProjection
    let isFallback: Bool
}

@MainActor
protocol WatchMapBackdropProviding {
    func backdrop(for request: WatchMapBackdropRequest) async throws -> WatchMapBackdropResult
    func clear()
}

/// RAM only: at most three zooms for the current coordinate, one snapshot in flight.
/// The only network operation is MapKit's snapshot request to Apple.
@MainActor
final class WatchMapBackdrop: WatchMapBackdropProviding {
    enum Failure: Error { case invalidRequest, renderingFailed }

    private struct Key: Equatable {
        let latitude: Double
        let longitude: Double
        let zoom: WatchMapZoom
        let size: CGSize
        let scale: CGFloat
    }

    private struct Base: Sendable {
        let image: CGImage
        let projection: WatchMapProjection
        let isDark: Bool
    }

    private struct Entry {
        let key: Key
        let base: Base
    }

    private struct Pending {
        let id: UUID
        let key: Key
        let task: Task<Base, Error>
    }

    private var entries: [WatchMapZoom: Entry] = [:]
    private var pending: Pending?
    private static let earthRadius = 6_378_137.0
    private static let worldMeters = 2 * Double.pi * earthRadius

    func clear() {
        pending?.task.cancel()
        pending = nil
        entries.removeAll()
    }

    func backdrop(for request: WatchMapBackdropRequest) async throws -> WatchMapBackdropResult {
        try Task.checkCancellation()
        let key = try validatedKey(request)
        // Do not retain a history of places, even within the bounded cache.
        if let previous = entries.values.first?.key ?? pending?.key,
           previous.latitude != key.latitude || previous.longitude != key.longitude {
            clear()
        }
        if let entry = entries[key.zoom], entry.key == key {
            return try render(entry.base, appearance: request.appearance, fallback: false, scale: key.scale)
        }

        let work: Pending
        if let pending, pending.key == key {
            work = pending
        } else {
            pending?.task.cancel()
            let task = Task { @MainActor in
                try Task.checkCancellation()
                let options = MKMapSnapshotter.Options()
                options.size = key.size
                options.scale = key.scale
                options.mapRect = Self.mapRect(for: key)
                let configuration = MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .muted)
                configuration.pointOfInterestFilter = .excludingAll
                configuration.showsTraffic = false
                options.preferredConfiguration = configuration
                let snapshotter = MKMapSnapshotter(options: options)
                // MKMapSnapshotter.cancel() is documented as callable from any thread.
                nonisolated(unsafe) let cancellable = snapshotter
                let snapshot = try await withTaskCancellationHandler {
                    try await snapshotter.start()
                } onCancel: {
                    cancellable.cancel()
                }
                try Task.checkCancellation()
                return try Self.base(from: snapshot, key: key)
            }
            work = Pending(id: UUID(), key: key, task: task)
            pending = work
        }

        let base: Base
        do {
            base = try await work.task.value
        } catch {
            try Task.checkCancellation()
            guard pending?.id == work.id else { throw CancellationError() }
            pending = nil
            if error is CancellationError { throw error }
            // Failures are not cached, so reopening the view can retry after going online.
            return try render(Self.fallback(for: key), appearance: .dark, fallback: true, scale: key.scale)
        }
        try Task.checkCancellation()
        if pending?.id == work.id {
            entries[key.zoom] = Entry(key: key, base: base)
            pending = nil
        } else if entries[key.zoom]?.key != key {
            // A newer place/size/zoom or clear() must not be undone by a late completion.
            throw CancellationError()
        }
        return try render(base, appearance: request.appearance, fallback: false, scale: key.scale)
    }

    private func validatedKey(_ request: WatchMapBackdropRequest) throws -> Key {
        guard CLLocationCoordinate2DIsValid(request.coordinate),
              abs(request.coordinate.latitude) < 85,
              request.size.width.isFinite, request.size.height.isFinite,
              request.scale.isFinite, (1...3).contains(request.scale),
              request.size.width >= 1, request.size.height >= 1,
              request.size.width * request.scale <= 600,
              request.size.height * request.scale <= 600 else { throw Failure.invalidRequest }
        let size = CGSize(
            width: (request.size.width * request.scale).rounded() / request.scale,
            height: (request.size.height * request.scale).rounded() / request.scale
        )
        return Key(latitude: request.coordinate.latitude, longitude: request.coordinate.longitude,
                   zoom: request.zoom, size: size, scale: request.scale)
    }

    private static func mapRect(for key: Key) -> MKMapRect {
        let center = MKMapPoint(CLLocationCoordinate2D(latitude: key.latitude, longitude: key.longitude))
        let width = key.zoom.widthMeters * MKMapPointsPerMeterAtLatitude(key.latitude)
        let height = width * key.size.height / key.size.width
        return MKMapRect(x: center.x - width / 2, y: center.y - height / 2, width: width, height: height)
    }

    private static func mercator(_ point: MKMapPoint) -> CGPoint {
        let metersPerPoint = worldMeters / MKMapRect.world.size.width
        return CGPoint(x: point.x * metersPerPoint - worldMeters / 2,
                       y: worldMeters / 2 - point.y * metersPerPoint)
    }

    private static func base(from snapshot: MKMapSnapshotter.Snapshot, key: Key) throws -> Base {
        guard let image = snapshot.image.cgImage else { throw Failure.renderingFailed }
        let center = MKMapPoint(CLLocationCoordinate2D(latitude: key.latitude, longitude: key.longitude))
        let step = mapRect(for: key).size.width / 4
        let east = MKMapPoint(x: center.x + step, y: center.y)
        let north = MKMapPoint(x: center.x, y: center.y - step)
        // point(for:) returns points. Use actual image dimensions to get pixels.
        let sx = CGFloat(image.width) / snapshot.image.size.width
        let sy = CGFloat(image.height) / snapshot.image.size.height
        func pixel(_ point: MKMapPoint) -> CGPoint {
            let value = snapshot.point(for: point.coordinate)
            return CGPoint(x: value.x * sx, y: value.y * sy)
        }
        let origin = pixel(center)
        let e = pixel(east)
        let n = pixel(north)
        let meters = step * worldMeters / MKMapRect.world.size.width
        let projection = WatchMapProjection(
            originMercator: mercator(center), originPixel: origin,
            eastPixelsPerMeter: CGPoint(x: (e.x - origin.x) / meters, y: (e.y - origin.y) / meters),
            northPixelsPerMeter: CGPoint(x: (n.x - origin.x) / meters, y: (n.y - origin.y) / meters)
        )
        guard [origin.x, origin.y, e.x, e.y, n.x, n.y].allSatisfy(\.isFinite),
              abs(projection.eastPixelsPerMeter.x * projection.northPixelsPerMeter.y
                  - projection.eastPixelsPerMeter.y * projection.northPixelsPerMeter.x) > 0 else {
            throw Failure.renderingFailed
        }
        return Base(image: image, projection: projection, isDark: try isDark(image))
    }

    private static func context(width: Int, height: Int) throws -> CGContext {
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw Failure.renderingFailed
        }
        return context
    }

    private static func fallback(for key: Key) throws -> Base {
        let width = Int((key.size.width * key.scale).rounded())
        let height = Int((key.size.height * key.scale).rounded())
        let context = try context(width: width, height: height)
        context.setFillColor(CGColor(gray: 0.04, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        guard let image = context.makeImage() else { throw Failure.renderingFailed }
        let center = MKMapPoint(CLLocationCoordinate2D(latitude: key.latitude, longitude: key.longitude))
        let rect = mapRect(for: key)
        let metersPerPoint = worldMeters / MKMapRect.world.size.width
        return Base(image: image, projection: WatchMapProjection(
            originMercator: mercator(center),
            originPixel: CGPoint(x: CGFloat(width) / 2, y: CGFloat(height) / 2),
            eastPixelsPerMeter: CGPoint(x: Double(width) / (rect.size.width * metersPerPoint), y: 0),
            northPixelsPerMeter: CGPoint(x: 0, y: -Double(height) / (rect.size.height * metersPerPoint))
        ), isDark: true)
    }

    private static func isDark(_ image: CGImage) throws -> Bool {
        let sample = try context(width: 8, height: 8)
        sample.interpolationQuality = .high
        sample.draw(image, in: CGRect(x: 0, y: 0, width: 8, height: 8))
        guard let data = sample.data else { throw Failure.renderingFailed }
        let bytes = data.assumingMemoryBound(to: UInt8.self)
        var brightness = 0.0
        for index in 0..<64 {
            brightness += (Double(bytes[index * 4]) + Double(bytes[index * 4 + 1])
                           + Double(bytes[index * 4 + 2])) / (3 * 255)
        }
        return brightness / 64 < 0.5
    }

    private func render(_ base: Base, appearance: WatchMapAppearance, fallback: Bool,
                        scale: CGFloat) throws -> WatchMapBackdropResult {
        let context = try Self.context(width: base.image.width, height: base.image.height)
        let bounds = CGRect(x: 0, y: 0, width: base.image.width, height: base.image.height)
        context.draw(base.image, in: bounds)
        // watchOS does not expose snapshot Options.traitCollection. Derive the requested
        // appearance locally, accounting for the source snapshot's measured brightness.
        if !fallback && ((appearance == .dark) != base.isDark) {
            context.setBlendMode(.difference)
            context.setFillColor(CGColor(gray: 1, alpha: 1))
            context.fill(bounds)
            context.setBlendMode(.normal)
        }
        if appearance == .dark && !fallback {
            context.setBlendMode(.multiply)
            context.setFillColor(CGColor(red: 0.65, green: 0.72, blue: 0.8, alpha: 1))
            context.fill(bounds)
            context.setBlendMode(.normal)
        }
        // Match the top-left pixel contract when drawing the marker over either backdrop.
        context.translateBy(x: 0, y: bounds.height)
        context.scaleBy(x: 1, y: -1)
        let marker = base.projection.originPixel
        let radius = 3 * scale
        if fallback {
            context.setStrokeColor(CGColor(gray: 0.45, alpha: 1))
            context.setLineWidth(scale)
            let ringRadius = min(bounds.width, bounds.height) / 4
            context.strokeEllipse(in: CGRect(x: marker.x - ringRadius, y: marker.y - ringRadius,
                                             width: 2 * ringRadius, height: 2 * ringRadius))
        }
        context.setFillColor(CGColor(red: 0.1, green: 0.65, blue: 1, alpha: 1))
        context.setStrokeColor(CGColor(gray: 1, alpha: 1))
        context.setLineWidth(scale)
        context.addEllipse(in: CGRect(x: marker.x - radius, y: marker.y - radius,
                                      width: 2 * radius, height: 2 * radius))
        context.drawPath(using: .fillStroke)
        guard let image = context.makeImage() else { throw Failure.renderingFailed }
        return WatchMapBackdropResult(image: image, markerPixel: marker,
                                      projection: base.projection, isFallback: fallback)
    }
}
