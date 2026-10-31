import XCTest
@testable import Weather

/// Point-forecast retries, distinguishable error kinds and the per-place last valid forecast.
/// No network: every test uses a scripted transport and an injected clock.
@MainActor
final class ForecastResilienceTests: XCTestCase {
    private let reference = DWDRequest.date("2026-10-28T15:15:00Z")!
    private let coordinate = WeatherCoordinate(latitude: 53.56, longitude: 6.74)

    private func fixture() throws -> Data {
        let bundle = Bundle(for: ForecastResilienceTests.self)
        let url = bundle.url(forResource: "wms-wet-point-response", withExtension: "json", subdirectory: "Fixtures")
            ?? bundle.url(forResource: "wms-wet-point-response", withExtension: "json")
        return try Data(contentsOf: XCTUnwrap(url))
    }

    private func client(_ transport: ScriptedTransport, clock: ResilienceClock? = nil) -> DWDClient {
        let now = clock ?? ResilienceClock(reference)
        return DWDClient(transport: { try await transport.respond($0) }, clock: { now.now }, retryDelay: { _ in 0 })
    }

    private func store(_ transport: ScriptedTransport, clock: ResilienceClock) -> WeatherStore {
        WeatherStore(client: client(transport, clock: clock), backend: DWDDataTests.unreachableBackend,
                     defaults: UserDefaults(suiteName: "ForecastResilienceTests-\(UUID().uuidString)")!)
    }

    // MARK: Retries

    func testTransientStatusesAreRetriedAndRecover() async throws {
        for status in [503, 502, 504] {
            let transport = ScriptedTransport(fixture: try fixture(), points: [.status(status), .status(503), .fixture])
            let forecast = try await client(transport).forecast(at: coordinate)
            XCTAssertEqual(forecast.samples.count, 25, "status \(status)")
            let count = await transport.pointCount
            XCTAssertEqual(count, 3, "status \(status)")
        }
    }

    func testTimeoutIsRetriedOnce() async throws {
        let transport = ScriptedTransport(fixture: try fixture(), points: [.error(URLError(.timedOut)), .fixture])
        _ = try await client(transport).forecast(at: coordinate)
        let count = await transport.pointCount
        XCTAssertEqual(count, 2)
    }

    func testRetriesAreLimitedToThreeRequestsPerCall() async throws {
        let transport = ScriptedTransport(fixture: try fixture(), points: Array(repeating: .status(503), count: 10))
        do { _ = try await client(transport).forecast(at: coordinate); XCTFail("must fail") }
        catch { XCTAssertEqual(error as? DWDDataError, .unavailable) }
        let count = await transport.pointCount
        XCTAssertEqual(count, 3)
        let transient = ScriptedTransport(fixture: try fixture(), points: Array(repeating: .error(URLError(.networkConnectionLost)), count: 10))
        do { _ = try await client(transient).forecast(at: coordinate); XCTFail("must fail") }
        catch { XCTAssertEqual(error as? DWDDataError, .unavailable) }
        let transientCount = await transient.pointCount
        XCTAssertEqual(transientCount, 3)
    }

    func testNoRetryForClientErrorsOfflineAndLowDataMode() async throws {
        for step in [ScriptStep.status(404), .status(400), .error(URLError(.notConnectedToInternet)), .error(URLError(.dataNotAllowed))] {
            let transport = ScriptedTransport(fixture: try fixture(), points: [step, .fixture])
            do { _ = try await client(transport).forecast(at: coordinate); XCTFail("must fail") }
            catch { XCTAssertEqual(error as? DWDDataError, .unavailable) }
            let count = await transport.pointCount
            XCTAssertEqual(count, 1, "\(step)")
        }
    }

    func testCancelledRequestIsCancellationWithoutRetry() async throws {
        let transport = ScriptedTransport(fixture: try fixture(), points: [.error(URLError(.cancelled)), .fixture])
        do { _ = try await client(transport).forecast(at: coordinate); XCTFail("must fail") }
        catch { XCTAssertTrue(error is CancellationError) }
        let count = await transport.pointCount
        XCTAssertEqual(count, 1)
    }

    // MARK: Error kinds

