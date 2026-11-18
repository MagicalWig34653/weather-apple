import XCTest
@testable import Weather

/// Timing and wording of the point forecast refresh: pure policy plus store behaviour with a scripted transport and
/// an injected clock (no network, no real waiting).
@MainActor
final class ForecastRefreshTests: XCTestCase {
    /// Grid point N0; fixture run.
    private let n0 = DWDRequest.date("2026-10-28T15:15:00Z")!
    private let coordinate = WeatherCoordinate(latitude: 53.56, longitude: 6.74)
    private func at(_ seconds: TimeInterval) -> Date { n0.addingTimeInterval(seconds) }

    // MARK: Pure policy

    func testThresholdStaysAtTwentyMinutes() {
        XCTAssertEqual(RainForecast.maximumAge, 20 * 60)
        let forecast = RainForecast(referenceTime: n0, samples: [])
        XCTAssertFalse(forecast.isStale(at: at(1200)))
        XCTAssertTrue(forecast.isStale(at: at(1201)))
    }

    func testNewRunExpectedWhenShownRunIsOlderThanExpected() {
        XCTAssertFalse(ForecastRefreshPolicy.newRunExpected(shown: n0, now: at(240)))
        // Return after 4 minutes: N0+300 is expected from N0+465 on.
        XCTAssertTrue(ForecastRefreshPolicy.newRunExpected(shown: n0, now: at(240 + 240)))
        XCTAssertFalse(ForecastRefreshPolicy.newRunExpected(shown: at(300), now: at(480)))
        XCTAssertTrue(ForecastRefreshPolicy.newRunExpected(shown: nil, now: at(10)))
    }

    func testScheduleWaitsForNextRunThenRepeatsFastAndBounded() {
        var s = ForecastRefreshSchedule(random: { 0 })
        // Current run shown at N0+240: next load at N0+500 (= N1 + 200 s).
        XCTAssertEqual(s.nextDelay(now: at(240), shown: n0, failures: 0, restricted: false), 260, accuracy: 0.001)
        // N1 expected, request time N1+200 not reached yet: wait for it.
        XCTAssertEqual(s.nextDelay(now: at(470), shown: n0, failures: 0, restricted: false), 30, accuracy: 0.001)
        // Due but missing: 20, 30, 60, 60 ...
        let delays = (0..<5).map { s.nextDelay(now: at(510 + Double($0)), shown: n0, failures: 0, restricted: false) }
        XCTAssertEqual(delays, [20, 30, 60, 60, 60])
    }

    func testFailureBackoffIsBoundedAndRestrictedModeIsSlow() {
        var s = ForecastRefreshSchedule(random: { 0 })
        let delays = (1...8).map { s.nextDelay(now: at(100), shown: n0, failures: $0, restricted: false) }
        XCTAssertEqual(delays, [20, 30, 60, 60, 60, 60, 300, 300])
        XCTAssertGreaterThanOrEqual(s.nextDelay(now: at(100), shown: n0, failures: 1, restricted: true), 300)
        XCTAssertGreaterThanOrEqual(s.nextDelay(now: at(240), shown: n0, failures: 0, restricted: true), 300)
    }

    func testServerBehindNeedsAnAnswerAfterRequestTimePlusGrace() {
        // Expected run N1 = N0+300 from N0+465 on; the service was asked at N0+520 (before N1+260): not yet.
        XCTAssertFalse(ForecastRefreshPolicy.serverBehind(shown: n0, checkedAt: at(520), now: at(530)))
        XCTAssertFalse(ForecastRefreshPolicy.serverBehind(shown: n0, checkedAt: nil, now: at(700)))
        XCTAssertTrue(ForecastRefreshPolicy.serverBehind(shown: n0, checkedAt: at(570), now: at(580)))
        XCTAssertFalse(ForecastRefreshPolicy.serverBehind(shown: at(300), checkedAt: at(570), now: at(580)))
    }

    // MARK: Store

