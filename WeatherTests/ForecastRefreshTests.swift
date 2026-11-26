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
        let store = WeatherStore.isolated(client: client, backend: DWDDataTests.unreachableBackend,
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

    // MARK: Overlapping loads (start-up: `refresh()` and the visible-app loop's `reloadForecast()`)

    private var newer: Date { n0.addingTimeInterval(300) }

    private func makeOverlapStore(_ transport: OverlapTransport, clock: Clock) -> WeatherStore {
        let client = DWDClient(transport: { try await transport.respond($0) }, clock: { clock.now }, retryDelay: { _ in 0 })
        let store = WeatherStore.isolated(client: client, backend: DWDDataTests.unreachableBackend,
                                 defaults: UserDefaults(suiteName: "ForecastRefreshTests-\(UUID().uuidString)")!)
        store.clock = { clock.now }
        store.selectedPlace = SavedPlace(name: "A", coordinate: coordinate)
        return store
    }

    private func waitFor(_ what: String, _ condition: () async -> Bool) async throws {
        for _ in 0..<500 {
            if await condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("not reached: \(what)")
    }

    /// Start-up: the loop's load runs first, then `refresh()` is called. Build 56 asked twice and `refresh()` took over the
    /// loop's token (the bar ended with the faster request, the other answer was dropped). Now `refresh()` joins the
    /// running load: ONE point request, the bar holds until it ends, and `refresh()` returns only after it.
    func testRefreshDuringRunningLoopLoadJoinsItAndAsksTheServiceOnce() async throws {
        let clock = Clock(at(480))
        let transport = OverlapTransport(fixture: try fixture(), origin: n0, listed: [n0, newer])
        let store = makeOverlapStore(transport, clock: clock)
        let loop = Task { await store.reloadForecast() }
        try await waitFor("loop request") { await transport.isWaiting(for: newer) }
        var refreshReturned = false
        let manual = Task { await store.refresh(); refreshReturned = true }
        try await Task.sleep(for: .milliseconds(150)) // the radar part is done, the forecast part waits
        XCTAssertFalse(refreshReturned, "refresh() waits for the running forecast load")
        XCTAssertTrue(store.isForecastLoading, "the bar holds while the one request runs")
        let requests = await transport.pointRequests
        XCTAssertEqual(requests, 1, "no second point request while one runs")

        await transport.open(newer)
        await loop.value
        await manual.value
        XCTAssertTrue(refreshReturned)
        XCTAssertEqual(store.forecast?.referenceTime, newer)
        XCTAssertFalse(store.isForecastLoading)
        XCTAssertNil(store.forecastError)
        XCTAssertEqual(store.forecastFailures, 0)
        let total = await transport.pointRequests
        XCTAssertEqual(total, 1)
    }

    /// Same start the other way round: `refresh()` first, the loop's `reloadForecast()` finds a load running and does not start one.
    func testReloadDuringRunningRefreshDoesNotAskAgain() async throws {
        let clock = Clock(at(480))
        let transport = OverlapTransport(fixture: try fixture(), origin: n0, listed: [n0, newer])
        let store = makeOverlapStore(transport, clock: clock)
        let manual = Task { await store.refresh() }
        try await waitFor("refresh request") { await transport.isWaiting(for: newer) }
        await store.reloadForecast() // returns at once
        let requests = await transport.pointRequests
        XCTAssertEqual(requests, 1)
        XCTAssertTrue(store.isForecastLoading)
        await transport.open(newer)
        await manual.value
        XCTAssertEqual(store.forecast?.referenceTime, newer)
        XCTAssertFalse(store.isForecastLoading)
    }

    /// The load `refresh()` joined ends without an answer (its task was cancelled, e.g. the loop on leaving the app): `refresh()`
    /// must not end without any forecast request and asks once itself.
    func testJoiningRefreshAsksItselfWhenTheJoinedLoadWasCancelled() async throws {
        let clock = Clock(at(480))
        let transport = OverlapTransport(fixture: try fixture(), origin: n0, listed: [n0, newer])
        let store = makeOverlapStore(transport, clock: clock)
        let loop = Task { await store.reloadForecast() }
        try await waitFor("loop request") { await transport.isWaiting(for: newer) }
        let manual = Task { await store.refresh() }
        try await Task.sleep(for: .milliseconds(150))
        loop.cancel()
        await transport.open(newer)
        await loop.value
        await manual.value
        XCTAssertEqual(store.forecast?.referenceTime, newer, "refresh() delivered the forecast after the joined load was cancelled")
        XCTAssertFalse(store.isForecastLoading)
    }

    /// Defence in depth (not reachable through `reloadForecast`'s guard unless `isForecastLoading` is out of step): two loads of the
    /// same place that overlap anyway. The newer run answers first; the bar holds until both ended and the late older answer does
    /// not replace the newer run.
    func testOverlappingLoadsKeepTheBarUntilBothEndAndNeverStepBack() async throws {
        let clock = Clock(at(480)) // N0+300 is expected, the index lists only N0 at first
        let transport = OverlapTransport(fixture: try fixture(), origin: n0, listed: [n0])
        let store = makeOverlapStore(transport, clock: clock)
        let first = Task { await store.reloadForecast() }
        try await waitFor("first request for the old run") { await transport.isWaiting(for: n0) }
        await transport.setListed([n0, newer])
        store.isForecastLoading = false // out of step on purpose: lets a second load start
        let second = Task { await store.reloadForecast() }
        try await waitFor("second request for the new run") { await transport.isWaiting(for: newer) }
        XCTAssertTrue(store.isForecastLoading)

        await transport.open(newer)
        await second.value
        XCTAssertEqual(store.forecast?.referenceTime, newer)
        XCTAssertTrue(store.isForecastLoading, "the first request still runs: the bar stays")

        await transport.open(n0) // the old run arrives late
        await first.value
        XCTAssertEqual(store.forecast?.referenceTime, newer, "a late older answer does not replace the newer run")
        XCTAssertEqual(store.lastValidForecast(for: store.selectedPlace.id)?.referenceTime, newer)
        XCTAssertFalse(store.isForecastLoading, "both requests are over")
        XCTAssertNil(store.forecastError)
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

/// Run index lists the runs set by the test; point queries wait until the test opens their run, then answer the fixture
/// shifted to the run asked for (`DIM_REFERENCE_TIME`).
private actor OverlapTransport {
    let fixture: Data
    let origin: Date
    private var listed: [Date]
    private var opened: Set<Date> = []
    private var waiting: Set<Date> = []
    private(set) var pointRequests = 0
    private var waiters: [Date: [CheckedContinuation<Void, Never>]] = [:]
    init(fixture: Data, origin: Date, listed: [Date]) { self.fixture = fixture; self.origin = origin; self.listed = listed }

    func setListed(_ runs: [Date]) { listed = runs }
    func isWaiting(for run: Date) -> Bool { waiting.contains(run) }
    func open(_ run: Date) {
        opened.insert(run)
        waiters.removeValue(forKey: run)?.forEach { $0.resume() }
    }

    func respond(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let url = request.url!
        func http(_ status: Int) -> HTTPURLResponse { HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)! }
        if url.host == "opendata.dwd.de" {
            let day = DateFormatter()
            day.locale = Locale(identifier: "en_US_POSIX"); day.timeZone = TimeZone(identifier: "UTC")
            day.dateFormat = "yyyyMMdd_HHmm"
            return (Data(listed.map { "composite_rv_\(day.string(from: $0)).tar" }.joined(separator: " ").utf8), http(200))
        }
        guard let value = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "DIM_REFERENCE_TIME" })?.value,
              let run = DWDRequest.date(value) else { return (fixture, http(200)) }
        pointRequests += 1
        waiting.insert(run)
        if !opened.contains(run) { await withCheckedContinuation { waiters[run, default: []].append($0) } }
        return (try shifted(to: run), http(200))
    }

    private func shifted(to run: Date) throws -> Data {
        let delta = run.timeIntervalSince(origin)
        var root = try XCTUnwrap(JSONSerialization.jsonObject(with: fixture) as? [String: Any])
        var features = try XCTUnwrap(root["features"] as? [[String: Any]])
        for index in features.indices {
            var properties = try XCTUnwrap(features[index]["properties"] as? [String: Any])
            for key in ["TIME", "REFERENCE_TIME"] {
                let date = try XCTUnwrap((properties[key] as? String).flatMap(DWDRequest.date))
                properties[key] = DWDRequest.timestamp(date.addingTimeInterval(delta))
            }
            features[index]["properties"] = properties
        }
        root["features"] = features
        return try JSONSerialization.data(withJSONObject: root)
    }
}
