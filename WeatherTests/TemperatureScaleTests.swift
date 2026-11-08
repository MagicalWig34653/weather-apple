import XCTest
@testable import Weather

// Colour scales of the 2 m fields (Teilprojekt 3, P5): bundled table, validation, legend rows, fail-closed lookup.
final class TemperatureScaleTests: XCTestCase {
    func fixtureData(_ name: String = "scales-v1") throws -> Data {
        let bundle = Bundle(for: TemperatureScaleTests.self)
        let url = bundle.url(forResource: name, withExtension: "json", subdirectory: "Fixtures") ?? bundle.url(forResource: name, withExtension: "json")
        return try Data(contentsOf: XCTUnwrap(url))
    }

    func testBundledTableEqualsBackendContractCopy() throws {
        let contract = try TemperatureScale.parse(fixtureData())
        XCTAssertEqual(Set(contract.map(\.id)), ["t2m-d2-v1", "td-d2-v1", "rh-d2-v1"])
        XCTAssertEqual(Set(TemperatureScale.bundled.keys), Set(contract.map(\.id)))
        for scale in contract { XCTAssertEqual(TemperatureScale.bundled[scale.id], scale) }
    }

    func testBandCountsAndRanges() throws {
        let t = try XCTUnwrap(TemperatureScale.bundled["t2m-d2-v1"])
        XCTAssertEqual(t.bands.count, 70)
        XCTAssertEqual(t.bands.first?.from, -30)
        XCTAssertEqual(try XCTUnwrap(TemperatureScale.bundled["td-d2-v1"]).bands.count, 44)
        XCTAssertEqual(try XCTUnwrap(TemperatureScale.bundled["rh-d2-v1"]).bands.count, 20)
    }

    func testValueToBandClampsOutsideTheRange() throws {
        let t = try XCTUnwrap(TemperatureScale.bundled["t2m-d2-v1"])
        XCTAssertEqual(t.bandIndex(forValue: -45), 0)
        XCTAssertEqual(t.bandIndex(forValue: -30), 0)
        XCTAssertEqual(t.bandIndex(forValue: -0.01), 29)
        XCTAssertEqual(t.bandIndex(forValue: 0), 30)
        XCTAssertEqual(t.bandIndex(forValue: 7.9), 37)
        XCTAssertEqual(t.bandIndex(forValue: 80), 69)
    }

    func testColourLookupExactAndUnknown() throws {
        let t = try XCTUnwrap(TemperatureScale.bundled["t2m-d2-v1"])
        for (index, band) in t.bands.enumerated() {
            XCTAssertEqual(t.bandIndex(red: band.red, green: band.green, blue: band.blue), index, "band \(index)")
        }
        XCTAssertNil(t.bandIndex(red: 0, green: 255, blue: 0))
    }

    func testRangeTextsAreModelWordedAndHaveOpenEnds() throws {
        let t = try XCTUnwrap(TemperatureScale.bundled["t2m-d2-v1"])
        XCTAssertTrue(t.rangeText(37).contains("7") && t.rangeText(37).contains("8"))
        XCTAssertTrue(t.rangeText(0).contains("29"))      // unter -29
        XCTAssertTrue(t.rangeText(69).contains("39"))     // ab 39
        XCTAssertTrue(t.readoutText(bandIndex: 37, spoken: true).localizedCaseInsensitiveContains("model"))
        XCTAssertTrue(t.readoutText(bandIndex: 37, spoken: false).localizedCaseInsensitiveContains("model"))
    }

    func testLegendRowsLabelEveryFiveAndHaveSpokenText() throws {
        let t = try XCTUnwrap(TemperatureScale.bundled["t2m-d2-v1"])
        XCTAssertEqual(t.legendRows.count, 14)
        XCTAssertTrue(t.legendRows.allSatisfy { !$0.spokenLabel.isEmpty && !$0.label.isEmpty && $0.bands.count == 5 })
        XCTAssertEqual(t.legendRows.flatMap(\.bands).count, 70)
        let rh = try XCTUnwrap(TemperatureScale.bundled["rh-d2-v1"])
        XCTAssertEqual(rh.legendRows.count, 5)
        XCTAssertTrue(rh.legendRows[1].spokenLabel.contains("20") && rh.legendRows[1].spokenLabel.contains("40"))
    }

    func testRejectsDamagedTables() throws {
        let good = try XCTUnwrap(String(data: fixtureData(), encoding: .utf8))
        XCTAssertThrowsError(try TemperatureScale.parse(Data(good.replacingOccurrences(of: "\"schema\": 1", with: "\"schema\": 2").utf8)))
        XCTAssertThrowsError(try TemperatureScale.parse(Data(good.replacingOccurrences(of: "#240a4a", with: "#24").utf8)))
        XCTAssertThrowsError(try TemperatureScale.parse(Data(good.replacingOccurrences(of: "{\"from\": -29, \"hex\": \"#270f53\"},", with: "").utf8)))
        XCTAssertThrowsError(try TemperatureScale.parse(Data("{}".utf8)))
    }

    func testLookupFailsClosedForUnknownOrForeignIds() {
        XCTAssertNotNil(TemperatureScale.scale(for: "td-d2-v1", layer: .dewpoint))
        XCTAssertNil(TemperatureScale.scale(for: "td-d2-v9", layer: .dewpoint))
        XCTAssertNil(TemperatureScale.scale(for: "t2m-d2-v1", layer: .dewpoint), "scale of another layer")
        XCTAssertNil(TemperatureScale.scale(for: nil, layer: .temperature))
    }

    func testManifestNativeScaleOnlyForIconD2() throws {
        let base = URL(string: "https://radar.example.invalid/v1/layers/dewpoint/")!
        let data = try fixtureData("layer-dewpoint-d2")
        let manifest = try RadarLayerManifest.parse(data, expected: .dewpoint, layersBaseURL: base)
        XCTAssertEqual(manifest.nativeScale?.id, "td-d2-v1")
        XCTAssertNil(RadarLayerLegendText.sourceNote(for: .dewpoint, manifest: manifest), "known scale: no fail-closed note")
        let wms = try RadarLayerManifest.parse(fixtureData("layer-temperature-wms"), expected: .temperature,
                                               layersBaseURL: URL(string: "https://radar.example.invalid/v1/layers/temperature/")!)
        XCTAssertNil(wms.nativeScale)
    }
}