    private func fixture() throws -> Data {
        let bundle = Bundle(for: ForecastRefreshTests.self)
        let url = bundle.url(forResource: "wms-wet-point-response", withExtension: "json", subdirectory: "Fixtures")
            ?? bundle.url(forResource: "wms-wet-point-response", withExtension: "json")
        return try Data(contentsOf: XCTUnwrap(url))
    }

    private func makeStore(_ transport: Transport, clock: Clock) -> WeatherStore {
        let client = DWDClient(transport: { try await transport.respond($0) }, clock: { clock.now }, retryDelay: { _ in 0 })
        let store = WeatherStore(client: client, backend: DWDDataTests.unreachableBackend,
                                 defaults: UserDefaults(suiteName: "ForecastRefreshTests-\(UUID().uuidString)")!)
        store.clock = { clock.now }
        store.selectedPlace = SavedPlace(name: "A", coordinate: coordinate)
        return store
    }

    func testReturnAfterFourMinutesLoadsAtOnceWhenNewRunIsExpected() async throws {
        let clock = Clock(at(240))
        let transport = Transport(fixture: try fixture())
        let store = makeStore(transport, clock: clock)
        XCTAssertTrue(store.needsRefresh(), "nothing loaded yet")
        await store.refresh()
        XCTAssertFalse(store.needsRefresh(), "the shown run is still the expected newest")
        clock.set(at(240 + 90)) // 90 s later: still N0
        XCTAssertFalse(store.needsRefresh())
        clock.set(at(240 + 240)) // returning after 4 minutes: N0+300 is expected
        XCTAssertTrue(store.needsRefresh())
    }

    func testCacheIsBypassedOnlyWhenNewRunIsExpected() async throws {
        let clock = Clock(at(240))
        let transport = Transport(fixture: try fixture())
        let store = makeStore(transport, clock: clock)
        await store.refresh()
        var indexCount = await transport.indexCount
        XCTAssertEqual(indexCount, 1)
        clock.set(at(250)) // N0 is current: the index cache is used
        await store.refresh()
        indexCount = await transport.indexCount
        XCTAssertEqual(indexCount, 1, "no new run expected: cache used")
        clock.set(at(470)) // N1 expected, cache (fetched at 240) is younger than 300 s but too old
        await store.refresh()
        indexCount = await transport.indexCount
        XCTAssertEqual(indexCount, 2, "new run expected: index fetched again")
    }

    /// Der Ladekreis am Pillenrand erscheint bei jedem Ladevorgang, auch beim Erstladen ohne Prognose.
    func testSpinnerShowsOnEveryForecastLoadIncludingFirst() async throws {
        let clock = Clock(at(240))
        let transport = Transport(fixture: try fixture())
        let store = makeStore(transport, clock: clock)
        XCTAssertFalse(store.showsForecastSpinner, "idle without forecast: no spinner")
        store.isForecastLoading = true
        XCTAssertNil(store.forecast)
        XCTAssertTrue(store.showsForecastSpinner, "first load without forecast shows the spinner")
        store.isForecastLoading = false
        await store.refresh()
        XCTAssertNotNil(store.forecast)
        XCTAssertFalse(store.showsForecastSpinner, "current forecast: no spinner")
        store.isForecastLoading = true
        XCTAssertTrue(store.showsForecastSpinner, "reload with forecast shows the spinner")
    }

    func testFirstFailureDoesNotShowOlderForecastButSecondDoes() async throws {
        let clock = Clock(at(240))
        let transport = Transport(fixture: try fixture())
        let store = makeStore(transport, clock: clock)
        await store.refresh()
        XCTAssertNil(store.forecastStatus())
        clock.set(at(560)) // beyond the 5-minute point cache
        await transport.setPointStatus(503)
        await store.refresh()
        XCTAssertNotNil(store.forecastError)
        XCTAssertEqual(store.forecastFailures, 1)
        XCTAssertFalse(store.forecastFailureConfirmed)
        XCTAssertNil(store.forecastStatus(), "a retry is pending, no failure message yet")
        XCTAssertFalse(store.showsForecastSpinner, "no request runs between the repeats: no spinner")
        XCTAssertNotNil(store.forecast, "last valid forecast stays")
        await store.refresh()
        XCTAssertTrue(store.forecastFailureConfirmed)
        XCTAssertEqual(store.forecastStatus(), .failed)
    }

