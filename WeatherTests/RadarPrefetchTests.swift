import MapKit
import XCTest
@testable import Weather

@MainActor
final class RadarPrefetchTests: XCTestCase {
    private let reference = DWDRequest.date("2026-10-28T15:15:00Z")!
    private var png: Data {
        Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=")!
    }
    private func key(_ index: Int) -> URL {
        DWDRequest.tileURL(x: 137 + index, y: 83, z: 8, date: reference, referenceTime: reference)
    }

    override func setUp() async throws {
        RadarPrefetcher.resetSharedStateForTesting()
    }
    override func tearDown() async throws {
        RadarPrefetcher.resetSharedStateForTesting()
    }

    func testPrefetchExpandsLeftThenRightFromSelectedFrame() {
        XCTAssertEqual(RadarPrefetchPolicy.order(selected: 3, count: 7), [3, 2, 4, 1, 5, 0, 6])
        XCTAssertEqual(RadarPrefetchPolicy.order(selected: 2, count: 6), [2, 1, 3, 0, 4, 5])
    }

    func testPrefetchOrderHandlesTimelineEdgesAndInvalidSelection() {
        XCTAssertEqual(RadarPrefetchPolicy.order(selected: 0, count: 4), [0, 1, 2, 3])
        XCTAssertEqual(RadarPrefetchPolicy.order(selected: 3, count: 4), [3, 2, 1, 0])
        XCTAssertEqual(RadarPrefetchPolicy.order(selected: 0, count: 1), [0])
        XCTAssertEqual(RadarPrefetchPolicy.order(selected: 0, count: 0), [])
        XCTAssertEqual(RadarPrefetchPolicy.order(selected: -1, count: 4), [])
        XCTAssertEqual(RadarPrefetchPolicy.order(selected: 4, count: 4), [])
    }

    func testPrefetchAllowsWiFiAndCellularUnlessDataSavingIsEnabled() {
        for expensive in [false, true] { // Ordinary Wi-Fi, then cellular/hotspot.
            XCTAssertTrue(RadarPrefetchPolicy.isAllowed(isActive: true, lowPower: false,
                                                       constrained: false, expensive: expensive))
            XCTAssertFalse(RadarPrefetchPolicy.isAllowed(isActive: true, lowPower: false,
                                                        constrained: true, expensive: expensive))
        }
    }

    func testPrefetchStillStopsForInactiveOrLowPowerDeviceOnEveryNetwork() {
        for expensive in [false, true] {
            XCTAssertFalse(RadarPrefetchPolicy.isAllowed(isActive: false, lowPower: false,
                                                        constrained: false, expensive: expensive))
            XCTAssertFalse(RadarPrefetchPolicy.isAllowed(isActive: true, lowPower: true,
                                                        constrained: false, expensive: expensive))
        }
    }

    func testMemoryCacheUsesDecimal50MBDefaultAndRejectsOversizedEntry() {
        let cache = TileMemoryCache()
        XCTAssertEqual(cache.byteCount, 0)
        let oversized = Data(repeating: 1, count: 50_000_001)
        cache.insert(oversized, for: key(0))
        XCTAssertEqual(cache.byteCount, 0)
        XCTAssertNil(cache.data(for: key(0)))
        XCTAssertEqual(cache.count, 0)
    }

    func testMemoryCacheEvictsLeastRecentlyUsedAndStaysWithinHardCap() {
        let cache = TileMemoryCache(limit: png.count * 2)
        cache.insert(png, for: key(0))
        cache.insert(png, for: key(1))
        XCTAssertEqual(cache.data(for: key(0)), png) // Touch zero, making one oldest.
        cache.insert(png, for: key(2))
        XCTAssertNil(cache.data(for: key(1)))
        XCTAssertEqual(cache.data(for: key(0)), png)
        XCTAssertEqual(cache.data(for: key(2)), png)
        XCTAssertEqual(cache.byteCount, png.count * 2)
        XCTAssertEqual(cache.count, 2)
        for index in 3..<100 {
            cache.insert(png, for: key(index))
            XCTAssertLessThanOrEqual(cache.byteCount, png.count * 2)
            XCTAssertLessThanOrEqual(cache.count, 2)
        }
    }

