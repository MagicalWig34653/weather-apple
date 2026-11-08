import CoreGraphics
import CoreLocation
import Foundation

/// Local value readout of a coloured 2 m field: the tapped coordinate is turned into a pixel of the slot image
/// already on screen, the pixel colour into a scale band. Nothing leaves the device: no request, no location service.
enum PixelReadout {
    enum Result: Equatable {
        /// Band index in the scale.
        case band(Int)
        /// Outside the image or a transparent cell (the model has no value there).
        case noValue
        /// Colour does not match any band of the scale (damaged or foreign image).
        case unreadable
    }

    /// Pixel of an EPSG:3857 image for a WGS84 coordinate; `nil` outside the bounds.
    static func pixel(latitude: Double, longitude: Double, bounds: RadarBounds, width: Int, height: Int) -> (x: Int, y: Int)? {
        guard latitude.isFinite, longitude.isFinite, abs(latitude) < 85.05, abs(longitude) <= 180 else { return nil }
        let x = longitude * RadarBounds.halfWorld / 180
        let y = log(tan((90 + latitude) * .pi / 360)) / .pi * RadarBounds.halfWorld
        guard x >= bounds.minX, x < bounds.maxX, y > bounds.minY, y <= bounds.maxY else { return nil }
        let px = Int((x - bounds.minX) / (bounds.maxX - bounds.minX) * Double(width))
        let py = Int((bounds.maxY - y) / (bounds.maxY - bounds.minY) * Double(height))
        return (min(width - 1, max(0, px)), min(height - 1, max(0, py)))
    }

    /// RGBA (straight alpha) of one pixel, read through a 1 x 1 sRGB context.
    static func rgba(of image: CGImage, x: Int, y: Int) -> (r: UInt8, g: UInt8, b: UInt8, a: UInt8)? {
        guard x >= 0, y >= 0, x < image.width, y < image.height,
              let cropped = image.cropping(to: CGRect(x: x, y: y, width: 1, height: 1)),
              let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        var pixel = [UInt8](repeating: 0, count: 4)
        let drawn = pixel.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                          space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.interpolationQuality = .none
            context.draw(cropped, in: CGRect(x: 0, y: 0, width: 1, height: 1))
            return true
        }
        guard drawn else { return nil }
        let alpha = pixel[3]
        guard alpha > 0 else { return (0, 0, 0, 0) }
        func straight(_ value: UInt8) -> UInt8 { UInt8(min(255, (Int(value) * 255 + Int(alpha) / 2) / Int(alpha))) }
        return (straight(pixel[0]), straight(pixel[1]), straight(pixel[2]), alpha)
    }

    static func result(image: CGImage, latitude: Double, longitude: Double, bounds: RadarBounds, scale: TemperatureScale) -> Result {
        guard let position = pixel(latitude: latitude, longitude: longitude, bounds: bounds, width: image.width, height: image.height) else { return .noValue }
        return result(image: image, x: position.x, y: position.y, scale: scale)
    }

    static func result(image: CGImage, x: Int, y: Int, scale: TemperatureScale) -> Result {
        guard let color = rgba(of: image, x: x, y: y) else { return .unreadable }
        guard color.a >= 128 else { return .noValue }
        guard let band = scale.bandIndex(red: color.r, green: color.g, blue: color.b) else { return .unreadable }
        return .band(band)
    }

    static func text(_ result: Result, scale: TemperatureScale, spoken: Bool) -> String {
        switch result {
        case .band(let index): return scale.readoutText(bandIndex: index, spoken: spoken)
        case .noValue: return NSLocalizedString("TEMP_READOUT_NONE", value: "Kein Wert an dieser Stelle", comment: "Readout without value")
        case .unreadable: return NSLocalizedString("TEMP_READOUT_UNREADABLE", value: "Wert nicht lesbar", comment: "Readout unreadable")
        }
    }
}
