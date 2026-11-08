import XCTest
@testable import Weather

// Temperature / dew point / relative humidity layers (Teilprojekt 3, P2): model, manifest fields,
// offering rule, legend notes. The layers exist on the cache backend only and appear once its manifest is there.
final class TemperatureLayerTests: XCTestCase {
    let radarBase = URL(string: "https://radar.example.invalid/v1/radar/")!
    static let fieldLayers: [RadarLayer] = [.temperature, .dewpoint, .humidity]

    func base(_ layer: RadarLayer) -> URL { RadarBackendConfig.layersBaseURL(for: layer, radarBaseURL: radarBase) }
    func fixture(_ name: String) throws -> Data {
        let bundle = Bundle(for: TemperatureLayerTests.self)
        let url = bundle.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")
            ?? bundle.url(forResource: name, withExtension: "json")
        return try Data(contentsOf: XCTUnwrap(url))
    }
    func parse(_ name: String, _ layer: RadarLayer) throws -> RadarLayerManifest {
        try RadarLayerManifest.parse(fixture(name), expected: layer, layersBaseURL: base(layer))
    }
    func utc(_ text: String) -> Date { DWDRequest.date(text)! }

    // MARK: Model

    func testRawValuesAndMembership() {
        XCTAssertEqual(RadarLayer.temperature.rawValue, "temperature")
        XCTAssertEqual(RadarLayer.dewpoint.rawValue, "dewpoint")
        XCTAssertEqual(RadarLayer.humidity.rawValue, "humidity")
        for layer in Self.fieldLayers {
            XCTAssertTrue(RadarLayer.selectable.contains(layer))
            XCTAssertTrue(RadarLayer.backendLayers.contains(layer))
            XCTAssertTrue(layer.isBackendLayer)
            XCTAssertFalse(layer.isOfferedWhenUnavailable, "only visible once the manifest is there")
            XCTAssertFalse(layer.isEurope)
            XCTAssertEqual(layer.nominalStepMinutes, 60)
            XCTAssertEqual(layer.prefetchSlotLimit, 13)
            XCTAssertEqual(layer.overlayOpacity, 0.8)
            XCTAssertEqual(layer.maximumObservationAge, 0)
            XCTAssertEqual(layer.pollInterval, 300)
            XCTAssertFalse(layer.symbolName.isEmpty)
            XCTAssertEqual(layer.backendPathComponent, layer.rawValue)
        }
        XCTAssertEqual(RadarLayer.selectable.prefix(4), [.radar, .pressure, .pressureEU, .temperature])
        XCTAssertTrue([RadarLayer.radar, .pressure, .lightning, .clouds, .cloudmask].allSatisfy(\.isOfferedWhenUnavailable))
        XCTAssertFalse(RadarLayer.pressureEU.isOfferedWhenUnavailable)
    }

    func testTitlesAndCaptionsMarkTheValuesAsModel() {
        XCTAssertTrue(["Temperatur", "Temperature"].contains(RadarLayer.temperature.title))
        XCTAssertTrue(["Feuchte (Taupunkt)", "Humidity (dew point)"].contains(RadarLayer.dewpoint.title))
        XCTAssertTrue(["Feuchte (relativ)", "Humidity (relative)"].contains(RadarLayer.humidity.title))
        for layer in Self.fieldLayers {
            XCTAssertTrue(layer.spokenName.localizedCaseInsensitiveContains("model"), layer.rawValue)
            XCTAssertTrue(layer.frameCaption(isForecast: true).localizedCaseInsensitiveContains("model"))
            XCTAssertTrue(layer.frameCaption(isForecast: false).localizedCaseInsensitiveContains("model"))
            XCTAssertTrue(layer.timeAxisLabel.contains(layer.title))
        }
        // untouched captions of the existing layers
        XCTAssertEqual(RadarLayer.pressure.frameCaption(isForecast: true), "Vorhersage")
        XCTAssertEqual(RadarLayer.lightning.frameCaption(isForecast: false), "Messung")
    }

    // MARK: Manifest

