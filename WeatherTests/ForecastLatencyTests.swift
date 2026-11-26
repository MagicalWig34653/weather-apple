import XCTest
@testable import Weather

/// Point forecast against a slow DWD WMS. Live measurement 20.11.2026 (public Berlin sample point, GetFeatureInfo with
/// 25 time steps): 3 to 14 s per answer, 18.11. up to 19 s; on 30.10. it was 1 s. The request timeout of 10 s turned
/// answers that would have arrived into "failed" loads, two in a row show "Aktualisierung fehlgeschlagen".
/// The transport simulates URLSession's idle timeout without real waiting: it fails with `.timedOut` when the request
/// allows less time than the (virtual) answer needs.
@MainActor
final class ForecastLatencyTests: XCTestCase {
    private let n0 = DWDRequest.date("2026-10-28T15:15:00Z")!
    private let coordinate = WeatherCoordinate(latitude: 53.56, longitude: 6.74)

    private func fixture() throws -> Data {
        let bundle = Bundle(for: ForecastLatencyTests.self)
        let url = bundle.url(forResource: "wms-wet-point-response", withExtension: "json", subdirectory: "Fixtures")
            ?? bundle.url(forResource: "wms-wet-point-response", withExtension: "json")
        return try Data(contentsOf: XCTUnwrap(url))
    }

    private func makeStore(_ transport: LatencyTransport) -> WeatherStore {
        let now = n0.addingTimeInterval(240)
        let client = DWDClient(transport: { try await transport.respond($0) }, clock: { now }, retryDelay: { _ in 0 })
        let store = WeatherStore.isolated(client: client, backend: DWDDataTests.unreachableBackend,
                                 defaults: UserDefaults(suiteName: "ForecastLatencyTests-\(UUID().uuidString)")!)
        store.clock = { now }
        store.selectedPlace = SavedPlace(name: "A", coordinate: coordinate)
        return store
    }

    /// A point answer that takes 14 s (measured) is a success, not a failure.
    func testPointAnswerAfterFourteenSecondsIsNotAFailure() async throws {
        let transport = LatencyTransport(fixture: try fixture(), pointLatency: 14)
        let store = makeStore(transport)
        await store.refresh()
        XCTAssertNotNil(store.forecast)
        XCTAssertNil(store.forecastError)
        XCTAssertEqual(store.forecastFailures, 0)
        let attempts = await transport.pointAttempts
        XCTAssertEqual(attempts, 1, "no retry needed when the single request is allowed to wait")
    }

    /// The upper end measured on 18.11. (19 s) is still within the allowed time.
    func testPointAnswerAfterNineteenSecondsIsNotAFailure() async throws {
        let store = makeStore(LatencyTransport(fixture: try fixture(), pointLatency: 19))
        await store.refresh()
        XCTAssertNotNil(store.forecast)
        XCTAssertEqual(store.forecastFailures, 0)
    }

    /// A hanging service still ends: at most `DWDRetryPolicy.maxAttempts` requests, then a counted failure.
    func testHangingServiceStaysBoundedAndCountsAsFailure() async throws {
        let transport = LatencyTransport(fixture: try fixture(), pointLatency: 120)
        let store = makeStore(transport)
        await store.refresh()
        XCTAssertNil(store.forecastStatus(), "first failure alone shows no message")
        XCTAssertEqual(store.forecastFailures, 1)
        let attempts = await transport.pointAttempts
        XCTAssertEqual(attempts, DWDRetryPolicy.maxAttempts)
    }

    /// Live measurement 20.11.2026: a new run is listed in the index about 200 s after N, but the point query for it
    /// answers HTTP 200 `InvalidDimensionValue` for 10 to 30 s more. The app asks right at listing time, retries three
    /// times within about one second and repeats after 20 s: two failures in a row showed "Aktualisierung
    /// fehlgeschlagen" although the service only had not finished the run yet and the shown forecast was still valid.
    func testRunListedButNotReadyIsNoFailureWhileAValidForecastIsShown() async throws {
        let transport = LatencyTransport(fixture: try fixture(), pointLatency: 0, notReady: true)
        let store = makeStore(transport)
        let older = RainForecast(referenceTime: n0.addingTimeInterval(-300),
                                 samples: [RainSample(date: n0.addingTimeInterval(-300), amountMM: 0)])
        store.rememberForecast(older, for: store.selectedPlace.id)
        store.forecast = older
        await store.reloadForecast() // at listing time
        await store.reloadForecast() // the repeat 20 s later: still not ready
        XCTAssertEqual(store.forecastFailures, 0, "run not ready is not a failed load")
        XCTAssertFalse(store.forecastFailureConfirmed)
        XCTAssertNotEqual(store.forecastStatus(), .failed)
        XCTAssertNil(store.forecastError)
        XCTAssertEqual(store.forecast?.referenceTime, older.referenceTime, "the valid forecast stays shown")
        await transport.setNotReady(false)
        await store.reloadForecast()
        XCTAssertEqual(store.forecast?.referenceTime, n0)
        XCTAssertNil(store.forecastStatus())
    }

    /// Without any forecast to show a missing run stays an error (nothing to fall back to).
    func testRunNotReadyWithoutForecastStaysAnError() async throws {
        let store = makeStore(LatencyTransport(fixture: try fixture(), pointLatency: 0, notReady: true))
        await store.reloadForecast()
        XCTAssertEqual(store.forecastFailures, 1)
        XCTAssertNotNil(store.forecastError)
    }
}

private actor LatencyTransport {
    let fixture: Data
    let pointLatency: TimeInterval
    private(set) var pointAttempts = 0
    private var notReady: Bool
    init(fixture: Data, pointLatency: TimeInterval, notReady: Bool = false) {
        self.fixture = fixture; self.pointLatency = pointLatency; self.notReady = notReady
    }
    func setNotReady(_ value: Bool) { notReady = value }

    func respond(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let url = request.url!
        func http(_ status: Int) -> HTTPURLResponse { HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)! }
        if url.host == "opendata.dwd.de" { return (Data("composite_rv_20261028_1515.tar".utf8), http(200)) }
        pointAttempts += 1
        if notReady {
            return (Data("<ServiceExceptionReport><ServiceException code=\"InvalidParameterValue\">InvalidDimensionValue</ServiceException></ServiceExceptionReport>".utf8), http(200))
        }
        if pointLatency > request.timeoutInterval { throw URLError(.timedOut) }
        return (fixture, http(200))
    }
}
