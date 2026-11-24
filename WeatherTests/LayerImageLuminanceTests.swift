#if DEBUG
import CoreGraphics
import Foundation
import ImageIO
import XCTest
@testable import Weather

/// Why a layer can look bright in dark mode: measures the data image itself (stub images and one real OPERA Europe slot, fixed data,
/// no network). `coverage` = share of pixels with alpha, `luma` = mean relative luminance of the covered pixels (colour only),
/// `alpha` = mean opacity of the covered pixels. Over a map of luminance `m`, the screen shows about
/// `coverage * (alpha * luma + (1 - alpha) * m) + (1 - coverage) * m`; the lines `LAYERLUM ...` go to the log and the nachweis.
final class LayerImageLuminanceTests: XCTestCase {
    struct Stats { let coverage: Double, luma: Double, alpha: Double }

    private func stats(of data: Data) throws -> Stats {
        let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        let width = image.width, height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let context = try XCTUnwrap(CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                              space: CGColorSpaceCreateDeviceRGB(),
                                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        var covered = 0.0, lumaSum = 0.0, alphaSum = 0.0
        for index in stride(from: 0, to: pixels.count, by: 4) {
            let a = Double(pixels[index + 3]) / 255
            guard a > 0.02 else { continue }
            covered += 1
            alphaSum += a
            let r = Double(pixels[index]) / 255 / a, g = Double(pixels[index + 1]) / 255 / a, b = Double(pixels[index + 2]) / 255 / a
            lumaSum += 0.2126 * min(r, 1) + 0.7152 * min(g, 1) + 0.0722 * min(b, 1)
        }
        let total = Double(width * height)
        guard covered > 0 else { return Stats(coverage: 0, luma: 0, alpha: 0) }
        return Stats(coverage: covered / total, luma: lumaSum / covered, alpha: alphaSum / covered)
    }

    private func line(_ name: String, _ stats: Stats) {
        // Expected screen luminance over a dark map (0.15) and over the light map (0.85), same formula as above.
        func screen(_ m: Double) -> Double { stats.coverage * (stats.alpha * stats.luma + (1 - stats.alpha) * m) + (1 - stats.coverage) * m }
        print(String(format: "LAYERLUM %@ coverage=%.3f luma=%.3f alpha=%.3f overDarkMap=%.3f overLightMap=%.3f", name,
                     stats.coverage, stats.luma, stats.alpha, screen(0.15), screen(0.85)))
    }

    func testStubLayerImagesAreMeasuredAndStable() throws {
        // Time is irrelevant outside history mode: the stub images are fixed.
        var table: [String: Stats] = [:]
        for id in ["radar_eu", "radar_world", "lightning", "clouds", "cloudmask", "pressure", "pressure_eu", "temperature", "dewpoint", "humidity"] {
            let data = try XCTUnwrap(UITestLayerImage.data(forLayer: id), id)
            let value = try stats(of: data)
            table[id] = value
            line(id, value)
            XCTAssertEqual(try stats(of: try XCTUnwrap(UITestLayerImage.data(forLayer: id))).luma, value.luma, accuracy: 1e-9, "\(id) is deterministic")
        }
        // Cause of the bright dark-mode screens: these layers colour (almost) the whole map with light colours.
        for id in ["temperature", "dewpoint", "humidity", "clouds"] {
            let value = try XCTUnwrap(table[id])
            XCTAssertGreaterThan(value.coverage, 0.95, "\(id) covers the whole map")
            XCTAssertGreaterThan(value.luma, 0.45, "\(id): the data colours themselves are bright")
        }
        // The layers that pass in dark mode only touch a small part of the map.
        for id in ["radar_eu", "radar_world", "lightning", "pressure", "pressure_eu"] {
            XCTAssertLessThan(try XCTUnwrap(table[id]).coverage, 0.5, "\(id) leaves most of the map alone")
        }
    }

    func testRealEuropeSlotIsMeasured() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("WeatherUITests/Fixtures/radar_eu-real-20261120T0455Z.webp")
        let value = try stats(of: try Data(contentsOf: url))
        line("radar_eu-real", value)
        XCTAssertGreaterThan(value.coverage, 0, "the real slot contains rain")
    }
}
#endif