    func testMemoryCacheReplacementDoesNotDoubleCountBytes() {
        let cache = TileMemoryCache(limit: png.count * 2)
        cache.insert(png, for: key(0))
        cache.insert(png, for: key(0))
        XCTAssertEqual(cache.byteCount, png.count)
        XCTAssertEqual(cache.count, 1)
        cache.insert(png, for: key(1))
        XCTAssertEqual(cache.byteCount, png.count * 2)
    }

    func testTileCacheSeparatesRunFrameZoomAndCoverageButReusesIdenticalKeys() {
        let cache = TileMemoryCache()
        let original = key(0)
        cache.insert(png, for: original)
        XCTAssertEqual(cache.data(for: key(0)), png)
        XCTAssertNil(cache.data(for: DWDRequest.tileURL(x: 137, y: 83, z: 8, date: reference,
                                                       referenceTime: reference.addingTimeInterval(-300))))
        XCTAssertNil(cache.data(for: DWDRequest.tileURL(x: 137, y: 83, z: 8,
                                                       date: reference.addingTimeInterval(300), referenceTime: reference)))
        XCTAssertNil(cache.data(for: DWDRequest.tileURL(x: 137, y: 83, z: 9, date: reference, referenceTime: reference)))
        XCTAssertNil(cache.data(for: key(1)))
    }

    func testRequestAndByteBudgetsPauseUntilNextWindow() {
        let budget = RadarPrefetchBudget(maxRequests: 2, interval: 60, maxBytes: 100)
        XCTAssertTrue(budget.claim(now: reference))
        XCTAssertTrue(budget.claim(now: reference.addingTimeInterval(1)))
        XCTAssertFalse(budget.claim(now: reference.addingTimeInterval(2)))
        XCTAssertEqual(budget.retryAfter(now: reference.addingTimeInterval(2)), 58)
        XCTAssertTrue(budget.claim(now: reference.addingTimeInterval(60)))
        budget.received(100)
        XCTAssertFalse(budget.claim(now: reference.addingTimeInterval(61)))
        XCTAssertEqual(budget.retryAfter(now: reference.addingTimeInterval(61)), 59)
        XCTAssertTrue(budget.claim(now: reference.addingTimeInterval(120)))
        budget.received(-100)
        XCTAssertTrue(budget.claim(now: reference.addingTimeInterval(121)))
    }

    func testMatchingDemandSurvivesSpeculativeSubscriberCancellation() async throws {
        let session = makeSession()
        defer { session.invalidateAndCancel() }
        let flight = RadarPrefetchFlight()
        let started = expectation(description: "Speculative transport started")
        PrefetchGateProtocol.gate.reset(started: started)
        let url = key(104)
        let speculative = Task { await flight.load(url: url, session: session, received: { _ in }) }
        await fulfillment(of: [started], timeout: 2)
        let foreground = expectation(description: "Promoted foreground receives shared PNG")
        let expectedPNG = png
        XCTAssertTrue(flight.join(url: url) { response in
            RadarNetworkPriority.shared.endDemand()
            XCTAssertNil(response.error)
            XCTAssertEqual(response.data, expectedPNG)
            foreground.fulfill()
        })
        speculative.cancel()
        let cancelled = await speculative.value
        XCTAssertEqual((cancelled.error as? URLError)?.code, .cancelled)
        XCTAssertEqual(PrefetchGateProtocol.gate.starts, 1)
        XCTAssertEqual(PrefetchGateProtocol.gate.stops, 0, "Demand owns the promoted transport")
        PrefetchGateProtocol.gate.finish(data: png)
        await fulfillment(of: [foreground], timeout: 2)
        XCTAssertEqual(PrefetchGateProtocol.gate.starts, 1, "Promotion must not start a second URLSession request")
    }

