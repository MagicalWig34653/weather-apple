import XCTest
@testable import Weather

/// Progress bar on the bottom edge of the forecast header: measurable only where every request of a load reports a
/// total size; otherwise a running bar without a number. End states (success, nothing new, failure, cancellation) hide it.
@MainActor
final class UpdateProgressTests: XCTestCase {
    // MARK: LoadProgress (source of the measured value)

    func testWithoutAnyReportTheReadingIsIndeterminate() {
        let progress = LoadProgress()
        progress.begin(plannedRequests: 1)
        _ = progress.startRequest()
        XCTAssertEqual(progress.reading, .indeterminate)
    }

    func testUnknownOrZeroTotalStaysIndeterminate() {
        for expected in [nil, 0, -1] as [Int64?] {
            let progress = LoadProgress()
            progress.begin(plannedRequests: 1)
            progress.startRequest().report(expected: expected, received: 500)
            XCTAssertEqual(progress.reading, .indeterminate, "expected \(String(describing: expected)): no invented percent")
        }
    }

    func testSingleRequestWithKnownTotalIsMeasured() {
        let progress = LoadProgress()
        progress.begin(plannedRequests: 1)
        let request = progress.startRequest()
        request.report(expected: 1000, received: 250)
        XCTAssertEqual(progress.reading, .measured(0.25))
        request.report(expected: 1000, received: 1000)
        XCTAssertEqual(progress.reading, .measured(1))
    }

    func testReceivedBeyondTotalIsCappedAtOne() {
        let progress = LoadProgress()
        progress.begin(plannedRequests: 1)
        progress.startRequest().report(expected: 100, received: 900)   // e.g. decompressed bytes against the encoded length
        XCTAssertEqual(progress.reading, .measured(1))
    }

    func testTwoRequestsAreMeasuredOnlyOnceBothTotalsAreKnown() {
        let progress = LoadProgress()
        progress.begin(plannedRequests: 2)
        let first = progress.startRequest()
        first.report(expected: 1000, received: 1000)
        XCTAssertEqual(progress.reading, .indeterminate, "the second total is not known yet")
        progress.endRequest(first, completed: true)
        XCTAssertEqual(progress.reading, .indeterminate)
        let second = progress.startRequest()
        XCTAssertEqual(progress.reading, .indeterminate, "second request without headers")
        second.report(expected: 3000, received: 1000)
        XCTAssertEqual(progress.reading, .measured(0.5), "(1000 + 1000) / (1000 + 3000)")
    }

    func testSecondRequestWithoutTotalKeepsTheWholeLoadIndeterminate() {
        let progress = LoadProgress()
        progress.begin(plannedRequests: 2)
        let first = progress.startRequest()
        first.report(expected: 1000, received: 1000)
        progress.endRequest(first, completed: true)
        progress.startRequest().report(expected: nil, received: 700)
        XCTAssertEqual(progress.reading, .indeterminate)
    }

    func testRetryNeverMovesTheMeasuredValueBackwards() {
        let progress = LoadProgress()
        progress.begin(plannedRequests: 1)
        let first = progress.startRequest()
        first.report(expected: 1000, received: 800)
        XCTAssertEqual(progress.reading, .measured(0.8))
        progress.endRequest(first, completed: false)          // failed attempt, the client retries
        let retry = progress.startRequest()
        retry.report(expected: 1000, received: 100)
        XCTAssertEqual(progress.reading, .measured(0.8), "high-water mark")
        retry.report(expected: 1000, received: 900)
        XCTAssertEqual(progress.reading, .measured(0.9))
    }

    func testFinishAndBeginResetTheReading() {
        let progress = LoadProgress()
        progress.begin(plannedRequests: 1)
        progress.startRequest().report(expected: 1000, received: 500)
        progress.finish()
        XCTAssertEqual(progress.reading, .indeterminate)
        progress.begin(plannedRequests: 1)
        XCTAssertEqual(progress.reading, .indeterminate, "a new load starts without the old value")
    }

    // MARK: Display decision

    func testNothingLoadingMeansNoBar() {
        XCTAssertEqual(UpdateProgressDisplay.make(isForecastLoading: false, isRadarLoading: false, reading: .measured(0.5)), .hidden)
        XCTAssertEqual(UpdateProgressDisplay.make(isForecastLoading: false, isRadarLoading: false, reading: .indeterminate), .hidden)
    }

    func testForecastLoadWithoutTotalRunsWithoutNumber() {
        XCTAssertEqual(UpdateProgressDisplay.make(isForecastLoading: true, isRadarLoading: false, reading: .indeterminate), .running)
    }