    func testBodiesMapToDistinctErrorsWithoutRetry() async throws {
        let big = Data(repeating: 0x20, count: 2 * 1024 * 1024 + 1)
        let otherXML = Data("<ServiceExceptionReport><ServiceException code=\"NoApplicableCode\">x</ServiceException></ServiceExceptionReport>".utf8)
        let cases: [(Data, DWDDataError)] = [
            (Data("<html><body>Bad gateway</body></html>".utf8), .malformedPayload),
            (Data(), .emptyBody),
            (otherXML, .serviceFailure),
            (big, .oversizedBody),
        ]
        for (body, expected) in cases {
            let transport = ScriptedTransport(fixture: try fixture(), points: [.body(body), .fixture])
            do { _ = try await client(transport).forecast(at: coordinate); XCTFail("must fail") }
            catch { XCTAssertEqual(error as? DWDDataError, expected) }
            let count = await transport.pointCount
            XCTAssertEqual(count, 1)
        }
    }

    func testPayloadShapesMapToDistinctErrors() throws {
        let now = reference
        func parse(_ data: Data) -> DWDDataError? {
            do { _ = try DWDResponse.forecast(from: data, expectedReference: reference, now: now); return nil }
            catch { return error as? DWDDataError }
        }
        XCTAssertEqual(parse(Data("{\"type\":".utf8)), .malformedPayload)
        XCTAssertEqual(parse(Data("{\"type\":\"FeatureCollection\"}".utf8)), .malformedPayload)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: fixture()) as? [String: Any])
        object["type"] = "Something"
        XCTAssertEqual(parse(try JSONSerialization.data(withJSONObject: object)), .unexpectedPayload)
        var timeObject = try XCTUnwrap(JSONSerialization.jsonObject(with: fixture()) as? [String: Any])
        var features = try XCTUnwrap(timeObject["features"] as? [[String: Any]])
        var properties = try XCTUnwrap(features[0]["properties"] as? [String: Any])
        properties["TIME"] = "tomorrow-ish"
        features[0]["properties"] = properties
        timeObject["features"] = features
        XCTAssertEqual(parse(try JSONSerialization.data(withJSONObject: timeObject)), .invalidTimeFormat)
    }

    func testEveryReadFailureKeepsTheCommonTermAndLeaksNoBody() {
        let kinds: [DWDDataError] = [.invalidResponse, .emptyBody, .oversizedBody, .malformedPayload, .unexpectedPayload, .invalidTimeFormat, .serviceFailure]
        XCTAssertEqual(Set(kinds.compactMap(\.errorDescription)).count, kinds.count, "messages are distinguishable")
        for kind in kinds {
            XCTAssertTrue(kind.errorDescription?.hasPrefix("Die Wetterdaten konnten nicht gelesen werden") == true)
        }
    }

    // MARK: Last valid forecast

    func testLastValidForecastSurvivesFailureAndCarriesAge() async throws {
        let clock = ResilienceClock(reference)
        let transport = ScriptedTransport(fixture: try fixture(), points: [.fixture])
        let store = store(transport, clock: clock)
        let place = SavedPlace(name: "A", coordinate: coordinate)
        store.selectedPlace = place
        await store.refresh()
        let valid = try XCTUnwrap(store.forecast)
        XCTAssertNil(store.forecastError)
        clock.advance(400) // beyond the 5-minute memory caches, still inside the 20-minute limit
        await transport.setPoints(Array(repeating: .status(503), count: 3))
        await store.refresh()
        XCTAssertNotNil(store.forecastError)
        XCTAssertEqual(store.forecast?.referenceTime, valid.referenceTime, "last valid forecast is kept")
        XCTAssertEqual(store.forecast?.ageDescription(at: clock.now), "Stand vor 6 Min.")
    }

    func testPlaceSwitchShowsMatchingEntryAndNeverForeignForecast() async throws {
        let clock = ResilienceClock(reference)
        let transport = ScriptedTransport(fixture: try fixture(), points: [.fixture])
        let store = store(transport, clock: clock)
        let a = SavedPlace(name: "A", coordinate: coordinate)
        let b = SavedPlace(name: "B", coordinate: WeatherCoordinate(latitude: 50, longitude: 8))
        store.selectedPlace = a
        await store.refresh()
        XCTAssertNotNil(store.forecast)
        clock.advance(400)
        await transport.setPoints(Array(repeating: .status(503), count: 6))
        store.selectedPlace = b
        store.select(b)
        XCTAssertNil(store.forecast, "B has no forecast of its own; A's must not be shown")
        await store.refresh()
        XCTAssertNil(store.forecast)
        XCTAssertNotNil(store.forecastError)
        store.select(a)
        XCTAssertNotNil(store.forecast, "switching back shows A's last valid forecast")
        XCTAssertNil(store.forecastError)
        await store.refresh()
    }

    func testMemoryKeepsOnlyTheLastTenPlaces() {
        let store = WeatherStore(client: DWDClient(transport: { _ in throw URLError(.notConnectedToInternet) }),
                                 backend: DWDDataTests.unreachableBackend,
                                 defaults: UserDefaults(suiteName: "ForecastResilienceTests-\(UUID().uuidString)")!)
        let forecast = RainForecast(referenceTime: reference, samples: [])
        let ids = (0..<12).map { _ in UUID() }
        for id in ids { store.rememberForecast(forecast, for: id) }
        XCTAssertNil(store.lastValidForecast(for: ids[0]))
        XCTAssertNil(store.lastValidForecast(for: ids[1]))
        XCTAssertNotNil(store.lastValidForecast(for: ids[2]))
        XCTAssertNotNil(store.lastValidForecast(for: ids[11]))
        store.rememberForecast(forecast, for: ids[2]) // refresh moves it to most recent
        store.rememberForecast(forecast, for: UUID())
        XCTAssertNotNil(store.lastValidForecast(for: ids[2]))
        XCTAssertNil(store.lastValidForecast(for: ids[3]))
    }

    func testOldForecastNeverPromisesDryWeather() {
        let samples = (0...24).map { RainSample(date: reference.addingTimeInterval(Double($0 * 300)), amountMM: 0) }
        let forecast = RainForecast(referenceTime: reference, samples: samples)
        XCTAssertEqual(forecast.summary(at: reference.addingTimeInterval(10 * 60)), "Vorerst kein messbarer Regen erwartet")
        let late = reference.addingTimeInterval(21 * 60)
        XCTAssertTrue(forecast.isStale(at: late))
        XCTAssertEqual(forecast.summary(at: late), "Prognosedaten sind veraltet")
        XCTAssertEqual(forecast.ageDescription(at: late), "Stand vor 21 Min.")
        XCTAssertEqual(forecast.ageDescription(at: reference.addingTimeInterval(3900)), "Stand vor 1 Std. 5 Min.")
    }
}