    func testUnrelatedDemandPreemptsSpeculativeWorkAndDoesNotJoinAnotherKey() async throws {
        let session = makeSession()
        defer { session.invalidateAndCancel() }
        let flight = RadarPrefetchFlight()
        let started = expectation(description: "Speculative transport started")
        PrefetchGateProtocol.gate.reset(started: started)
        let speculative = Task { await flight.load(url: key(105), session: session, received: { _ in }) }
        await fulfillment(of: [started], timeout: 2)
        XCTAssertFalse(flight.join(url: key(106), result: { _ in XCTFail("Unrelated key joined") }))
        XCTAssertTrue(RadarNetworkPriority.shared.register { speculative.cancel() })
        RadarNetworkPriority.shared.beginDemand()
        let cancelled = await speculative.value
        RadarNetworkPriority.shared.endDemand()
        RadarNetworkPriority.shared.clear()
        XCTAssertEqual((cancelled.error as? URLError)?.code, .cancelled)
        XCTAssertEqual(PrefetchGateProtocol.gate.starts, 1)
    }

    func testPrefetchedHistoricalNeighborBecomesForegroundCacheHitWithoutAnotherRequest() async throws {
        let session = makeSession()
        defer { session.invalidateAndCancel() }
        let now = Date()
        let historical = now.addingTimeInterval(-3600)
        let path = RadarTileCoordinate(x: 139, y: 84, z: 8)
        let selectedURL = DWDRequest.tileURL(x: path.x, y: path.y, z: path.z, date: now, referenceTime: now)
        let neighborURL = DWDRequest.tileURL(x: path.x, y: path.y, z: path.z, date: historical, referenceTime: historical)
        RadarTileOverlay.cache.insert(png, for: selectedURL)
        let started = expectation(description: "Uncached historical neighbor starts")
        PrefetchGateProtocol.gate.reset(started: started)
        var state = RadarLoadState(contextID: UUID(), frameDate: now, referenceTime: now, reloadRevision: 2401)
        state.requested = 1; state.succeeded = 1; state.isViewportIdle = true
        let prefetch = RadarPrefetcher(session: session, networkAllowed: true, quiescence: .zero, spacing: .zero, priority: RadarNetworkPriority())
        defer { prefetch.cancel() }
        let bytesReceived = expectation(description: "Prefetch bytes counted separately")
        let expectedPNG = png
        let update = {
            prefetch.update(timeline: RadarTimeline(referenceTime: now, dates: [historical, now]), selected: now,
                            paths: [path], state: state, active: true, revision: 2401,
                            cache: RadarTileOverlay.cache) { count in
                XCTAssertEqual(count, expectedPNG.count)
                bytesReceived.fulfill()
            }
        }
        update()
        await fulfillment(of: [started], timeout: 2)
        update() // Identical UI updates must leave the in-flight sweep intact.
        PrefetchGateProtocol.gate.finish(data: expectedPNG)
        await fulfillment(of: [bytesReceived], timeout: 2)
        for _ in 0..<1000 {
            if RadarTileOverlay.cache.data(for: neighborURL) != nil { break }
            await Task.yield()
        }
        XCTAssertEqual(RadarTileOverlay.cache.data(for: neighborURL), expectedPNG)
        let visibleSettled = expectation(description: "Foreground state records cache hit without download")
        let overlay = RadarTileOverlay(date: historical, referenceTime: historical, reloadRevision: 2401,
                                       session: session, onLoadState: { state in
            if state.cacheHits == 1 {
                XCTAssertEqual(state.pending, 0)
                XCTAssertEqual(state.failed, 0)
                XCTAssertEqual(state.receivedBodyBytes, 0)
                visibleSettled.fulfill()
            }
        })
        let loaded = expectation(description: "Foreground uses prewarmed image")
        overlay.loadTile(at: MKTileOverlayPath(x: path.x, y: path.y, z: path.z, contentScaleFactor: 1)) { data, error in
            XCTAssertNil(error)
            XCTAssertEqual(data, expectedPNG)
            loaded.fulfill()
        }
        await fulfillment(of: [loaded, visibleSettled], timeout: 2)
        XCTAssertEqual(PrefetchGateProtocol.gate.starts, 1, "Neighbor selection starts zero further transports")
        XCTAssertNil(RadarTileOverlay.cache.data(for: DWDRequest.tileURL(x: path.x, y: path.y, z: path.z,
                                                                        date: historical, referenceTime: now)),
                     "Historical analyses must not be mislabeled as current-run forecasts")
    }

