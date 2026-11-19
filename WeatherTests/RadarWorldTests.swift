import XCTest
@testable import Weather

// Third rain map (world, NOAA RRQPE satellite estimate): manifest of the real backend, coverage, honest states,
// attribution. The fixture `layer-radar_world.json` is a manifest served by a local backend from PR #2
// (feature/radar-world, 728191b) on 19.11.2026 with real NOAA slots (05:10 to 06:10 UTC), unchanged.
final class RadarWorldTests: XCTestCase {
    let radarBase = URL(string: "https://radar.example.invalid/v1/radar/")!
    var worldBase: URL { RadarBackendConfig.layersBaseURL(for: .radarWorld, radarBaseURL: radarBase) }

    func fixture() throws -> Data {
        let bundle = Bundle(for: RadarWorldTests.self)
        let url = bundle.url(forResource: "layer-radar_world", withExtension: "json", subdirectory: "Fixtures")
            ?? bundle.url(forResource: "layer-radar_world", withExtension: "json")
        return try Data(contentsOf: XCTUnwrap(url))
    }

    func manifest() throws -> RadarLayerManifest {
        try RadarLayerManifest.parse(fixture(), expected: .radarWorld, layersBaseURL: worldBase)
    }

    // MARK: Manifest

    func testParsesRealWorldManifest() throws {
        let value = try manifest()
        XCTAssertEqual(value.layer, .radarWorld)
        XCTAssertEqual(value.kind, .observation)
        XCTAssertEqual(value.stepMinutes, 10)
        XCTAssertEqual(value.source, "noaa_rrqpe")
        XCTAssertNil(value.legend, "the app draws the rain scale itself")
        XCTAssertEqual(value.backend.imageWidth, 2048)
        XCTAssertEqual(value.backend.imageHeight, 995)
        XCTAssertFalse(value.slots.isEmpty)
        XCTAssertTrue(value.slots.allSatisfy { $0.kind == .analysis }, "observation slots only, no forecast")
        XCTAssertTrue(value.slots[0].url.absoluteString.hasPrefix("https://radar.example.invalid/v1/layers/radar_world/"))
        XCTAssertTrue(value.attribution.contains("NOAA"))
        XCTAssertTrue(value.attribution.contains("geschätzt"), "the estimate is part of the credit")
        XCTAssertFalse(value.attribution.lowercased().contains("logo"))
        XCTAssertTrue(value.modificationNotice.contains("umprojiziert"), "processed data is never passed off as the original")
    }

    func testWorldBoundsCoverTheWholeWidthFrom60SouthTo70North() throws {
        let bounds = try manifest().backend.bounds
        XCTAssertEqual(bounds.minX, -RadarBounds.halfWorld, accuracy: 1)
        XCTAssertEqual(bounds.maxX, RadarBounds.halfWorld, accuracy: 1)
        func latitude(_ y: Double) -> Double { atan(sinh(y / RadarBounds.halfWorld * .pi)) * 180 / .pi }
        XCTAssertEqual(latitude(bounds.minY), -60, accuracy: 0.01)
        XCTAssertEqual(latitude(bounds.maxY), 70, accuracy: 0.01)
        // North up: maxY is north. MapKit's rect starts at the north edge.
        let rect = RadarImageGeometry.mapRect(for: bounds)
        XCTAssertEqual(MKMapPointCoordinate.latitude(x: rect.x, y: rect.y), 70, accuracy: 0.01)
        XCTAssertEqual(MKMapPointCoordinate.latitude(x: rect.x, y: rect.y + rect.height), -60, accuracy: 0.01)
        XCTAssertEqual(MKMapPointCoordinate.longitude(x: rect.x, y: rect.y), -180, accuracy: 0.01)
    }

    // MARK: Coverage

    func testCoverageByLatitude() {
        XCTAssertEqual(RainLayerNotice.coverage(latitude: 50), .full)
        XCTAssertEqual(RainLayerNotice.coverage(latitude: -59.9), .full)
        XCTAssertEqual(RainLayerNotice.coverage(latitude: 60), .full)
        XCTAssertEqual(RainLayerNotice.coverage(latitude: 60.1), .degraded)
        XCTAssertEqual(RainLayerNotice.coverage(latitude: 70), .degraded)
        XCTAssertEqual(RainLayerNotice.coverage(latitude: 70.1), .outside)
        XCTAssertEqual(RainLayerNotice.coverage(latitude: -60.1), .outside)
        XCTAssertEqual(RainLayerNotice.coverage(latitude: .nan), .full, "unknown map centre: no coverage note")
    }

