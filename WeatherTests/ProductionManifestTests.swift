import XCTest
@testable import Weather

/// Acceptance of the app against the REAL production manifests (read-only HTTP check, 20 Nov 2026 09:53:48 UTC, backend with
/// `history.hours` 72 on every layer, `complete: false` everywhere except Deutschland). The files are fixtures in the repo:
/// no network, no live fetch, deterministic. They show what a user sees when the backend is still building up its history.
final class ProductionManifestTests: XCTestCase {
    static let queried = DWDRequest.date("2026-11-20T09:53:48Z")!
    let radarBase = URL(string: "https://showers.linolaske.de/v1/radar/")!

    private func fixture(_ name: String) throws -> Data {
        let bundle = Bundle(for: ProductionManifestTests.self)
        let url = bundle.url(forResource: name, withExtension: "json", subdirectory: "Fixtures/produktion-20261120")
            ?? bundle.url(forResource: name, withExtension: "json", subdirectory: "produktion-20261120")
            ?? bundle.url(forResource: name, withExtension: "json")
        return try Data(contentsOf: XCTUnwrap(url, name))
    }

    private struct Case { let layer: RadarLayer, file: String, step: Int, expected: Int, present: Int, oldest: String, past: Int }

    /// Numbers from `zusammenfassung.json` of the check (not from memory).
    private let cases: [Case] = [
        Case(layer: .radarEU, file: "manifest-radar_eu", step: 5, expected: 865, present: 141, oldest: "2026-11-19T22:05:00Z", past: 0),
        Case(layer: .radarWorld, file: "manifest-radar_world", step: 10, expected: 433, present: 214, oldest: "2026-11-18T22:00:00Z", past: 0),
        Case(layer: .lightning, file: "manifest-lightning", step: 5, expected: 865, present: 134, oldest: "2026-11-19T22:40:00Z", past: 0),
        Case(layer: .clouds, file: "manifest-clouds", step: 10, expected: 433, present: 83, oldest: "2026-11-19T19:50:00Z", past: 0),
        Case(layer: .cloudmask, file: "manifest-cloudmask", step: 15, expected: 289, present: 65, oldest: "2026-11-19T17:30:00Z", past: 0),
        Case(layer: .pressure, file: "manifest-pressure", step: 60, expected: 72, present: 6, oldest: "2026-11-20T00:00:00Z", past: 6),
        Case(layer: .temperature, file: "manifest-temperature", step: 60, expected: 72, present: 6, oldest: "2026-11-20T00:00:00Z", past: 6),
        Case(layer: .dewpoint, file: "manifest-dewpoint", step: 60, expected: 72, present: 6, oldest: "2026-11-20T00:00:00Z", past: 6),
        Case(layer: .humidity, file: "manifest-humidity", step: 60, expected: 72, present: 6, oldest: "2026-11-20T00:00:00Z", past: 6),
    ]

    private func manifest(_ test: Case) throws -> RadarLayerManifest {
        try RadarLayerManifest.parse(fixture(test.file), expected: test.layer,
                                     layersBaseURL: RadarBackendConfig.layersBaseURL(for: test.layer, radarBaseURL: radarBase))
    }

    func testParserAcceptsEveryProductionManifestWithItsHistoryBlock() throws {
        for test in cases {
            let value = try manifest(test)
            let info = try XCTUnwrap(value.historyInfo, "\(test.layer.rawValue): history block")
            XCTAssertEqual(info.hours, 72, test.layer.rawValue)
            XCTAssertEqual(info.expected, test.expected, test.layer.rawValue)
            XCTAssertEqual(info.present, test.present, test.layer.rawValue)
            XCTAssertFalse(info.complete, "\(test.layer.rawValue): complete is false")
            XCTAssertEqual(info.oldest, DWDRequest.date(test.oldest), test.layer.rawValue)
            XCTAssertEqual(info.gaps.count, 1, "\(test.layer.rawValue): one gap entry")
            XCTAssertEqual(value.offeredHistoryHours, 72, "the server reports 72 h: the steps up to 72 stay selectable")
            XCTAssertTrue(value.isFresh(at: Self.queried), "\(test.layer.rawValue) is fresh at the time of the check")
        }
    }