    func testFrameHandoffRetainsTransportUntilNewOverlayDemandsMatchingTile() async throws {
        let session = makeSession()
        defer { session.invalidateAndCancel(); RadarPrefetchFlight.shared.cancelHandoff() }
        let now = Date()
        let historical = now.addingTimeInterval(-300)
        let path = MKTileOverlayPath(x: 147, y: 87, z: 8, contentScaleFactor: 1)
        let url = DWDRequest.tileURL(x: path.x, y: path.y, z: path.z, date: historical, referenceTime: historical)
        let started = expectation(description: "Neighbor prefetch transport started")
        PrefetchGateProtocol.gate.reset(started: started)
        let speculative = Task { await RadarPrefetchFlight.shared.load(url: url, session: session, received: { _ in }) }
        await fulfillment(of: [started], timeout: 2)
        // This is the frame-replacement order used by RadarMap: reserve the new
        // frame, detach its scheduler, then let the replacement overlay request it.
        RadarPrefetchFlight.shared.prepareHandoff(date: historical, referenceTime: historical)
        speculative.cancel()
        _ = await speculative.value
        XCTAssertEqual(PrefetchGateProtocol.gate.stops, 0)
        let loaded = expectation(description: "Replacement overlay receives reserved transport")
        let expectedPNG = png
        let overlay = RadarTileOverlay(date: historical, referenceTime: historical, reloadRevision: 2410,
                                       session: session, onLoadState: { _ in })
        overlay.loadTile(at: path) { data, error in
            XCTAssertNil(error)
            XCTAssertEqual(data, expectedPNG)
            loaded.fulfill()
        }
        XCTAssertEqual(PrefetchGateProtocol.gate.starts, 1)
        PrefetchGateProtocol.gate.finish(data: expectedPNG)
        await fulfillment(of: [loaded], timeout: 2)
        XCTAssertEqual(PrefetchGateProtocol.gate.starts, 1, "Frame handoff must promote the existing transport")
    }

    func testPromotedFailureAfterSameFrameRefreshDoesNotPoisonNewRevision() async throws {
        let session = makeSession()
        defer { session.invalidateAndCancel(); RadarPrefetchFlight.shared.cancelHandoff() }
        let now = Date()
        let path = MKTileOverlayPath(x: 148, y: 87, z: 8, contentScaleFactor: 1)
        let url = DWDRequest.tileURL(x: path.x, y: path.y, z: path.z, date: now, referenceTime: now)
        let started = expectation(description: "Old revision speculative transport started")
        PrefetchGateProtocol.gate.reset(started: started)
        let speculative = Task { await RadarPrefetchFlight.shared.load(url: url, session: session, received: { _ in }) }
        await fulfillment(of: [started], timeout: 2)
        let failed = expectation(description: "Old promoted subscriber receives failure")
        let overlay = RadarTileOverlay(date: now, referenceTime: now, reloadRevision: 2411,
                                       session: session, onLoadState: { _ in })
        overlay.loadTile(at: path) { data, error in
            XCTAssertNil(data)
            XCTAssertNotNil(error)
            failed.fulfill()
        }
        _ = overlay.beginViewport(reloadRevision: 2412)
        speculative.cancel()
        _ = await speculative.value
        PrefetchGateProtocol.gate.finish(data: Data("<ServiceExceptionReport><ServiceException code=\"InvalidDimensionValue\">not ready</ServiceException></ServiceExceptionReport>".utf8))
        await fulfillment(of: [failed], timeout: 2)
        XCTAssertTrue(RadarTileOverlay.hasFailure(url: url, revision: 2411))
        XCTAssertFalse(RadarTileOverlay.hasFailure(url: url, revision: 2412), "Late promoted failures belong to their captured reload revision")
    }

