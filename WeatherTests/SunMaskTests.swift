import CoreGraphics
import ImageIO
import XCTest
@testable import Weather

// Sun layer: classification of the EUMETView cloud mask (msg_fes:clm), overlay composition (day, night,
// terminator), place line, time zones. Fixtures `clm-20261031T1100Z.png` (day) and `clm-20261031T0100Z.png`
// (night slot, with transparent pixels) are real GetMap images (EPSG:3857, bbox of the radar grid, 1024 x 1311,
// retrieved 31 Oct 2026), reduced to the four classes (cloud white, land green, water blue, unknown transparent).
final class SunMaskTests: XCTestCase {
    let bounds = RadarBounds(minX: 612257.0, minY: 5942074.0, maxX: 1736584.0, maxY: 7381298.0)

    func utc(_ text: String) -> Date { DWDRequest.date(text)! }

    func mask(_ name: String) throws -> CGImage {
        let bundle = Bundle(for: SunMaskTests.self)
        let url = try XCTUnwrap(bundle.url(forResource: name, withExtension: "png", subdirectory: "Fixtures")
                                ?? bundle.url(forResource: name, withExtension: "png"))
        let source = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil))
        return try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
    }

    // MARK: Classification

    func testClassifiesTheThreeLegendColoursAndTransparency() {
        XCTAssertEqual(CloudMaskClass.classify(red: 255, green: 255, blue: 255, alpha: 255), .cloud)
        XCTAssertEqual(CloudMaskClass.classify(red: 0, green: 192, blue: 0, alpha: 255), .clearLand)
        XCTAssertEqual(CloudMaskClass.classify(red: 1, green: 192, blue: 0, alpha: 255), .clearLand, "measured variant")
        XCTAssertEqual(CloudMaskClass.classify(red: 0, green: 0, blue: 254, alpha: 255), .clearWater)
        XCTAssertEqual(CloudMaskClass.classify(red: 255, green: 254, blue: 255, alpha: 255), .cloud, "measured variant")
        XCTAssertEqual(CloudMaskClass.classify(red: 0, green: 0, blue: 0, alpha: 0), .unknown, "off Earth disc")
        XCTAssertEqual(CloudMaskClass.classify(red: 255, green: 255, blue: 255, alpha: 120), .unknown)
        XCTAssertTrue(CloudMaskClass.clearLand.isClear)
        XCTAssertTrue(CloudMaskClass.clearWater.isClear)
        XCTAssertFalse(CloudMaskClass.cloud.isClear)
    }

    func testResamplingMixturesAreUnknownNotGuessed() {
        // Mixes of white and green / white and blue / green and blue from reprojection edges.
        XCTAssertEqual(CloudMaskClass.classify(red: 128, green: 224, blue: 128, alpha: 255), .unknown)
        XCTAssertEqual(CloudMaskClass.classify(red: 128, green: 128, blue: 255, alpha: 255), .unknown)
        XCTAssertEqual(CloudMaskClass.classify(red: 0, green: 96, blue: 128, alpha: 255), .unknown)
        XCTAssertEqual(CloudMaskClass.classify(red: 0, green: 0, blue: 0, alpha: 255), .unknown, "black is no class")
    }

    func testFixtureHoldsOnlyTheDocumentedClasses() throws {
        let day = try XCTUnwrap(SunOverlay.pixels(of: mask("clm-20261031T1100Z")))
        var counts: [CloudMaskClass: Int] = [:]
        var i = 0
        while i < day.count {
            counts[CloudMaskClass.classify(red: day[i], green: day[i + 1], blue: day[i + 2], alpha: day[i + 3]), default: 0] += 1
            i += 4
        }
        let total = Double(day.count / 4)
        XCTAssertGreaterThan(Double(counts[.cloud] ?? 0) / total, 0.6, "11:00 UTC slot is mostly cloudy (76.9 % measured)")
        XCTAssertGreaterThan(Double(counts[.clearLand] ?? 0) / total, 0.10)
        XCTAssertLessThan(Double(counts[.unknown] ?? 0) / total, 0.05)
    }

    // MARK: Geometry

    func testPixelMappingRoundTrip() throws {
        let berlin = try XCTUnwrap(SunGeometry.pixel(latitude: 52.52, longitude: 13.405, bounds: bounds, width: 1024, height: 1311))
        XCTAssertEqual(berlin.x, 800, accuracy: 3)
        XCTAssertEqual(berlin.y, 443, accuracy: 4)
        // Centre of that pixel maps back to a point within about 1 km of Berlin.
        let x = bounds.minX + (bounds.maxX - bounds.minX) * (Double(berlin.x) + 0.5) / 1024
        let y = bounds.maxY - (bounds.maxY - bounds.minY) * (Double(berlin.y) + 0.5) / 1311
        XCTAssertEqual(SunGeometry.longitude(x: x), 13.405, accuracy: 0.02)
        XCTAssertEqual(SunGeometry.latitude(y: y), 52.52, accuracy: 0.02)
        XCTAssertNil(SunGeometry.pixel(latitude: 40, longitude: 13, bounds: bounds, width: 1024, height: 1311), "south of the image")
        XCTAssertNil(SunGeometry.pixel(latitude: 52, longitude: 2, bounds: bounds, width: 1024, height: 1311), "west of the image")
    }

    // MARK: Composition

    func testShadeAlphaIsMonotonicAndAnchored() {
        XCTAssertEqual(SunOverlay.shadeAlpha(elevation: 10), 0)
        XCTAssertEqual(SunOverlay.shadeAlpha(elevation: -0.833), 0, accuracy: 1e-9)
        XCTAssertEqual(SunOverlay.shadeAlpha(elevation: -6), 0.30, accuracy: 1e-9)
        XCTAssertEqual(SunOverlay.shadeAlpha(elevation: -12), 0.50, accuracy: 1e-9)
        XCTAssertEqual(SunOverlay.shadeAlpha(elevation: -18), 0.62, accuracy: 1e-9)
        XCTAssertEqual(SunOverlay.shadeAlpha(elevation: -60), 0.68, accuracy: 1e-9)
        var last = -1.0
        for h in stride(from: 5.0, through: -40.0, by: -0.5) {
            let a = SunOverlay.shadeAlpha(elevation: h)
            XCTAssertGreaterThanOrEqual(a, last)
            last = a
        }
    }

    func testDaySlotTintsClearYellowAndCloudGrey() throws {
        // 11:00 UTC: sun high over the whole image (Berlin 23 degrees), no shade, no terminator.
        let image = try mask("clm-20261031T1100Z")
        let rgba = try XCTUnwrap(SunOverlay.pixels(of: image))
        let out = SunOverlay.render(rgba: rgba, width: 1024, height: 1311, bounds: bounds, date: utc("2026-10-31T11:00:00Z"))
        var sunny = 0, grey = 0, transparent = 0
        var i = 0
        while i < rgba.count {
            switch CloudMaskClass.classify(red: rgba[i], green: rgba[i + 1], blue: rgba[i + 2], alpha: rgba[i + 3]) {
            case .clearLand, .clearWater:
                XCTAssertEqual(out[i + 3], 140, "0.55 alpha"); XCTAssertEqual(out[i], 140)
                sunny += 1
            case .cloud:
                XCTAssertEqual(out[i + 3], 97, "0.38 alpha"); grey += 1
            case .unknown:
                XCTAssertEqual(out[i + 3], 0); transparent += 1
            }
            i += 4
        }
        XCTAssertGreaterThan(sunny, 100_000)
        XCTAssertGreaterThan(grey, 500_000)
        XCTAssertGreaterThan(transparent, 1000)
    }

    func testNightIsDarkenedAndIgnoresTheMask() throws {
        // 00:00 UTC: sun about -38 degrees at Berlin, below -18 degrees over the whole image.
        let rgba = try XCTUnwrap(SunOverlay.pixels(of: mask("clm-20261031T0100Z")))
        let out = SunOverlay.render(rgba: rgba, width: 1024, height: 1311, bounds: bounds, date: utc("2026-10-31T00:00:00Z"))
        for index in stride(from: 0, to: out.count, by: 4 * 997) {
            XCTAssertEqual(out[index + 3], UInt8((0.68 * 255).rounded()), "night shade, identical for clear, cloud and unknown")
            XCTAssertLessThan(out[index], 10)
            XCTAssertLessThan(out[index + 2], 30)
        }
    }

    func testTerminatorSplitsDayTwilightAndLine() throws {
        // 15:40 UTC on 31 Oct: the sunset line crosses Germany (day in the west, twilight in the east).
        let rgba = try XCTUnwrap(SunOverlay.pixels(of: mask("clm-20261031T1100Z")))
        let date = utc("2026-10-31T15:40:00Z")
        let out = SunOverlay.render(rgba: rgba, width: 1024, height: 1311, bounds: bounds, date: date)
        var day = 0, twilight = 0, line = 0, lineHits = 0
        var westDay = 0, eastTwilight = 0
        for r in stride(from: 2, to: 1311, by: 5) {
            for c in stride(from: 2, to: 1024, by: 5) {
                let y = bounds.maxY - (bounds.maxY - bounds.minY) * (Double(r) + 0.5) / 1311
                let x = bounds.minX + (bounds.maxX - bounds.minX) * (Double(c) + 0.5) / 1024
                let h = SolarPosition.elevation(at: date, latitude: SunGeometry.latitude(y: y), longitude: SunGeometry.longitude(x: x))
                let alpha = Double(out[(r * 1024 + c) * 4 + 3]) / 255
                if abs(h - SolarPosition.sunriseElevation) < 0.01 {
                    line += 1
                    if alpha >= 0.85 { lineHits += 1 }
                } else if h > 0.1 {
                    day += 1
                    XCTAssertLessThanOrEqual(alpha, 0.56)
                    if c < 100 { westDay += 1 }
                } else if h < -1.5 && h > -6 {
                    twilight += 1
                    XCTAssertEqual(alpha, SunOverlay.shadeAlpha(elevation: h), accuracy: 0.01)
                    if c > 900 { eastTwilight += 1 }
                }
            }
        }
        XCTAssertGreaterThan(day, 1000, "day pixels")
        XCTAssertGreaterThan(twilight, 1000, "twilight pixels")
        XCTAssertGreaterThan(westDay, 100, "west is still day")
        XCTAssertGreaterThan(eastTwilight, 100, "east is already in twilight")
        XCTAssertGreaterThan(line, 5, "the terminator crosses the image")
        XCTAssertEqual(lineHits, line, "every pixel on the terminator carries the line")
    }

    func testOverlayAgreesWithSolarPositionAtSamplePixels() throws {
        let rgba = try XCTUnwrap(SunOverlay.pixels(of: mask("clm-20261031T1100Z")))
        let date = utc("2026-10-31T15:30:00Z")
        let out = SunOverlay.render(rgba: rgba, width: 1024, height: 1311, bounds: bounds, date: date)
        var checked = 0
        for r in stride(from: 5, to: 1311, by: 37) {
            for c in stride(from: 3, to: 1024, by: 41) {
                let y = bounds.maxY - (bounds.maxY - bounds.minY) * (Double(r) + 0.5) / 1311
                let x = bounds.minX + (bounds.maxX - bounds.minX) * (Double(c) + 0.5) / 1024
                let h = SolarPosition.elevation(at: date, latitude: SunGeometry.latitude(y: y), longitude: SunGeometry.longitude(x: x))
                let alpha = Double(out[(r * 1024 + c) * 4 + 3]) / 255
                if abs(h - SolarPosition.sunriseElevation) < 0.1 { continue }
                if h < SolarPosition.sunriseElevation {
                    XCTAssertEqual(alpha, SunOverlay.shadeAlpha(elevation: h), accuracy: 0.01, "shade at h=\(h)")
                } else if h > 0.1 {
                    XCTAssertLessThanOrEqual(alpha, 0.55 + 0.01, "day pixel at h=\(h) has no shade")
                }
                checked += 1
            }
        }
        XCTAssertGreaterThan(checked, 500)
    }

    func testComposeProducesSameSizedImageAndIsFast() throws {
        let image = try mask("clm-20261031T1100Z")
        let start = Date()
        let composed = try XCTUnwrap(SunOverlay.compose(mask: image, bounds: bounds, date: utc("2026-10-31T15:40:00Z")))
        let duration = Date().timeIntervalSince(start)
        XCTAssertEqual(composed.width, 1024)
        XCTAssertEqual(composed.height, 1311)
        print("SUN-OVERLAY compose 1024x1311: \(Int(duration * 1000)) ms")
        XCTAssertLessThan(duration, 1.5, "generous bound; measured value is printed")
    }

    func testComposerCachesPerSlot() throws {
        let image = try mask("clm-20261031T1100Z")
        let composer = SunOverlayComposer(bounds: bounds, limit: 2)
        let url = URL(string: "https://radar.example.invalid/a.webp")!
        var calls = 0
        let first = composer.image(for: url, time: utc("2026-10-31T15:00:00Z")) { calls += 1; return image }
        let second = composer.image(for: url, time: utc("2026-10-31T15:00:00Z")) { calls += 1; return image }
        XCTAssertNotNil(first)
        XCTAssertTrue(first === second)
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(composer.composeCount, 1)
        XCTAssertNil(composer.image(for: URL(string: "https://radar.example.invalid/b.webp")!, time: Date()) { nil }, "no mask yet")
    }

    // MARK: Place line

    func testCloudClassAtPlaceNeedsAnUnambiguousNeighbourhood() throws {
        let image = try mask("clm-20261031T1100Z")
        let berlin = SunPlace.cloudClass(in: image, bounds: bounds, latitude: 52.52, longitude: 13.405)
        // 11:00 UTC fixture over Berlin: derive the expectation from the pixels themselves.
        let pixel = try XCTUnwrap(SunGeometry.pixel(latitude: 52.52, longitude: 13.405, bounds: bounds, width: 1024, height: 1311))
        let rgba = try XCTUnwrap(SunOverlay.pixels(of: image))
        var classes = Set<CloudMaskClass>()
        for dy in -1...1 { for dx in -1...1 {
            let i = ((pixel.y + dy) * 1024 + pixel.x + dx) * 4
            let c = CloudMaskClass.classify(red: rgba[i], green: rgba[i + 1], blue: rgba[i + 2], alpha: rgba[i + 3])
            classes.insert(c.isClear ? .clearLand : c)
        } }
        if classes == [.cloud] { XCTAssertEqual(berlin, .cloud) }
        else if classes == [.clearLand] { XCTAssertEqual(berlin, .clearLand) }
        else { XCTAssertNil(berlin) }
        XCTAssertNil(SunPlace.cloudClass(in: image, bounds: bounds, latitude: 40, longitude: 13), "outside the image")
    }

    func testUnambiguousNeighbourhoods() {
        func block(_ p: [(UInt8, UInt8, UInt8, UInt8)]) -> [UInt8] { p.flatMap { [$0.0, $0.1, $0.2, $0.3] } }
        let white: (UInt8, UInt8, UInt8, UInt8) = (255, 255, 255, 255)
        let green: (UInt8, UInt8, UInt8, UInt8) = (0, 192, 0, 255)
        let blue: (UInt8, UInt8, UInt8, UInt8) = (0, 0, 255, 255)
        let none: (UInt8, UInt8, UInt8, UInt8) = (0, 0, 0, 0)
        XCTAssertEqual(SunPlace.unambiguous(rgba: block(Array(repeating: white, count: 9))), .cloud)
        XCTAssertEqual(SunPlace.unambiguous(rgba: block(Array(repeating: green, count: 9))), .clearLand)
        XCTAssertEqual(SunPlace.unambiguous(rgba: block(Array(repeating: green, count: 5) + Array(repeating: blue, count: 4)))?.isClear, true,
                       "land and water are both clear")
        XCTAssertNil(SunPlace.unambiguous(rgba: block(Array(repeating: white, count: 8) + [green])), "cloud edge")
        XCTAssertNil(SunPlace.unambiguous(rgba: block(Array(repeating: white, count: 8) + [none])), "unknown pixel")
        XCTAssertNil(SunPlace.unambiguous(rgba: []))
    }

    func testCloudLineWording() {
        let slot = utc("2026-10-31T11:00:00Z")
        XCTAssertEqual(SunPlace.cloudLine(.clearLand, slotTime: slot, now: utc("2026-10-31T11:32:30Z")), "Aktuell klar (Satellit, vor 32 min)")
        XCTAssertEqual(SunPlace.cloudLine(.clearWater, slotTime: slot, now: utc("2026-10-31T11:40:00Z")), "Aktuell klar (Satellit, vor 40 min)")
        XCTAssertEqual(SunPlace.cloudLine(.cloud, slotTime: slot, now: utc("2026-10-31T11:25:00Z")), "Aktuell bewölkt (Satellit, vor 25 min)")
        XCTAssertEqual(SunPlace.cloudLine(.cloud, slotTime: slot, now: utc("2026-10-31T10:59:00Z")), "Aktuell bewölkt (Satellit, vor 0 min)", "never negative")
        XCTAssertNil(SunPlace.cloudLine(nil, slotTime: slot, now: slot))
        XCTAssertNil(SunPlace.cloudLine(.unknown, slotTime: slot, now: slot))
    }

    func testSunLineUsesTheTimeZoneOfThePlace() {
        let noon = utc("2026-10-31T11:00:00Z")
        let berlin = SunPlace.sunLine(at: noon, latitude: 52.52, longitude: 13.405)
        XCTAssertTrue(berlin.hasPrefix("Sonne bis "), berlin)
        let utcLine = SunPlace.sunLine(at: noon, latitude: 52.52, longitude: 13.405, timeZone: TimeZone(identifier: "UTC")!)
        XCTAssertEqual(minutes(berlin) - minutes(utcLine), 60, "CET (winter time since 25 Oct 2026) is UTC+1")
        let summer = utc("2026-07-15T10:00:00Z")
        let summerBerlin = SunPlace.sunLine(at: summer, latitude: 52.52, longitude: 13.405)
        let summerUTC = SunPlace.sunLine(at: summer, latitude: 52.52, longitude: 13.405, timeZone: TimeZone(identifier: "UTC")!)
        XCTAssertEqual(minutes(summerBerlin) - minutes(summerUTC), 120, "CEST is UTC+2")
        XCTAssertEqual(SunPlace.regionTimeZone.identifier, "Europe/Berlin")
    }

    func testSunLineBeforeSunrise() {
        let night = utc("2026-10-31T02:00:00Z")
        let line = SunPlace.sunLine(at: night, latitude: 52.52, longitude: 13.405)
        XCTAssertTrue(line.hasPrefix("Sonne ab "), line)
        XCTAssertGreaterThan(minutes(line), 6 * 60, "sunrise after 06:00 local time")
        XCTAssertLessThan(minutes(line), 8 * 60)
    }

    /// Minutes of the "HH:mm" at the end of a sun line.
    private func minutes(_ line: String) -> Int {
        let parts = line.suffix(5).split(separator: ":").compactMap { Int($0) }
        return parts[0] * 60 + parts[1]
    }

    // MARK: Layer

    func testSunLegendOnlyHasDocumentedClasses() {
        XCTAssertEqual(SunLegend.entries.map(\.id), ["sunny", "cloudy", "civil", "night", "terminator"])
        XCTAssertFalse(SunLegend.entries.contains { $0.label.lowercased().contains("heiter") }, "no thickness class without data")
        XCTAssertTrue(RadarLayerLegendText.hint(for: .cloudmask).contains("keine Vorhersage"))
        XCTAssertTrue(RadarLayerLegendText.hint(for: .cloudmask).contains("keine Wolkendicke"))
    }

    // MARK: Visible channel (cloudmask_vis, backend format: R = G = B, raw 0...~180, alpha 255)

    private func gray(_ value: UInt8, count: Int) -> [UInt8] {
        (0..<count).flatMap { _ in [value, value, value, 255] }
    }

    func testCloudinessNormalisesBySunHeight() {
        // The same surface (normalised value 180) is half cloudy at any sun height: raw = 180 * sin(h).
        let high = VisibleChannel.cloudiness(raw: UInt8((180 * sin(40.0 * .pi / 180)).rounded()), sinElevation: sin(40.0 * .pi / 180))
        let low = VisibleChannel.cloudiness(raw: UInt8((180 * sin(15.0 * .pi / 180)).rounded()), sinElevation: sin(15.0 * .pi / 180))
        XCTAssertEqual(high, low, accuracy: 0.05)
        XCTAssertEqual(VisibleChannel.cloudiness(raw: 0, sinElevation: 0.9), 0)
        XCTAssertEqual(VisibleChannel.cloudiness(raw: 200, sinElevation: 0.5), 1)
        XCTAssertGreaterThan(VisibleChannel.cloudiness(raw: 70, sinElevation: 0.5), VisibleChannel.cloudiness(raw: 60, sinElevation: 0.5))
        XCTAssertEqual(VisibleChannel.weight(elevation: 3), 0)
        XCTAssertEqual(VisibleChannel.weight(elevation: 12), 1)
        XCTAssertEqual(VisibleChannel.weight(elevation: 7.5), 0.5, accuracy: 0.001)
    }

    func testVisibleChannelSoftensDayColoursAndFallsBackAtNight() {
        // 4 x 4 image, Germany bounds. Day: 11:00 UTC (sun > 10 degrees everywhere); the mask says "clear" (green).
        let n = 16
        let green: [UInt8] = (0..<n).flatMap { _ in [0, 192, 0, 255] }
        let day = utc("2026-10-31T11:00:00Z")
        let maskOnly = SunOverlay.render(rgba: green, width: 4, height: 4, bounds: bounds, date: day)
        XCTAssertEqual(maskOnly[3], 140, "mask only: clear = sunny alpha 0.55")
        // Bright visible pixels (normalised far above the cloud value) turn the cell grey, dark ones stay sunny.
        let cloudy = SunOverlay.render(rgba: green, width: 4, height: 4, bounds: bounds, date: day, visible: gray(150, count: n))
        XCTAssertEqual(cloudy[3], 97, accuracy: 3, "0.38 alpha")
        let clear = SunOverlay.render(rgba: green, width: 4, height: 4, bounds: bounds, date: day, visible: gray(0, count: n))
        XCTAssertEqual(clear[3], 140)
        // Soft in between: alpha lies strictly between sunny and cloudy.
        let mid = SunOverlay.render(rgba: green, width: 4, height: 4, bounds: bounds, date: day, visible: gray(54, count: n))
        XCTAssertLessThan(mid[3], 140); XCTAssertGreaterThan(mid[3], 97)
        // Night: the (black or noisy) visible image is ignored, shade only.
        let night = SunOverlay.render(rgba: green, width: 4, height: 4, bounds: bounds, date: utc("2026-10-31T00:00:00Z"),
                                      visible: gray(150, count: n))
        XCTAssertEqual(night[3], UInt8((0.68 * 255).rounded()))
        // A visible image of the wrong size is ignored (mask result).
        let wrong = SunOverlay.render(rgba: green, width: 4, height: 4, bounds: bounds, date: day, visible: gray(150, count: 3))
        XCTAssertEqual(wrong, maskOnly)
    }

    func testComposeIgnoresVisibleImageOfAnotherExtent() throws {
        let image = try mask("clm-20261031T1100Z")
        let small = try XCTUnwrap(SunOverlay.image(rgba: gray(150, count: 16), width: 4, height: 4))
        let a = try XCTUnwrap(SunOverlay.compose(mask: image, visible: small, bounds: bounds, date: utc("2026-10-31T11:00:00Z")))
        let b = try XCTUnwrap(SunOverlay.compose(mask: image, bounds: bounds, date: utc("2026-10-31T11:00:00Z")))
        XCTAssertEqual(SunOverlay.pixels(of: a), SunOverlay.pixels(of: b))
    }

    // MARK: Europe extent (manifest bounds per layer, memory)

    /// Backend `RadarConstants.europeBBox` (lon -25..45, lat 30..72), image 2048 x 2168.
    let europe = RadarBounds(minX: -2782987, minY: 3503550, maxX: 5009377, maxY: 11753185)

    func testEuropeManifestImageInfoGivesItsOwnBoundsAndMapRect() throws {
        let json = #"{"format":"image/webp","width":2048,"height":2168,"projection":"EPSG:3857","bbox":[-2782987.0,3503550.0,5009377.0,11753185.0],"bbox_wgs84":[-25.0,30.0,45.0,72.0]}"#
        let info = try JSONDecoder().decode(RadarImageInfo.self, from: Data(json.utf8))
        XCTAssertEqual(info.validatedBounds, europe)
        let germany = RadarImageGeometry.mapRect(for: bounds), eu = RadarImageGeometry.mapRect(for: europe)
        XCTAssertGreaterThan(eu.width, germany.width * 5)
        XCTAssertLessThan(eu.x, germany.x)
        // The pixel mapping uses the bounds of the given image: Berlin lies in both, at other pixels.
        let inGermany = try XCTUnwrap(SunGeometry.pixel(latitude: 52.52, longitude: 13.405, bounds: bounds, width: 1024, height: 1311))
        let inEurope = try XCTUnwrap(SunGeometry.pixel(latitude: 52.52, longitude: 13.405, bounds: europe, width: 2048, height: 2168))
        XCTAssertNotEqual(inGermany.x, inEurope.x)
        XCTAssertNotNil(SunGeometry.pixel(latitude: 40, longitude: -5, bounds: europe, width: 2048, height: 2168), "Spain is inside")
        XCTAssertNil(SunGeometry.pixel(latitude: 40, longitude: -5, bounds: bounds, width: 1024, height: 1311))
    }

    func testEuropeSunOverlayUsesBoundsAndSpansTimeZones() {
        // 16:00 UTC on 1 Nov: sun still up in the west (Lisbon, about 6 degrees), night in the east (Volga, 44 E).
        let w = 64, h = 68
        let clearMask: [UInt8] = (0..<(w * h)).flatMap { _ in [0, 192, 0, 255] }
        let out = SunOverlay.render(rgba: clearMask, width: w, height: h, bounds: europe, date: utc("2026-11-01T16:00:00Z"))
        func alpha(lat: Double, lon: Double) -> UInt8 {
            let p = SunGeometry.pixel(latitude: lat, longitude: lon, bounds: europe, width: w, height: h)!
            return out[(p.y * w + p.x) * 4 + 3]
        }
        XCTAssertEqual(alpha(lat: 38.7, lon: -9.1), 140, "Lisbon, sun up: sunny")
        XCTAssertEqual(alpha(lat: 45, lon: 44), UInt8((SunOverlay.shadeAlpha(elevation: -30) * 255).rounded()),
                       accuracy: 8, "far east: night shade")
    }

    func testCachesStayWithinByteBudgetForEuropeImages() throws {
        // 2048 x 2168 x 4 = 17.8 MB per image: a 48 MB decoded budget keeps two, a 40 MB composer budget two.
        let cache = DecodedImageCache()
        let big = try XCTUnwrap(SunOverlay.image(rgba: [UInt8](repeating: 0, count: 2048 * 2168 * 4), width: 2048, height: 2168))
        for index in 0..<5 { cache.insert(big, for: URL(string: "https://radar.example.invalid/\(index).webp")!) }
        XCTAssertEqual(cache.count, 2)
        XCTAssertLessThanOrEqual(cache.byteCount, RadarBackendPolicy.decodedImageByteBudget)
        let small = try XCTUnwrap(SunOverlay.image(rgba: [UInt8](repeating: 0, count: 1024 * 1311 * 4), width: 1024, height: 1311))
        let smallCache = DecodedImageCache()
        for index in 0..<12 { smallCache.insert(small, for: URL(string: "https://radar.example.invalid/\(index).webp")!) }
        XCTAssertEqual(smallCache.count, RadarBackendPolicy.decodedImageLimit, "German grid keeps the old count")

        let composer = SunOverlayComposer(bounds: europe, limit: 4)
        let mask = try XCTUnwrap(SunOverlay.image(rgba: (0..<(2048 * 2168)).flatMap { _ in [255, 255, 255, 255] }, width: 2048, height: 2168))
        for index in 0..<3 {
            XCTAssertNotNil(composer.image(for: URL(string: "https://radar.example.invalid/m\(index).webp")!,
                                           time: utc("2026-11-01T12:00:00Z")) { mask })
        }
        XCTAssertLessThanOrEqual(composer.cachedBytes, SunOverlayComposer.byteBudget)
        XCTAssertGreaterThanOrEqual(composer.cachedBytes, 1)
    }

    func testSunTimeZoneOnlyForTheGermanGridIsBerlin() {
        XCTAssertEqual(SunPlace.timeZone(latitude: 52.52, longitude: 13.405).identifier, "Europe/Berlin")
        XCTAssertEqual(SunPlace.timeZone(latitude: 38.7, longitude: -9.1), TimeZone.current, "Lisbon: device zone, not Berlin")
        XCTAssertEqual(SunPlace.timeZone(latitude: 60.17, longitude: 24.94), TimeZone.current, "Helsinki")
    }

    // MARK: Welle 2: vis-Slot-Zuordnung

    private func visSlots(_ times: [String]) -> [RadarManifest.Slot] {
        times.map { RadarManifest.Slot(time: utc($0), kind: .analysis, path: "r/\($0).webp",
                                      url: URL(string: "https://radar.example.invalid/v1/layers/cloudmask_vis/r/\($0).webp")!) }
    }

    func testVisibleSlotMatchesNearestWithinTenMinutes() {
        let slots = visSlots(["2026-11-01T11:00:00Z", "2026-11-01T11:10:00Z", "2026-11-01T11:20:00Z", "2026-11-01T11:30:00Z"])
        func match(_ text: String) -> String? { SunVisibleMatch.nearest(to: utc(text), in: slots).map { $0.path } }
        XCTAssertEqual(match("2026-11-01T11:15:00Z"), "r/2026-11-01T11:10:00Z.webp", "tie: the earlier slot")
        XCTAssertEqual(match("2026-11-01T11:30:00Z"), "r/2026-11-01T11:30:00Z.webp")
        XCTAssertNil(match("2026-11-01T11:44:00Z"), "14 min after the last slot is too far")
        XCTAssertEqual(match("2026-11-01T11:39:59Z"), "r/2026-11-01T11:30:00Z.webp", "inside 10 min")
        XCTAssertNil(match("2026-11-01T11:40:01Z"), "beyond 10 min: mask only")
        XCTAssertNil(match("2026-11-01T10:49:00Z"))
        XCTAssertNil(SunVisibleMatch.nearest(to: Date(), in: []))
    }

    func testVisibleSlotGapFallsBackToMask() {
        // Source gap (night outage): slots at 11:00 and 12:00, the mask slot at 11:30 has no partner.
        let slots = visSlots(["2026-11-01T11:00:00Z", "2026-11-01T12:00:00Z"])
        XCTAssertNil(SunVisibleMatch.nearest(to: utc("2026-11-01T11:30:00Z"), in: slots))
        XCTAssertNil(SunVisibleMatch.nearest(to: utc("2026-11-01T11:45:00Z"), in: slots), "15 min from 12:00")
        XCTAssertNotNil(SunVisibleMatch.nearest(to: utc("2026-11-01T11:51:00Z"), in: slots))
    }

    func testComposerKeepsMaskOnlyAndVisibleCompositionsApart() throws {
        let image = try mask("clm-20261031T1100Z")
        let composer = SunOverlayComposer(bounds: bounds, limit: 4)
        let url = URL(string: "https://radar.example.invalid/a.webp")!
        let vis = URL(string: "https://radar.example.invalid/v.webp")!
        let time = utc("2026-10-31T11:00:00Z")
        let plain = composer.image(for: url, time: time, mask: { image })
        let again = composer.image(for: url, time: time, visibleURL: nil, mask: { image })
        XCTAssertTrue(plain === again)
        var visibleAsked = 0
        let refined = composer.image(for: url, time: time, visibleURL: vis, mask: { image }, visible: { visibleAsked += 1; return image })
        XCTAssertNotNil(refined)
        XCTAssertFalse(plain === refined, "the visible image arriving later replaces the mask-only composition")
        XCTAssertEqual(visibleAsked, 1)
        _ = composer.image(for: url, time: time, visibleURL: vis, mask: { image }, visible: { visibleAsked += 1; return image })
        XCTAssertEqual(visibleAsked, 1, "cached")
        XCTAssertEqual(composer.composeCount, 2)
    }
}
