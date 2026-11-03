import Foundation
import CoreGraphics
import ImageIO

/// Local-only geometry. Pixel coordinates have their origin at the image's top left.
enum RadarCrop {
    enum Zoom: Int, CaseIterable, Sendable {
        case local, regional, wide
        /// Approximate ground radius; converted to Mercator meters at the chosen latitude.
        var radiusKilometers: Double {
            switch self { case .local: 40; case .regional: 70; case .wide: 100 }
        }
    }

    enum Failure: Error, Equatable { case invalidGeometry, outsideCoverage, invalidImage }

    struct Layout: Equatable, Sendable {
        /// Integer rectangle intersected with the radar image. Never empty or out of bounds.
        let pixelRect: CGRect
        /// Desired viewport, including uncovered margins at the edge of the radar coverage.
        let viewportBounds: RadarBounds
        /// Mercator bounds of pixelRect, for alignment with a map snapshot.
        let imageBounds: RadarBounds
        /// Marker and image placement normalized to the desired viewport (top-left origin).
        let marker: CGPoint
        let imagePlacement: CGRect
    }

    static let maximumDecodedEdge = 160

    static func layout(coordinate: WeatherCoordinate, zoom: Zoom,
                       bounds: RadarBounds, width: Int = 1024, height: Int = 1311) throws -> Layout {
        guard coordinate.latitude.isFinite, coordinate.longitude.isFinite,
              abs(coordinate.latitude) <= 85.05112878, abs(coordinate.longitude) <= 180,
              (1...4096).contains(width), (1...4096).contains(height),
              [bounds.minX, bounds.minY, bounds.maxX, bounds.maxY].allSatisfy({
                  $0.isFinite && abs($0) <= RadarBounds.halfWorld + 1
              }), bounds.minX < bounds.maxX, bounds.minY < bounds.maxY else {
            throw Failure.invalidGeometry
        }
        let radians = coordinate.latitude * .pi / 180
        let earthRadius = RadarBounds.halfWorld / .pi
        let x = earthRadius * coordinate.longitude * .pi / 180
        let y = earthRadius * log(tan(.pi / 4 + radians / 2))
        guard x >= bounds.minX, x <= bounds.maxX, y >= bounds.minY, y <= bounds.maxY else {
            throw Failure.outsideCoverage
        }
        let radius = zoom.radiusKilometers * 1000 / cos(radians)
        let dx = (bounds.maxX - bounds.minX) / Double(width)
        let dy = (bounds.maxY - bounds.minY) / Double(height)
        // Snap outwards, keeping the viewport and the cropped pixels in the same projection.
        let left = floor((x - radius - bounds.minX) / dx)
        let right = ceil((x + radius - bounds.minX) / dx)
        let top = floor((bounds.maxY - y - radius) / dy)
        let bottom = ceil((bounds.maxY - y + radius) / dy)
        let viewport = RadarBounds(minX: bounds.minX + left * dx, minY: bounds.maxY - bottom * dy,
                                   maxX: bounds.minX + right * dx, maxY: bounds.maxY - top * dy)
        let cropLeft = max(0, left), cropTop = max(0, top)
        let cropRight = min(Double(width), right), cropBottom = min(Double(height), bottom)
        let rect = CGRect(x: cropLeft, y: cropTop, width: cropRight - cropLeft, height: cropBottom - cropTop)
        return Layout(pixelRect: rect, viewportBounds: viewport,
                      imageBounds: RadarBounds(minX: bounds.minX + cropLeft * dx,
                                               minY: bounds.maxY - cropBottom * dy,
                                               maxX: bounds.minX + cropRight * dx,
                                               maxY: bounds.maxY - cropTop * dy),
                      marker: CGPoint(x: (x - viewport.minX) / (viewport.maxX - viewport.minX),
                                      y: (viewport.maxY - y) / (viewport.maxY - viewport.minY)),
                      imagePlacement: CGRect(x: (cropLeft - left) / (right - left),
                                             y: (cropTop - top) / (bottom - top),
                                             width: rect.width / (right - left), height: rect.height / (bottom - top)))
    }

    /// Decode one full image transiently, crop, then copy into independent RGBA storage.
    /// CGImage.cropping alone may retain the parent image; the context copy is intentional.
    static func decode(_ data: Data, layout: Layout, width: Int = 1024, height: Int = 1311) throws -> CGImage {
        guard !data.isEmpty, data.count <= RadarBackendConfig.maximumImageBytes else { throw Failure.invalidImage }
        return try autoreleasepool {
            let options = [kCGImageSourceShouldCache: false] as CFDictionary
            guard data.count >= 12, data.prefix(4) == Data("RIFF".utf8), data[8..<12] == Data("WEBP".utf8),
                  layout.pixelRect.width > 0, layout.pixelRect.height > 0,
                  CGRect(x: 0, y: 0, width: width, height: height).contains(layout.pixelRect) else { throw Failure.invalidImage }
            let cropped: CGImage
            // ImageIO first; watchOS has no WebP codec in ImageIO (source count 0), so fall back to the
            // software decoder for the lossless WebP that the backend serves.
            if let source = CGImageSourceCreateWithData(data as CFData, options), CGImageSourceGetCount(source) == 1 {
                guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, options) as? [CFString: Any],
                      (properties[kCGImagePropertyPixelWidth] as? Int) == width,
                      (properties[kCGImagePropertyPixelHeight] as? Int) == height,
                      let full = CGImageSourceCreateImageAtIndex(source, 0, options),
                      let part = full.cropping(to: layout.pixelRect) else { throw Failure.invalidImage }
                cropped = part
            } else {
                do {
                    cropped = try WebPLosslessDecoder.decodeCropped(data, expectedWidth: width, expectedHeight: height,
                                                                    crop: layout.pixelRect)
                } catch { throw Failure.invalidImage }
            }
            let scale = min(1, Double(maximumDecodedEdge) / max(layout.pixelRect.width, layout.pixelRect.height))
            let outputWidth = max(1, Int(ceil(layout.pixelRect.width * scale)))
            let outputHeight = max(1, Int(ceil(layout.pixelRect.height * scale)))
            guard let context = CGContext(data: nil, width: outputWidth, height: outputHeight,
                                          bitsPerComponent: 8, bytesPerRow: outputWidth * 4,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
                throw Failure.invalidImage
            }
            context.interpolationQuality = .none
            context.draw(cropped, in: CGRect(x: 0, y: 0, width: outputWidth, height: outputHeight))
            guard let image = context.makeImage() else { throw Failure.invalidImage }
            return image
        }
    }
}

/// All store generations share one decoder: at most one transient full bitmap at a time.
actor WatchRadarDecoder {
    func decode(_ data: Data, layout: RadarCrop.Layout, width: Int, height: Int) throws -> CGImage {
        try Task.checkCancellation()
        return try RadarCrop.decode(data, layout: layout, width: width, height: height)
    }
}