    func testMultipleForegroundWaitersCountPromotedResponseBodyOnce() async throws {
        let session = makeSession()
        defer { session.invalidateAndCancel() }
        let now = Date()
        let path = MKTileOverlayPath(x: 149, y: 87, z: 8, contentScaleFactor: 1)
        let url = DWDRequest.tileURL(x: path.x, y: path.y, z: path.z, date: now, referenceTime: now)
        let started = expectation(description: "One speculative transport")
        PrefetchGateProtocol.gate.reset(started: started)
        let speculative = Task { await RadarPrefetchFlight.shared.load(url: url, session: session, received: { _ in }) }
        await fulfillment(of: [started], timeout: 2)
        var maximumBodyBytes: Int64 = 0
        let stateReceived = expectation(description: "Foreground body recorded")
        stateReceived.assertForOverFulfill = false
        let overlay = RadarTileOverlay(date: now, referenceTime: now, reloadRevision: 2413,
                                       session: session, onLoadState: { state in
            maximumBodyBytes = max(maximumBodyBytes, state.receivedBodyBytes)
            if state.receivedBodyBytes > 0 { stateReceived.fulfill() }
        })
        let loaded = expectation(description: "Both MapKit subscribers complete")
        loaded.expectedFulfillmentCount = 2
        let expectedPNG = png
        for _ in 0..<2 {
            overlay.loadTile(at: path) { data, error in
                XCTAssertNil(error)
                XCTAssertEqual(data, expectedPNG)
                loaded.fulfill()
            }
        }
        speculative.cancel()
        _ = await speculative.value
        PrefetchGateProtocol.gate.finish(data: expectedPNG)
        await fulfillment(of: [loaded, stateReceived], timeout: 2)
        for _ in 0..<50 { await Task.yield() }
        XCTAssertEqual(PrefetchGateProtocol.gate.starts, 1)
        XCTAssertEqual(maximumBodyBytes, Int64(expectedPNG.count), "Two subscribers share one response body")
    }

    func testSchedulerDoesNotStartWhileInactiveOrSelectedFramePending() async {
        let session = makeSession()
        defer { session.invalidateAndCancel() }
        let now = Date()
        let state = RadarLoadState(contextID: UUID(), frameDate: now, referenceTime: now, reloadRevision: 2402)
        let noStart = expectation(description: "No speculative request before foreground settles")
        noStart.isInverted = true
        PrefetchGateProtocol.gate.reset(started: noStart)
        let prefetch = RadarPrefetcher(session: session, networkAllowed: true, quiescence: .zero, spacing: .zero, priority: RadarNetworkPriority())
        defer { prefetch.cancel() }
        prefetch.update(timeline: RadarTimeline(referenceTime: now, dates: [now]), selected: now,
                        paths: [RadarTileCoordinate(x: 140, y: 84, z: 8)], state: state,
                        active: true, revision: 2402, cache: TileMemoryCache(), received: { _ in XCTFail("Unexpected body") })
        var settled = state
        settled.requested = 1; settled.succeeded = 1; settled.isViewportIdle = true
        prefetch.update(timeline: RadarTimeline(referenceTime: now, dates: [now]), selected: now,
                        paths: [RadarTileCoordinate(x: 140, y: 84, z: 8)], state: settled,
                        active: false, revision: 2402, cache: TileMemoryCache(), received: { _ in XCTFail("Unexpected body") })
        await fulfillment(of: [noStart], timeout: 0.15)
        XCTAssertEqual(PrefetchGateProtocol.gate.starts, 0)
    }