    func testForecastLoadWithKnownTotalIsMeasured() {
        XCTAssertEqual(UpdateProgressDisplay.make(isForecastLoading: true, isRadarLoading: false, reading: .measured(0.4)), .measured(0.4))
    }

    func testRadarPartHasNoTotalSoTheWholeUpdateRuns() {
        XCTAssertEqual(UpdateProgressDisplay.make(isForecastLoading: true, isRadarLoading: true, reading: .measured(0.4)), .running,
                       "the radar part reports no total: no percent for the forecast alone")
        XCTAssertEqual(UpdateProgressDisplay.make(isForecastLoading: false, isRadarLoading: true, reading: .measured(0.4)), .running)
    }

    func testPercentTextRoundsDownAndNeverShowsHundredBeforeTheEnd() {
        XCTAssertTrue(UpdateProgressDisplay.percentText(0.5).contains("50"))
        XCTAssertTrue(UpdateProgressDisplay.percentText(0.999).contains("99"))
        XCTAssertTrue(UpdateProgressDisplay.percentText(1).contains("100"))
        XCTAssertTrue(UpdateProgressDisplay.percentText(-0.2).contains("0"))
        XCTAssertTrue(UpdateProgressDisplay.percentText(7).contains("100"))
    }

    func testIndeterminateSweepStaysInsideTheBarAndMoves() {
        for phase in stride(from: 0.0, through: 1.0, by: 0.05) {
            let segment = UpdateProgressDisplay.sweepSegment(phase: phase)
            XCTAssertGreaterThanOrEqual(segment.lowerBound, 0)
            XCTAssertLessThanOrEqual(segment.upperBound, 1)
            if (0.2...0.8).contains(phase) { XCTAssertGreaterThan(segment.upperBound - segment.lowerBound, 0.05) }
        }
        XCTAssertNotEqual(UpdateProgressDisplay.sweepSegment(phase: 0.2), UpdateProgressDisplay.sweepSegment(phase: 0.6))
    }

    // MARK: Client (task-local request handle reaches the progress)