    func testParsesWMSTemperatureManifest() throws {
        let value = try parse("layer-temperature-wms", .temperature)
        XCTAssertEqual(value.kind, .forecast)
        XCTAssertEqual(value.slots.count, 49)
        XCTAssertEqual(value.stepMinutes, 60)
        XCTAssertEqual(value.source, "wms")
        XCTAssertNil(value.scale)
        XCTAssertEqual(value.legend?.url.host, "maps.dwd.de")
        XCTAssertEqual(value.slots.first?.kind, .analysis)
        XCTAssertEqual(value.slots.last?.kind, .forecast)
        XCTAssertEqual(value.slots[1].url.absoluteString,
                       "https://radar.example.invalid/v1/layers/temperature/20261031T1200Z/20261031T1300Z.webp")
    }

    func testParsesIconD2ManifestsWithScale() throws {
        let temperature = try parse("layer-temperature-d2", .temperature)
        XCTAssertEqual(temperature.source, "icon_d2")
        XCTAssertEqual(temperature.scale, "t2m-d2-v1")
        XCTAssertNil(temperature.legend)
        XCTAssertEqual(try parse("layer-dewpoint-d2", .dewpoint).scale, "td-d2-v1")
        XCTAssertEqual(try parse("layer-humidity-d2", .humidity).scale, "rh-d2-v1")
    }

    func testExistingManifestsHaveNoSourceOrScale() throws {
        let value = try RadarLayerManifest.parse(fixture("layer-pressure"), expected: .pressure, layersBaseURL: base(.pressure))
        XCTAssertNil(value.source)
        XCTAssertNil(value.scale)
    }

    func testWrongLayerIsRejected() {
        XCTAssertThrowsError(try parse("layer-dewpoint-d2", .temperature))
        XCTAssertThrowsError(try parse("layer-temperature-d2", .humidity))
    }

    func testForecastFreshnessOfFortyEightHours() throws {
        let value = try parse("layer-temperature-d2", .temperature)
        XCTAssertTrue(value.isFresh(at: utc("2026-10-31T13:30:00Z")))
        XCTAssertTrue(value.isFresh(at: utc("2026-11-02T11:30:00Z")) == false, "run older than 18 h is not shown as current")
        let timeline = value.timeline(at: utc("2026-10-31T13:30:00Z"))
        XCTAssertEqual(timeline.dates.count, 49)
        XCTAssertEqual(timeline.referenceTime, utc("2026-10-31T13:00:00Z"), "the slot of the current hour is 'now'")
    }

    // MARK: Offering (like pressureEU)

    @MainActor
    func testLayersAreOfferedOnlyWithManifest() async throws {
        let withTemperature = TemperatureResponder.serving(["temperature": try fixture("layer-temperature-d2"),
                                                 "dewpoint": try fixture("layer-dewpoint-d2"),
                                                 "pressure": try fixture("layer-pressure")])
        let now = utc("2026-10-31T13:30:00Z")
        let store = RadarLayerStore(radarBaseURL: radarBase,
                                    client: RadarLayerClient(radarBaseURL: radarBase, transport: withTemperature.transport,
                                                             clock: { now }),
                                    clock: { now })
        XCTAssertFalse(store.isOffered(.temperature), "not asked yet: no menu entry, no greyed-out entry")
        XCTAssertFalse(store.offeredLayers.contains(.dewpoint))
        await store.probeAll(force: true)
        XCTAssertTrue(store.offeredLayers.contains(.temperature))
        XCTAssertTrue(store.offeredLayers.contains(.dewpoint))
        XCTAssertFalse(store.offeredLayers.contains(.humidity), "server does not offer relative humidity (flag off)")
        XCTAssertEqual(store.availability(.humidity), .notPublished)
        XCTAssertFalse(store.select(.humidity))
        XCTAssertTrue(store.select(.dewpoint))
        XCTAssertEqual(store.active, .dewpoint)
        XCTAssertEqual(store.activeTimeline?.dates.count, 49)
        // server switches the source off: silent hand-back to the radar
        store.apply(.notPublished, to: .dewpoint, now: utc("2026-10-31T13:31:00Z"))
        XCTAssertEqual(store.active, .radar)
        XCTAssertFalse(store.isOffered(.dewpoint))
    }

    // MARK: Legend