private enum ScriptStep {
    case fixture
    case status(Int)
    case body(Data)
    case error(URLError)
}

private final class ResilienceClock: @unchecked Sendable {
    private let lock = NSLock()
    private var date: Date
    init(_ date: Date) { self.date = date }
    var now: Date { lock.withLock { date } }
    func advance(_ seconds: TimeInterval) { lock.withLock { date = date.addingTimeInterval(seconds) } }
}

/// Answers the run index with one fixed run and point queries from a script (the last step repeats).
private actor ScriptedTransport {
    let fixture: Data
    private var points: [ScriptStep]
    private(set) var pointCount = 0

    init(fixture: Data, points: [ScriptStep]) { self.fixture = fixture; self.points = points }
    func setPoints(_ steps: [ScriptStep]) { points = steps; pointCount = 0 }

    func respond(_ request: URLRequest) throws -> (Data, HTTPURLResponse) {
        let url = request.url!
        func http(_ status: Int) -> HTTPURLResponse {
            HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
        }
        if url.host == "opendata.dwd.de" { return (Data("composite_rv_20261028_1515.tar".utf8), http(200)) }
        pointCount += 1
        let step = points.count > 1 ? points.removeFirst() : (points.first ?? .fixture)
        switch step {
        case .fixture: return (fixture, http(200))
        case .status(let code): return (Data("<html>error</html>".utf8), http(code))
        case .body(let data): return (data, http(200))
        case .error(let error): throw error
        }
    }
}