    func testTimelineReachesTheOldestExistingSlotAndNamesWhatIsMissingExactlyOnce() throws {
        for test in cases {
            let value = try manifest(test)
            let timeline = value.timeline(at: Self.queried, pastHours: nil)   // no stored choice: the backend's window, limited to what exists
            let oldest = try XCTUnwrap(DWDRequest.date(test.oldest))
            XCTAssertEqual(timeline.dates.first, oldest, "\(test.layer.rawValue): the oldest slot that exists")
            XCTAssertEqual(timeline.dates, timeline.dates.sorted(), "ascending")
            XCTAssertEqual(Set(timeline.dates).count, timeline.dates.count, "no duplicates")
            if test.past == 0 {
                XCTAssertEqual(timeline.dates.count, test.present, "\(test.layer.rawValue): exactly the slots that exist, nothing added")
            } else {
                XCTAssertEqual(timeline.dates.count, test.past + 49, "\(test.layer.rawValue): past slots plus the latest run, nothing interpolated")
            }
            // The shortfall: one note at the oldest slot, covering what the window lacks; no other note anywhere.
            let lead = try XCTUnwrap(timeline.gaps.before(index: 0), "\(test.layer.rawValue): 'Davor fehlen Daten' at the oldest slot")
            XCTAssertEqual(lead.slots, test.expected - test.present, "\(test.layer.rawValue): the missing count from the history block")
            XCTAssertEqual(lead.to, oldest.addingTimeInterval(-Double(test.step) * 60))
            XCTAssertEqual(timeline.gaps.gaps.count, 1, "\(test.layer.rawValue): one gap, nothing else")
            XCTAssertTrue(timeline.gaps.inner.isEmpty, "\(test.layer.rawValue): no hole between slots")
            let noted = timeline.dates.indices.filter { !TimelineGapText.lines(for: $0, gaps: timeline.gaps).isEmpty }
            XCTAssertEqual(noted, [0], "\(test.layer.rawValue): the note appears at the oldest slot only (not restless)")
            XCTAssertEqual(TimelineGapText.lines(for: 0, gaps: timeline.gaps).count, 1)
        }
    }

    func testModelLayersAreNotPresentedAsCompleteAndForecastStaysSeparate() throws {
        for test in cases where test.past > 0 {
            let value = try manifest(test)
            let timeline = value.timeline(at: Self.queried, pastHours: nil)
            let reference = value.referenceTime
            let past = timeline.dates.filter { $0 < reference }
            XCTAssertEqual(past.count, 6, "\(test.layer.rawValue): only the 6 hours that exist, expected 72")
            XCTAssertEqual(timeline.backend?.slots.filter { $0.time < reference }.count, 6)
            let lead = try XCTUnwrap(timeline.gaps.before(index: 0))
            XCTAssertEqual(lead.slots, 66, "\(test.layer.rawValue): 66 of the 72 expected hours are named as missing")
            XCTAssertEqual(lead.from, reference.addingTimeInterval(-72 * 3600), "the window starts 72 h before the run")
            let slotTimes = Set(value.slots.map(\.time))
            XCTAssertTrue(timeline.dates.allSatisfy { slotTimes.contains($0) }, "every shown time is a real slot (no interpolation)")
        }
    }

    func testExplicitFortyEightHoursClipsTheMissingSpanButKeepsTheOldestSlot() throws {
        for test in cases where test.layer == .radarWorld || test.layer == .radarEU {
            let value = try manifest(test)
            let timeline = value.timeline(at: Self.queried, pastHours: 48)
            let reference = timeline.referenceTime
            let oldest = try XCTUnwrap(DWDRequest.date(test.oldest))
            let cutoff = reference.addingTimeInterval(-48 * 3600)
            XCTAssertEqual(timeline.dates.first, max(oldest, timeline.dates.first!), "no slot older than what exists")
            let lead = try XCTUnwrap(timeline.gaps.before(index: 0), "\(test.layer.rawValue): the source has less than 48 h as well")
            XCTAssertEqual(lead.from, cutoff, "the note starts at the chosen 48 h, not at 72 h")
            XCTAssertEqual(Double(lead.slots), oldest.timeIntervalSince(cutoff) / Double(test.step * 60), accuracy: 0.5)
        }
    }