    func testPlanAppliesViewportCoordinatesToEverySlotIncludingUnvisitedOnes() {
        let paths = (0..<4).map { RadarTileCoordinate(x: 100 + $0, y: 50, z: 8) }
        let plan = RadarPrefetchPolicy.plan(selected: 18, count: 37, paths: paths)
        XCTAssertEqual(plan.count, 37 * 4, "Every slot receives the full observed coordinate set")
        XCTAssertEqual(Set(plan.map(\.slot)), Set(0..<37))
        XCTAssertEqual(plan.map(\.slot).prefix(12).filter { $0 == 18 }.count, 4, "Selected slot first")
        let slotOrder = stride(from: 0, to: plan.count, by: 4).map { plan[$0].slot }
        XCTAssertEqual(slotOrder, RadarPrefetchPolicy.order(selected: 18, count: 37))
        XCTAssertEqual(slotOrder.prefix(5), [18, 17, 19, 16, 20])
        XCTAssertTrue(plan.allSatisfy { paths.contains($0.path) })
        XCTAssertEqual(RadarPrefetchPolicy.plan(selected: 0, count: 0, paths: paths), [])
        XCTAssertEqual(RadarPrefetchPolicy.plan(selected: 0, count: 3, paths: []), [])
    }

    func testDefaultBudgetAllowsFullTimelineWarmupWithinHardWindowLimits() {
        let budget = RadarPrefetchBudget()
        var claims = 0
        while budget.claim(now: reference) { claims += 1 }
        XCTAssertEqual(claims, 240)
        XCTAssertEqual(budget.retryAfter(now: reference), 60)
        XCTAssertEqual(RadarPrefetchPolicy.parallelism, 3)
        // 32 coordinates x 37 slots = 1,184 requests -> 5 windows at 240 per minute.
        XCTAssertEqual(Int((1184.0 / 240.0).rounded(.up)), 5)
    }

    func testParallelismIsCappedAndCancelStopsAllWorkers() async {
        let session = makeSession()
        defer { session.invalidateAndCancel() }
        let now = Date()
        let dates = (0..<7).map { now.addingTimeInterval(Double($0 - 3) * 300) }
        var state = RadarLoadState(contextID: UUID(), frameDate: now, referenceTime: now, reloadRevision: 2404)
        state.requested = 1; state.succeeded = 1; state.isViewportIdle = true
        PrefetchGateProtocol.gate.reset()
        let prefetch = RadarPrefetcher(session: session, networkAllowed: true, quiescence: .zero, spacing: .zero, priority: RadarNetworkPriority())
        defer { prefetch.cancel() }
        let paths = [RadarTileCoordinate(x: 150, y: 90, z: 8), RadarTileCoordinate(x: 151, y: 90, z: 8)]
        prefetch.update(timeline: RadarTimeline(referenceTime: now, dates: dates), selected: dates[3], paths: paths,
                        state: state, active: true, revision: 2404, cache: TileMemoryCache(), received: { _ in })
        await waitForStarts(3)
        try? await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(PrefetchGateProtocol.gate.starts, 3, "Never more than the configured parallel transports")
        prefetch.cancel() // Location/zoom change or demand: all workers stop, no new starts.
        await waitForStops(3)
        try? await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(PrefetchGateProtocol.gate.starts, 3)
    }

