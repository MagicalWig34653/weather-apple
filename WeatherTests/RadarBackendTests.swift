import ImageIO
import MapKit
import XCTest
@testable import Weather

// Logic tests without network. Every test builds its own state (own caches, clients,
// loaders); nothing here touches shared singletons.
final class RadarBackendTests: XCTestCase {
    private let base = URL(string: "https://radar.example.invalid/v1/radar/")!

    private func fixtureData() throws -> Data {
        let bundle = Bundle(for: RadarBackendTests.self)
        let url = bundle.url(forResource: "radar-latest", withExtension: "json", subdirectory: "Fixtures")
            ?? bundle.url(forResource: "radar-latest", withExtension: "json")
        return try Data(contentsOf: XCTUnwrap(url))
    }

    private func manifest() throws -> RadarManifest { try RadarManifest.parse(fixtureData(), baseURL: base) }

    private func modified(_ change: (inout [String: Any]) -> Void) throws -> Data {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: fixtureData()) as? [String: Any])
        change(&object)
        return try JSONSerialization.data(withJSONObject: object)
    }

    private func slotsJSON(count: Int, start: Date, run: String = "20261030T1800Z") -> [[String: Any]] {
        (0..<count).map { index in
            let time = start.addingTimeInterval(Double(index) * 300)
            let id = Self.id(time)
            return ["time": DWDRequest.timestamp(time).replacingOccurrences(of: ".000Z", with: "Z"),
                    "kind": index == 0 ? "analysis" : "forecast", "path": "\(run)/\(id).webp"]
        }
    }

    private static func id(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd'T'HHmm'Z'"
        return formatter.string(from: date)
    }

    // MARK: Parsing and validation

    func testRealFixtureParses() throws {
        let value = try manifest()
        XCTAssertEqual(value.run, "20261030T1825Z")
        XCTAssertEqual(value.slots.count, 27)
        XCTAssertEqual(value.stepMinutes, 5)
        XCTAssertEqual(value.imageWidth, 1024)
        XCTAssertEqual(value.imageHeight, 1311)
        XCTAssertEqual(value.referenceTime, DWDRequest.date("2026-10-30T18:25:00Z"))
        XCTAssertEqual(value.slot(at: value.referenceTime)?.kind, .analysis)
        XCTAssertEqual(value.slots.last?.kind, .forecast)
        XCTAssertEqual(value.attribution, "Quelle: Deutscher Wetterdienst")
        XCTAssertTrue(value.modificationNotice.contains("Rasterdaten"))
        XCTAssertEqual(value.slots.first?.url.host, "radar.example.invalid")
        XCTAssertTrue(value.slots.allSatisfy { $0.url.path.hasPrefix("/v1/radar/") && $0.url.query == nil })
        XCTAssertEqual(value.timeline.dates.count, 27)
        XCTAssertNotNil(value.timeline.backend)
    }

    func testUnknownSchemaMissingFieldsAndEmptySlotsAreRejected() throws {
        XCTAssertThrowsError(try RadarManifest.parse(modified { $0["schema"] = 2 }, baseURL: base)) {
            XCTAssertEqual($0 as? RadarBackendError, .unsupportedSchema(2))
        }
        // A future schema may change other fields; the schema check comes first.
        XCTAssertThrowsError(try RadarManifest.parse(Data(#"{"schema":7,"x":1}"#.utf8), baseURL: base)) {
            XCTAssertEqual($0 as? RadarBackendError, .unsupportedSchema(7))
        }
        for key in ["run", "reference_time", "generated_at", "image", "slots", "attribution", "modification_notice", "step_minutes"] {
            XCTAssertThrowsError(try RadarManifest.parse(modified { $0[key] = nil }, baseURL: base), key) {
                XCTAssertEqual($0 as? RadarBackendError, .invalid)
            }
        }
        XCTAssertThrowsError(try RadarManifest.parse(modified { $0["slots"] = [] as [Any] }, baseURL: base))
        XCTAssertThrowsError(try RadarManifest.parse(Data(), baseURL: base))
        XCTAssertThrowsError(try RadarManifest.parse(Data("not json".utf8), baseURL: base))
        XCTAssertThrowsError(try RadarManifest.parse(modified { $0["attribution"] = "  " }, baseURL: base))
        XCTAssertThrowsError(try RadarManifest.parse(modified { $0["modification_notice"] = "" }, baseURL: base))
    }

    func testImageAndBoundingBoxValidation() throws {
        func image(_ change: (inout [String: Any]) -> Void) throws -> Data {
            try modified { object in
                var image = object["image"] as! [String: Any]
                change(&image)
                object["image"] = image
            }
        }
        XCTAssertThrowsError(try RadarManifest.parse(image { $0["format"] = "image/png" }, baseURL: base))
        XCTAssertThrowsError(try RadarManifest.parse(image { $0["projection"] = "EPSG:4326" }, baseURL: base))
        XCTAssertThrowsError(try RadarManifest.parse(image { $0["width"] = 0 }, baseURL: base))
        XCTAssertThrowsError(try RadarManifest.parse(image { $0["height"] = 100_000 }, baseURL: base))
        XCTAssertThrowsError(try RadarManifest.parse(image { $0["bbox"] = [1.0, 2.0, 3.0] }, baseURL: base))
        XCTAssertThrowsError(try RadarManifest.parse(image { $0["bbox"] = [10.0, 0.0, 5.0, 10.0] }, baseURL: base), "min > max")
        XCTAssertThrowsError(try RadarManifest.parse(image { $0["bbox"] = [0.0, 0.0, 9e9, 10.0] }, baseURL: base), "outside the world")
    }

    func testSlotValidationRejectsBadTimesPathsAndMissingReference() throws {
        func slots(_ change: (inout [[String: Any]]) -> Void) throws -> Data {
            try modified { object in
                var list = object["slots"] as! [[String: Any]]
                change(&list)
                object["slots"] = list
            }
        }
        XCTAssertThrowsError(try RadarManifest.parse(slots { $0[0]["path"] = "../secret.webp" }, baseURL: base))
        XCTAssertThrowsError(try RadarManifest.parse(slots { $0[0]["path"] = "https://other.example/x/y.webp" }, baseURL: base))
        XCTAssertThrowsError(try RadarManifest.parse(slots { $0[0]["path"] = "/abs/x.webp" }, baseURL: base))
        XCTAssertThrowsError(try RadarManifest.parse(slots { $0[0]["path"] = "a/b.webp?x=1" }, baseURL: base))
        XCTAssertThrowsError(try RadarManifest.parse(slots { $0[0]["kind"] = "nowcast" }, baseURL: base))
        XCTAssertThrowsError(try RadarManifest.parse(slots { $0[0]["time"] = "yesterday" }, baseURL: base))
        XCTAssertThrowsError(try RadarManifest.parse(slots { $0.swapAt(0, 1) }, baseURL: base), "unsorted")
        XCTAssertThrowsError(try RadarManifest.parse(slots { $0[1] = $0[0] }, baseURL: base), "duplicate times")
        XCTAssertThrowsError(try RadarManifest.parse(slots { $0 = Array($0.prefix(2)) }, baseURL: base), "reference slot missing")
    }

    func testVariableSlotCountsAreAccepted() throws {
        let start = DWDRequest.date("2026-10-30T18:00:00Z")!
        for count in [1, 13, 26, 37] {
            let data = try modified { object in
                object["slots"] = slotsJSON(count: count, start: start)
                object["reference_time"] = "2026-10-30T18:00:00Z"
                object["run"] = "20261030T1800Z"
            }
            let value = try RadarManifest.parse(data, baseURL: base)
            XCTAssertEqual(value.slots.count, count)
            XCTAssertEqual(value.timeline.dates.count, count)
        }
    }

    // MARK: Freshness

    func testFreshnessUsesRunAgeWithTwentyMinuteLimit() throws {
        let value = try manifest()
        let reference = value.referenceTime
        XCTAssertTrue(value.isFresh(at: reference.addingTimeInterval(5 * 60)))
        XCTAssertTrue(value.isFresh(at: reference.addingTimeInterval(20 * 60)))
        XCTAssertFalse(value.isFresh(at: reference.addingTimeInterval(20 * 60 + 1)))
        XCTAssertFalse(value.isFresh(at: reference.addingTimeInterval(-120)), "Run from the future")
    }

    // MARK: Client: fallback decision and ETag

    private final class Script: @unchecked Sendable {
        struct Reply { var status: Int; var body: Data = Data(); var etag: String? }
        private let lock = NSLock()
        private var replies: [Reply]
        private(set) var requests: [URLRequest] = []
        init(_ replies: [Reply]) { self.replies = replies }
        func next(_ request: URLRequest) throws -> (Data, HTTPURLResponse) {
            let reply: Reply = lock.withLock {
                requests.append(request)
                return replies.count > 1 ? replies.removeFirst() : replies[0]
            }
            if reply.status == -1 { throw URLError(.timedOut) }
            var headers: [String: String] = [:]
            if let etag = reply.etag { headers["ETag"] = etag }
            return (reply.body, HTTPURLResponse(url: request.url!, statusCode: reply.status, httpVersion: nil, headerFields: headers)!)
        }
    }

    private func client(_ script: Script, now: Date) -> RadarBackendClient {
        RadarBackendClient(baseURL: base, transport: { try script.next($0) }, clock: { now })
    }

    func testFreshManifestUsesBackendAndSendsNoIdentifyingRequestData() async throws {
        let data = try fixtureData()
        let script = Script([.init(status: 200, body: data, etag: "\"abc\"")])
        let reference = try manifest().generatedAt
        let outcome = await client(script, now: reference.addingTimeInterval(60)).latest()
        guard case .fresh(let value, let changed) = outcome else { return XCTFail("\(outcome)") }
        XCTAssertTrue(changed)
        XCTAssertEqual(value.run, "20261030T1825Z")
        let request = try XCTUnwrap(script.requests.first)
        XCTAssertEqual(request.url?.absoluteString, "https://radar.example.invalid/v1/radar/latest.json")
        XCTAssertFalse(request.httpShouldHandleCookies)
        XCTAssertNil(request.url?.query)
        XCTAssertNil(request.httpBody)
        XCTAssertTrue(Set(request.allHTTPHeaderFields?.keys.map { $0 } ?? []).isSubset(of: ["Accept", "If-None-Match"]))
    }

    func testErrorsNotFoundTimeoutInvalidAndStaleFallBack() async throws {
        let data = try fixtureData()
        let reference = try manifest().referenceTime
        let fresh = try manifest().generatedAt.addingTimeInterval(60)
        var outcome = await client(Script([.init(status: 404)]), now: fresh).latest()
        XCTAssertEqual(outcome, .fallback(.notPublished))
        outcome = await client(Script([.init(status: -1)]), now: fresh).latest()
        XCTAssertEqual(outcome, .fallback(.unreachable))
        outcome = await client(Script([.init(status: 503)]), now: fresh).latest()
        XCTAssertEqual(outcome, .fallback(.unreachable))
        outcome = await client(Script([.init(status: 200, body: Data("{}".utf8))]), now: fresh).latest()
        XCTAssertEqual(outcome, .fallback(.invalid))
        let unknown = try modified { $0["schema"] = 3 }
        outcome = await client(Script([.init(status: 200, body: unknown)]), now: fresh).latest()
        XCTAssertEqual(outcome, .fallback(.unsupportedSchema(3)))
        outcome = await client(Script([.init(status: 200, body: data)]), now: reference.addingTimeInterval(21 * 60)).latest()
        XCTAssertEqual(outcome, .fallback(.stale), "Old backend images are never shown as current")
        outcome = await client(Script([.init(status: 304)]), now: fresh).latest()
        XCTAssertEqual(outcome, .fallback(.invalid), "304 without a stored manifest is unusable")
    }

    func testETagRevalidationUsesIfNoneMatchAnd304KeepsManifestButRechecksFreshness() async throws {
        let data = try fixtureData()
        let reference = try manifest().referenceTime
        let script = Script([.init(status: 200, body: data, etag: "\"v1\""), .init(status: 304)])
        let clock = ClockBox(try manifest().generatedAt.addingTimeInterval(60))
        let backend = RadarBackendClient(baseURL: base, transport: { try script.next($0) }, clock: { clock.now })
        let first = await backend.latest()
        guard case .fresh(let original, true) = first else { return XCTFail("\(first)") }
        let second = await backend.latest()
        XCTAssertEqual(second, .fresh(original, changed: false))
        XCTAssertNil(script.requests[0].value(forHTTPHeaderField: "If-None-Match"))
        XCTAssertEqual(script.requests[1].value(forHTTPHeaderField: "If-None-Match"), "\"v1\"")
        clock.now = reference.addingTimeInterval(25 * 60)
        let third = await backend.latest()
        XCTAssertEqual(third, .fallback(.stale), "A 304 does not make aging data fresh")
    }

    private final class ClockBox: @unchecked Sendable {
        private let lock = NSLock()
        private var value: Date
        init(_ value: Date) { self.value = value }
        var now: Date { get { lock.withLock { value } } set { lock.withLock { value = newValue } } }
    }

    // MARK: Slot to frame mapping and selection

    func testSelectionKeepsInstantAcrossRunsAndFollowsNow() {
        let t0 = DWDRequest.date("2026-10-30T18:00:00Z")!
        func dates(_ from: Int, _ count: Int) -> [Date] { (0..<count).map { t0.addingTimeInterval(Double(from + $0) * 300) } }
        let oldDates = dates(0, 13), oldReference = oldDates[6]
        // Same instant remains selected although the slot list grew and shifted.
        let newDates = dates(1, 37), newReference = newDates[12]
        XCTAssertEqual(RadarTimelineSelection.index(previous: oldDates[9], previousReference: oldReference,
                                                    dates: newDates, reference: newReference),
                       newDates.firstIndex(of: oldDates[9]))
        // "Now" follows the new reference.
        XCTAssertEqual(RadarTimelineSelection.index(previous: oldReference, previousReference: oldReference,
                                                    dates: newDates, reference: newReference), 12)
        // A dropped instant snaps to the nearest slot.
        XCTAssertEqual(RadarTimelineSelection.index(previous: oldDates[0], previousReference: oldReference,
                                                    dates: newDates, reference: newReference), 0)
        XCTAssertEqual(RadarTimelineSelection.index(previous: t0.addingTimeInterval(40 * 3600), previousReference: oldReference,
                                                    dates: newDates, reference: newReference), newDates.count - 1)
        XCTAssertEqual(RadarTimelineSelection.index(previous: nil, previousReference: nil,
                                                    dates: newDates, reference: newReference), 12)
        XCTAssertEqual(RadarTimelineSelection.index(previous: nil, previousReference: nil, dates: [], reference: t0), 0)
    }

    func testEverySlotMapsToItsFrameDate() throws {
        let value = try manifest()
        let timeline = value.timeline
        for (index, date) in timeline.dates.enumerated() {
            XCTAssertEqual(value.slot(at: date)?.time, date)
            XCTAssertEqual(value.slots[index].time, date)
        }
        XCTAssertNil(value.slot(at: value.referenceTime.addingTimeInterval(1)))
        XCTAssertEqual(timeline.dates.firstIndex(of: timeline.referenceTime), value.slots.firstIndex { $0.time == value.referenceTime })
    }

    // MARK: Geometry

    func testBoundsMapOntoMapKitPointSpace() throws {
        let value = try manifest()
        let rect = RadarImageGeometry.mapRect(for: value.bounds)
        // bbox_wgs84 of the service: lon 5.5...15.6, lat 47.0...55.1 (rounded values).
        let northWest = MKMapPoint(CLLocationCoordinate2D(latitude: 55.1, longitude: 5.5))
        let southEast = MKMapPoint(CLLocationCoordinate2D(latitude: 47.0, longitude: 15.6))
        XCTAssertEqual(rect.x, northWest.x, accuracy: 2_500)
        XCTAssertEqual(rect.y, northWest.y, accuracy: 2_500)
        XCTAssertEqual(rect.x + rect.width, southEast.x, accuracy: 2_500)
        XCTAssertEqual(rect.y + rect.height, southEast.y, accuracy: 2_500)
        // Whole world maps onto the whole MapKit square.
        let world = RadarBounds(minX: -RadarBounds.halfWorld, minY: -RadarBounds.halfWorld,
                                maxX: RadarBounds.halfWorld, maxY: RadarBounds.halfWorld)
        let all = RadarImageGeometry.mapRect(for: world)
        XCTAssertEqual(all.x, 0, accuracy: 1e-6)
        XCTAssertEqual(all.y, 0, accuracy: 1e-6)
        XCTAssertEqual(all.width, MKMapSize.world.width, accuracy: 1e-6)
        XCTAssertEqual(all.height, MKMapSize.world.height, accuracy: 1e-6)
    }

    func testOverlayCoversBoundingRect() throws {
        let overlay = RadarImageOverlay(loader: BackendRadarLoader(manifest: try manifest(), cache: TileMemoryCache(),
                                                                  fetch: { _ in Data() }, decode: { _ in nil }))
        let rect = RadarImageGeometry.mapRect(for: try manifest().bounds)
        XCTAssertEqual(overlay.boundingMapRect.minX, rect.x, accuracy: 1e-6)
        XCTAssertEqual(overlay.boundingMapRect.height, rect.height, accuracy: 1e-6)
        XCTAssertTrue(overlay.boundingMapRect.contains(MKMapPoint(overlay.coordinate)))
        XCTAssertTrue(overlay.boundingMapRect.contains(MKMapPoint(CLLocationCoordinate2D(latitude: 52.52, longitude: 13.4))))
    }

    // MARK: Decoder

    func testDecoderChecksDimensionsAndRejectsGarbage() {
        // 1x1 lossless WebP.
        let webp = Data(base64Encoded: "UklGRhoAAABXRUJQVlA4TA0AAAAvAAAAEAcQERGIiP4HAA==")!
        XCTAssertNotNil(RadarImageDecoder.decode(webp, width: 1, height: 1))
        XCTAssertNil(RadarImageDecoder.decode(webp, width: 1024, height: 1311))
        XCTAssertNil(RadarImageDecoder.decode(Data("<html>".utf8), width: 1, height: 1))
        XCTAssertNil(RadarImageDecoder.decode(Data(), width: 1, height: 1))
    }

    // MARK: Loader: cache, order, parallelism

    private final class FetchProbe: @unchecked Sendable {
        private let lock = NSLock()
        private(set) var started: [URL] = []
        private var running = 0
        private(set) var maxRunning = 0
        var failing: Set<URL> = []
        func begin(_ url: URL) { lock.withLock { started.append(url); running += 1; maxRunning = max(maxRunning, running) } }
        func end() { lock.withLock { running -= 1 } }
        var count: Int { lock.withLock { started.count } }
    }

    private static let pixel: CGImage = {
        let context = CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        return context.makeImage()!
    }()

    private func loader(_ probe: FetchProbe, cache: TileMemoryCache = TileMemoryCache(), delay: Duration = .milliseconds(20)) throws -> BackendRadarLoader {
        BackendRadarLoader(manifest: try manifest(), cache: cache, fetch: { url in
            probe.begin(url)
            defer { probe.end() }
            try await Task.sleep(for: delay)
            if probe.failing.contains(url) { throw URLError(.badServerResponse) }
            return Data([1, 2, 3])
        }, decode: { _ in Self.pixel })
    }

    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<500 where !condition() { try? await Task.sleep(for: .milliseconds(10)) }
    }

    func testPrefetchStartsAlternatingLeftRightFromSelectedSlot() async throws {
        let probe = FetchProbe()
        let value = try loader(probe, delay: .milliseconds(1))
        let slots = value.manifest.slots
        // One worker's worth: order is deterministic when requests are served one by one.
        let serial = BackendRadarLoader(manifest: value.manifest, cache: TileMemoryCache(), fetch: { url in
            probe.begin(url); defer { probe.end() }
            try await Task.sleep(for: .milliseconds(30))
            return Data([1])
        }, decode: { _ in Self.pixel })
        serial.prefetch(selected: 10) { true }
        await waitUntil { probe.count >= RadarBackendPolicy.prefetchParallelism }
        let firstBatch = Set(probe.started.prefix(RadarBackendPolicy.prefetchParallelism))
        let expected = Set(RadarPrefetchPolicy.order(selected: 10, count: slots.count).prefix(RadarBackendPolicy.prefetchParallelism).map { slots[$0].url })
        XCTAssertEqual(firstBatch, expected, "selected, then 9, 11, 8")
        await waitUntil { probe.count == slots.count }
        XCTAssertEqual(probe.count, slots.count, "every slot of the run is loaded once")
        XCTAssertEqual(Set(probe.started).count, slots.count)
        XCTAssertLessThanOrEqual(probe.maxRunning, RadarBackendPolicy.prefetchParallelism)
        XCTAssertEqual(probe.maxRunning, RadarBackendPolicy.prefetchParallelism, "uses the allowed parallelism")
        serial.cancelPrefetch()
    }

    func testPrefetchSkipsCachedAndStopsWhenNotAllowed() async throws {
        let probe = FetchProbe()
        let cache = TileMemoryCache()
        let value = try loader(probe, cache: cache, delay: .milliseconds(1))
        let slots = value.manifest.slots
        let first = await value.demand(slots[0].url)
        XCTAssertTrue(first)
        XCTAssertTrue(value.hasImage(for: slots[0].url))
        XCTAssertEqual(probe.count, 1)
        let allowed = AllowFlag()
        value.prefetch(selected: 0) { allowed.value }
        await waitUntil { probe.count == slots.count }
        XCTAssertEqual(probe.count, slots.count, "cached slot 0 is not fetched twice")
        // Not allowed (Low Power, Low Data, inactive): nothing starts.
        let probe2 = FetchProbe()
        let blocked = try loader(probe2)
        allowed.value = false
        blocked.prefetch(selected: 5) { allowed.value }
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(probe2.count, 0)
        XCTAssertFalse(blocked.hasImage(for: blocked.manifest.slots[5].url))
    }

    private final class AllowFlag: @unchecked Sendable {
        private let lock = NSLock()
        private var flag = true
        var value: Bool { get { lock.withLock { flag } } set { lock.withLock { flag = newValue } } }
    }

    func testDemandSharesInflightRequestAndFailureCoolsDown() async throws {
        let probe = FetchProbe()
        let value = try loader(probe, delay: .milliseconds(40))
        let url = value.manifest.slots[3].url
        async let a = value.demand(url)
        async let b = value.demand(url)
        let results = await [a, b]
        XCTAssertEqual(results, [true, true])
        XCTAssertEqual(probe.count, 1, "two waiters share one transport")
        XCTAssertGreaterThan(value.receivedBytes, 0)

        let bad = value.manifest.slots[4].url
        probe.failing = [bad]
        let failed = await value.demand(bad)
        XCTAssertFalse(failed)
        let failedAgain = await value.demand(bad)
        XCTAssertFalse(failedAgain)
        XCTAssertEqual(probe.count, 2, "no request storm for a failing image within the cooldown")
        XCTAssertEqual(value.failureCount, 1)
        XCTAssertEqual(value.successCount, 1)
    }

    func testByteLimitedCacheAndRunReplacement() throws {
        let cache = TileMemoryCache(limit: 10)
        let one = URL(string: "https://radar.example.invalid/v1/radar/a/a.webp")!
        let two = URL(string: "https://radar.example.invalid/v1/radar/b/b.webp")!
        cache.insertTrusted(Data(repeating: 1, count: 6), for: one)
        cache.insertTrusted(Data(repeating: 1, count: 6), for: two)
        XCTAssertLessThanOrEqual(cache.byteCount, 10)
        XCTAssertFalse(cache.contains(one))
        cache.insertTrusted(Data(repeating: 1, count: 4), for: one)
        let manifestValue = try manifest()
        _ = BackendRadarLoader(manifest: manifestValue, cache: cache, fetch: { _ in Data() }, decode: { _ in nil })
        XCTAssertEqual(cache.count, 0, "a new run drops entries which it no longer lists")
        XCTAssertEqual(cache.byteCount, 0)
    }

    func testDecodedImageCacheIsBounded() {
        let cache = DecodedImageCache(limit: 3)
        let urls = (0..<5).map { URL(string: "https://radar.example.invalid/v1/radar/r/\($0).webp")! }
        for url in urls { cache.insert(Self.pixel, for: url) }
        XCTAssertEqual(cache.count, 3)
        XCTAssertNil(cache.image(for: urls[0]))
        XCTAssertNotNil(cache.image(for: urls[4]))
    }

    // MARK: Retry policy

    func testRetryPolicyIsBoundedJitteredAndOnlyForInvalidDimension() {
        XCTAssertEqual(RadarRetryPolicy.maxAttempts, 3)
        XCTAssertTrue(RadarRetryPolicy.shouldRetry(DWDDataError.runUnavailable, attempt: 1))
        XCTAssertTrue(RadarRetryPolicy.shouldRetry(DWDDataError.runUnavailable, attempt: 2))
        XCTAssertFalse(RadarRetryPolicy.shouldRetry(DWDDataError.runUnavailable, attempt: 3))
        XCTAssertFalse(RadarRetryPolicy.shouldRetry(DWDDataError.invalidResponse, attempt: 1))
        XCTAssertFalse(RadarRetryPolicy.shouldRetry(URLError(.timedOut), attempt: 1))
        XCTAssertFalse(RadarRetryPolicy.shouldRetry(nil, attempt: 1))
        XCTAssertEqual(RadarRetryPolicy.delay(afterAttempt: 1, jitter: 1), 0.3, accuracy: 1e-9)
        XCTAssertEqual(RadarRetryPolicy.delay(afterAttempt: 2, jitter: 1), 0.6, accuracy: 1e-9)
        for _ in 0..<50 {
            let value = RadarRetryPolicy.delay(afterAttempt: 1)
            XCTAssertTrue((0.3 * 0.75...0.3 * 1.25).contains(value))
        }
    }

    func testBaseURLDefaultsToProductionService() {
        XCTAssertEqual(RadarBackendConfig.baseURL(arguments: []).absoluteString, "https://showernow.linolaske.de/v1/radar/")
        XCTAssertEqual(RadarBackendConfig.maximumDataAge, 20 * 60)
        XCTAssertEqual(RadarBackendConfig.pollInterval, 60)
    }

    // MARK: Store: source choice, fallback, selection across runs

    private func failingDWD() -> DWDClient {
        DWDClient(transport: { _ in throw URLError(.notConnectedToInternet) }, retryDelay: { _ in 0 })
    }

    @MainActor func testStoreUsesBackendTimelineAndLabelsSource() async throws {
        let data = try fixtureData()
        let reference = try manifest().referenceTime
        let store = WeatherStore(client: failingDWD(),
                                 backend: client(Script([.init(status: 200, body: data, etag: "\"a\"")]), now: try manifest().generatedAt.addingTimeInterval(60)))
        await store.refresh()
        XCTAssertEqual(store.radarSource, .cache)
        XCTAssertNotNil(store.timeline?.backend)
        XCTAssertEqual(store.timeline?.dates.count, 27)
        XCTAssertEqual(store.frameDate, reference)
        XCTAssertEqual(store.radarAttribution.attribution, "Quelle: Deutscher Wetterdienst")
        XCTAssertNil(store.radarError)
    }

    @MainActor func testStoreFallsBackToDirectDWDWhenBackendFailsOrIsStale() async throws {
        let data = try fixtureData()
        let reference = try manifest().referenceTime
        let now = DWDRequest.date("2026-10-28T15:15:00Z")!
        let dwd = DWDClient(transport: { request in
            (Data("composite_rv_20261028_1510.tar composite_rv_20261028_1515.tar".utf8),
             HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }, clock: { now }, retryDelay: { _ in 0 })
        for replies in [[Script.Reply(status: 404)], [.init(status: -1)], [.init(status: 200, body: data)]] {
            // The last variant is "stale": the backend clock is a day after its run.
            let backendNow = replies[0].status == 200 ? reference.addingTimeInterval(86_400) : reference
            let store = WeatherStore(client: dwd, backend: client(Script(replies), now: backendNow))
            await store.refresh()
            XCTAssertEqual(store.radarSource, .direct, "status \(replies[0].status)")
            XCTAssertNil(store.timeline?.backend)
            XCTAssertEqual(store.timeline?.referenceTime, now)
        }
    }

    @MainActor func testPollingNewRunKeepsSelectedInstantAndSameRunIsNoOp() async throws {
        let data = try fixtureData()
        let reference = try manifest().referenceTime
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object["generated_at"] = "2026-10-30T18:30:00Z"
        let newer = try JSONSerialization.data(withJSONObject: object)
        let script = Script([.init(status: 200, body: data, etag: "\"a\""), .init(status: 304), .init(status: 200, body: newer, etag: "\"b\"")])
        let store = WeatherStore(client: failingDWD(), backend: client(script, now: try manifest().generatedAt.addingTimeInterval(120)))
        await store.refresh()
        store.selectedFrame = 4
        let selected = store.frameDate
        await store.pollRadar() // 304: unchanged
        XCTAssertEqual(store.timeline?.backend?.generatedAt, DWDRequest.date("2026-10-30T18:29:17Z"))
        await store.pollRadar() // changed manifest replaces the slots
        XCTAssertEqual(store.timeline?.backend?.generatedAt, DWDRequest.date("2026-10-30T18:30:00Z"))
        XCTAssertEqual(store.frameDate, selected, "selected instant survives the new run")
        XCTAssertEqual(script.requests[1].value(forHTTPHeaderField: "If-None-Match"), "\"a\"")
    }
}
