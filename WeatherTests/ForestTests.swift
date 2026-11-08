import XCTest
@testable import Weather

// Forest orientation layer (Teilprojekt 3, P5): bundled data, setting, source line, memory handling.
final class ForestTests: XCTestCase {
    func testBundledInfoMatchesToolOutput() throws {
        let info = try XCTUnwrap(ForestInfo.bundled)
        XCTAssertEqual(info.width, 2048)
        XCTAssertEqual(info.height, 2622)
        XCTAssertEqual(info.bounds, RadarBounds(minX: 612257.5, minY: 5942074, maxX: 1736584, maxY: 7381298))
        XCTAssertEqual(info.attribution, "© ESA WorldCover project 2021 / Contains modified Copernicus Sentinel data (2021) processed by ESA WorldCover consortium")
        XCTAssertFalse(info.modificationNotice.isEmpty)
        XCTAssertTrue(info.sourceLine.contains("ESA WorldCover"))
    }

    func testOnlyOverAirFieldsAndOnlyWhenSwitchedOn() throws {
        let info = ForestInfo.bundled
        for layer in RadarLayer.allCases {
            XCTAssertEqual(ForestPreference.isShown(layer: layer, visible: true, info: info), layer.isAirField, layer.rawValue)
            XCTAssertFalse(ForestPreference.isShown(layer: layer, visible: false, info: info))
        }
        XCTAssertFalse(ForestPreference.isShown(layer: .temperature, visible: true, info: nil))
    }

    func testPreferenceDefaultsOffAndIsRemembered() {
        let defaults = UserDefaults(suiteName: "forest-test-\(UUID().uuidString)")!
        XCTAssertFalse(ForestPreference.isVisible(defaults))
        ForestPreference.set(true, defaults)
        XCTAssertTrue(ForestPreference.isVisible(defaults))
    }

    func testSourceLineGetsForestSourceOnlyWhileShown() throws {
        let info = ForestInfo.bundled
        let base = "Quelle: Deutscher Wetterdienst · Showers-Server"
        XCTAssertEqual(ForestPreference.sourceLine(base: base, layer: .dewpoint, visible: false, info: info), base)
        XCTAssertEqual(ForestPreference.sourceLine(base: base, layer: .pressure, visible: true, info: info), base)
        let line = try XCTUnwrap(ForestPreference.sourceLine(base: base, layer: .dewpoint, visible: true, info: info))
        XCTAssertTrue(line.hasPrefix(base))
        XCTAssertTrue(line.contains("ESA WorldCover") && line.contains("550"))
        XCTAssertNil(ForestPreference.sourceLine(base: nil, layer: .dewpoint, visible: true, info: info))
    }

    func testInfoParserRejectsBrokenData() {
        XCTAssertNil(ForestInfo.parse(Data("{}".utf8)))
        XCTAssertNil(ForestInfo.parse(Data(#"{"schema":1,"bounds_epsg3857":[5,5,1,1],"width":10,"height":10,"attribution":"a","modification_notice":"b"}"#.utf8)))
        XCTAssertNil(ForestInfo.parse(Data(#"{"schema":1,"bounds_epsg3857":[1,1,5,5],"width":10,"height":10,"attribution":"","modification_notice":"b"}"#.utf8)))
    }

    func testImageIsDecodedLazilyAndReleasable() throws {
        let info = try XCTUnwrap(ForestInfo.bundled)
        let store = ForestImageStore(observeMemoryWarnings: false)
        XCTAssertFalse(store.isLoaded)
        let image = try XCTUnwrap(store.current(info: info))
        XCTAssertEqual(image.width, 2048)
        XCTAssertEqual(image.height, 2622)
        XCTAssertTrue(store.isLoaded)
        store.release()
        XCTAssertFalse(store.isLoaded)
        XCTAssertNotNil(store.current(info: info), "decoded again on the next draw")
        store.release()
    }

    func testMemoryWarningReleasesTheSharedImage() throws {
        let info = try XCTUnwrap(ForestInfo.bundled)
        _ = ForestImageStore.shared.current(info: info)
        XCTAssertTrue(ForestImageStore.shared.isLoaded)
        NotificationCenter.default.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        XCTAssertFalse(ForestImageStore.shared.isLoaded)
    }

    func testForestImageHasFourAlphaLevels() throws {
        let info = try XCTUnwrap(ForestInfo.bundled)
        let image = try XCTUnwrap(ForestImageStore(observeMemoryWarnings: false).current(info: info))
        // Black Forest (48.0 N, 8.2 E) is wooded, the North Sea is not.
        let wood = try XCTUnwrap(PixelReadout.pixel(latitude: 48.0, longitude: 8.2, bounds: info.bounds, width: image.width, height: image.height))
        let sea = try XCTUnwrap(PixelReadout.pixel(latitude: 54.5, longitude: 6.0, bounds: info.bounds, width: image.width, height: image.height))
        let woodAlpha = try XCTUnwrap(PixelReadout.rgba(of: image, x: wood.x, y: wood.y)).a
        let seaAlpha = try XCTUnwrap(PixelReadout.rgba(of: image, x: sea.x, y: sea.y)).a
        XCTAssertTrue([85, 170, 255].contains(Int(woodAlpha)), "alpha \(woodAlpha)")
        XCTAssertEqual(seaAlpha, 0)
    }
}