    func testIsolatedTileFailureIsSkippedButRepeatedFailuresStopSweep() async {
        let session = makeSession()
        defer { session.invalidateAndCancel() }
        let now = Date()
        let dates = (0..<8).map { now.addingTimeInterval(Double($0 - 4) * 300) }
        var state = RadarLoadState(contextID: UUID(), frameDate: now, referenceTime: now, reloadRevision: 2403)
        state.requested = 1; state.succeeded = 1; state.isViewportIdle = true
        PrefetchGateProtocol.gate.reset()
        let prefetch = RadarPrefetcher(session: session, networkAllowed: true, quiescence: .zero, spacing: .zero, parallelism: 1, priority: RadarNetworkPriority(), retryDelay: { _ in 0 })
        defer { prefetch.cancel() }
        let bodyCount = Counter()
        prefetch.update(timeline: RadarTimeline(referenceTime: now, dates: dates), selected: dates[4],
                        paths: [RadarTileCoordinate(x: 141, y: 84, z: 8)], state: state, active: true,
                        revision: 2403, cache: TileMemoryCache(), received: { _ in bodyCount.increment() })
        let bad = Data("<ServiceExceptionReport><ServiceException code=\"InvalidDimensionValue\">not ready</ServiceException></ServiceExceptionReport>".utf8)
        for expected in 1...9 { // three tiles, each with three attempts
            await waitForStarts(expected)
            PrefetchGateProtocol.gate.finish(data: bad)
        }
        try? await Task.sleep(for: .milliseconds(150))
        XCTAssertEqual(PrefetchGateProtocol.gate.starts, 9, "Third consecutive failed tile (3 attempts each) ends the sweep; no flood")
        prefetch.update(timeline: RadarTimeline(referenceTime: now, dates: dates), selected: dates[4],
                        paths: [RadarTileCoordinate(x: 141, y: 84, z: 8)], state: state, active: true,
                        revision: 2403, cache: TileMemoryCache(), received: { _ in })
        try? await Task.sleep(for: .milliseconds(150))
        XCTAssertEqual(PrefetchGateProtocol.gate.starts, 9, "Cooldown blocks an identical update")
    }

    // Polling with a generous deadline instead of fixed short timeouts.
    private func waitForStarts(_ count: Int) async {
        for _ in 0..<1000 where PrefetchGateProtocol.gate.starts < count { try? await Task.sleep(for: .milliseconds(10)) }
        XCTAssertGreaterThanOrEqual(PrefetchGateProtocol.gate.starts, count)
    }
    private func waitForStops(_ count: Int) async {
        for _ in 0..<1000 where PrefetchGateProtocol.gate.stops < count { try? await Task.sleep(for: .milliseconds(10)) }
        XCTAssertGreaterThanOrEqual(PrefetchGateProtocol.gate.stops, count)
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [PrefetchGateProtocol.self]
        return URLSession(configuration: configuration)
    }

}


private final class PrefetchGateProtocol: URLProtocol, @unchecked Sendable {
    static let gate = PrefetchProtocolGate()
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() { Self.gate.start(self) }
    override func stopLoading() { Self.gate.stop() }
    func finish(data: Data) {
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: 200,
                                                            httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
}

private final class PrefetchProtocolGate: @unchecked Sendable {
    private let lock = NSLock()
    private var pending: [PrefetchGateProtocol] = []
    private var started: XCTestExpectation?
    private var startCount = 0
    private var stopCount = 0
    var starts: Int { lock.withLock { startCount } }
    var stops: Int { lock.withLock { stopCount } }
    func reset(started: XCTestExpectation? = nil) {
        lock.withLock { pending = []; self.started = started; startCount = 0; stopCount = 0 }
    }
    func start(_ request: PrefetchGateProtocol) {
        let event = lock.withLock { pending.append(request); startCount += 1; return started }
        event?.fulfill()
    }
    func expectFurtherStarts(_ event: XCTestExpectation) { lock.withLock { started = event } }
    func stop() { lock.withLock { stopCount += 1 } }
    func finish(data: Data) {
        let requests = lock.withLock { let value = pending; pending = []; return value }
        requests.forEach { $0.finish(data: data) }
    }
}

private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    func increment() { lock.withLock { value += 1 } }
}
