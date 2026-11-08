import XCTest
import CoreGraphics
@testable import Weather

// Local value readout (Teilprojekt 3, P5): coordinate -> pixel -> band, no network.
final class PixelReadoutTests: XCTestCase {
    let bounds = RadarBounds(minX: 612257.5, minY: 5942074, maxX: 1736584, maxY: 7381298)
    var scale: TemperatureScale { TemperatureScale.bundled["t2m-d2-v1"]! }

    /// 4 x 2 image: top row bands 30..33, bottom row left transparent, others band 0.
    func makeImage() -> CGImage {
        var pixels = [UInt8](repeating: 0, count: 4 * 2 * 4)
        func set(_ x: Int, _ y: Int, _ band: Int?) {
            guard let band else { return }
            let b = scale.bands[band]
            let o = (y * 4 + x) * 4
            pixels[o] = b.red; pixels[o + 1] = b.green; pixels[o + 2] = b.blue; pixels[o + 3] = 255
        }
        for x in 0..<4 { set(x, 0, 30 + x) }
        set(0, 1, nil); set(1, 1, 0); set(2, 1, 0); set(3, 1, 69)
        let provider = CGDataProvider(data: Data(pixels) as CFData)!
        return CGImage(width: 4, height: 2, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 16,
                       space: CGColorSpace(name: CGColorSpace.sRGB)!,
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue), provider: provider,
                       decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
    }

    func testCoordinateToPixelCornersAndOutside() {
        // Cologne is inside, the North Sea west of the bounds and the Mediterranean south are not.
        let cologne = PixelReadout.pixel(latitude: 50.94, longitude: 6.96, bounds: bounds, width: 1024, height: 1311)
        XCTAssertNotNil(cologne)
        XCTAssertNil(PixelReadout.pixel(latitude: 43.0, longitude: 7.0, bounds: bounds, width: 1024, height: 1311))
        XCTAssertNil(PixelReadout.pixel(latitude: 50.0, longitude: 2.0, bounds: bounds, width: 1024, height: 1311))
        // Northwest corner maps to pixel (0,0), centre to the middle.
        let west = bounds.minX / RadarBounds.halfWorld * 180 + 0.0001
        let northLat = (2 * atan(exp(bounds.maxY / RadarBounds.halfWorld * .pi)) - .pi / 2) * 180 / .pi - 0.0001
        let corner = PixelReadout.pixel(latitude: northLat, longitude: west, bounds: bounds, width: 1024, height: 1311)
        XCTAssertEqual(corner?.x, 0); XCTAssertEqual(corner?.y, 0)
        XCTAssertNil(PixelReadout.pixel(latitude: .nan, longitude: 7, bounds: bounds, width: 10, height: 10))
    }

    func testPixelColourToBandAndNoValue() {
        let image = makeImage()
        XCTAssertEqual(PixelReadout.result(image: image, x: 0, y: 0, scale: scale), .band(30))
        XCTAssertEqual(PixelReadout.result(image: image, x: 3, y: 0, scale: scale), .band(33))
        XCTAssertEqual(PixelReadout.result(image: image, x: 3, y: 1, scale: scale), .band(69))
        XCTAssertEqual(PixelReadout.result(image: image, x: 0, y: 1, scale: scale), .noValue, "transparent cell")
        XCTAssertEqual(PixelReadout.result(image: image, x: 9, y: 9, scale: scale), .unreadable)
    }

    func testForeignColourIsUnreadableNotGuessed() {
        // a grey pixel is no band of the temperature scale
        let provider = CGDataProvider(data: Data([128, 128, 128, 255]) as CFData)!
        let image = CGImage(width: 1, height: 1, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 4,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue), provider: provider,
                            decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
        XCTAssertEqual(PixelReadout.result(image: image, x: 0, y: 0, scale: scale), .unreadable)
    }

    func testReadoutTextIsModelValueAndTakesNoNetwork() {
        final class Counter: URLProtocol, @unchecked Sendable {
            nonisolated(unsafe) static var requests = 0
            override class func canInit(with request: URLRequest) -> Bool { requests += 1; return false }
            override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
            override func startLoading() {}
            override func stopLoading() {}
        }
        URLProtocol.registerClass(Counter.self)
        defer { URLProtocol.unregisterClass(Counter.self) }
        let image = makeImage()
        let result = PixelReadout.result(image: image, latitude: 50.94, longitude: 6.96, bounds: bounds, scale: scale)
        let spoken = PixelReadout.text(.band(37), scale: scale, spoken: true)
        XCTAssertTrue(spoken.contains("7") && spoken.contains("8"))
        XCTAssertTrue(spoken.localizedCaseInsensitiveContains("model"))
        _ = result
        XCTAssertEqual(Counter.requests, 0)
        XCTAssertFalse(PixelReadout.text(.noValue, scale: scale, spoken: true).isEmpty)
    }
}