    func testClientReportsMeasuredProgressWhileTheRequestsRun() async throws {
        let gate = Gate()
        let client = DWDClient(transport: { request in
            let url = request.url!
            func http(_ status: Int) -> HTTPURLResponse { HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)! }
            let handle = LoadProgress.activeRequest
            if url.host == "opendata.dwd.de" {
                handle?.report(expected: 100, received: 100)
                return (Data("composite_rv_20261028_1515.tar".utf8), http(200))
            }
            handle?.report(expected: 300, received: 150)
            await gate.wait()
            return (try UpdateProgressTests.fixture(), http(200))
        }, clock: { DWDRequest.date("2026-10-28T15:20:00Z")! }, retryDelay: { _ in 0 })
        let load = Task { try await client.forecast(at: WeatherCoordinate(latitude: 53.56, longitude: 6.74)) }
        try await waitUntil { client.progress.reading == .measured(0.625) }   // (100 + 150) / (100 + 300)
        await gate.open()
        _ = try await load.value
        XCTAssertEqual(client.progress.reading, .indeterminate, "load over: reading reset")
    }

    func testRepeatedCallJoiningARunningRequestKeepsTheMeasuredReading() async throws {
        let gate = Gate()
        let client = DWDClient(transport: { request in
            let url = request.url!
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            if url.host == "opendata.dwd.de" {
                LoadProgress.activeRequest?.report(expected: 100, received: 100)
                return (Data("composite_rv_20261028_1515.tar".utf8), response)
            }
            LoadProgress.activeRequest?.report(expected: 300, received: 100)
            await gate.wait()
            return (try UpdateProgressTests.fixture(), response)
        }, clock: { DWDRequest.date("2026-10-28T15:20:00Z")! }, retryDelay: { _ in 0 })
        let coordinate = WeatherCoordinate(latitude: 53.56, longitude: 6.74)
        let first = Task { try await client.forecast(at: coordinate) }
        try await waitUntil { client.progress.reading == .measured(0.5) }   // (100 + 100) / (100 + 300)
        let second = Task { try await client.forecast(at: coordinate) }       // joins the running point query
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(client.progress.reading, .measured(0.5), "the joining call does not reset the reading")
        await gate.open()
        _ = try await first.value
        _ = try await second.value
        XCTAssertEqual(client.progress.reading, .indeterminate, "all calls over: reading reset")
    }

    func testClientWithoutReportsStaysIndeterminate() async throws {
        let gate = Gate()
        let client = DWDClient(transport: { request in
            let url = request.url!
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            if url.host == "opendata.dwd.de" { return (Data("composite_rv_20261028_1515.tar".utf8), response) }
            await gate.wait()
            return (try UpdateProgressTests.fixture(), response)
        }, clock: { DWDRequest.date("2026-10-28T15:20:00Z")! }, retryDelay: { _ in 0 })
        let load = Task { try await client.forecast(at: WeatherCoordinate(latitude: 53.56, longitude: 6.74)) }
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(client.progress.reading, .indeterminate)
        await gate.open()
        _ = try await load.value
    }

    // MARK: End states in the store (bar hidden afterwards)

    private func makeStore(point: @escaping @Sendable () async throws -> (Data, Int)) -> WeatherStore {
        let client = DWDClient(transport: { request in
            let url = request.url!
            if url.host == "opendata.dwd.de" {
                return (Data("composite_rv_20261028_1515.tar".utf8), HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!)
            }
            let (data, status) = try await point()
            return (data, HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!)
        }, clock: { DWDRequest.date("2026-10-28T15:20:00Z")! }, retryDelay: { _ in 0 })
        let store = WeatherStore(client: client, backend: DWDDataTests.unreachableBackend,
                                 defaults: UserDefaults(suiteName: "UpdateProgressTests-\(UUID().uuidString)")!)
        store.clock = { DWDRequest.date("2026-10-28T15:20:00Z")! }
        store.selectedPlace = SavedPlace(name: "A", coordinate: WeatherCoordinate(latitude: 53.56, longitude: 6.74))
        return store
    }

    func testBarRunsWhileLoadingAndEndsAfterSuccess() async throws {
        let gate = Gate()
        let data = try Self.fixture()
        let store = makeStore { await gate.wait(); return (data, 200) }
        XCTAssertEqual(store.updateProgressDisplay, .hidden)
        let load = Task { await store.reloadForecast() }
        try await waitUntil { store.updateProgressDisplay == .running }
        await gate.open()
        await load.value
        XCTAssertNotNil(store.forecast)
        XCTAssertEqual(store.updateProgressDisplay, .hidden, "success")
    }

    func testManualReloadShowsTheRunningBarAndEndsIt() async throws {
        let gate = Gate()
        let data = try Self.fixture()
        let store = makeStore { await gate.wait(); return (data, 200) }
        let reload = Task { await store.refresh() }   // "Daten neu laden": radar part and forecast part
        try await waitUntil { store.updateProgressDisplay == .running }
        await gate.open()
        await reload.value
        XCTAssertEqual(store.updateProgressDisplay, .hidden, "manual reload over")
    }

    func testBarEndsWhenTheLoadBringsNothingNew() async throws {
        let data = try Self.fixture()
        let store = makeStore { (data, 200) }
        await store.reloadForecast()
        let shown = store.forecast?.referenceTime
        await store.reloadForecast()   // same run again: nothing new
        XCTAssertEqual(store.forecast?.referenceTime, shown)
        XCTAssertEqual(store.updateProgressDisplay, .hidden, "unchanged answer")
    }

    func testBarEndsAfterFailure() async throws {
        let store = makeStore { (Data("<html>error</html>".utf8), 503) }
        await store.reloadForecast()
        XCTAssertNotNil(store.forecastError)
        XCTAssertEqual(store.updateProgressDisplay, .hidden, "failure")
    }

    func testBarEndsAfterCancellation() async throws {
        let store = makeStore { try await Task.sleep(for: .seconds(5)); return (Data(), 200) }
        let load = Task { await store.reloadForecast() }
        try await waitUntil { store.updateProgressDisplay == .running }
        load.cancel()
        await load.value
        XCTAssertEqual(store.updateProgressDisplay, .hidden, "cancelled")
    }

    // MARK: Helpers

    nonisolated static func fixture() throws -> Data {
        let bundle = Bundle(for: UpdateProgressTests.self)
        let url = bundle.url(forResource: "wms-wet-point-response", withExtension: "json", subdirectory: "Fixtures")
            ?? bundle.url(forResource: "wms-wet-point-response", withExtension: "json")
        return try Data(contentsOf: try XCTUnwrap(url))
    }

    private func waitUntil(timeout: TimeInterval = 5, _ condition: () -> Bool) async throws {
        let end = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > end { XCTFail("condition not reached in \(timeout) s"); return }
            try await Task.sleep(for: .milliseconds(20))
        }
    }
}

private actor Gate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    func wait() async {
        if isOpen { return }
        await withCheckedContinuation { waiters.append($0) }
    }
    func open() { isOpen = true; waiters.forEach { $0.resume() }; waiters = [] }
}