    // MARK: Notices (appear and disappear)

    func testEstimateNoticeOnlyWhileWorldIsActive() {
        let world = RainLayerNotice.notices(active: .radarWorld, availability: .available, centerLatitude: 50)
        XCTAssertEqual(world.map(\.kind), [.estimate])
        XCTAssertTrue(world[0].text.contains("Satellit"))
        XCTAssertTrue(world[0].text.contains("ungenauer"))
        XCTAssertFalse(world[0].text.contains("NOAA"), "no endorsement wording in the hint")
        for layer in [RadarLayer.radar, .radarEU, .pressure] {
            XCTAssertEqual(RainLayerNotice.notices(active: layer, availability: .available, centerLatitude: 80), [], "\(layer)")
        }
    }

    func testCoverageNoticeAppearsOutsideAndDisappearsInside() {
        let north = RainLayerNotice.notices(active: .radarWorld, availability: .available, centerLatitude: 78)
        XCTAssertEqual(north.map(\.kind), [.estimate, .outside])
        XCTAssertTrue(north[1].text.contains("70"))
        let fringe = RainLayerNotice.notices(active: .radarWorld, availability: .available, centerLatitude: 65)
        XCTAssertEqual(fringe.map(\.kind), [.estimate, .degraded])
        let back = RainLayerNotice.notices(active: .radarWorld, availability: .available, centerLatitude: 48)
        XCTAssertEqual(back.map(\.kind), [.estimate])
    }

    func testUnavailableNoticeNamesTheStateAndNoCoverageNoteWithoutData() {
        for state in [LayerAvailability.notPublished, .unreachable, .invalid, .stale] {
            let notices = RainLayerNotice.notices(active: .radarWorld, availability: state, centerLatitude: 80)
            XCTAssertEqual(notices.map(\.kind), [.estimate, .unavailable], "\(state)")
            XCTAssertFalse(notices[1].text.isEmpty)
        }
        XCTAssertEqual(RainLayerNotice.notices(active: .radarWorld, availability: .unknown, centerLatitude: 50).map(\.kind), [.estimate],
                       "still loading: no error yet")
    }

    // MARK: Store: no silent fallback

    @MainActor
    func testWorldStaysActiveWhenItDisappearsInsteadOfFallingBackToGermany() throws {
        let manifest = try manifest()
        let now = manifest.slots.last!.time.addingTimeInterval(120)
        let store = RadarLayerStore(radarBaseURL: radarBase, client: RadarLayerClient(radarBaseURL: radarBase, transport: { request in
            (Data(), HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!)
        }), clock: { now })
        store.apply(.fresh(manifest), to: .radarWorld, now: now)
        XCTAssertTrue(store.select(.radarWorld))
        XCTAssertEqual(store.activeTimeline?.dates.count, manifest.slots.count)
        for outcome in [RadarLayerClient.Outcome.notPublished, .stale, .invalid, .unreachable] {
            store.apply(outcome, to: .radarWorld, now: now.addingTimeInterval(7200))
            XCTAssertEqual(store.active, .radarWorld, "no silent switch to another source (\(outcome))")
            XCTAssertNil(store.activeManifest, "no old picture shown as current")
            XCTAssertNotEqual(store.availability(.radarWorld), .available)
            XCTAssertEqual(store.rainMenuEntries.last, .init(layer: .radarWorld, isSoon: false), "active entry keeps its checkmark")
            store.apply(.fresh(manifest), to: .radarWorld, now: now)
            XCTAssertEqual(store.availability(.radarWorld), .available, "notice disappears once data is back")
        }
    }