    func testServerBehindOnlyAfterAnAnswerWithoutNewerRun() async throws {
        let clock = Clock(at(240))
        let transport = Transport(fixture: try fixture())
        let store = makeStore(transport, clock: clock)
        await store.refresh()
        clock.set(at(520)) // N1 expected, asked before N1+260
        await store.refresh()
        XCTAssertNil(store.forecastStatus(), "shown run is only 8.7 minutes old and not confirmed missing yet")
        clock.set(at(570))
        await store.refresh()
        XCTAssertEqual(store.forecastStatus(), .serverBehind)
        XCTAssertNil(store.forecastError)
    }

    func testLoopRepeatsWithBackoffAfterFailureAndDoesNotFireContinuously() async throws {
        let clock = Clock(at(470))
        let transport = Transport(fixture: try fixture())
        await transport.setPointStatus(503)
        let store = makeStore(transport, clock: clock)
        var waits: [TimeInterval] = []
        await store.runForecastRefresh(schedule: ForecastRefreshSchedule(random: { 0 }), restricted: { false }) { delay in
            waits.append(delay)
            if waits.count == 4 { throw CancellationError() }
        }
        XCTAssertEqual(waits, [20, 30, 60, 60])
        XCTAssertEqual(store.forecastFailures, 4)
    }

    // MARK: Spinner ends (Build 49: "WARUM GEHT DER LADEKREIS JETZT NICHT WEG")

    private func staleForecast() -> RainForecast {
        RainForecast(referenceTime: at(-1500), samples: [RainSample(date: at(-1500), amountMM: 0)])
    }

    /// Shown and remembered as the place's last valid forecast (like a saved place with its cache).
    private func show(_ forecast: RainForecast, in store: WeatherStore) {
        store.forecast = forecast
        store.rememberForecast(forecast, for: store.selectedPlace.id)
    }

    /// Load ends with the same run (the service has nothing newer yet): no spinner afterwards.
    func testSpinnerEndsWhenLoadBringsNothingNewer() async throws {
        let clock = Clock(at(240))
        let transport = Transport(fixture: try fixture())
        let store = makeStore(transport, clock: clock)
        await store.refresh()
        clock.set(at(520)) // N1 expected, the index still answers N0
        XCTAssertTrue(store.needsRefresh())
        await store.reloadForecast()
        XCTAssertEqual(store.forecast?.referenceTime, n0)
        XCTAssertFalse(store.isForecastLoading)
        XCTAssertFalse(store.showsForecastSpinner, "load finished without a newer run")
        clock.set(at(580)) // later answer without newer run: "server behind", still no spinner
        await store.reloadForecast()
        XCTAssertEqual(store.forecastStatus(), .serverBehind)
        XCTAssertFalse(store.showsForecastSpinner)
    }

    /// The current run is shown and a load fails (e.g. WMS timeout): the loop does not repeat before the next run is
    /// expected, so an "unconfirmed failure" spinner would spin for minutes.
    func testSpinnerEndsAfterFailedLoadWhileCurrentRunIsShown() async throws {
        let clock = Clock(at(240))
        let transport = Transport(fixture: try fixture())
        await transport.setPointStatus(503)
        let store = makeStore(transport, clock: clock)
        show(RainForecast(referenceTime: n0, samples: [RainSample(date: n0, amountMM: 0)]), in: store)
        await store.refresh() // e.g. "Daten neu laden" or the start-up load
        XCTAssertEqual(store.forecastFailures, 1)
        XCTAssertFalse(store.needsRefresh(), "current run shown: the loop will not repeat before the next run")
        XCTAssertFalse(store.isForecastLoading)
        XCTAssertFalse(store.showsForecastSpinner, "no request runs: no spinner")
        XCTAssertNotEqual(store.forecastStatus(), .refreshing)
    }