    @MainActor func testStoreAcceptsTheNineProductionLayersAndRepeatedRefreshStaysQuiet() throws {
        let store = RadarLayerStore(radarBaseURL: radarBase, client: RadarLayerClient(radarBaseURL: radarBase, transport: { _ in throw URLError(.cancelled) }))
        for test in cases { store.apply(.fresh(try manifest(test)), to: test.layer, now: Self.queried) }
        for test in cases {
            XCTAssertEqual(store.availability(test.layer), .available, test.layer.rawValue)
            let snapshot = store.snapshot(test.layer)
            let timeline = try XCTUnwrap(snapshot.timeline)
            XCTAssertEqual(timeline.dates.first, DWDRequest.date(test.oldest), "\(test.layer.rawValue): reachable oldest slot")
            XCTAssertEqual(store.offeredHistoryHours(test.layer), 72)
            // Selection starts at "now" (the newest observation / the current model hour), not at the oldest slot.
            XCTAssertEqual(timeline.dates[snapshot.selectedFrame], timeline.referenceTime, test.layer.rawValue)
        }
        // A second refresh with the same data changes nothing (no restless notes, no moved selection).
        let before = store.snapshots
        for test in cases { store.apply(.fresh(try manifest(test)), to: test.layer, now: Self.queried.addingTimeInterval(60)) }
        XCTAssertEqual(store.snapshots.mapValues(\.selectedFrame), before.mapValues(\.selectedFrame))
        XCTAssertEqual(store.snapshots.mapValues { $0.timeline?.gaps }, before.mapValues { $0.timeline?.gaps })
    }

    func testRadarGermanyHistoryJsonOfSeventyTwoHoursIsCompleteAndTheStandardIsSeventyTwo() throws {
        let history = try RadarHistory.parse(fixture("history-radar"), baseURL: radarBase, now: Self.queried)
        XCTAssertEqual(history.slots.count, 864)
        XCTAssertEqual(history.info?.hours, 72)
        XCTAssertEqual(history.info?.complete, true)
        XCTAssertEqual(history.info?.gaps.count, 0)
        XCTAssertEqual(RadarPastWindow.standardHours(history: history), 72, "no stored choice: the backend's 72 h")
        let reference = try XCTUnwrap(DWDRequest.date("2026-11-20T09:45:00Z"))
        let slots = (0...12).map { index -> [String: Any] in
            let time = reference.addingTimeInterval(Double(index - 11) * 300)
            let iso = ISO8601DateFormatter().string(from: time)
            return ["time": iso, "kind": index <= 11 ? "analysis" : "forecast", "path": "20261120T0945Z/\(iso.replacingOccurrences(of: "-", with: "").replacingOccurrences(of: ":", with: "")).webp"]
        }
        let image = try XCTUnwrap(JSONSerialization.jsonObject(with: fixture("history-radar")) as? [String: Any])["image"] as Any
        let latestObject: [String: Any] = ["schema": 1, "run": "20261120T0945Z", "reference_time": "2026-11-20T09:45:00Z",
                                           "generated_at": "2026-11-20T09:50:26Z", "step_minutes": 5, "forecast_horizon_minutes": 60,
                                           "image": image, "slots": slots, "attribution": "Quelle: Deutscher Wetterdienst",
                                           "modification_notice": "Datenbasis: Deutscher Wetterdienst"]
        let latest = try RadarManifest.parse(JSONSerialization.data(withJSONObject: latestObject), baseURL: radarBase)
        let composed = RadarTimelineComposer.compose(latest: latest, history: history, hours: RadarPastWindow.standardHours(history: history)).timeline
        XCTAssertEqual(composed.dates.first, history.slots.first?.time, "the oldest history slot is reachable")
        XCTAssertTrue(composed.gaps.isEmpty, "864 of 864: no note")
        XCTAssertGreaterThan(composed.dates.count, 860)
    }
}