    /// Europe (19.11., Lino): like the world map, no silent switch to Germany; one note, then recovery on the next refresh.
    @MainActor
    func testEuropeStaysActiveWhenItDisappearsAndRecovers() throws {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: fixture()) as? [String: Any])
        object["layer"] = "radar_eu"
        let europe = try RadarLayerManifest.parse(JSONSerialization.data(withJSONObject: object), expected: .radarEU,
                                                  layersBaseURL: RadarBackendConfig.layersBaseURL(for: .radarEU, radarBaseURL: radarBase))
        let now = europe.slots.last!.time.addingTimeInterval(120)
        let store = RadarLayerStore(radarBaseURL: radarBase, client: RadarLayerClient(radarBaseURL: radarBase, transport: { request in
            (Data(), HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!)
        }), clock: { now })
        store.apply(.fresh(europe), to: .radarEU, now: now)
        XCTAssertTrue(store.select(.radarEU))
        for outcome in [RadarLayerClient.Outcome.notPublished, .stale, .invalid, .unreachable] {
            store.apply(outcome, to: .radarEU, now: now.addingTimeInterval(7200))
            XCTAssertEqual(store.active, .radarEU, "Europe stays chosen (\(outcome))")
            XCTAssertNil(store.activeManifest)
            let notices = RainLayerNotice.notices(active: .radarEU, availability: store.availability(.radarEU), centerLatitude: 80)
            XCTAssertEqual(notices.map(\.kind), [.unavailable], "exactly one note, no estimate/coverage note for Europe")
            guard notices.count == 1 else { continue }
            XCTAssertTrue(notices[0].text.contains("Europa"), notices[0].text)
            XCTAssertEqual(notices[0].identifier, "radar-eu-note-unavailable")
            store.apply(.fresh(europe), to: .radarEU, now: now)
            XCTAssertEqual(store.active, .radarEU)
            XCTAssertEqual(RainLayerNotice.notices(active: .radarEU, availability: store.availability(.radarEU), centerLatitude: 50), [],
                           "note disappears once data is back")
        }
    }

    @MainActor
    func testGermanyAndOtherLayersKeepTheirBehaviour() {
        XCTAssertEqual(RainLayerNotice.notices(active: .radar, availability: .notPublished, centerLatitude: 50), [])
        XCTAssertEqual(RainLayerNotice.notices(active: .pressureEU, availability: .notPublished, centerLatitude: 50), [])
        XCTAssertFalse(RadarLayer.pressureEU.staysActiveWhenUnavailable, "Europe pressure keeps its quiet fallback")
        XCTAssertFalse(RadarLayer.lightning.staysActiveWhenUnavailable)
        XCTAssertEqual(RainLayerNotice.notices(active: .radarWorld, availability: .available, centerLatitude: 50).first?.identifier,
                       "radar-world-note-estimate", "world identifiers unchanged")
    }

    // MARK: Name

    func testVisibleWorldNameIsRegenWelt() throws {
        XCTAssertEqual(RadarLayer.radarWorld.title, "Regen Welt")
        XCTAssertTrue(RadarLayer.radarWorld.spokenName.hasPrefix("Regen Welt, "), RadarLayer.radarWorld.spokenName)
        XCTAssertEqual(RadarLayer.radarWorld.menuTitle, "Welt (NOAA)", "menu entry unchanged")
        XCTAssertEqual(RadarLayer.radarEU.title, "Regenradar Europa", "Europe name unchanged")
        let path = try XCTUnwrap(Bundle.main.path(forResource: "Localizable", ofType: "strings", inDirectory: nil, forLocalization: "en"))
        let en = try XCTUnwrap(NSDictionary(contentsOfFile: path) as? [String: String])
        XCTAssertEqual(en["LAYER_RADAR_WORLD_TITLE"], "Rain world")
        XCTAssertEqual(en["LAYER_RADAR_WORLD_SPOKEN"]?.hasPrefix("Rain world, "), true)
    }

    // MARK: Attribution

    @MainActor
    func testShortCreditIsNOAAWithoutLogoOrEndorsement() throws {
        XCTAssertEqual(RadarLayer.radarWorld.shortAttribution, "NOAA")
        XCTAssertEqual(RadarLayer.radarWorld.frameCaption(isForecast: true), RadarLayer.radarWorld.frameCaption(isForecast: false),
                       "never called a forecast")
    }
}

/// Inverse of MapKit's map point projection (`MKMapPoint` world is 2^28 points wide), without MapKit in the assertion.
private enum MKMapPointCoordinate {
    static let world = 268_435_456.0
    static func longitude(x: Double, y: Double) -> Double { x / world * 360 - 180 }
    static func latitude(x: Double, y: Double) -> Double {
        let n = .pi * (1 - 2 * y / world)
        return atan(sinh(n)) * 180 / .pi
    }
}