    func testHintsAreModelValuesWithoutFeltTemperatureAndWithoutHumidityWords() {
        for layer in Self.fieldLayers {
            let hint = RadarLayerLegendText.hint(for: layer)
            XCTAssertTrue(hint.contains("Modell") || hint.contains("model"), layer.rawValue)
            XCTAssertTrue(hint.contains("kein Messwert") || hint.contains("not a measurement"), layer.rawValue)
            for forbidden in ["gefühlt", "Wald", "schwül", "trocken", "feels", "muggy"] {
                XCTAssertFalse(hint.localizedCaseInsensitiveContains(forbidden), "\(layer.rawValue): \(forbidden)")
            }
            XCTAssertFalse(RadarLayerLegendText.title(for: layer).isEmpty)
            XCTAssertFalse(RadarLayerLegendText.toggleHint(for: layer).isEmpty)
        }
    }

    func testLegendImageOnlyForWMSTemperature() throws {
        let wms = try parse("layer-temperature-wms", .temperature)
        let d2 = try parse("layer-temperature-d2", .temperature)
        XCTAssertTrue(RadarLayerLegendText.usesLegendImage(for: .temperature, manifest: wms))
        XCTAssertFalse(RadarLayerLegendText.usesLegendImage(for: .temperature, manifest: d2))
        XCTAssertFalse(RadarLayerLegendText.usesLegendImage(for: .dewpoint, manifest: try parse("layer-dewpoint-d2", .dewpoint)))
        XCTAssertTrue(RadarLayerLegendText.usesLegendImage(for: .lightning, manifest: nil))
        XCTAssertFalse(RadarLayerLegendText.usesLegendImage(for: .pressure, manifest: nil))
    }

    func testForeignLegendHostIsDroppedForTemperature() throws {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: fixture("layer-temperature-wms")) as? [String: Any])
        object["legend"] = ["url": "https://evil.example.invalid/l.png", "width": 88, "height": 505]
        let data = try JSONSerialization.data(withJSONObject: object)
        let value = try RadarLayerManifest.parse(data, expected: .temperature, layersBaseURL: base(.temperature))
        XCTAssertNil(value.legend)
    }

    func testUnknownScaleGivesOnlyANoteAndNoGuessedRaster() throws {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: fixture("layer-dewpoint-d2")) as? [String: Any])
        object["scale"] = "td-d2-v9"
        let unknown = try RadarLayerManifest.parse(JSONSerialization.data(withJSONObject: object), expected: .dewpoint,
                                                   layersBaseURL: base(.dewpoint))
        let note = try XCTUnwrap(RadarLayerLegendText.sourceNote(for: .dewpoint, manifest: unknown))
        XCTAssertFalse(note.isEmpty)
        XCTAssertFalse(RadarLayerLegendText.usesLegendImage(for: .dewpoint, manifest: unknown))
        // WMS temperature with its image needs no extra note, other layers none
        XCTAssertNil(RadarLayerLegendText.sourceNote(for: .temperature, manifest: try parse("layer-temperature-wms", .temperature)))
        XCTAssertNil(RadarLayerLegendText.sourceNote(for: .pressure, manifest: nil))
        // unknown source value is treated like an unknown scale
        object["scale"] = nil
        object["source"] = "satellite"
        let foreign = try RadarLayerManifest.parse(JSONSerialization.data(withJSONObject: object), expected: .dewpoint,
                                                   layersBaseURL: base(.dewpoint))
        XCTAssertNotNil(RadarLayerLegendText.sourceNote(for: .dewpoint, manifest: foreign))
    }

    func testSourceLineIsTheManifestAttribution() throws {
        let value = try parse("layer-dewpoint-d2", .dewpoint)
        XCTAssertEqual(value.attribution, "Quelle: Deutscher Wetterdienst")
        XCTAssertTrue(value.modificationNotice.contains("ICON-D2"))
    }
}

/// Minimal transport for the layer client: serves `latest.json` per layer id, `404` otherwise.
struct TemperatureResponder {
    let transport: RadarBackendClient.Transport
    static func serving(_ files: [String: Data]) -> TemperatureResponder {
        TemperatureResponder { request in
            let id = request.url!.pathComponents.dropLast().last!
            let response = HTTPURLResponse(url: request.url!, statusCode: files[id] == nil ? 404 : 200, httpVersion: nil, headerFields: nil)!
            return (files[id] ?? Data(), response)
        }
    }
    init(_ transport: @escaping RadarBackendClient.Transport) { self.transport = transport }
}
