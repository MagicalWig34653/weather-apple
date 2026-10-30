import MapKit
import XCTest
@testable import Weather

@MainActor
final class DWDDataTests: XCTestCase {
    private let reference = DWDRequest.date("2026-10-28T15:15:00Z")!

    /// Stores in these tests must not reach the live radar cache: it counts as unreachable.
    static let unreachableBackend = RadarBackendClient(transport: { _ in throw URLError(.notConnectedToInternet) })

    private func fixture() throws -> Data {
        let bundle = Bundle(for: DWDDataTests.self)
        let url = bundle.url(forResource: "wms-wet-point-response", withExtension: "json", subdirectory: "Fixtures")
            ?? bundle.url(forResource: "wms-wet-point-response", withExtension: "json")
        return try Data(contentsOf: XCTUnwrap(url))
    }

    private func modifiedFixture(_ change: (inout [[String: Any]]) -> Void) throws -> Data {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: fixture()) as? [String: Any])
        var features = try XCTUnwrap(object["features"] as? [[String: Any]])
        change(&features)
        object["features"] = features
        object["numberReturned"] = features.count
        return try JSONSerialization.data(withJSONObject: object)
    }

    func testWMSTimestampsAlwaysIncludeExplicitUTCDesignator() throws {
        XCTAssertEqual(DWDRequest.timestamp(reference), "2026-10-28T15:15:00.000Z")
        let url = try DWDRequest.pointURL(at: WeatherCoordinate(latitude: 53, longitude: 10), referenceTime: reference)
        let query = Dictionary(uniqueKeysWithValues: URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!.map { ($0.name, $0.value!) })
        XCTAssertEqual(query["TIME"], "2026-10-28T15:15:00.000Z/2026-10-28T17:15:00.000Z/PT5M")
        XCTAssertEqual(query["DIM_REFERENCE_TIME"], "2026-10-28T15:15:00.000Z")
    }

    func testRealWMSFixtureUsesAccumulationAndConvertsToHourlyRate() throws {
        let result = try DWDResponse.forecast(from: fixture(), expectedReference: reference, now: reference)
        XCTAssertEqual(result.samples.count, 25)
        XCTAssertEqual(try XCTUnwrap(result.samples[0].amountMM), 1.874, accuracy: 0.000001)
        XCTAssertEqual(try XCTUnwrap(result.samples[0].rateMMPerHour), 22.488, accuracy: 0.00001)
        XCTAssertEqual(result.samples[2].amountMM, 0)
        XCTAssertEqual(result.samples.last?.date, reference.addingTimeInterval(7200))
    }

    func testOnlyValidatedUndetectMapsToZero() {
        XCTAssertEqual(DWDResponse.amount(from: -0.0009999999310821295), 0)
        XCTAssertNil(DWDResponse.amount(from: -0.002))
        XCTAssertNil(DWDResponse.amount(from: -0.0001))
        XCTAssertNil(DWDResponse.amount(from: 4_294_967))
        XCTAssertNil(DWDResponse.amount(from: .infinity))
        XCTAssertNil(DWDResponse.amount(from: .nan))
        XCTAssertNil(DWDResponse.amount(from: nil))
        XCTAssertEqual(DWDResponse.amount(from: 0), 0)
    }

    func testDifferentRunIsRejected() throws {
        XCTAssertThrowsError(try DWDResponse.forecast(from: fixture(), expectedReference: reference.addingTimeInterval(300), now: reference)) {
            XCTAssertEqual($0 as? DWDDataError, .mismatchedRun)
        }
    }

    func testDuplicatedTimestampIsRejectedInsteadOfHidingGap() throws {
        let data = try modifiedFixture { features in
            features[1] = features[0]
        }
        XCTAssertThrowsError(try DWDResponse.forecast(from: data, expectedReference: reference, now: reference)) {
            XCTAssertEqual($0 as? DWDDataError, .incompleteForecast)
        }
    }

    func testMissingStepIsRejected() throws {
        let data = try modifiedFixture { $0.remove(at: 10) }
        XCTAssertThrowsError(try DWDResponse.forecast(from: data, expectedReference: reference, now: reference)) {
            XCTAssertEqual($0 as? DWDDataError, .incompleteForecast)
        }
    }

    func testNullValuesRemainUnknownAndDoNotBecomeDryWeather() throws {
        let data = try modifiedFixture { features in
            for index in features.indices {
                var properties = features[index]["properties"] as! [String: Any]
                properties["RV_ANALYSIS"] = NSNull()
                features[index]["properties"] = properties
            }
        }
        XCTAssertThrowsError(try DWDResponse.forecast(from: data, expectedReference: reference, now: reference)) {
            XCTAssertEqual($0 as? DWDDataError, .incompleteForecast)
        }
        let partial = RainForecast(referenceTime: reference, samples: [
            RainSample(date: reference, amountMM: nil),
            RainSample(date: reference.addingTimeInterval(300), amountMM: 0)
        ])
        XCTAssertEqual(partial.summary(at: reference), "Keine verlässliche Regenaussage verfügbar")
    }

    func testStaleAndFutureRunsAreRejected() throws {
        XCTAssertThrowsError(try DWDResponse.forecast(from: fixture(), expectedReference: reference, now: reference.addingTimeInterval(1201))) {
            XCTAssertEqual($0 as? DWDDataError, .staleData)
        }
        XCTAssertThrowsError(try DWDResponse.forecast(from: fixture(), expectedReference: reference, now: reference.addingTimeInterval(-61))) {
            XCTAssertEqual($0 as? DWDDataError, .staleData)
        }
    }

    func testIndexFindsNewestDatedRunAndIgnoresLATESTAlias() throws {
        let html = "composite_rv_LATEST.tar composite_rv_20261028_1510.tar composite_rv_20261028_1515.tar composite_rv_20261028_1515.tar"
        let dates = try DWDRunIndex.dates(from: Data(html.utf8), now: reference)
        XCTAssertEqual(dates, [reference.addingTimeInterval(-300), reference])
        XCTAssertThrowsError(try DWDRunIndex.dates(from: Data(html.utf8), now: reference.addingTimeInterval(1201)))
        XCTAssertThrowsError(try DWDRunIndex.dates(from: Data("unrelated html".utf8), now: reference))
    }

    func testPointRequestUsesLatitudeLongitudeAxisOrderAndExplicitRun() throws {
        let url = try DWDRequest.pointURL(at: WeatherCoordinate(latitude: 53, longitude: 10), referenceTime: reference)
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!
        let query = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value!) })
        let bounds = query["BBOX"]!.split(separator: ",").compactMap { Double($0) }
        XCTAssertEqual(bounds, [52.995, 9.995, 53.005, 10.005])
        XCTAssertEqual(query["CRS"], "EPSG:4326")
        XCTAssertEqual(query["DIM_REFERENCE_TIME"], DWDRequest.timestamp(reference))
        XCTAssertThrowsError(try DWDRequest.pointURL(at: WeatherCoordinate(latitude: .nan, longitude: 10), referenceTime: reference))
        XCTAssertThrowsError(try DWDRequest.pointURL(at: WeatherCoordinate(latitude: 0, longitude: 0), referenceTime: reference))
    }

    func testTileProjectionUsesNorthWestTileAndExplicitForecastReference() {
        let url = DWDRequest.tileURL(x: 0, y: 0, z: 1, date: reference.addingTimeInterval(300), referenceTime: reference)
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!
        let query = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value!) })
        let bounds = query["BBOX"]!.split(separator: ",").compactMap { Double($0) }
        XCTAssertEqual(bounds[0], -20_037_508.342789244, accuracy: 0.0001)
        XCTAssertEqual(bounds[1], 0, accuracy: 0.0001)
        XCTAssertEqual(bounds[2], 0, accuracy: 0.0001)
        XCTAssertEqual(bounds[3], 20_037_508.342789244, accuracy: 0.0001)
        XCTAssertEqual(query["SRS"], "EPSG:3857")
        XCTAssertEqual(query["TIME"], DWDRequest.timestamp(reference.addingTimeInterval(300)))
        XCTAssertEqual(query["DIM_REFERENCE_TIME"], DWDRequest.timestamp(reference))
    }

    func testClientCoalescesIndexAndCachesPointInMemory() async throws {
        let data = try fixture()
        let counter = RequestCounter(fixture: data)
        let fixedNow = reference
        let client = DWDClient(transport: { request in try await counter.respond(to: request) }, clock: { fixedNow })
        let coordinate = WeatherCoordinate(latitude: 53.56, longitude: 6.74)
        async let timeline = client.radarTimeline()
        async let forecast = client.forecast(at: coordinate)
        let (frames, first) = try await (timeline, forecast)
        XCTAssertEqual(frames.dates.first, reference.addingTimeInterval(-300))
        XCTAssertEqual(first.samples.count, 25)
        _ = try await client.forecast(at: coordinate)
        let requests = await counter.count
        XCTAssertEqual(requests, 2)
    }

    func testConcurrentPointRequestsShareOneTransportAndCancelledConsumerDoesNotPoisonCache() async throws {
        let gate = SuspendedPointTransport(fixture: try fixture())
        let fixedNow = reference
        let client = DWDClient(transport: { try await gate.respond(to: $0) }, clock: { fixedNow })
        let point = WeatherCoordinate(latitude: 53.56, longitude: 6.74)
        let first = Task { try await client.forecast(at: point) }
        await gate.waitForPoint()
        let second = Task { try await client.forecast(at: point) }
        // Keep the response suspended while both consumers reach the actor.
        for _ in 0..<100 { await Task.yield() }
        first.cancel()
        await gate.releasePoints()
        do { _ = try await first.value; XCTFail("Cancelled consumer returned a forecast") }
        catch { XCTAssertTrue(error is CancellationError) }
        let secondForecast = try await second.value
        XCTAssertEqual(secondForecast.samples.count, 25)
        _ = try await client.forecast(at: point)
        let counts = await gate.counts
        XCTAssertEqual(counts.index, 1)
        XCTAssertEqual(counts.point, 1)
    }

    func testRadarPublishesBeforeSuspendedPointForecast() async throws {
        let gate = SuspendedPointTransport(fixture: try fixture())
        let fixedNow = reference
        let store = WeatherStore(client: DWDClient(transport: { try await gate.respond(to: $0) }, clock: { fixedNow }), backend: Self.unreachableBackend)
        let refresh = Task { await store.refresh() }
        await gate.waitForPoint()
        for _ in 0..<100 where store.timeline == nil { await Task.yield() }
        XCTAssertNotNil(store.timeline, "A slow point response must not hold back the radar")
        XCTAssertNil(store.forecast)
        XCTAssertTrue(store.isLoading)
        XCTAssertFalse(store.isRadarLoading)
        XCTAssertTrue(store.isForecastLoading)
        await gate.releasePoints()
        await refresh.value
        XCTAssertNotNil(store.forecast)
        XCTAssertFalse(store.isLoading)
    }

    func testCancelledRefreshDoesNotPublishDelayedPointResult() async throws {
        let gate = SuspendedPointTransport(fixture: try fixture())
        let fixedNow = reference
        let store = WeatherStore(client: DWDClient(transport: { try await gate.respond(to: $0) }, clock: { fixedNow }), backend: Self.unreachableBackend)
        let refresh = Task { await store.refresh() }
        await gate.waitForPoint()
        refresh.cancel()
        await gate.releasePoints()
        await refresh.value
        XCTAssertNil(store.forecast)
        XCTAssertFalse(store.isLoading)
        // A later request may reuse the completed shared response without being poisoned by cancellation.
        await store.refresh()
        XCTAssertNotNil(store.forecast)
    }

    func testPointCacheExpiresAndRejectsStaleForecast() async throws {
        let data = try fixture()
        let counter = RequestCounter(fixture: data)
        let clock = TestClock(reference)
        let client = DWDClient(transport: { try await counter.respond(to: $0) }, clock: { clock.now })
        let point = WeatherCoordinate(latitude: 53.56, longitude: 6.74)
        _ = try await client.forecast(at: point)
        clock.advance(301)
        _ = try await client.forecast(at: point)
        let requests = await counter.count
        XCTAssertEqual(requests, 4, "Both expired index and point must be fetched again")
        clock.advance(901)
        do { _ = try await client.forecast(at: point); XCTFail("Stale run accepted") }
        catch { XCTAssertEqual(error as? DWDDataError, .staleData) }
    }

    func testTileRequestsCoalesceAndCancelEveryConsumerExactlyOnce() {
        let requests = TileRequests()
        let url = URL(string: "https://example.invalid/public-weather-tile")!
        let session = URLSession(configuration: .ephemeral)
        defer { session.invalidateAndCancel() }
        let first = UUID()
        let calls = LockedResults()
        XCTAssertEqual(requests.add(session.dataTask(with: url), url: url, id: first,
                                    result: { _, error in calls.append(error) }), .start)
        XCTAssertEqual(requests.add(session.dataTask(with: url), url: url, id: UUID(),
                                    result: { _, error in calls.append(error) }), .joined)
        requests.cancelAll()
        requests.cancelAll()
        XCTAssertEqual(calls.errors.count, 2)
        XCTAssertTrue(calls.errors.allSatisfy { ($0 as? URLError)?.code == .cancelled })
        XCTAssertTrue(requests.finished(url: url, id: first).isEmpty)
        XCTAssertEqual(requests.add(session.dataTask(with: url), url: url, id: UUID(), result: { _, _ in }), .cancelled)
    }

    func testCompletedTileFansOutAndNextAttemptCanRetry() {
        let requests = TileRequests()
        let url = URL(string: "https://example.invalid/public-weather-tile")!
        let session = URLSession(configuration: .ephemeral)
        defer { session.invalidateAndCancel() }
        let id = UUID()
        let calls = LockedResults()
        _ = requests.add(session.dataTask(with: url), url: url, id: id, result: { _, error in calls.append(error) })
        _ = requests.add(session.dataTask(with: url), url: url, id: UUID(), result: { _, error in calls.append(error) })
        XCTAssertTrue(requests.finished(url: url, id: UUID()).isEmpty)
        let callbacks = requests.finished(url: url, id: id)
        callbacks.forEach { $0(nil, URLError(.timedOut)) }
        requests.cancelAll()
        XCTAssertEqual(calls.errors.count, 2)
        let retry = TileRequests()
        XCTAssertEqual(retry.add(session.dataTask(with: url), url: url, id: UUID(), result: { _, _ in }), .start)
    }

    func testUnavailableRunRetryBudgetIsSharedAndBoundedAcrossFrames() {
        let budget = RadarAvailabilityRetryBudget(limit: 4)
        for _ in 0..<4 { XCTAssertTrue(budget.claim(referenceTime: reference, reloadRevision: 1, now: reference)) }
        for _ in 0..<32 { XCTAssertFalse(budget.claim(referenceTime: reference, reloadRevision: 1, now: reference)) }
        XCTAssertTrue(budget.claim(referenceTime: reference, reloadRevision: 2, now: reference), "Explicit refresh has its own capped retry allowance")
        XCTAssertTrue(budget.claim(referenceTime: reference.addingTimeInterval(-300), reloadRevision: 1, now: reference), "A single correctly-labelled fallback run has a separate capped allowance")
    }

    func testViewportWithoutNewRequestsBecomesIdleWithoutInventingCacheSuccess() {
        let tracker = RadarLoadTracker(date: reference, referenceTime: reference, reloadRevision: 0, notify: { _ in })
        let state = tracker.snapshot
        XCTAssertFalse(state.isSettled)
        tracker.endViewportDemand(contextID: UUID())
        XCTAssertFalse(tracker.snapshot.isViewportIdle)
        tracker.endViewportDemand(contextID: state.contextID)
        XCTAssertTrue(tracker.snapshot.isSettled)
        XCTAssertEqual(tracker.snapshot.succeeded, 0)
        XCTAssertEqual(tracker.snapshot.cacheHits, 0)
        let tile = URL(string: "https://example.invalid/later-request")!
        _ = tracker.began(tile)
        XCTAssertFalse(tracker.snapshot.isSettled, "Late genuine requests restart loading")
    }

    func testStoreUsesAtMostOneCorrectlyLabelledRadarFallbackPerRefresh() async throws {
        let counter = RequestCounter(fixture: try fixture())
        let now = reference
        let store = WeatherStore(client: DWDClient(transport: { try await counter.respond(to: $0) }, clock: { now }), backend: Self.unreachableBackend)
        await store.refresh()
        var failed = RadarLoadState(contextID: UUID(), frameDate: reference, referenceTime: reference,
                                    reloadRevision: store.radarReloadRevision)
        failed.requested = 1
        failed.failed = 1
        failed.runUnavailable = 1
        store.acceptRadarLoadState(failed)
        for _ in 0..<100 where store.isRadarLoading { await Task.yield() }
        XCTAssertEqual(store.timeline?.referenceTime, reference.addingTimeInterval(-300))
        XCTAssertEqual(store.forecast?.referenceTime, reference, "Point forecast keeps its own real source run")
        XCTAssertNotNil(store.radarNotice)
        failed = RadarLoadState(contextID: UUID(), frameDate: reference.addingTimeInterval(-300),
                                referenceTime: reference.addingTimeInterval(-300), reloadRevision: store.radarReloadRevision)
        failed.requested = 1
        failed.failed = 1
        failed.runUnavailable = 1
        store.acceptRadarLoadState(failed)
        XCTAssertFalse(store.isRadarLoading, "No cascading fallback through every old run")
    }

    func testPersistentXMLTileErrorIsBoundedAndNextRequestCanRecover() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RadarTestURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let png = Self.validRadarPNG
        RadarTestURLProtocol.responses.configure(png: png, alwaysUnavailable: true)
        let overlay = RadarTileOverlay(date: reference.addingTimeInterval(124), referenceTime: reference, reloadRevision: 124,
                                       session: session, retryDelay: { _ in 0.01 }, onLoadState: { _ in })
        let path = MKTileOverlayPath(x: 137, y: 83, z: 8, contentScaleFactor: 1)
        let unavailable = expectation(description: "Persistent XML ends after two retries")
        overlay.loadTile(at: path) { data, error in
            XCTAssertNil(data)
            XCTAssertEqual(error as? DWDDataError, .runUnavailable)
            unavailable.fulfill()
        }
        await fulfillment(of: [unavailable], timeout: 3)
        XCTAssertEqual(RadarTestURLProtocol.responses.count, 3, "One original plus two jittered retries")
        RadarTestURLProtocol.responses.configure(png: png)
        let recovered = expectation(description: "Explicit refresh can recover")
        _ = overlay.beginViewport(reloadRevision: 1124)
        overlay.loadTile(at: path) { data, error in
            XCTAssertNil(error)
            XCTAssertEqual(data, png)
            recovered.fulfill()
        }
        await fulfillment(of: [recovered], timeout: 3)
        XCTAssertEqual(RadarTestURLProtocol.responses.count, 2, "Negative XML never became a memory hit")
    }

    func testFailedTileRepeatsStaySettledAcrossViewportsAndRefreshReleasesNetwork() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RadarTestURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        RadarTestURLProtocol.responses.configure(png: Self.validRadarPNG, alwaysUnavailable: true)
        let trackerStates = LockedRadarStates()
        var overlay = RadarTileOverlay(date: reference.addingTimeInterval(812), referenceTime: reference,
                                       reloadRevision: 812, session: session, retryDelay: { _ in 0.01 }, onLoadState: { trackerStates.append($0) })
        let path = MKTileOverlayPath(x: 137, y: 83, z: 8, contentScaleFactor: 1)
        for index in 0..<8 {
            if index == 4 { _ = overlay.beginViewport(reloadRevision: 812) }
            if index == 6 {
                overlay = RadarTileOverlay(date: reference.addingTimeInterval(812), referenceTime: reference,
                                           reloadRevision: 812, session: session, retryDelay: { _ in 0.01 }, onLoadState: { trackerStates.append($0) })
            }
            let finished = expectation(description: "Bounded repeat \(index)")
            overlay.loadTile(at: path) { data, error in
                XCTAssertNil(data)
                XCTAssertEqual(error as? DWDDataError, .runUnavailable)
                finished.fulfill()
            }
            await fulfillment(of: [finished], timeout: 3)
        }
        XCTAssertEqual(RadarTestURLProtocol.responses.count, 3, "One original plus two permitted dimension retries, never eight originals")
        for _ in 0..<10 { await Task.yield() }
        XCTAssertEqual(trackerStates.last?.pending, 0)
        XCTAssertEqual(trackerStates.last?.failed, 1)
        RadarTestURLProtocol.responses.configure(png: Self.validRadarPNG)
        _ = overlay.beginViewport(reloadRevision: 1812)
        let refreshed = expectation(description: "Explicit refresh releases failed key")
        overlay.loadTile(at: path) { data, error in
            XCTAssertNil(error)
            XCTAssertEqual(data, Self.validRadarPNG)
            refreshed.fulfill()
        }
        await fulfillment(of: [refreshed], timeout: 3)
        XCTAssertEqual(RadarTestURLProtocol.responses.count, 2)
    }

    func testFailedTileRegistrySeparatesKeysAndDoesNotStampCancellation() {
        let failures = RadarTileFailures()
        let first = URL(string: "https://example.invalid/run/frame/tile")!
        let other = URL(string: "https://example.invalid/other-run/frame/tile")!
        failures.record(URLError(.cancelled), for: first, reloadRevision: 1, now: reference)
        XCTAssertNil(failures.error(for: first, reloadRevision: 1, now: reference))
        failures.record(CancellationError(), for: first, reloadRevision: 1, now: reference)
        XCTAssertNil(failures.error(for: first, reloadRevision: 1, now: reference))
        failures.record(URLError(.timedOut), for: first, reloadRevision: 1, now: reference)
        XCTAssertEqual((failures.error(for: first, reloadRevision: 1, now: reference) as? URLError)?.code, .timedOut)
        XCTAssertNil(failures.error(for: first, reloadRevision: 2, now: reference))
        XCTAssertNil(failures.error(for: other, reloadRevision: 1, now: reference))
        XCTAssertNil(failures.error(for: first, reloadRevision: 1, now: reference.addingTimeInterval(1200)))
    }

    nonisolated private static var validRadarPNG: Data {
        // A complete 1x1 PNG, not just its signature.
        Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=")!
    }

    func testRadarImageRequiresDecodedCompletePNG() throws {
        XCTAssertEqual(try DWDResponse.radarImage(from: Self.validRadarPNG), Self.validRadarPNG)
        XCTAssertThrowsError(try DWDResponse.radarImage(from: Data([137, 80, 78, 71, 13, 10, 26, 10, 0])))
        XCTAssertThrowsError(try DWDResponse.radarImage(from: Self.validRadarPNG.prefix(45)))
        var corrupt = Self.validRadarPNG
        corrupt.replaceSubrange(41..<50, with: repeatElement(UInt8(0), count: 9))
        XCTAssertThrowsError(try DWDResponse.radarImage(from: corrupt))
    }

    func testFailedFrameStopsPlaybackWithoutBlockingIdleOrValidFrames() {
        var state = RadarLoadState(contextID: UUID(), frameDate: reference, referenceTime: reference, reloadRevision: 0)
        state.isViewportIdle = true
        XCTAssertFalse(state.shouldStopPlayback, "No demand/cancellation is not a source failure")
        state.requested = 2
        state.failed = 2
        XCTAssertTrue(state.shouldStopPlayback, "Offline, HTTP and image failures stop fan-out too")
        state.pending = 1
        XCTAssertFalse(state.shouldStopPlayback, "Wait for the remaining request")
        state.pending = 0
        state.succeeded = 1
        XCTAssertFalse(state.shouldStopPlayback, "Partially valid frames may still animate")
    }

    func testInvalidPNGNeverBecomesMemoryCacheHit() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RadarTestURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        RadarTestURLProtocol.responses.configure(png: Data([137, 80, 78, 71, 13, 10, 26, 10, 0]))
        let overlay = RadarTileOverlay(date: reference.addingTimeInterval(129), referenceTime: reference, reloadRevision: 129,
                                       session: session, retryDelay: { _ in 0.01 }, onLoadState: { _ in })
        let path = MKTileOverlayPath(x: 137, y: 83, z: 8, contentScaleFactor: 1)
        let invalid = expectation(description: "Pseudo PNG rejected")
        overlay.loadTile(at: path) { data, error in
            XCTAssertNil(data)
            XCTAssertEqual(error as? DWDDataError, .invalidResponse)
            invalid.fulfill()
        }
        await fulfillment(of: [invalid], timeout: 3)
        RadarTestURLProtocol.responses.configure(png: Self.validRadarPNG)
        let recovered = expectation(description: "A real PNG can recover after explicit refresh without a poisoned cache")
        _ = overlay.beginViewport(reloadRevision: 1129)
        overlay.loadTile(at: path) { data, error in
            XCTAssertNil(error)
            XCTAssertEqual(data, Self.validRadarPNG)
            recovered.fulfill()
        }
        await fulfillment(of: [recovered], timeout: 3)
        XCTAssertEqual(RadarTestURLProtocol.responses.count, 2, "Rejected image was never cached")
    }

    func testHTTP200ServiceExceptionsAreNotImagesOrForecasts() throws {
        let xml = Data("<ServiceExceptionReport><ServiceException code=\"InvalidDimensionValue\">not ready</ServiceException></ServiceExceptionReport>".utf8)
        XCTAssertEqual(DWDResponse.serviceError(in: xml), .runUnavailable)
        XCTAssertThrowsError(try DWDResponse.radarImage(from: xml)) {
            XCTAssertEqual($0 as? DWDDataError, .runUnavailable)
        }
        XCTAssertThrowsError(try DWDResponse.forecast(from: xml, expectedReference: reference, now: reference)) {
            XCTAssertEqual($0 as? DWDDataError, .runUnavailable)
        }
        XCTAssertThrowsError(try DWDResponse.radarImage(from: Data("bad image".utf8)))
    }

    func testDimensionRetryIsBoundedAndPointErrorNeverBecomesDryForecast() async throws {
        let fixture = try fixture()
        let transport = DimensionTransport(fixture: fixture, alwaysUnavailable: false)
        let now = reference
        let client = DWDClient(transport: { try await transport.respond($0) }, clock: { now }, retryDelay: { _ in 0 })
        let value = try await client.forecast(at: WeatherCoordinate(latitude: 53, longitude: 10))
        XCTAssertEqual(value.samples.count, 25)
        let count = await transport.pointCount
        XCTAssertEqual(count, 2)
        let unavailable = DimensionTransport(fixture: fixture, alwaysUnavailable: true)
        let failed = DWDClient(transport: { try await unavailable.respond($0) }, clock: { now }, retryDelay: { _ in 0 })
        do { _ = try await failed.forecast(at: WeatherCoordinate(latitude: 53, longitude: 10)); XCTFail("Invalid dimension accepted") }
        catch { XCTAssertEqual(error as? DWDDataError, .runUnavailable) }
        let failureCount = await unavailable.pointCount
        XCTAssertEqual(failureCount, 3, "Three attempts in total, never more")
    }

    func testPreviousRadarRunRetainsActualReferenceAndFreshnessBoundary() async throws {
        let counter = RequestCounter(fixture: try fixture())
        let now = reference
        let client = DWDClient(transport: { try await counter.respond(to: $0) }, clock: { now })
        let value = try await client.radarTimeline(before: reference)
        XCTAssertEqual(value.referenceTime, reference.addingTimeInterval(-300))
        XCTAssertTrue(value.dates.contains(value.referenceTime))
        do { _ = try await client.radarTimeline(before: reference.addingTimeInterval(-300)); XCTFail("Invented prior run") }
        catch { XCTAssertEqual(error as? DWDDataError, .staleData) }
    }

    func testRadarStateIgnoresOldViewportErrorsAndCountsOnlyActualResponseBytes() {
        let tracker = RadarLoadTracker(date: reference, referenceTime: reference, reloadRevision: 0, notify: { _ in })
        let tile = URL(string: "https://example.invalid/tile")!
        let old = tracker.began(tile)
        tracker.received(100, for: tile)
        tracker.finished(tile, contextID: old, error: DWDDataError.runUnavailable)
        XCTAssertEqual(tracker.snapshot.failed, 1)
        XCTAssertEqual(tracker.snapshot.receivedBodyBytes, 100)
        let current = tracker.reset(reloadRevision: 1)
        _ = tracker.began(tile)
        tracker.finished(tile, contextID: old, error: DWDDataError.runUnavailable)
        XCTAssertEqual(tracker.snapshot.failed, 0)
        XCTAssertEqual(tracker.snapshot.pending, 1)
        tracker.finished(tile, contextID: current.contextID, error: nil, cached: true)
        XCTAssertEqual(tracker.snapshot.succeeded, 1)
        XCTAssertEqual(tracker.snapshot.cacheHits, 1)
        XCTAssertEqual(tracker.snapshot.receivedBodyBytes, 0)
        XCTAssertTrue(tracker.snapshot.isSettled)
        XCTAssertTrue(tracker.snapshot.hasUnknownVisibleTileTotal)
    }

    func testRadarStateSuccessfulRetryClearsFailureAndObsoleteCancellationIsNotError() {
        let tracker = RadarLoadTracker(date: reference, referenceTime: reference, reloadRevision: 0, notify: { _ in })
        let tile = URL(string: "https://example.invalid/tile")!
        let context = tracker.began(tile)
        tracker.finished(tile, contextID: context, error: DWDDataError.runUnavailable)
        XCTAssertEqual(tracker.snapshot.runUnavailable, 1)
        _ = tracker.began(tile)
        XCTAssertEqual(tracker.snapshot.pending, 0, "Automatic repeat preserves settled failure")
        let refreshed = tracker.reset(reloadRevision: 1)
        _ = tracker.began(tile)
        tracker.finished(tile, contextID: refreshed.contextID, error: nil)
        XCTAssertEqual(tracker.snapshot.failed, 0)
        XCTAssertEqual(tracker.snapshot.succeeded, 1)
        let other = URL(string: "https://example.invalid/other")!
        _ = tracker.began(other)
        tracker.finished(other, contextID: refreshed.contextID, error: URLError(.cancelled))
        XCTAssertEqual(tracker.snapshot.failed, 0)
        XCTAssertEqual(tracker.snapshot.requested, 1)
    }

    func testTileHTTP200XMLRetriesOnceAndNeverPoisonsMemoryCache() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RadarTestURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let png = Self.validRadarPNG
        RadarTestURLProtocol.responses.configure(png: png)
        let overlay = RadarTileOverlay(date: reference.addingTimeInterval(123), referenceTime: reference, reloadRevision: 123,
                                       session: session, retryDelay: { _ in 0.01 }, onLoadState: { _ in })
        let path = MKTileOverlayPath(x: 137, y: 83, z: 8, contentScaleFactor: 1)
        let first = expectation(description: "XML then valid PNG")
        overlay.loadTile(at: path) { data, error in
            XCTAssertNil(error)
            XCTAssertEqual(data, png)
            first.fulfill()
        }
        await fulfillment(of: [first], timeout: 3)
        XCTAssertEqual(RadarTestURLProtocol.responses.count, 2)
        let cached = expectation(description: "Valid PNG cached")
        overlay.loadTile(at: path) { data, error in
            XCTAssertNil(error)
            XCTAssertEqual(data, png)
            cached.fulfill()
        }
        await fulfillment(of: [cached], timeout: 3)
        XCTAssertEqual(RadarTestURLProtocol.responses.count, 2)
    }

}