    /// A load whose task is cancelled (scene change) leaves an old stale forecast without error: no spinner.
    func testSpinnerEndsAfterCancelledLoad() async throws {
        let clock = Clock(at(240))
        let transport = Transport(fixture: try fixture())
        await transport.setPointDelay(0.3)
        let store = makeStore(transport, clock: clock)
        show(staleForecast(), in: store)
        let task = Task { await store.reloadForecast() }
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertTrue(store.isForecastLoading)
        XCTAssertTrue(store.showsForecastSpinner, "spinner while the request runs")
        task.cancel()
        await task.value
        XCTAssertFalse(store.isForecastLoading)
        XCTAssertFalse(store.showsForecastSpinner, "cancelled load: no request runs, no spinner")
    }

    /// The visible-app loop with failures: the spinner never shows while the loop waits between attempts.
    func testNoSpinnerWhileLoopWaitsBetweenAttempts() async throws {
        let clock = Clock(at(470))
        let transport = Transport(fixture: try fixture())
        await transport.setPointStatus(503)
        let store = makeStore(transport, clock: clock)
        show(RainForecast(referenceTime: n0, samples: [RainSample(date: n0, amountMM: 0)]), in: store)
        var spinnerWhileWaiting: [Bool] = []
        await store.runForecastRefresh(schedule: ForecastRefreshSchedule(random: { 0 }), restricted: { false }) { _ in
            spinnerWhileWaiting.append(store.showsForecastSpinner)
            if spinnerWhileWaiting.count == 3 { throw CancellationError() }
        }
        XCTAssertEqual(spinnerWhileWaiting, [false, false, false])
        XCTAssertEqual(store.forecastStatus(), .failed, "the stale hint after a confirmed failure stays")
    }

    func testLoopWaitsForTheNextRunAfterSuccess() async throws {
        let clock = Clock(at(240))
        let transport = Transport(fixture: try fixture())
        let store = makeStore(transport, clock: clock)
        var waits: [TimeInterval] = []
        await store.runForecastRefresh(schedule: ForecastRefreshSchedule(random: { 0 }), restricted: { false }) { delay in
            waits.append(delay)
            throw CancellationError()
        }
        XCTAssertEqual(waits.count, 1)
        XCTAssertEqual(waits[0], 260, accuracy: 0.001)
        XCTAssertNotNil(store.forecast)
        XCTAssertEqual(store.forecastFailures, 0)
    }
}

private final class Clock: @unchecked Sendable {
    private let lock = NSLock()
    private var date: Date
    init(_ date: Date) { self.date = date }
    var now: Date { lock.withLock { date } }
    func set(_ value: Date) { lock.withLock { date = value } }
}

/// Run index always answers N0; point queries answer the fixture or a fixed HTTP status.
private actor Transport {
    let fixture: Data
    private(set) var indexCount = 0
    private var pointStatus: Int?
    private var pointDelay: TimeInterval = 0
    init(fixture: Data) { self.fixture = fixture }
    func setPointStatus(_ status: Int?) { pointStatus = status }
    func setPointDelay(_ seconds: TimeInterval) { pointDelay = seconds }

    func respond(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let url = request.url!
        func http(_ status: Int) -> HTTPURLResponse { HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)! }
        if url.host == "opendata.dwd.de" {
            indexCount += 1
            return (Data("composite_rv_20261028_1515.tar".utf8), http(200))
        }
        if pointDelay > 0 { try await Task.sleep(for: .seconds(pointDelay)) }
        if let pointStatus { return (Data("<html>error</html>".utf8), http(pointStatus)) }
        return (fixture, http(200))
    }
}
