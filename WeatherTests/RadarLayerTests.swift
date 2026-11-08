import CoreGraphics
import XCTest
@testable import Weather

// Logic tests without network: manifests of the optional layers, layer state, 404 handling, time axes,
// attribution, prefetch rules. Fixtures follow the backend's `LayerManifest.build` output.
final class RadarLayerTests: XCTestCase {
    let radarBase = URL(string: "https://radar.example.invalid/v1/radar/")!

    func base(_ layer: RadarLayer) -> URL { RadarBackendConfig.layersBaseURL(for: layer, radarBaseURL: radarBase) }

    func fixture(_ name: String) throws -> Data {
        let bundle = Bundle(for: RadarLayerTests.self)
        let url = bundle.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")
            ?? bundle.url(forResource: name, withExtension: "json")
        return try Data(contentsOf: XCTUnwrap(url))
    }

    func manifest(_ layer: RadarLayer) throws -> RadarLayerManifest {
        try RadarLayerManifest.parse(fixture("layer-\(layer.rawValue)"), expected: layer, layersBaseURL: base(layer))
    }

    func utc(_ text: String) -> Date { DWDRequest.date(text)! }

    private func modified(_ name: String, _ change: (inout [String: Any]) -> Void) throws -> Data {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: fixture(name)) as? [String: Any])
        change(&object)
        return try JSONSerialization.data(withJSONObject: object)
    }

    // MARK: URLs

    func testLayerBaseURLsDeriveFromRadarBase() {
        XCTAssertEqual(base(.pressure).absoluteString, "https://radar.example.invalid/v1/layers/pressure/")
        XCTAssertEqual(base(.cloudmask).absoluteString, "https://radar.example.invalid/v1/layers/cloudmask/")
        let odd = URL(string: "http://localhost:8080/")!
        XCTAssertEqual(RadarBackendConfig.layersBaseURL(for: .clouds, radarBaseURL: odd).absoluteString,
                       "http://localhost:8080/layers/clouds/")
    }

    // MARK: Parser

    func testParsesPressureForecastManifest() throws {
        let value = try manifest(.pressure)
        XCTAssertEqual(value.kind, .forecast)
        XCTAssertEqual(value.stepMinutes, 60)
        XCTAssertEqual(value.forecastHorizonMinutes, 360)
        XCTAssertEqual(value.slots.count, 7)
        XCTAssertEqual(value.slots.first?.kind, .analysis)
        XCTAssertEqual(value.slots.last?.kind, .forecast)
        XCTAssertEqual(value.slots[1].url.absoluteString,
                       "https://radar.example.invalid/v1/layers/pressure/20261031T1200Z/20261031T1300Z.webp")
        XCTAssertEqual(value.attribution, "Quelle: Deutscher Wetterdienst")
        XCTAssertTrue(value.modificationNotice.contains("ICON"))
        XCTAssertEqual(value.legend?.width, 219)
        XCTAssertEqual(value.legend?.url.host, "maps.dwd.de")
        XCTAssertEqual(value.backend.bounds.minX, 612257.0)
        XCTAssertEqual(value.backend.imageWidth, 1024)
    }

    func testParsesLightningObservationManifestWithGap() throws {
        let value = try manifest(.lightning)
        XCTAssertEqual(value.kind, .observation)
        XCTAssertEqual(value.stepMinutes, 5)
        XCTAssertEqual(value.historyHours, 3)
        XCTAssertEqual(value.slots.count, 6, "the 12:15 gap is simply absent")
        XCTAssertTrue(value.slots.allSatisfy { $0.kind == .analysis }, "observation slots are plain measurements")
        XCTAssertEqual(value.legend?.height, 344)
    }

    func testParsesCloudsWithEumetsatAttributionAndNoLegend() throws {
        let value = try manifest(.clouds)
        XCTAssertEqual(value.stepMinutes, 10)
        XCTAssertEqual(value.attribution, "Contains modified EUMETSAT Meteosat data 2026")
        XCTAssertTrue(value.modificationNotice.contains("EUMETView"))
        XCTAssertNil(value.legend)
        XCTAssertEqual(value.radarAttribution.attribution, value.attribution)
    }

    func testRejectsInvalidManifests() throws {
        func parse(_ data: Data, as layer: RadarLayer = .pressure) throws -> RadarLayerManifest {
            try RadarLayerManifest.parse(data, expected: layer, layersBaseURL: base(layer))
        }
        XCTAssertThrowsError(try parse(Data()))
        XCTAssertThrowsError(try parse(fixture("layer-lightning"), as: .pressure), "layer id must match the endpoint")
        XCTAssertThrowsError(try parse(modified("layer-pressure") { $0["schema"] = 2 })) {
            XCTAssertEqual($0 as? RadarBackendError, .unsupportedSchema(2))
        }
        XCTAssertThrowsError(try parse(modified("layer-pressure") { $0["attribution"] = "  " }))
        XCTAssertThrowsError(try parse(modified("layer-pressure") { $0["kind"] = "observation" }), "slot kinds must fit the layer kind")
        XCTAssertThrowsError(try parse(modified("layer-pressure") { $0["run"] = "../x" }))
        XCTAssertThrowsError(try parse(modified("layer-pressure") { $0["step_minutes"] = 0 }))
        XCTAssertThrowsError(try parse(modified("layer-pressure") { $0["slots"] = [] }))
        XCTAssertThrowsError(try parse(modified("layer-pressure") {
            var slots = $0["slots"] as! [[String: Any]]
            slots[1]["path"] = "../../etc/passwd.webp"
            $0["slots"] = slots
        }), "unsafe path")
        XCTAssertThrowsError(try parse(modified("layer-pressure") {
            var slots = $0["slots"] as! [[String: Any]]
            slots.swapAt(1, 2)
            $0["slots"] = slots
        }), "slots must ascend")
        XCTAssertThrowsError(try parse(modified("layer-pressure") { var image = $0["image"] as! [String: Any]; image["projection"] = "EPSG:4326"; $0["image"] = image }))
    }

    func testLegendFromForeignHostIsDroppedButLayerStaysUsable() throws {
        let data = try modified("layer-lightning") {
            $0["legend"] = ["url": "https://evil.example.invalid/l.png", "width": 119, "height": 344]
        }
        let value = try RadarLayerManifest.parse(data, expected: .lightning, layersBaseURL: base(.lightning))
        XCTAssertNil(value.legend)
        let http = try modified("layer-lightning") {
            $0["legend"] = ["url": "http://maps.dwd.de/x.png", "width": 119, "height": 344]
        }
        XCTAssertNil(try RadarLayerManifest.parse(http, expected: .lightning, layersBaseURL: base(.lightning)).legend)
    }

    // MARK: Freshness and time axes

    func testPressureFreshnessAndNowSlot() throws {
        let value = try manifest(.pressure)
        XCTAssertTrue(value.isFresh(at: utc("2026-10-31T13:20:00Z")))
        XCTAssertFalse(value.isFresh(at: utc("2026-10-31T18:30:00Z")), "forecast exhausted (last slot 18:00)")
        XCTAssertFalse(value.isFresh(at: utc("2026-11-01T07:00:00Z")), "run older than 18 h")
        XCTAssertFalse(value.isFresh(at: utc("2026-10-31T11:00:00Z")), "generated in the future")
        let now = utc("2026-10-31T13:20:00Z")
        XCTAssertEqual(value.nowSlotTime(at: now), utc("2026-10-31T13:00:00Z"), "slot of the current hour, not the run time")
        let timeline = value.timeline(at: now)
        XCTAssertEqual(timeline.dates.count, 7)
        XCTAssertEqual(timeline.dates[1].timeIntervalSince(timeline.dates[0]), 3600, "hourly step")
        XCTAssertEqual(timeline.referenceTime, utc("2026-10-31T13:00:00Z"))
        XCTAssertEqual(timeline.backend, value.backend)
        XCTAssertEqual(value.timeline(at: utc("2026-10-31T11:00:00Z")).referenceTime, utc("2026-10-31T12:00:00Z"), "before the first slot: first slot")
    }

    func testLightningFreshnessAndTimeline() throws {
        let value = try manifest(.lightning)
        XCTAssertTrue(value.isFresh(at: utc("2026-10-31T12:40:00Z")))
        XCTAssertTrue(value.isFresh(at: utc("2026-10-31T13:00:00Z")))
        XCTAssertFalse(value.isFresh(at: utc("2026-10-31T13:10:00Z")), "older than 30 min is not shown as current")
        let timeline = value.timeline(at: utc("2026-10-31T12:40:00Z"))
        XCTAssertEqual(timeline.referenceTime, utc("2026-10-31T12:30:00Z"), "now = newest measurement")
        XCTAssertEqual(timeline.dates.count, 6)
        XCTAssertFalse(timeline.dates.contains(utc("2026-10-31T12:15:00Z")))
        // Nothing after "now": the whole axis is measurement.
        XCTAssertTrue(timeline.dates.allSatisfy { $0 <= timeline.referenceTime })
    }

    func testCloudsFreshnessAndTenMinuteAxis() throws {
        let value = try manifest(.clouds)
        XCTAssertTrue(value.isFresh(at: utc("2026-10-31T13:30:00Z")))
        XCTAssertFalse(value.isFresh(at: utc("2026-10-31T14:30:00Z")))
        let timeline = value.timeline(at: utc("2026-10-31T12:40:00Z"))
        XCTAssertEqual(timeline.dates[1].timeIntervalSince(timeline.dates[0]), 600)
        XCTAssertEqual(timeline.referenceTime, utc("2026-10-31T12:20:00Z"))
    }

    func testSlotFrameCaptionsPerLayer() {
        XCTAssertEqual(RadarLayer.pressure.frameCaption(isForecast: false), "Modell")
        XCTAssertEqual(RadarLayer.pressure.frameCaption(isForecast: true), "Vorhersage")
        XCTAssertEqual(RadarLayer.lightning.frameCaption(isForecast: false), "Messung")
        XCTAssertEqual(RadarLayer.clouds.frameCaption(isForecast: false), "Messung")
        XCTAssertEqual(RadarLayer.radar.frameCaption(isForecast: true), "Vorhersage")
        let date = utc("2026-10-31T13:00:00Z")
        XCTAssertTrue(TimelineAccessibility.value(date: date, isForecast: false, reference: date, caption: "Modell").hasSuffix(", Modell"))
        XCTAssertTrue(TimelineAccessibility.value(date: date, isForecast: false, reference: date).hasSuffix(", Messung"), "radar wording unchanged")
        XCTAssertEqual(RadarLayer.selectable, [.radar, .pressure, .pressureEU, .temperature, .dewpoint, .humidity, .lightning, .clouds, .cloudmask], "cloudmask is the sun layer")
        XCTAssertFalse(RadarLayer.selectable.contains(.cloudmaskVis), "the visible channel is a helper, not a menu entry")
        XCTAssertEqual(RadarLayer.pressureEU.title, "Luftdruck Europa")
        XCTAssertEqual(RadarLayer.pressureEU.rawValue, "pressure_eu")
        XCTAssertEqual(RadarLayer.cloudmaskVis.rawValue, "cloudmask_vis")
        XCTAssertEqual(RadarLayer.cloudmask.title, "Sonne")
        XCTAssertEqual(RadarLayer.cloudmask.frameCaption(isForecast: false), "Rückblick")
        XCTAssertEqual(RadarLayer.cloudmask.nominalStepMinutes, 15)
    }

    // MARK: Client (404, ETag, errors)

    private final class Responder: @unchecked Sendable {
        private let lock = NSLock()
        var requests: [URLRequest] = []
        var handler: @Sendable (URLRequest) throws -> (Int, Data, [String: String])
        init(_ handler: @escaping @Sendable (URLRequest) throws -> (Int, Data, [String: String])) { self.handler = handler }
        func transport() -> RadarBackendClient.Transport {
            { [self] request in
                lock.withLock { requests.append(request) }
                let (status, data, headers) = try handler(request)
                let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: headers)!
                return (data, response)
            }
        }
        var paths: [String] { lock.withLock { requests.map { $0.url!.path } } }
    }

    private func client(_ responder: Responder, now: String = "2026-10-31T13:00:00Z") -> RadarLayerClient {
        let date = utc(now)
        return RadarLayerClient(radarBaseURL: radarBase, transport: responder.transport(), clock: { date })
    }

    func testClientLoadsLayerAndUsesEtag() async throws {
        let pressure = try fixture("layer-pressure")
        let responder = Responder { request in
            if request.value(forHTTPHeaderField: "If-None-Match") == "\"v1\"" { return (304, Data(), [:]) }
            return (200, pressure, ["ETag": "\"v1\""])
        }
        let client = client(responder)
        let first = await client.latest(.pressure)
        guard case .fresh(let value) = first else { return XCTFail("\(first)") }
        XCTAssertEqual(value.layer, .pressure)
        let second = await client.latest(.pressure)
        XCTAssertEqual(second, first, "304 reuses the cached manifest")
        XCTAssertEqual(responder.paths, ["/v1/layers/pressure/latest.json", "/v1/layers/pressure/latest.json"])
        XCTAssertNil(responder.requests[0].value(forHTTPHeaderField: "Cookie"))
        XCTAssertFalse(responder.requests[0].httpShouldHandleCookies)
    }

    func test404MeansNotPublishedAndDropsCache() async throws {
        let pressure = try fixture("layer-pressure")
        let flag = ResponseFlag()
        let responder = Responder { _ in flag.is404 ? (404, Data(), [:]) : (200, pressure, ["ETag": "\"v1\""]) }
        let client = client(responder)
        _ = await client.latest(.pressure)
        flag.is404 = true
        let result = await client.latest(.pressure)
        XCTAssertEqual(result, .notPublished)
        flag.is404 = false
        _ = await client.latest(.pressure)
        XCTAssertNil(responder.requests.last?.value(forHTTPHeaderField: "If-None-Match"), "no stale ETag after a 404")
    }

    private final class ResponseFlag: @unchecked Sendable {
        private let lock = NSLock(); private var flag = false
        var is404: Bool { get { lock.withLock { flag } } set { lock.withLock { flag = newValue } } }
    }

    func testClientMapsErrorsAndStaleData() async throws {
        let pressure = try fixture("layer-pressure")
        let bad = Responder { _ in (200, Data("<html>".utf8), [:]) }
        let invalid = await client(bad).latest(.pressure)
        XCTAssertEqual(invalid, .invalid)
        let server = Responder { _ in (503, Data(), [:]) }
        let unreachable = await client(server).latest(.pressure)
        XCTAssertEqual(unreachable, .unreachable)
        let offline = Responder { _ in throw URLError(.notConnectedToInternet) }
        let offlineResult = await client(offline).latest(.lightning)
        XCTAssertEqual(offlineResult, .unreachable)
        let old = Responder { _ in (200, pressure, [:]) }
        let stale = await client(old, now: "2026-11-02T00:00:00Z").latest(.pressure)
        XCTAssertEqual(stale, .stale)
        let radarAsLayer = await client(old).latest(.radar)
        XCTAssertEqual(radarAsLayer, .invalid, "the radar has its own client")
    }

    // MARK: Store: selection, availability, 404

    @MainActor
    private func store(_ responder: Responder, now: String = "2026-10-31T13:00:00Z") -> RadarLayerStore {
        let date = utc(now)
        return RadarLayerStore(radarBaseURL: radarBase, client: client(responder, now: now), clock: { date })
    }

    private func backendResponder() throws -> Responder {
        let files = ["pressure": try fixture("layer-pressure"), "lightning": try fixture("layer-lightning"), "clouds": try fixture("layer-clouds"),
                     "cloudmask": try fixture("layer-cloudmask")]
        return Responder { request in
            let id = request.url!.pathComponents.dropLast().last!
            if let data = files[id] { return (200, data, [:]) }
            return (404, Data(), [:])
        }
    }

    @MainActor
    func testDefaultIsRadarAndRadarIsAlwaysAvailable() throws {
        let layers = store(try backendResponder())
        XCTAssertEqual(layers.active, .radar)
        XCTAssertNil(layers.activeTimeline)
        XCTAssertTrue(layers.isSelectable(.radar))
        XCTAssertEqual(layers.availability(.radar), .available)
        XCTAssertTrue(layers.select(.radar))
        XCTAssertEqual(layers.active, .radar)
    }

    @MainActor
    func testProbeGreysOutLayersThatAnswer404() async throws {
        // Default backend: LAYERS=radar, every layer answers 404.
        let responder = Responder { _ in (404, Data(), [:]) }
        let layers = store(responder)
        await layers.probeAll(force: true)
        for layer in [RadarLayer.pressure, .pressureEU, .temperature, .dewpoint, .humidity, .lightning, .clouds, .cloudmask] {
            XCTAssertEqual(layers.availability(layer), .notPublished)
            XCTAssertFalse(layers.isSelectable(layer))
            XCTAssertFalse(layers.select(layer), "a layer the server does not offer cannot be chosen")
        }
        XCTAssertEqual(layers.active, .radar)
        XCTAssertEqual(responder.paths.count, 8, "one request per optional layer, including the sun layer; no helper request without the sun layer")
        XCTAssertEqual(layers.availability(.pressure).hint, "nicht verfügbar")
    }

    @MainActor
    func testProbeIsThrottledAndRestrictedModeAsksOnlyTheActiveLayer() async throws {
        let responder = try backendResponder()
        let layers = store(responder)
        await layers.probeAll()
        XCTAssertEqual(responder.paths.count, 9, "eight optional layers plus the visible-channel helper of the available sun layer")
        await layers.probeAll()
        XCTAssertEqual(responder.paths.count, 9, "throttled")
        await layers.probeAll(force: true, restricted: true)
        XCTAssertEqual(responder.paths.count, 9, "restricted with the radar active: no layer requests")
        for layer in [RadarLayer.pressure, .lightning, .clouds, .cloudmask] { XCTAssertEqual(layers.availability(layer), .available) }
    }

    @MainActor
    func testSelectLoadsLayerWithItsOwnTimelineAndSelection() async throws {
        let layers = store(try backendResponder(), now: "2026-10-31T13:20:00Z")
        await layers.refresh(.pressure)
        XCTAssertTrue(layers.select(.pressure))
        XCTAssertEqual(layers.active, .pressure)
        let timeline = try XCTUnwrap(layers.activeTimeline)
        XCTAssertEqual(timeline.dates.count, 7)
        XCTAssertEqual(layers.snapshot(.pressure).selectedFrame, 1, "starts on the current hour (13:00)")
        layers.setFrame(4, for: .pressure)
        XCTAssertEqual(layers.snapshot(.pressure).selectedFrame, 4)
        layers.setFrame(99, for: .pressure)
        XCTAssertEqual(layers.snapshot(.pressure).selectedFrame, 4, "out of range ignored")
        layers.setFrame(2, for: .radar)
        XCTAssertEqual(layers.snapshot(.radar).selectedFrame, 0, "the radar's frame is not owned by the layer store")
        // A poll with the same data keeps the viewed instant.
        await layers.refresh(.pressure)
        XCTAssertEqual(layers.snapshot(.pressure).selectedFrame, 4)
        XCTAssertEqual(layers.activeManifest?.attribution, "Quelle: Deutscher Wetterdienst")
    }

    @MainActor
    func testActiveLayerThatTurns404HandsBackToRadarWithoutError() async throws {
        let flag = ResponseFlag()
        let lightning = try fixture("layer-lightning")
        let responder = Responder { _ in flag.is404 ? (404, Data(), [:]) : (200, lightning, [:]) }
        let layers = store(responder, now: "2026-10-31T12:40:00Z")
        await layers.refresh(.lightning)
        XCTAssertTrue(layers.select(.lightning))
        XCTAssertEqual(layers.active, .lightning)
        flag.is404 = true
        await layers.refresh(.lightning)
        XCTAssertEqual(layers.active, .radar, "silently back to the radar")
        XCTAssertEqual(layers.availability(.lightning), .notPublished)
        XCTAssertNil(layers.snapshot(.lightning).timeline)
    }

    @MainActor
    func testShortOutageKeepsFreshDataButLongOutageDropsIt() async throws {
        let flag = ResponseFlag()
        let lightning = try fixture("layer-lightning")
        let responder = Responder { _ in flag.is404 ? (503, Data(), [:]) : (200, lightning, [:]) }
        let layers = store(responder, now: "2026-10-31T12:40:00Z")
        await layers.refresh(.lightning)
        flag.is404 = true
        await layers.refresh(.lightning)
        XCTAssertEqual(layers.availability(.lightning), .available)
        XCTAssertNotNil(layers.snapshot(.lightning).timeline)
        // 40 minutes later the newest measurement is too old to pass for current.
        layers.apply(.unreachable, to: .lightning, now: utc("2026-10-31T13:15:00Z"))
        XCTAssertEqual(layers.availability(.lightning), .unreachable)
        XCTAssertNil(layers.snapshot(.lightning).timeline)
        XCTAssertTrue(layers.isSelectable(.lightning), "unreachable can be retried; only 404/invalid/stale are greyed")
        XCTAssertEqual(layers.availability(.lightning).hint, "nicht erreichbar")
    }

    @MainActor
    func testStaleLayerIsNotOffered() async throws {
        let layers = store(try backendResponder(), now: "2026-11-02T00:00:00Z")
        await layers.refresh(.lightning)
        XCTAssertEqual(layers.availability(.lightning), .stale)
        XCTAssertFalse(layers.isSelectable(.lightning))
    }

    @MainActor
    func testPollingStopsWhenLayerChangesOrTaskIsCancelled() async throws {
        let responder = try backendResponder()
        let layers = store(responder, now: "2026-10-31T12:40:00Z")
        await layers.refresh(.lightning)
        layers.select(.lightning)
        let delays = DelayRecorder()
        let task = Task { @MainActor in
            await layers.runPolling(for: .lightning, restricted: { true }, sleep: { seconds in
                delays.append(seconds)
                if delays.values.count >= 2 { try await Task.sleep(for: .seconds(3600)) }
            })
        }
        while delays.values.count < 2 { try await Task.sleep(for: .milliseconds(5)) }
        task.cancel()
        await task.value
        XCTAssertEqual(delays.values, [120, 120], "lightning 60 s, doubled in Low Power / Low Data")
        XCTAssertEqual(RadarLayer.pressure.pollInterval, 300)
        XCTAssertEqual(RadarLayer.clouds.pollInterval, 120)
    }

    private final class DelayRecorder: @unchecked Sendable {
        private let lock = NSLock(); private var items: [TimeInterval] = []
        func append(_ value: TimeInterval) { lock.withLock { items.append(value) } }
        var values: [TimeInterval] { lock.withLock { items } }
    }

    // MARK: WeatherStore display state (radar unaffected)

    @MainActor
    func testStoreDisplaysRadarByDefaultAndTheLayerWhenActive() async throws {
        let layers = store(try backendResponder(), now: "2026-10-31T12:40:00Z")
        let weather = WeatherStore(client: DWDClient(), backend: DWDDataTests.unreachableBackend,
                                   defaults: UserDefaults(suiteName: "layers-\(UUID().uuidString)")!, layers: layers)
        let radar = RadarTimeline(referenceTime: utc("2026-10-31T12:30:00Z"),
                                  dates: [utc("2026-10-31T12:25:00Z"), utc("2026-10-31T12:30:00Z"), utc("2026-10-31T12:35:00Z")])
        weather.timeline = radar
        weather.selectedFrame = 1
        XCTAssertEqual(weather.displayTimeline?.dates, radar.dates)
        XCTAssertEqual(weather.displayFrameDate, utc("2026-10-31T12:30:00Z"))
        XCTAssertEqual(weather.displayAttributionLine, "Quelle: Deutscher Wetterdienst · Showers-Cache")
        weather.displayFrameIndex = 2
        XCTAssertEqual(weather.selectedFrame, 2, "radar index is written through")
        XCTAssertTrue(weather.displayIsForecastFrame)

        await layers.refresh(.clouds)
        XCTAssertTrue(layers.select(.clouds))
        XCTAssertEqual(weather.displayTimeline?.dates.count, 5, "the layer has its own axis")
        XCTAssertEqual(weather.displayFrameIndex, 4, "newest cloud image")
        weather.displayFrameIndex = 1
        XCTAssertEqual(layers.snapshot(.clouds).selectedFrame, 1)
        XCTAssertEqual(weather.selectedFrame, 2, "the radar selection is untouched by the layer")
        XCTAssertEqual(weather.timeline?.dates, radar.dates, "radar timeline untouched")
        XCTAssertFalse(weather.displayIsForecastFrame)
        XCTAssertEqual(weather.displayAttributionLine, "Contains modified EUMETSAT Meteosat data 2026 · Showers-Cache")
        XCTAssertEqual(weather.displayFrameReference, utc("2026-10-31T11:50:00Z"))
    }

    @MainActor
    func testLayerWithoutDataShowsNoTimelineInsteadOfRadar() async throws {
        let layers = store(Responder { _ in throw URLError(.notConnectedToInternet) })
        let weather = WeatherStore(client: DWDClient(), backend: DWDDataTests.unreachableBackend,
                                   defaults: UserDefaults(suiteName: "layers-\(UUID().uuidString)")!, layers: layers)
        weather.timeline = RadarTimeline(referenceTime: utc("2026-10-31T12:30:00Z"), dates: [utc("2026-10-31T12:30:00Z")])
        XCTAssertTrue(layers.select(.pressure), "unknown/unreachable layers can be tried")
        XCTAssertNil(weather.displayTimeline, "no radar fallback for optional layers")
        XCTAssertNil(weather.displayAttributionLine)
    }

    // MARK: Attribution strings

    func testEveryLayerHasItsOwnSourceText() throws {
        let radar = RadarAttribution.default
        XCTAssertEqual(radar.attribution, "Quelle: Deutscher Wetterdienst")
        let clouds = try manifest(.clouds).radarAttribution
        XCTAssertTrue(clouds.attribution.contains("EUMETSAT"))
        XCTAssertNotEqual(clouds.modificationNotice, radar.modificationNotice)
        XCTAssertTrue(try manifest(.lightning).radarAttribution.attribution.contains("Deutscher Wetterdienst"))
        for layer in RadarLayer.selectable {
            XCTAssertFalse(RadarLayerLegendText.hint(for: layer).isEmpty)
            XCTAssertFalse(RadarLayerLegendText.toggleHint(for: layer).isEmpty)
        }
        XCTAssertTrue(RadarLayerLegendText.hint(for: .pressure).contains("Isobaren"))
        XCTAssertTrue(RadarLayerLegendText.hint(for: .clouds).contains("keine Farbskala"))
    }

    // MARK: Legend image safety

    func testLegendDecodeLimits() throws {
        let reference = try XCTUnwrap(try manifest(.lightning).legend)
        XCTAssertNil(RadarLegendImageLoader.decode(Data(), reference: reference))
        XCTAssertNil(RadarLegendImageLoader.decode(Data(repeating: 7, count: 1000), reference: reference), "not an image")
        XCTAssertNil(RadarLegendImageLoader.decode(Data(repeating: 0, count: RadarLegendImageLoader.maximumBytes + 1), reference: reference))
    }

    func testLegendLoaderRefusesForeignHosts() async {
        let foreign = RadarLayerLegendRef(url: URL(string: "https://evil.example.invalid/l.png")!, width: 10, height: 10)
        let image = await RadarLegendImageLoader.load(foreign)
        XCTAssertNil(image)
    }

    // MARK: Prefetch and cache rules

    func testPrefetchWindowAndSharedCache() async throws {
        XCTAssertNil(RadarLayer.pressure.prefetchSlotLimit)
        XCTAssertNil(RadarLayer.lightning.prefetchSlotLimit)
        XCTAssertEqual(RadarLayer.clouds.prefetchSlotLimit, 19, "large cloud images: only a window around the selected slot")
        let value = try manifest(.lightning).backend
        let cache = TileMemoryCache()
        let foreign = URL(string: "https://radar.example.invalid/v1/radar/keep/this.webp")!
        cache.insertTrusted(Data([1]), for: foreign)
        _ = BackendRadarLoader(manifest: value, cache: cache, trimsCache: false)
        XCTAssertTrue(cache.contains(foreign), "an optional layer does not evict the radar's images")
        _ = BackendRadarLoader(manifest: value, cache: cache)
        XCTAssertFalse(cache.contains(foreign), "the radar loader keeps trimming to its own run")

        let counter = Counter()
        let loader = BackendRadarLoader(manifest: try manifest(.clouds).backend, cache: TileMemoryCache(), trimsCache: false,
                                        fetch: { _ in counter.increment(); return Data([1]) }, decode: { _ in Self.pixel })
        loader.prefetch(selected: 2, limit: 3) { true }
        for _ in 0..<200 where counter.value < 3 { try await Task.sleep(for: .milliseconds(10)) }
        try await Task.sleep(for: .milliseconds(80))
        XCTAssertEqual(counter.value, 3, "limit caps the slots preloaded around the selected one")
        loader.cancelPrefetch()
    }

    func testPrefetchRespectsRestrictions() async throws {
        let counter = Counter()
        let loader = BackendRadarLoader(manifest: try manifest(.pressure).backend, cache: TileMemoryCache(), trimsCache: false,
                                        fetch: { _ in counter.increment(); return Data([1]) }, decode: { _ in Self.pixel })
        loader.prefetch(selected: 0) { false } // Low Power / Low Data / background
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(counter.value, 0)
    }

    private final class Counter: @unchecked Sendable {
        private let lock = NSLock(); private var count = 0
        func increment() { lock.withLock { count += 1 } }
        var value: Int { lock.withLock { count } }
    }

    private static let pixel: CGImage = {
        let context = CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        return context.makeImage()!
    }()

    // MARK: Welle 2: Europa-Auswahl, Sonnen-Hilfsebene

    /// A fixture re-labelled as another layer (no new fixture files): `pressure_eu` with the Europe extent,
    /// `cloudmask_vis` with the 10 min grid.
    private func europeData() throws -> Data {
        try modified("layer-pressure") { object in
            object["layer"] = "pressure_eu"
            object["image"] = ["format": "image/webp", "width": 2048, "height": 2168, "projection": "EPSG:3857",
                               "bbox": [-2782987.0, 3503550.0, 5009377.0, 11753185.0], "bbox_wgs84": [-25.0, 30.0, 45.0, 72.0]]
        }
    }

    private func visibleData(extent: Bool = true, newest: String = "2026-10-31T12:30:00Z") throws -> Data {
        try modified("layer-cloudmask") { object in
            object["layer"] = "cloudmask_vis"
            object["step_minutes"] = 10
            object["reference_time"] = newest
            object["slots"] = [["time": "2026-10-31T09:10:00Z", "kind": "observation", "path": "20261031T1215Z/20261031T0910Z.webp"],
                               ["time": newest, "kind": "observation", "path": "20261031T1215Z/\(newest.replacingOccurrences(of: "-", with: "").replacingOccurrences(of: ":", with: "").replacingOccurrences(of: "00Z", with: "Z")).webp"]]
            if !extent {
                object["image"] = ["format": "image/webp", "width": 2048, "height": 2168, "projection": "EPSG:3857",
                                   "bbox": [-2782987.0, 3503550.0, 5009377.0, 11753185.0], "bbox_wgs84": [-25.0, 30.0, 45.0, 72.0]]
            }
        }
    }

    private func responder(europe: Bool, visible: Data?) throws -> Responder {
        var files = ["pressure": try fixture("layer-pressure"), "lightning": try fixture("layer-lightning"),
                     "clouds": try fixture("layer-clouds"), "cloudmask": try fixture("layer-cloudmask")]
        if europe { files["pressure_eu"] = try europeData() }
        if let visible { files["cloudmask_vis"] = visible }
        let served = files
        return Responder { request in
            let id = request.url!.pathComponents.dropLast().last!
            if let data = served[id] { return (200, data, [:]) }
            return (404, Data(), [:])
        }
    }

    func testEuropeManifestKeepsItsOwnBounds() throws {
        let value = try RadarLayerManifest.parse(europeData(), expected: .pressureEU, layersBaseURL: base(.pressureEU))
        XCTAssertEqual(value.layer, .pressureEU)
        XCTAssertEqual(value.backend.bounds, RadarBounds(minX: -2782987, minY: 3503550, maxX: 5009377, maxY: 11753185))
        XCTAssertEqual(value.backend.imageWidth, 2048)
        XCTAssertEqual(base(.pressureEU).absoluteString, "https://radar.example.invalid/v1/layers/pressure_eu/")
        XCTAssertThrowsError(try RadarLayerManifest.parse(europeData(), expected: .pressure, layersBaseURL: base(.pressure)),
                             "pressure_eu must not pass as the German layer")
    }

    @MainActor
    func testEuropeIsOnlyOfferedWhenTheBackendReportsIt() async throws {
        let without = store(try responder(europe: false, visible: nil))
        XCTAssertFalse(without.isOffered(.pressureEU), "not asked yet: not offered (no greyed-out entry)")
        await without.probeAll(force: true)
        XCTAssertEqual(without.availability(.pressureEU), .notPublished)
        XCTAssertFalse(without.offeredLayers.contains(.pressureEU))
        XCTAssertEqual(without.offeredLayers, [.radar, .pressure, .lightning, .clouds, .cloudmask],
                       "German layers keep their (greyed-out) entries")
        XCTAssertFalse(without.select(.pressureEU))
        XCTAssertEqual(without.active, .radar, "no fallback banner state, just refused")

        let with = store(try responder(europe: true, visible: nil))
        await with.probeAll(force: true)
        XCTAssertTrue(with.offeredLayers.contains(.pressureEU))
        XCTAssertEqual(with.offeredLayers.firstIndex(of: .pressureEU), with.offeredLayers.firstIndex(of: .pressure)! + 1)
        XCTAssertTrue(with.select(.pressureEU))
        XCTAssertEqual(with.active, .pressureEU)
        XCTAssertEqual(with.activeManifest?.backend.bounds.minX, -2782987)
    }

    @MainActor
    func testEuropeThatDisappearsHandsTheMapBackToTheRadarSilently() async throws {
        let layers = store(try responder(europe: true, visible: nil))
        await layers.refresh(.pressureEU)
        XCTAssertTrue(layers.select(.pressureEU))
        layers.apply(.notPublished, to: .pressureEU, now: utc("2026-10-31T13:00:00Z"))
        XCTAssertEqual(layers.active, .radar)
        XCTAssertFalse(layers.isOffered(.pressureEU))
    }

    @MainActor
    func testSunUsesTheVisibleHelperOnlyWhenItIsFreshAndMatchesTheMaskExtent() async throws {
        let none = store(try responder(europe: false, visible: nil))
        await none.refresh(.cloudmask)
        XCTAssertEqual(none.availability(.cloudmaskVis), .notPublished)
        XCTAssertNil(none.sunVisibleManifest, "404: mask only")
        XCTAssertEqual(none.availability(.cloudmask), .available, "a missing helper never degrades the sun layer")

        let ok = store(try responder(europe: false, visible: try visibleData()))
        await ok.refresh(.cloudmask)
        XCTAssertEqual(ok.sunVisibleManifest?.layer, .cloudmaskVis)
        XCTAssertEqual(ok.sunVisibleManifest?.slots.count, 2)

        let other = store(try responder(europe: false, visible: try visibleData(extent: false)))
        await other.refresh(.cloudmask)
        XCTAssertNil(other.sunVisibleManifest, "a helper with another extent cannot be matched pixel by pixel")

        // Helper older than two hours (e.g. night outage at the source): stale, mask only.
        let old = store(try responder(europe: false, visible: try visibleData(newest: "2026-10-31T10:30:00Z")), now: "2026-10-31T13:00:00Z")
        await old.refresh(.cloudmask)
        XCTAssertEqual(old.availability(.cloudmaskVis), .stale)
        XCTAssertNil(old.sunVisibleManifest)
        XCTAssertEqual(old.availability(.cloudmask), .available)
    }

    @MainActor
    func testHelperIsNotRequestedWithoutTheSunLayer() async throws {
        let responder = try responder(europe: false, visible: try visibleData())
        let layers = store(responder)
        await layers.refresh(.pressure)
        XCTAssertFalse(responder.paths.contains { $0.contains("cloudmask_vis") })
    }
}