private actor RequestCounter {
    let fixture: Data
    var count = 0
    init(fixture: Data) { self.fixture = fixture }

    func respond(to request: URLRequest) throws -> (Data, HTTPURLResponse) {
        count += 1
        let url = request.url!
        let data = url.host == "opendata.dwd.de"
            ? Data("composite_rv_20261028_1510.tar composite_rv_20261028_1515.tar".utf8)
            : fixture
        return (data, HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }
}


private final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var date: Date
    init(_ date: Date) { self.date = date }
    var now: Date { lock.withLock { date } }
    func advance(_ seconds: TimeInterval) { lock.withLock { date = date.addingTimeInterval(seconds) } }
}

private final class LockedResults: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [Error?] = []
    var errors: [Error?] { lock.withLock { values } }
    func append(_ error: Error?) { lock.withLock { values.append(error) } }
}

private actor SuspendedPointTransport {
    let fixture: Data
    var counts = (index: 0, point: 0)
    private var started = false
    private var observers: [CheckedContinuation<Void, Never>] = []
    private var responses: [CheckedContinuation<Void, Never>] = []
    private var released = false
    init(fixture: Data) { self.fixture = fixture }

    func waitForPoint() async {
        if started { return }
        await withCheckedContinuation { observers.append($0) }
    }

    func releasePoints() {
        released = true
        let pending = responses
        responses.removeAll()
        pending.forEach { $0.resume() }
    }

    func respond(to request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let url = request.url!
        let data: Data
        if url.host == "opendata.dwd.de" {
            counts.index += 1
            data = Data("composite_rv_20261028_1510.tar composite_rv_20261028_1515.tar".utf8)
        } else {
            counts.point += 1
            started = true
            let pending = observers
            observers.removeAll()
            pending.forEach { $0.resume() }
            if !released { await withCheckedContinuation { responses.append($0) } }
            data = fixture
        }
        return (data, HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }
}

private actor DimensionTransport {
    let fixture: Data
    let alwaysUnavailable: Bool
    var pointCount = 0
    init(fixture: Data, alwaysUnavailable: Bool) {
        self.fixture = fixture
        self.alwaysUnavailable = alwaysUnavailable
    }
    func respond(_ request: URLRequest) throws -> (Data, HTTPURLResponse) {
        let url = request.url!
        let data: Data
        if url.host == "opendata.dwd.de" {
            data = Data("composite_rv_20261028_1510.tar composite_rv_20261028_1515.tar".utf8)
        } else {
            pointCount += 1
            data = pointCount == 1 || alwaysUnavailable
                ? Data("<ServiceExceptionReport><ServiceException code=\"InvalidDimensionValue\">not ready</ServiceException></ServiceExceptionReport>".utf8)
                : fixture
        }
        return (data, HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }
}

private final class RadarTestURLProtocol: URLProtocol, @unchecked Sendable {
    static let responses = RadarResponses()
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let data = Self.responses.next()
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: 200,
                                                            httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

private final class RadarResponses: @unchecked Sendable {
    private let lock = NSLock()
    private var body = Data()
    private var calls = 0
    private var alwaysUnavailable = false
    var count: Int { lock.withLock { calls } }
    func configure(png: Data, alwaysUnavailable: Bool = false) {
        lock.withLock { body = png; calls = 0; self.alwaysUnavailable = alwaysUnavailable }
    }
    func next() -> Data {
        lock.withLock {
            calls += 1
            return calls == 1 || alwaysUnavailable ? Data("<ServiceExceptionReport><ServiceException code=\"InvalidDimensionValue\">not ready</ServiceException></ServiceExceptionReport>".utf8) : body
        }
    }
}

private final class LockedRadarStates: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [RadarLoadState] = []
    func append(_ state: RadarLoadState) { lock.withLock { values.append(state) } }
    var last: RadarLoadState? { lock.withLock { values.last } }
}
