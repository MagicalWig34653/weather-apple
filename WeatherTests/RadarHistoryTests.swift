import ImageIO
import XCTest
@testable import Weather

// Logic tests for the "maximum past" feature: history.json, timeline composition, setting,
// store behaviour and prefetch limits. No network; every test owns its defaults suite and caches.
extension RadarBackendTests {
    // MARK: Helpers

    private func historyData() throws -> Data {
        let bundle = Bundle(for: RadarBackendTests.self)
        let url = bundle.url(forResource: "radar-history", withExtension: "json", subdirectory: "Fixtures")
            ?? bundle.url(forResource: "radar-history", withExtension: "json")
        return try Data(contentsOf: XCTUnwrap(url))
    }

    /// Fixed clock just after the fixture's `generated_at`, so parsing never depends on the real date.
    private func parseHistory(_ data: Data, now: Date = DWDRequest.date("2026-10-30T18:30:00Z")!) throws -> RadarHistory {
        try RadarHistory.parse(data, baseURL: base, now: now)
    }

    private func history() throws -> RadarHistory { try parseHistory(historyData()) }

    private func modifiedHistory(_ change: (inout [String: Any]) -> Void) throws -> Data {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: historyData()) as? [String: Any])
        change(&object)
        return try JSONSerialization.data(withJSONObject: object)
    }

    private func slot(_ time: String, path: String, kind: String = "analysis") -> [String: Any] {
        ["time": time, "kind": kind, "path": path]
    }

    private static func slotID(_ date: Date) -> (name: String, iso: String) {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd'T'HHmm'Z'"
        let name = formatter.string(from: date)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:00'Z'"
        return (name, formatter.string(from: date))
    }

    /// Latest manifest with `analysis` analysis slots ending at 18:25 plus six forecast slots.
    private func latestData(analysis: Int) throws -> Data {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: fixtureData()) as? [String: Any])
        let reference = DWDRequest.date("2026-10-30T18:25:00Z")!
        object["slots"] = (0..<(analysis + 6)).map { index -> [String: Any] in
            let id = Self.slotID(reference.addingTimeInterval(Double(index - analysis + 1) * 300))
            return ["time": id.iso, "kind": index < analysis ? "analysis" : "forecast", "path": "20261030T1825Z/\(id.name).webp"]
        }
        return try JSONSerialization.data(withJSONObject: object)
    }

    /// Synthetic history on the 5-minute grid ending at 18:10 (just before the fixture's latest slots).
    private func bigHistoryData(slots count: Int, hours: Int = 48) throws -> Data {
        let end = DWDRequest.date("2026-10-30T18:10:00Z")!
        return try modifiedHistory {
            $0["history_hours"] = hours
            $0["slots"] = (0..<count).map { index -> [String: Any] in
                let id = Self.slotID(end.addingTimeInterval(-Double(count - 1 - index) * 300))
                return ["time": id.iso, "kind": "analysis", "path": "history/\(id.name).webp"]
            }
        }
    }

    private func bigHistory(slots count: Int) throws -> RadarHistory { try parseHistory(bigHistoryData(slots: count)) }

    private func isolatedDefaults() -> UserDefaults {
        let name = "ShowerNowTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        addTeardownBlock { UserDefaults(suiteName: name)?.removePersistentDomain(forName: name) }
        return defaults
    }

    @MainActor private func waitFor(_ condition: @MainActor () -> Bool) async {
        var attempts = 0
        while attempts < 500, !condition() {
            attempts += 1
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    private static let historyPixel: CGImage = {
        CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!.makeImage()!
    }()

    // MARK: history.json parsing and validation

    func testHistoryFixtureParses() throws {
        let value = try history()
        XCTAssertEqual(value.slots.count, 13)
        XCTAssertEqual(value.historyHours, 48)
        XCTAssertEqual(value.stepMinutes, 5)
        XCTAssertEqual(value.imageWidth, 1024)
        XCTAssertTrue(value.slots.allSatisfy { $0.kind == .analysis })
        XCTAssertEqual(value.slots.first?.url.absoluteString,
                       "https://radar.example.invalid/v1/radar/history/20261030T1715Z.webp", "path is used as given")
        XCTAssertEqual(value.slots.map(\.time), value.slots.map(\.time).sorted())
        XCTAssertFalse(value.slots.contains { $0.time == DWDRequest.date("2026-10-30T17:35:00Z") }, "gaps are allowed")
        XCTAssertEqual(value.bounds, try manifest().bounds)
    }

    func testHistoryRejectsUnknownSchemaGarbageAndMissingFields() throws {
        XCTAssertThrowsError(try parseHistory(Data()))
        XCTAssertThrowsError(try parseHistory(Data("nope".utf8)))
        XCTAssertThrowsError(try parseHistory(modifiedHistory { $0["schema"] = 2 })) {
            XCTAssertEqual($0 as? RadarBackendError, .unsupportedSchema(2))
        }
        for key in ["run", "generated_at", "step_minutes", "history_hours", "image", "slots"] {
            XCTAssertThrowsError(try parseHistory(modifiedHistory { $0[key] = nil }), key) {
                XCTAssertEqual($0 as? RadarBackendError, .invalid)
            }
        }
        XCTAssertThrowsError(try parseHistory(modifiedHistory { $0["history_hours"] = 0 }))
        XCTAssertThrowsError(try parseHistory(modifiedHistory { $0["history_hours"] = 10_000 }))
        XCTAssertThrowsError(try parseHistory(modifiedHistory { $0["run"] = "../x" }))
        XCTAssertThrowsError(try parseHistory(modifiedHistory { $0["generated_at"] = "gestern" }))
        XCTAssertThrowsError(try parseHistory(historyData(), now: DWDRequest.date("2026-10-30T10:00:00Z")!), "generated in the future")
        XCTAssertThrowsError(try parseHistory(modifiedHistory {
            var image = $0["image"] as! [String: Any]; image["projection"] = "EPSG:4326"; $0["image"] = image
        }))
    }

    func testHistoryRejectsEmptyUnsortedDuplicateForecastAndUnsafeSlots() throws {
        XCTAssertThrowsError(try parseHistory(modifiedHistory { $0["slots"] = [[String: Any]]() }), "empty")
        let a = slot("2026-10-30T17:15:00Z", path: "h/a.webp"), b = slot("2026-10-30T17:20:00Z", path: "h/b.webp")
        XCTAssertNoThrow(try parseHistory(modifiedHistory { $0["slots"] = [a, b] }))
        XCTAssertThrowsError(try parseHistory(modifiedHistory { $0["slots"] = [b, a] }), "unsorted")
        XCTAssertThrowsError(try parseHistory(modifiedHistory { $0["slots"] = [a, a] }), "duplicate time")
        XCTAssertThrowsError(try parseHistory(modifiedHistory {
            $0["slots"] = [slot("2026-10-30T17:15:00Z", path: "h/a.webp", kind: "forecast")]
        }), "history carries analyses only")
        XCTAssertThrowsError(try parseHistory(modifiedHistory { $0["slots"] = [slot("heute", path: "h/a.webp")] }))
        XCTAssertThrowsError(try parseHistory(modifiedHistory {
            $0["slots"] = [slot("2026-10-30T19:15:00Z", path: "h/a.webp")]
        }), "slot after generated_at")
        for path in ["../a.webp", "/v1/radar/a.webp", "https://evil.example/a.webp", "h/a.webp?x=1", "h/a.png", "h//a.webp",
                     "a/b/c/d/e/f.webp", "h/a b.webp", ".webp", ""] {
            XCTAssertThrowsError(try parseHistory(modifiedHistory {
                $0["slots"] = [slot("2026-10-30T17:15:00Z", path: path)]
            }), path)
        }
    }

    func testHistoryHoursSmallerThanSelectionIsAcceptedAndReported() throws {
        XCTAssertEqual(try parseHistory(modifiedHistory { $0["history_hours"] = 6 }).historyHours, 6)
    }

    func testFullSizeHistoryParsesAndFitsTheManifestSizeLimit() throws {
        let data = try bigHistoryData(slots: 576)
        XCTAssertLessThan(data.count, RadarBackendConfig.maximumManifestBytes, "48 h of slots stay small")
        let value = try parseHistory(data)
        XCTAssertEqual(value.slots.count, 576)
        XCTAssertEqual(Set(value.slots.map(\.url)).count, 576)
    }

    // MARK: Composition

    func testNeedsHistoryOnlyBeyondWhatLatestCovers() throws {
        let twelve = try RadarManifest.parse(latestData(analysis: 12), baseURL: base)
        XCTAssertFalse(RadarTimelineComposer.needsHistory(latest: twelve, hours: 1), "about 1 h is already in latest")
        XCTAssertTrue(RadarTimelineComposer.needsHistory(latest: twelve, hours: 2))
        XCTAssertTrue(RadarTimelineComposer.needsHistory(latest: twelve, hours: 48))
    }

    func testComposeFiltersToChosenPastDeduplicatesAndSorts() throws {
        let latest = try manifest(), history = try history()
        let ref = latest.referenceTime
        let one = RadarTimelineComposer.compose(latest: latest, history: history, hours: 1)
        let times = one.slots.map(\.time)
        XCTAssertEqual(times, times.sorted())
        XCTAssertEqual(Set(times).count, times.count, "no duplicates")
        XCTAssertGreaterThanOrEqual(times.first!, ref.addingTimeInterval(-3600))
        XCTAssertEqual(one.slot(at: DWDRequest.date("2026-10-30T18:15:00Z")!)?.path, "20261030T1815Z/20261030T1815Z.webp",
                       "latest wins for overlapping slots")
        XCTAssertEqual(one.slot(at: DWDRequest.date("2026-10-30T18:10:00Z")!)?.path, "history/20261030T1810Z.webp")
        XCTAssertEqual(one.slots.filter { $0.kind == .forecast }.count, latest.slots.filter { $0.kind == .forecast }.count)
        XCTAssertEqual(one.referenceTime, ref)
        XCTAssertNotNil(one.slot(at: ref))

        let all = RadarTimelineComposer.compose(latest: latest, history: history, hours: 48)
        XCTAssertEqual(all.slots.count, 11 + latest.slots.count, "11 older history slots + latest (2 overlaps dropped)")
        XCTAssertEqual(all.slots.first?.time, DWDRequest.date("2026-10-30T17:15:00Z"))
        XCTAssertLessThan(one.slots.count, all.slots.count)
        XCTAssertEqual(one.timeline.dates.firstIndex(of: ref), one.slots.firstIndex { $0.time == ref })
    }

    func testComposeWithoutUsableHistoryKeepsLatestOnly() throws {
        let latest = try manifest()
        XCTAssertEqual(RadarTimelineComposer.compose(latest: latest, history: nil, hours: 48).slots, latest.slots)
        let other = try modifiedHistory {
            var image = $0["image"] as! [String: Any]; image["width"] = 512; $0["image"] = image
        }
        let incompatible = try parseHistory(other)
        XCTAssertFalse(RadarTimelineComposer.isCompatible(incompatible, with: latest))
        XCTAssertEqual(RadarTimelineComposer.compose(latest: latest, history: incompatible, hours: 48).slots, latest.slots)
    }

    func testComposeDropsHistoryNewerThanReference() throws {
        let latest = try manifest()
        let future = try modifiedHistory {
            $0["slots"] = [slot("2026-10-30T18:10:00Z", path: "h/a.webp"), slot("2026-10-30T18:28:00Z", path: "h/b.webp")]
        }
        let merged = RadarTimelineComposer.compose(latest: latest, history: try parseHistory(future), hours: 48)
        XCTAssertNil(merged.slot(at: DWDRequest.date("2026-10-30T18:28:00Z")!))
        XCTAssertNotNil(merged.slot(at: DWDRequest.date("2026-10-30T18:10:00Z")!))
    }

    func testFullFortyEightHourTimelineHasAscendingUniqueSlots() throws {
        let merged = RadarTimelineComposer.compose(latest: try manifest(), history: try bigHistory(slots: 576), hours: 48)
        // History starts at 2026-10-28T18:15Z; the 48 h cutoff (reference minus 48 h) is 18:25Z.
        XCTAssertEqual(merged.slots.first?.time, DWDRequest.date("2026-10-28T18:25:00Z"))
        XCTAssertEqual(merged.slots.count, 574 + 27)
        XCTAssertEqual(Set(merged.slots.map(\.time)).count, merged.slots.count)
        XCTAssertEqual(merged.slots.map(\.time), merged.slots.map(\.time).sorted())
    }

    // MARK: Setting

    func testPastSettingDefaultsPersistsAndRejectsInvalidValues() {
        let defaults = isolatedDefaults()
        XCTAssertEqual(RadarPastWindow.options, [1, 2, 6, 12, 24, 48])
        XCTAssertEqual(RadarPastWindow.load(defaults), 2, "default is 2 h")
        RadarPastWindow.save(24, to: defaults)
        XCTAssertEqual(RadarPastWindow.load(defaults), 24)
        RadarPastWindow.save(5, to: defaults)
        XCTAssertEqual(RadarPastWindow.load(defaults), 24, "invalid values are not stored")
        defaults.set(999, forKey: RadarPastWindow.defaultsKey)
        XCTAssertEqual(RadarPastWindow.load(defaults), 2, "a corrupt stored value falls back to the default")
        XCTAssertEqual(RadarPastWindow.label(1), "1 Stunde")
        XCTAssertEqual(RadarPastWindow.label(48), "48 Stunden")
    }

    @MainActor func testStorePersistsAndRestoresPastHours() {
        let defaults = isolatedDefaults()
        let first = WeatherStore(client: failingDWD(), backend: client(Script([.init(status: 404)]), now: Date()), defaults: defaults)
        XCTAssertEqual(first.pastHours, 2)
        first.setPastHours(48)
        first.setPastHours(7) // ignored
        XCTAssertEqual(first.pastHours, 48)
        let second = WeatherStore(client: failingDWD(), backend: client(Script([.init(status: 404)]), now: Date()), defaults: defaults)
        XCTAssertEqual(second.pastHours, 48)
    }

    // MARK: Client: ETag and errors

    func testHistoryClientUsesETagAnd304KeepsCachedHistory() async throws {
        let script = Script([.init(status: 404)], history: [.init(status: 200, body: try historyData(), etag: "\"h1\""), .init(status: 304)])
        let backend = client(script, now: try manifest().generatedAt)
        let first = await backend.history()
        guard case .loaded(let one, let changed) = first else { return XCTFail("\(first)") }
        XCTAssertTrue(changed)
        let second = await backend.history()
        guard case .loaded(let two, let changedAgain) = second else { return XCTFail("\(second)") }
        XCTAssertFalse(changedAgain)
        XCTAssertEqual(one, two)
        XCTAssertNil(script.historyRequests[0].value(forHTTPHeaderField: "If-None-Match"))
        XCTAssertEqual(script.historyRequests[1].value(forHTTPHeaderField: "If-None-Match"), "\"h1\"")
        XCTAssertEqual(script.historyRequests[0].url?.absoluteString, "https://radar.example.invalid/v1/radar/history.json")
        XCTAssertFalse(script.historyRequests[0].httpShouldHandleCookies)
        XCTAssertTrue(script.requests.isEmpty, "history.json never touches latest.json")
    }

    func testHistoryClientMapsErrorsToUnavailable() async throws {
        let now = try manifest().generatedAt
        let cases: [(Script.Reply, RadarBackendError)] = [
            (.init(status: 404), .notPublished), (.init(status: -1), .unreachable), (.init(status: 500), .unreachable),
            (.init(status: 200, body: Data("{}".utf8)), .invalid),
            (.init(status: 200, body: try modifiedHistory { $0["schema"] = 9 }), .unsupportedSchema(9)),
            (.init(status: 304), .invalid)]
        for (reply, expected) in cases {
            let outcome = await client(Script([.init(status: 404)], history: [reply]), now: now).history()
            XCTAssertEqual(outcome, .unavailable(expected), "status \(reply.status)")
        }
    }

    func testHistory404AfterSuccessDropsCachedHistory() async throws {
        let script = Script([.init(status: 404)],
                            history: [.init(status: 200, body: try historyData(), etag: "\"h\""), .init(status: 404), .init(status: 304)])
        let backend = client(script, now: try manifest().generatedAt)
        _ = await backend.history()
        let gone = await backend.history()
        XCTAssertEqual(gone, .unavailable(.notPublished))
        let after = await backend.history()
        XCTAssertEqual(after, .unavailable(.invalid), "no stale copy is served for a 304 once the file was withdrawn")
        XCTAssertNil(script.historyRequests[2].value(forHTTPHeaderField: "If-None-Match"))
    }

    // MARK: Store

    @MainActor private func historyStore(latest: Data? = nil, history: [Script.Reply], hours: Int = 2,
                                         latestReplies: [Script.Reply]? = nil) throws -> (WeatherStore, Script) {
        let defaults = isolatedDefaults()
        RadarPastWindow.save(hours, to: defaults)
        let data = try latest ?? fixtureData()
        let script = Script(latestReplies ?? [.init(status: 200, body: data, etag: "\"a\"")], history: history)
        let store = WeatherStore(client: failingDWD(), backend: client(script, now: try manifest().generatedAt.addingTimeInterval(60)),
                                 defaults: defaults)
        return (store, script)
    }

    @MainActor func testStoreComposesHistoryAndLatestForChosenPast() async throws {
        let (store, script) = try historyStore(history: [.init(status: 200, body: try historyData(), etag: "\"h\"")])
        await store.refresh()
        XCTAssertEqual(store.radarSource, .cache)
        XCTAssertEqual(store.timeline?.dates.count, 11 + 27)
        XCTAssertEqual(store.historyStatus, .loaded(hours: 48))
        XCTAssertEqual(store.frameDate, try manifest().referenceTime, "starts at now")
        XCTAssertEqual(script.historyRequests.count, 1)
        XCTAssertNil(store.radarError)
    }

    @MainActor func testStoreKeepsSelectedInstantWhenPastChanges() async throws {
        let (store, _) = try historyStore(history: [.init(status: 200, body: try historyData(), etag: "\"h\"")], hours: 6)
        await store.refresh()
        let chosen = try XCTUnwrap(DWDRequest.date("2026-10-30T17:50:00Z"))
        store.selectedFrame = try XCTUnwrap(store.timeline?.dates.firstIndex(of: chosen))
        let cutoff = try manifest().referenceTime.addingTimeInterval(-3600)
        store.setPastHours(1) // keeps 17:25 and later
        await waitFor { (store.timeline?.dates.first ?? .distantPast) >= cutoff }
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(store.timeline?.dates.first), cutoff)
        XCTAssertEqual(store.frameDate, chosen, "17:50 is still inside the window")
        let early = try XCTUnwrap(DWDRequest.date("2026-10-30T17:25:00Z"))
        store.selectedFrame = try XCTUnwrap(store.timeline?.dates.firstIndex(of: early))
        store.setPastHours(6)
        await waitFor { store.timeline?.dates.count == 11 + 27 }
        XCTAssertEqual(store.frameDate, early, "widening the window keeps the instant")
        XCTAssertEqual(store.pastHours, 6)
    }

    @MainActor func testStoreFallsBackToLatestPastWhenHistoryMissingOrInvalid() async throws {
        for reply in [Script.Reply(status: 404), .init(status: -1), .init(status: 200, body: Data("{}".utf8)), .init(status: 500)] {
            let (store, _) = try historyStore(history: [reply])
            await store.refresh()
            XCTAssertEqual(store.radarSource, .cache, "status \(reply.status)")
            XCTAssertEqual(store.timeline?.dates.count, 27, "latest's own past only")
            XCTAssertEqual(store.historyStatus, .unavailable)
            XCTAssertNil(store.radarError)
            XCTAssertEqual(store.frameDate, try manifest().referenceTime)
        }
    }

    @MainActor func testStoreChecksHistoryOnlyForNewRunsAndSkipsItWhenLatestCoversThePast() async throws {
        let data = try fixtureData()
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object["generated_at"] = "2026-10-30T18:30:00Z"
        object["run"] = "20261030T1830Z"
        let newer = try JSONSerialization.data(withJSONObject: object)
        let (store, script) = try historyStore(
            history: [.init(status: 200, body: try historyData(), etag: "\"h\""), .init(status: 304)],
            latestReplies: [.init(status: 200, body: data, etag: "\"a\""), .init(status: 304), .init(status: 200, body: newer, etag: "\"b\"")])
        await store.refresh()
        store.selectedFrame = 3
        let selected = store.frameDate
        await store.pollRadar() // latest 304: no history request
        XCTAssertEqual(script.historyRequests.count, 1)
        await store.pollRadar() // new run: history is checked again (ETag, 304)
        XCTAssertEqual(script.historyRequests.count, 2)
        XCTAssertEqual(script.historyRequests[1].value(forHTTPHeaderField: "If-None-Match"), "\"h\"")
        XCTAssertEqual(store.frameDate, selected, "selected instant survives the new run with history")
        XCTAssertEqual(store.timeline?.backend?.run, "20261030T1830Z")
        XCTAssertEqual(store.historyStatus, .loaded(hours: 48))

        let (covered, quiet) = try historyStore(latest: try latestData(analysis: 12),
                                                history: [.init(status: 200, body: try historyData())], hours: 1)
        await covered.refresh()
        XCTAssertEqual(quiet.historyRequests.count, 0, "1 h is already covered by latest.json")
        XCTAssertEqual(covered.historyStatus, .notNeeded)
        XCTAssertEqual(covered.timeline?.dates.count, 12 + 6)
    }

    @MainActor func testTransientHistoryErrorKeepsLastValidHistory() async throws {
        let data = try fixtureData()
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object["run"] = "20261030T1830Z"; object["generated_at"] = "2026-10-30T18:30:00Z"
        let newer = try JSONSerialization.data(withJSONObject: object)
        let (store, _) = try historyStore(history: [.init(status: 200, body: try historyData()), .init(status: -1)],
                                          latestReplies: [.init(status: 200, body: data), .init(status: 200, body: newer)])
        await store.refresh()
        await store.pollRadar()
        XCTAssertEqual(store.timeline?.backend?.run, "20261030T1830Z")
        XCTAssertEqual(store.timeline?.dates.count, 11 + 27, "a network hiccup does not shrink the timeline")
        XCTAssertEqual(store.historyStatus, .loaded(hours: 48))
    }

    @MainActor func testServerOffersLessThanChosenPast() async throws {
        let short = try modifiedHistory { $0["history_hours"] = 6 }
        let (store, _) = try historyStore(history: [.init(status: 200, body: short)], hours: 48)
        await store.refresh()
        XCTAssertEqual(store.pastHours, 48, "the choice is kept")
        XCTAssertEqual(store.serverHistoryHours, 6, "but the UI knows the server offers less")
        XCTAssertEqual(store.historyStatus, .loaded(hours: 6))
    }

    @MainActor func testDirectFallbackIgnoresPastSettingAndNeverAsksForHistory() async throws {
        let now = DWDRequest.date("2026-10-28T15:15:00Z")!
        let dwd = DWDClient(transport: { request in
            (Data("composite_rv_20261028_1510.tar composite_rv_20261028_1515.tar".utf8),
             HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }, clock: { now }, retryDelay: { _ in 0 })
        let defaults = isolatedDefaults()
        RadarPastWindow.save(48, to: defaults)
        let script = Script([.init(status: 404)])
        let store = WeatherStore(client: dwd, backend: client(script, now: now), defaults: defaults)
        await store.refresh()
        XCTAssertEqual(store.radarSource, .direct)
        XCTAssertNil(store.timeline?.backend)
        XCTAssertEqual(store.pastHours, 48, "the setting is kept for when the cache returns")
        XCTAssertTrue(script.historyRequests.isEmpty)
        XCTAssertEqual(RadarPastWindow.directHours, 1)
    }

    // MARK: Prefetch with many slots

    func testPrefetchOrderCoversAllSlotsAlternatingForSixHundredSlots() {
        let count = 603
        let order = RadarPrefetchPolicy.order(selected: 576, count: count)
        XCTAssertEqual(order.count, count)
        XCTAssertEqual(Set(order).count, count)
        XCTAssertEqual(Array(order.prefix(7)), [576, 575, 577, 574, 578, 573, 579])
        XCTAssertEqual(Array(RadarPrefetchPolicy.order(selected: 0, count: count).prefix(3)), [0, 1, 2])
        XCTAssertEqual(Array(RadarPrefetchPolicy.order(selected: count - 1, count: count).prefix(3)), [602, 601, 600])
    }

    func testCacheStaysBelowHardLimitWithFortyEightHoursOfImages() {
        let cache = TileMemoryCache() // 50 MB
        let payload = Data(count: 100_000) // pessimistic: 100 KB per image
        for index in 0..<603 {
            cache.insertTrusted(payload, for: URL(string: "https://radar.example.invalid/v1/radar/h/\(index).webp")!)
            XCTAssertLessThanOrEqual(cache.byteCount, 50_000_000)
        }
        XCTAssertEqual(cache.count, 500)
    }

    func testPrefetchStopsAtCeilingKeepingTheNearestSlots() async throws {
        let merged = RadarTimelineComposer.compose(latest: try manifest(), history: try bigHistory(slots: 576), hours: 48)
        let cache = TileMemoryCache(limit: 10_000)
        let probe = FetchProbe()
        let loader = BackendRadarLoader(manifest: merged, cache: cache, prefetchCeiling: 2_000, fetch: { url in
            probe.begin(url); defer { probe.end() }
            return Data(count: 100)
        }, decode: { _ in Self.historyPixel })
        let selected = 300
        loader.prefetch(selected: selected) { true }
        for _ in 0..<200 where cache.byteCount < 2_000 { try await Task.sleep(for: .milliseconds(10)) }
        try await Task.sleep(for: .milliseconds(150))
        let fetched = Set(probe.started)
        XCTAssertGreaterThanOrEqual(fetched.count, 20)
        XCTAssertLessThanOrEqual(fetched.count, 20 + RadarBackendPolicy.prefetchParallelism, "ceiling 2000 B / 100 B plus requests in flight")
        let nearest = Set(RadarPrefetchPolicy.order(selected: selected, count: merged.slots.count)
            .prefix(20 + RadarBackendPolicy.prefetchParallelism).map { merged.slots[$0].url })
        XCTAssertTrue(fetched.isSubset(of: nearest), "only the slots nearest to the selection were loaded")
        XCTAssertTrue(cache.contains(merged.slots[selected].url))
        XCTAssertLessThanOrEqual(cache.byteCount, 10_000)
        loader.cancelPrefetch()
    }
}
