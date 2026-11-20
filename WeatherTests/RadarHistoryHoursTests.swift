import CoreGraphics
import XCTest
@testable import Weather

// 48 or 72 hours of past for every map (backend PR #4, additive `history` block and `past_slots`).
// No network. The manifests are built here the way the backend documents them (docs-site/content/api.md of PR #4);
// the backend of today (no `history`, no `past_slots`) is covered by the fixtures of the other test classes
// and by the explicit "old backend" tests below.
final class RadarHistoryHoursTests: XCTestCase {
    let radarBase = URL(string: "https://radar.example.invalid/v1/radar/")!
    func base(_ layer: RadarLayer) -> URL { RadarBackendConfig.layersBaseURL(for: layer, radarBaseURL: radarBase) }

    static let reference = DWDRequest.date("2026-11-20T10:00:00Z")!
    var reference: Date { Self.reference }
    var berlin: Calendar { var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!; return calendar }

    // MARK: Builders

    private static func compact(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyyMMdd'T'HHmm'Z'"
        return formatter.string(from: date)
    }

    private static func iso(_ date: Date) -> String { DWDRequest.timestamp(date) }

    private static var imageBlock: [String: Any] { [
        "format": "image/webp", "width": 1024, "height": 1311, "projection": "EPSG:3857",
        "bbox": [612257.0, 5942074.0, 1736584.0, 7381298.0], "bbox_wgs84": [5.5, 47.0, 15.6, 55.1]] }

    /// Reported `history` block for the grid `hours` back from the reference (observation: `hours * 60 / step + 1` times).
    private func historyBlock(hours: Int, step: Int, present: Set<Int>, expected: Int, oldestIndex: Int?, gapsFrom first: Int = 0) -> [String: Any] {
        var gaps: [[String: Any]] = []
        var run: (from: Int, to: Int)?
        let start = reference.addingTimeInterval(-Double(hours) * 3600)
        func time(_ index: Int) -> Date { start.addingTimeInterval(Double(index * step * 60)) }
        for index in 0..<expected {
            if present.contains(index) {
                if let r = run { gaps.append(["from": Self.iso(time(r.from)), "to": Self.iso(time(r.to)), "slots": r.to - r.from + 1]); run = nil }
            } else if run == nil { run = (index, index) } else { run!.to = index }
        }
        if let r = run { gaps.append(["from": Self.iso(time(r.from)), "to": Self.iso(time(r.to)), "slots": r.to - r.from + 1]) }
        var block: [String: Any] = ["hours": hours, "expected": expected, "present": present.count,
                                    "complete": present.count == expected, "gaps": gaps]
        block["oldest"] = oldestIndex.map { Self.iso(time($0)) } ?? NSNull()
        return block
    }

    /// Observation layer (`radar_eu`: 5 minutes) with `hours` of past, grid index 0 = oldest. `missing` are grid indexes without image.
    func observationObject(hours: Int, step: Int = 5, missing: Set<Int> = [], oldestAvailableHours: Int? = nil,
                           withHistory: Bool = true, layer: String = "radar_eu") -> [String: Any] {
        let expected = hours * 60 / step + 1
        let start = reference.addingTimeInterval(-Double(hours) * 3600)
        let firstIndex = oldestAvailableHours.map { (hours - $0) * 60 / step } ?? 0
        let present = Set((firstIndex..<expected).filter { !missing.contains($0) })
        let run = Self.compact(reference)
        let slots = present.sorted().map { index -> [String: Any] in
            let time = start.addingTimeInterval(Double(index * step * 60))
            return ["time": Self.iso(time), "kind": "observation", "path": "\(Self.compact(time.addingTimeInterval(300)))/\(Self.compact(time)).webp"]
        }
        var object: [String: Any] = [
            "schema": 1, "layer": layer, "title": "Karte", "kind": "observation", "run": run,
            "reference_time": Self.iso(reference), "generated_at": Self.iso(reference.addingTimeInterval(120)),
            "step_minutes": step, "history_hours": hours, "image": Self.imageBlock, "slots": slots,
            "attribution": "Quelle: EUMETNET", "modification_notice": "umprojiziert"]
        if withHistory {
            object["history"] = historyBlock(hours: hours, step: step, present: present, expected: expected, oldestIndex: present.min())
        }
        return object
    }

    /// Model layer (`temperature`: hourly): `slots` = latest run (reference plus `forecastHours`), `past_slots` = one slot per
    /// past hour (`pastHours` back, up to one hour before the reference), the run start hours as `analysis`.
    func modelObject(pastHours: Int, forecastHours: Int = 48, missingPast: Set<Int> = [], withPast: Bool = true,
                     layer: String = "temperature") -> [String: Any] {
        let run = Self.compact(reference)
        let slots = (0...forecastHours).map { index -> [String: Any] in
            let time = reference.addingTimeInterval(Double(index) * 3600)
            return ["time": Self.iso(time), "kind": index == 0 ? "analysis" : "forecast", "path": "\(run)/\(Self.compact(time)).webp"]
        }
        let start = reference.addingTimeInterval(-Double(pastHours) * 3600)
        let presentIndexes = (0..<pastHours).filter { !missingPast.contains($0) }
        let past = presentIndexes.map { index -> [String: Any] in
            let time = start.addingTimeInterval(Double(index) * 3600)
            let runStart = time.addingTimeInterval(-Double(index % 3) * 3600)   // an earlier run (3-hourly run starts)
            return ["time": Self.iso(time), "kind": index % 3 == 0 ? "analysis" : "forecast", "path": "\(Self.compact(runStart))/\(Self.compact(time)).webp"]
        }
        var object: [String: Any] = [
            "schema": 1, "layer": layer, "title": "Modell", "kind": "forecast", "run": run,
            "reference_time": Self.iso(reference), "generated_at": Self.iso(reference.addingTimeInterval(120)),
            "step_minutes": 60, "forecast_horizon_minutes": forecastHours * 60, "image": Self.imageBlock,
            "slots": slots, "attribution": "Quelle: DWD", "modification_notice": "bildlich wiedergegeben", "source": "icon_d2", "scale": "t2m-d2-v1"]
        if withPast {
            object["history_hours"] = pastHours
            object["past_slots"] = past
            object["history"] = historyBlock(hours: pastHours, step: 60, present: Set(presentIndexes), expected: pastHours, oldestIndex: presentIndexes.min())
        }
        return object
    }

    private func data(_ object: [String: Any]) throws -> Data { try JSONSerialization.data(withJSONObject: object) }

    func parse(_ object: [String: Any], layer: RadarLayer = .radarEU) throws -> RadarLayerManifest {
        try RadarLayerManifest.parse(data(object), expected: layer, layersBaseURL: base(layer))
    }

    // MARK: 48 and 72 hours through manifest -> app (observation layers)

    func testSeventyTwoHoursOfFiveMinuteSlotsParse865TimesWithinTheSizeLimit() throws {
        let raw = try data(observationObject(hours: 72))
        XCTAssertLessThan(raw.count, RadarBackendConfig.maximumManifestBytes, "865 slots stay far below the manifest limit")
        let manifest = try RadarLayerManifest.parse(raw, expected: .radarEU, layersBaseURL: base(.radarEU))
        XCTAssertEqual(manifest.slots.count, 865)
        XCTAssertEqual(manifest.historyInfo?.hours, 72)
        XCTAssertEqual(manifest.historyInfo?.expected, 865)
        XCTAssertEqual(manifest.historyInfo?.present, 865)
        XCTAssertEqual(manifest.historyInfo?.complete, true)
        let timeline = manifest.timeline(at: reference.addingTimeInterval(200))
        XCTAssertEqual(timeline.dates.count, 865)
        XCTAssertEqual(timeline.dates.first, reference.addingTimeInterval(-72 * 3600), "the slider reaches the oldest slot")
        XCTAssertEqual(timeline.dates.last, reference)
        XCTAssertEqual(timeline.dates, timeline.dates.sorted())
        XCTAssertTrue(timeline.gaps.isEmpty, "a complete grid has no marks")
    }

    func testFortyEightHoursOfFiveMinuteSlotsParse577Times() throws {
        let manifest = try parse(observationObject(hours: 48))
        XCTAssertEqual(manifest.slots.count, 577)
        XCTAssertEqual(manifest.historyInfo?.expected, 577)
        XCTAssertEqual(manifest.timeline(at: reference).dates.first, reference.addingTimeInterval(-48 * 3600))
    }

    func testGapsOfTheBackendAndOfTheSlotsAgreeAndNothingIsInvented() throws {
        // 03:00 to 03:25 style hole in the middle (6 times) and a single missing time.
        let manifest = try parse(observationObject(hours: 72, missing: Set(400...405).union([700])))
        XCTAssertEqual(manifest.slots.count, 865 - 7, "missing times stay missing: no placeholder slots")
        let info = try XCTUnwrap(manifest.historyInfo)
        XCTAssertEqual(info.present, 858)
        XCTAssertFalse(info.complete)
        XCTAssertEqual(info.gaps.map(\.slots), [6, 1])
        let timeline = manifest.timeline(at: reference)
        XCTAssertEqual(timeline.dates.count, 858)
        let inner = timeline.gaps.inner
        XCTAssertEqual(inner.count, 2)
        XCTAssertEqual(inner.map(\.slots), [6, 1])
        // The hole lies between the slot before it and the next existing one.
        let hole = try XCTUnwrap(inner.first)
        XCTAssertEqual(timeline.dates[hole.afterIndex], reference.addingTimeInterval(-72 * 3600 + 399 * 300))
        XCTAssertEqual(timeline.dates[hole.afterIndex + 1], reference.addingTimeInterval(-72 * 3600 + 406 * 300))
        XCTAssertEqual(hole.from, reference.addingTimeInterval(-72 * 3600 + 400 * 300))
        XCTAssertEqual(hole.to, reference.addingTimeInterval(-72 * 3600 + 405 * 300))
        XCTAssertEqual(timeline.gaps.before(index: hole.afterIndex + 1), hole)
        XCTAssertEqual(timeline.gaps.after(index: hole.afterIndex), hole)
        XCTAssertNil(timeline.gaps.before(index: hole.afterIndex))
        XCTAssertNil(timeline.gaps.after(index: hole.afterIndex + 1))
    }

    func testSourceThatReachesBackLessFarShowsTheOldestRealSlotAndALeadingGap() throws {
        // Lightning style: the source delivers only 24 of the 72 hours.
        let manifest = try parse(observationObject(hours: 72, oldestAvailableHours: 24), layer: .radarEU)
        XCTAssertEqual(manifest.slots.count, 24 * 12 + 1)
        let info = try XCTUnwrap(manifest.historyInfo)
        XCTAssertEqual(info.oldest, reference.addingTimeInterval(-24 * 3600))
        XCTAssertEqual(info.gaps.count, 1)
        let timeline = manifest.timeline(at: reference)
        XCTAssertEqual(timeline.dates.first, reference.addingTimeInterval(-24 * 3600), "the oldest slot that really exists")
        let leading = try XCTUnwrap(timeline.gaps.before(index: 0))
        XCTAssertEqual(leading.afterIndex, -1)
        XCTAssertEqual(leading.from, reference.addingTimeInterval(-72 * 3600))
        XCTAssertEqual(leading.to, reference.addingTimeInterval(-24 * 3600 - 300))
        XCTAssertEqual(leading.slots, 48 * 12)
        XCTAssertTrue(timeline.gaps.inner.isEmpty)
    }

    func testTruncatedGapListStillShowsTheHolesVisibleInTheSlots() throws {
        var object = observationObject(hours: 72, missing: Set(stride(from: 10, to: 400, by: 2)))   // 195 single holes
        var block = try XCTUnwrap(object["history"] as? [String: Any])
        block["gaps"] = Array((block["gaps"] as! [[String: Any]]).prefix(100))
        block["gaps_truncated"] = true
        object["history"] = block
        let manifest = try parse(object)
        XCTAssertEqual(manifest.historyInfo?.gapsTruncated, true)
        XCTAssertEqual(manifest.timeline(at: reference).gaps.inner.count, 195, "the timeline derives its holes from the real slots")
    }

    // MARK: Malformed or unknown history data never breaks the layer

    func testMalformedHistoryBlocksFallBackToTheActualSlots() throws {
        let good = observationObject(hours: 48)
        let goodGaps: [[String: Any]] = [["from": "2026-11-19T10:00:00Z", "to": "2026-11-19T10:05:00Z", "slots": 2]]
        func block(_ change: [String: Any]) -> Any {
            var value: [String: Any] = ["hours": 48, "expected": 577, "present": 577, "complete": true, "gaps": [[String: Any]]()]
            for (key, entry) in change { value[key] = entry }
            return value
        }
        let hole: [String: Any] = ["from": "2026-11-19T11:00:00Z", "to": "2026-11-19T10:00:00Z", "slots": 3]
        let empty: [String: Any] = ["from": "2026-11-19T10:00:00Z", "to": "2026-11-19T10:05:00Z", "slots": 0]
        let cases: [(String, Any)] = [
            ("string", "kaputt"), ("null", NSNull()), ("array", [1, 2]),
            ("hours as text", block(["hours": "48"])), ("hours zero", block(["hours": 0])),
            ("negative expected", block(["expected": -1, "present": 0])),
            ("present above expected", block(["expected": 10, "present": 11])),
            ("gaps not a list", block(["gaps": "x"])),
            ("gap without dates", block(["present": 570, "complete": false, "gaps": [["slots": 3]]])),
            ("gap from after to", block(["present": 570, "complete": false, "gaps": [hole]])),
            ("gap with zero slots", block(["present": 570, "complete": false, "gaps": [empty]])),
            ("oldest not a date", block(["oldest": "gestern"])),
            ("complete not a bool", block(["complete": "yes", "gaps": goodGaps])),
        ]
        for (name, block) in cases {
            var object = good
            object["history"] = block
            let manifest = try parse(object)
            XCTAssertNil(manifest.historyInfo, name)
            XCTAssertEqual(manifest.slots.count, 577, "\(name): the layer stays usable")
            XCTAssertEqual(manifest.timeline(at: reference).dates.count, 577, name)
        }
    }

    func testUnknownFieldsAreIgnored() throws {
        var object = observationObject(hours: 48, missing: [100, 101])
        object["future_field"] = ["a": [1, 2, 3]]
        var block = try XCTUnwrap(object["history"] as? [String: Any])
        block["note"] = "später"
        var gaps = try XCTUnwrap(block["gaps"] as? [[String: Any]])
        gaps[0]["cause"] = "source"
        block["gaps"] = gaps
        object["history"] = block
        let manifest = try parse(object)
        XCTAssertEqual(manifest.slots.count, 575)
        XCTAssertEqual(manifest.historyInfo?.gaps.first?.slots, 2)
    }

    // MARK: Old backend (today's production): no `history`, no `past_slots`

    func testManifestWithoutHistoryBlockWorksAsBefore() throws {
        for (layer, hours, step) in [(RadarLayer.radarEU, 3, 5), (.radarWorld, 24, 10), (.lightning, 3, 5)] {
            var object = observationObject(hours: hours, step: step, withHistory: false)
            object["layer"] = layer.rawValue
            object.removeValue(forKey: "history_hours")
            let manifest = try parse(object, layer: layer)
            XCTAssertNil(manifest.historyInfo, layer.rawValue)
            XCTAssertEqual(manifest.slots.count, hours * 60 / step + 1)
            let timeline = manifest.timeline(at: reference)
            XCTAssertEqual(timeline.dates, manifest.slots.map(\.time), "the timeline is exactly the slots, as before")
            XCTAssertTrue(timeline.gaps.isEmpty)
        }
    }

    func testOldModelManifestWithoutPastSlotsShowsOnlyTheLatestRun() throws {
        let manifest = try parse(modelObject(pastHours: 72, withPast: false), layer: .temperature)
        XCTAssertEqual(manifest.slots.count, 49)
        XCTAssertNil(manifest.historyInfo)
        XCTAssertEqual(manifest.timeline(at: reference).dates.first, reference)
    }

    func testExistingFixturesStillParseUnchanged() throws {
        let bundle = Bundle(for: RadarHistoryHoursTests.self)
        for layer in [RadarLayer.lightning, .clouds, .pressure, .radarWorld, .cloudmask] {
            let url = try XCTUnwrap(bundle.url(forResource: "layer-\(layer.rawValue)", withExtension: "json", subdirectory: "Fixtures")
                ?? bundle.url(forResource: "layer-\(layer.rawValue)", withExtension: "json"))
            let manifest = try RadarLayerManifest.parse(Data(contentsOf: url), expected: layer, layersBaseURL: base(layer))
            XCTAssertNil(manifest.historyInfo, layer.rawValue)
            XCTAssertEqual(manifest.timeline(at: manifest.referenceTime).dates, manifest.slots.map(\.time), layer.rawValue)
        }
    }

    // MARK: Model layers: past valid times + latest run

    func testModelLayerTimelineIsPastSlotsPlusLatestRunAndPastStaysMeasurementFree() throws {
        let manifest = try parse(modelObject(pastHours: 72), layer: .temperature)
        XCTAssertEqual(manifest.slots.count, 72 + 49, "72 past valid times + the latest run")
        let now = reference.addingTimeInterval(1800)
        let timeline = manifest.timeline(at: now)
        XCTAssertEqual(timeline.dates.first, reference.addingTimeInterval(-72 * 3600))
        XCTAssertEqual(timeline.dates, timeline.dates.sorted())
        XCTAssertEqual(Set(timeline.dates).count, timeline.dates.count)
        XCTAssertEqual(timeline.referenceTime, reference, "now = the slot of the current hour; the forecast horizon stays separate")
        let referenceIndex = try XCTUnwrap(timeline.dates.firstIndex(of: reference))
        XCTAssertEqual(referenceIndex, 72)
        // Everything before the reference is past (model, never "Vorhersage"); everything after is forecast.
        for (index, date) in timeline.dates.enumerated() {
            XCTAssertEqual(ScreenGlow.isForecast(date: date, reference: timeline.referenceTime), index > referenceIndex)
        }
        XCTAssertEqual(RadarLayer.temperature.frameCaption(isForecast: false), "Modell")
        XCTAssertEqual(RadarLayer.temperature.frameCaption(isForecast: true), "Modellvorhersage")
        XCTAssertTrue(timeline.gaps.isEmpty)
    }

    func testModelLayerPastGapsAreMarkedAndLeadingGapShowsTheBuildUp() throws {
        // The past builds up from the deploy: only the newest 10 hours exist, plus one hole inside them.
        var object = modelObject(pastHours: 72, missingPast: Set(0..<62).union([66]))
        XCTAssertEqual((object["past_slots"] as? [[String: Any]])?.count, 9)
        object["history_hours"] = 72
        let manifest = try parse(object, layer: .temperature)
        let timeline = manifest.timeline(at: reference)
        XCTAssertEqual(timeline.dates.count, 9 + 49)
        XCTAssertEqual(timeline.dates.first, reference.addingTimeInterval(-10 * 3600))
        let leading = try XCTUnwrap(timeline.gaps.before(index: 0))
        XCTAssertEqual(leading.slots, 62)
        XCTAssertEqual(timeline.gaps.inner.map(\.slots), [1])
    }

    func testPastSlotsAreIgnoredAsAWholeWhenOneIsUnusable() throws {
        var object = modelObject(pastHours: 6)
        var past = try XCTUnwrap(object["past_slots"] as? [[String: Any]])
        past[2]["path"] = "../escape.webp"
        object["past_slots"] = past
        let manifest = try parse(object, layer: .temperature)
        XCTAssertEqual(manifest.slots.count, 49, "honest fallback: only the latest run, nothing half-trusted")
        var unsorted = try XCTUnwrap(modelObject(pastHours: 6)["past_slots"] as? [[String: Any]])
        unsorted.swapAt(1, 3)
        var other = modelObject(pastHours: 6)
        other["past_slots"] = unsorted
        XCTAssertEqual(try parse(other, layer: .temperature).slots.count, 49)
    }

    func testPastSlotAtTheSameTimeAsALatestSlotLosesAndObservationLayersIgnorePastSlots() throws {
        var object = modelObject(pastHours: 4)
        var past = try XCTUnwrap(object["past_slots"] as? [[String: Any]])
        past.append(["time": DWDRequest.timestamp(reference), "kind": "forecast", "path": "\(Self.compact(reference.addingTimeInterval(-7200)))/old.webp"])
        object["past_slots"] = past
        let manifest = try parse(object, layer: .temperature)
        XCTAssertEqual(manifest.slots.count, 4 + 49)
        XCTAssertEqual(manifest.slots.first { $0.time == reference }?.path.hasPrefix(Self.compact(reference)), true, "the latest run wins")

        var observation = observationObject(hours: 1)
        observation["past_slots"] = [["time": "2026-11-20T08:00:00Z", "kind": "observation", "path": "a/b.webp"]]
        XCTAssertEqual(try parse(observation).slots.count, 13)
    }

    // MARK: Store: the oldest real slot is reachable and shown with its own time

    @MainActor func testLayerStoreOffersTheOldestSlotAndKeepsTheSelectionAcrossRefresh() throws {
        let store = RadarLayerStore(radarBaseURL: radarBase, client: RadarLayerClient(radarBaseURL: radarBase, transport: { _ in throw URLError(.cancelled) }))
        store.setPastHours(72)
        let manifest = try parse(observationObject(hours: 72, missing: [5]))
        store.apply(.fresh(manifest), to: .radarEU, now: reference.addingTimeInterval(100))
        let snapshot = store.snapshot(.radarEU)
        let timeline = try XCTUnwrap(snapshot.timeline)
        XCTAssertEqual(timeline.dates.count, 864)
        XCTAssertEqual(snapshot.selectedFrame, timeline.dates.count - 1, "starts at now")
        store.setFrame(0, for: .radarEU)
        XCTAssertEqual(store.snapshot(.radarEU).selectedFrame, 0)
        XCTAssertEqual(timeline.dates[0], reference.addingTimeInterval(-72 * 3600), "oldest slot of the manifest")
        // Same manifest again (304): the selection on the oldest slot stays.
        store.apply(.fresh(manifest), to: .radarEU, now: reference.addingTimeInterval(160))
        XCTAssertEqual(store.snapshot(.radarEU).selectedFrame, 0)
    }

    // MARK: Slider, labels, time zone

    func testSliderReachesFirstAndLastOfAFullTimeline() {
        let count = 865
        var session = ScrubSession(touchX: 380, currentIndex: count - 1, trackWidth: 340, inset: 20, count: count)
        XCTAssertEqual(session.index, count - 1)
        XCTAssertEqual(session.update(x: -200, verticalDistance: 0, trackWidth: 340), 0, "drag to the left end = oldest slot")
        XCTAssertEqual(session.update(x: 600, verticalDistance: 0, trackWidth: 340), count - 1)
        // Fine stage: one finger width moves a few slots, never skips the end.
        var fine = ScrubSession(touchX: 20, currentIndex: 0, trackWidth: 340, inset: 20, count: count)
        XCTAssertEqual(fine.update(x: 20 + 34, verticalDistance: 200, trackWidth: 340), Int((34.0 / 340.0 * 864 * 0.1).rounded()))
        for value in [0.0, 0.4, 431.5, 864.0, 900.0, -3.0] {
            XCTAssertTrue((0..<count).contains(TimelineSlot.index(for: value, count: count)))
        }
    }

    func testOldestSlotIsLabelledWithItsOwnDayAndTimeAndTheKindOfValue() {
        let oldest = reference.addingTimeInterval(-72 * 3600)   // Tue 2026-11-17 11:00 in Berlin
        let german = TimelineAccessibility.value(date: oldest, isForecast: false, reference: reference, calendar: berlin,
                                                  locale: Locale(identifier: "de_DE"), caption: RadarLayer.radarEU.frameCaption(isForecast: false))
        XCTAssertEqual(german, "Di. 17. Nov., 11:00, Messung")
        let model = TimelineAccessibility.value(date: oldest, isForecast: false, reference: reference, calendar: berlin,
                                                locale: Locale(identifier: "de_DE"), caption: RadarLayer.temperature.frameCaption(isForecast: false))
        XCTAssertEqual(model, "Di. 17. Nov., 11:00, Modell")
        let future = TimelineAccessibility.value(date: reference.addingTimeInterval(7200), isForecast: true, reference: reference, calendar: berlin,
                                                 locale: Locale(identifier: "de_DE"), caption: RadarLayer.temperature.frameCaption(isForecast: true))
        XCTAssertEqual(future, "13:00, Modellvorhersage")
    }

    func testGapTextNamesTheMissingTimesAndStaysInSyncWithTheSlotAfterIt() throws {
        let manifest = try parse(observationObject(hours: 72, missing: Set(400...405)))
        let timeline = manifest.timeline(at: reference)
        let de = Locale(identifier: "de_DE")
        let hole = try XCTUnwrap(timeline.gaps.inner.first)
        // 400 * 5 min after -72 h = Tue 11:00 + 33 h 20 min = Wed 20:20 Berlin; to = 20:45.
        XCTAssertEqual(TimelineGapText.range(hole, calendar: berlin, locale: de), "20:20\u{2013}20:45")
        XCTAssertEqual(TimelineGapText.lines(for: hole.afterIndex + 1, gaps: timeline.gaps, calendar: berlin, locale: de),
                       ["Davor fehlen Daten: 20:20\u{2013}20:45"])
        XCTAssertEqual(TimelineGapText.lines(for: hole.afterIndex, gaps: timeline.gaps, calendar: berlin, locale: de),
                       ["Danach fehlen Daten: 20:20\u{2013}20:45"])
        XCTAssertEqual(TimelineGapText.lines(for: 0, gaps: timeline.gaps, calendar: berlin, locale: de), [])
        // A hole across midnight names both days.
        let overnight = try parse(observationObject(hours: 72, missing: Set(420...500))).timeline(at: reference)
        XCTAssertEqual(TimelineGapText.range(try XCTUnwrap(overnight.gaps.inner.first), calendar: berlin, locale: de), "Mi 22:00\u{2013}Do 04:40")
        XCTAssertEqual(TimelineGapText.lines(for: 3, gaps: .empty, calendar: berlin, locale: de), [])
    }

    func testAccessibilityValueAppendsTheGapLines() {
        let value = TimelineAccessibility.value(date: reference, isForecast: false, reference: reference, calendar: berlin,
                                                locale: Locale(identifier: "de_DE"), caption: "Messung", gapLines: ["Davor fehlen Daten: 20:20\u{2013}20:45"])
        XCTAssertEqual(value, "11:00, Messung. Davor fehlen Daten: 20:20\u{2013}20:45")
    }

    // MARK: History setting (radar Deutschland): 72 hours selectable where the server offers them

    func testPastSettingOffersSeventyTwoHoursOnlyWhereTheServerDelivers() {
        XCTAssertEqual(RadarPastWindow.options, [1, 2, 6, 12, 24, 48, 72])
        XCTAssertEqual(RadarPastWindow.label(72), "72 Stunden")
        XCTAssertTrue(RadarPastWindow.isUnavailable(72, direct: false, serverHours: 48), "today's server: 48 h")
        XCTAssertFalse(RadarPastWindow.isUnavailable(48, direct: false, serverHours: 48))
        XCTAssertFalse(RadarPastWindow.isUnavailable(72, direct: false, serverHours: 72), "PR #4 backend with HISTORY_HOURS=72")
        XCTAssertFalse(RadarPastWindow.isUnavailable(72, direct: false, serverHours: nil), "unknown: not greyed out")
        XCTAssertTrue(RadarPastWindow.isUnavailable(2, direct: true, serverHours: 72))
        XCTAssertFalse(RadarPastWindow.isUnavailable(1, direct: true, serverHours: nil))
        XCTAssertTrue(RadarPastWindow.isUnavailable(6, direct: false, serverHours: 3))
        XCTAssertFalse(RadarPastWindow.isUnavailable(1, direct: false, serverHours: 0), "the direct hour is always there")
    }

    func testPlaybackWindowStaysAtThreeHoursWhateverPastIsChosen() throws {
        let dates = try parse(observationObject(hours: 72)).timeline(at: reference).dates
        for hours in [1, 2, 6, 48, 72] {
            let start = PlaybackWindow.startIndex(dates: dates, reference: reference, pastHours: hours)
            XCTAssertEqual(dates[start], reference.addingTimeInterval(-Double(min(hours, 3)) * 3600), "\(hours) h")
        }
    }

    // MARK: history.json (radar Deutschland): 48 and 72 hours, block, composition

    private func latestRadarObject() -> [String: Any] {
        let slots = (0..<18).map { index -> [String: Any] in
            let time = reference.addingTimeInterval(Double(index - 11) * 300)
            return ["time": Self.iso(time), "kind": index <= 11 ? "analysis" : "forecast", "path": "\(Self.compact(reference))/\(Self.compact(time)).webp"]
        }
        return ["schema": 1, "run": Self.compact(reference), "reference_time": Self.iso(reference),
                "generated_at": Self.iso(reference.addingTimeInterval(190)), "step_minutes": 5, "forecast_horizon_minutes": 30,
                "image": Self.imageBlock, "slots": slots, "attribution": "Quelle: Deutscher Wetterdienst", "modification_notice": "Datenbasis: Deutscher Wetterdienst"]
    }

    /// `history.json` of the PR #4 backend: analyses `hours` back up to the slot before latest's first one.
    private func historyObject(hours: Int, missing: Set<Int> = [], oldestAvailableHours: Int? = nil, withBlock: Bool = true) -> [String: Any] {
        let last = reference.addingTimeInterval(-12 * 300)   // latest starts at reference - 55 min
        let expected = hours * 12 - 11
        let first = last.addingTimeInterval(-Double(expected - 1) * 300)
        let firstIndex = oldestAvailableHours.map { back in max(0, expected - (back * 12 - 11)) } ?? 0
        let present = Set((firstIndex..<expected).filter { !missing.contains($0) })
        let slots = present.sorted().map { index -> [String: Any] in
            let time = first.addingTimeInterval(Double(index) * 300)
            return ["time": Self.iso(time), "kind": "analysis", "path": "history/\(Self.compact(time)).webp"]
        }
        var gaps: [[String: Any]] = []
        var run: (Int, Int)?
        for index in 0..<expected {
            if present.contains(index) { if let r = run { gaps.append(["from": Self.iso(first.addingTimeInterval(Double(r.0) * 300)), "to": Self.iso(first.addingTimeInterval(Double(r.1) * 300)), "slots": r.1 - r.0 + 1]); run = nil } }
            else if run == nil { run = (index, index) } else { run!.1 = index }
        }
        if let r = run { gaps.append(["from": Self.iso(first.addingTimeInterval(Double(r.0) * 300)), "to": Self.iso(first.addingTimeInterval(Double(r.1) * 300)), "slots": r.1 - r.0 + 1]) }
        var object: [String: Any] = ["schema": 1, "run": Self.compact(reference), "generated_at": Self.iso(reference.addingTimeInterval(190)),
                                     "step_minutes": 5, "history_hours": hours, "image": Self.imageBlock, "slots": slots,
                                     "attribution": "Quelle: Deutscher Wetterdienst", "modification_notice": "Datenbasis: Deutscher Wetterdienst"]
        if withBlock {
            object["history"] = ["hours": hours, "oldest": present.min().map { Self.iso(first.addingTimeInterval(Double($0) * 300)) } ?? NSNull(),
                                 "expected": expected, "present": present.count, "complete": present.count == expected, "gaps": gaps] as [String: Any]
        }
        return object
    }

    func testHistoryJsonOfSeventyTwoHoursParsesComposesAndKeepsItsBlock() throws {
        let latest = try RadarManifest.parse(data(latestRadarObject()), baseURL: radarBase)
        let raw = try data(historyObject(hours: 72, missing: Set(100...105)))
        XCTAssertLessThan(raw.count, 4 * RadarBackendConfig.maximumManifestBytes)
        let history = try RadarHistory.parse(raw, baseURL: radarBase, now: reference.addingTimeInterval(200))
        XCTAssertEqual(history.historyHours, 72)
        XCTAssertEqual(history.info?.hours, 72)
        XCTAssertEqual(history.info?.expected, 72 * 12 - 11)
        XCTAssertEqual(history.info?.gaps.map(\.slots), [6])
        let merged = RadarTimelineComposer.compose(latest: latest, history: history, hours: 72)
        let timeline = merged.timeline
        XCTAssertEqual(timeline.dates.count, 72 * 12 - 11 - 6 + 18, "72 h of analyses (minus the hole) + latest")
        XCTAssertEqual(timeline.dates, timeline.dates.sorted())
        XCTAssertEqual(timeline.gaps.inner.map(\.slots), [6], "the hole of the source is visible, not interpolated")
        XCTAssertEqual(merged.history?.hours, 72)
        // Cut by the user's own choice: no gap claims about what the user chose not to see.
        let twoHours = RadarTimelineComposer.compose(latest: latest, history: history, hours: 2).timeline
        XCTAssertTrue(twoHours.gaps.isEmpty)
    }

    func testHistoryJsonOfFortyEightHoursWithAShorterSourceShowsALeadingGap() throws {
        let latest = try RadarManifest.parse(data(latestRadarObject()), baseURL: radarBase)
        let history = try RadarHistory.parse(data(historyObject(hours: 72, oldestAvailableHours: 30)), baseURL: radarBase, now: reference.addingTimeInterval(200))
        let timeline = RadarTimelineComposer.compose(latest: latest, history: history, hours: 72).timeline
        XCTAssertEqual(timeline.dates.first, history.info?.oldest, "the oldest slot that really exists")
        XCTAssertNotNil(timeline.gaps.before(index: 0), "what the server could not deliver is named")
        // Choosing only 24 h hides the shortfall: the oldest shown slot is not the oldest existing one.
        let day = RadarTimelineComposer.compose(latest: latest, history: history, hours: 24).timeline
        XCTAssertNil(day.gaps.before(index: 0))
    }

    func testMalformedHistoryBlockInHistoryJsonKeepsHistoryUsable() throws {
        var object = historyObject(hours: 48)
        object["history"] = ["hours": "viele"]
        object["future"] = true
        let history = try RadarHistory.parse(data(object), baseURL: radarBase, now: reference.addingTimeInterval(200))
        XCTAssertNil(history.info)
        XCTAssertEqual(history.slots.count, 48 * 12 - 11)
        let old = try RadarHistory.parse(data(historyObject(hours: 48, withBlock: false)), baseURL: radarBase, now: reference.addingTimeInterval(200))
        XCTAssertNil(old.info, "history.json of today's backend: no block")
    }

    // MARK: Prefetch window and memory with 865 slots

    private final class Probe: @unchecked Sendable {
        private let lock = NSLock(); private var urls: [URL] = []
        func add(_ url: URL) { lock.withLock { urls.append(url) } }
        var started: [URL] { lock.withLock { urls } }
    }
    private static let pixel: CGImage = CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!.makeImage()!

    func testPrefetchOrderWithLimitIsThePrefixOfTheFullOrderAndCheap() {
        for (selected, limit) in [(0, 61), (432, 61), (864, 61), (10, 5), (3, 1), (864, 2000)] {
            let full = RadarPrefetchPolicy.order(selected: selected, count: 865)
            XCTAssertEqual(RadarPrefetchPolicy.order(selected: selected, count: 865, limit: limit), Array(full.prefix(limit)), "\(selected)/\(limit)")
        }
        XCTAssertEqual(RadarPrefetchPolicy.order(selected: 900, count: 865, limit: 61), [])
        XCTAssertEqual(RadarPrefetchPolicy.order(selected: 0, count: 0, limit: 61), [])
    }

    func testPrefetchOfAFullManifestLoadsOnlyAWindowAroundTheSelectedSlot() async throws {
        let manifest = try parse(observationObject(hours: 72)).backend
        let cache = TileMemoryCache()
        let probe = Probe()
        let loader = BackendRadarLoader(manifest: manifest, cache: cache, trimsCache: false, fetch: { url in
            probe.add(url); return Data(count: 100_000)
        }, decode: { _ in Self.pixel })
        loader.prefetch(selected: 432) { true }
        for _ in 0..<300 where probe.started.count < RadarBackendPolicy.maximumPrefetchSlots { try await Task.sleep(for: .milliseconds(10)) }
        try await Task.sleep(for: .milliseconds(200))
        let fetched = Set(probe.started)
        XCTAssertEqual(fetched.count, RadarBackendPolicy.maximumPrefetchSlots, "a window, never all 865 images")
        let expected = Set(RadarPrefetchPolicy.order(selected: 432, count: 865, limit: RadarBackendPolicy.maximumPrefetchSlots).map { manifest.slots[$0].url })
        XCTAssertEqual(fetched, expected, "the slots around the selection")
        XCTAssertLessThanOrEqual(cache.count, RadarBackendPolicy.maximumPrefetchSlots)
        XCTAssertLessThanOrEqual(cache.byteCount, RadarBackendPolicy.maximumPrefetchSlots * 100_000, "about 6 MB of compressed images, not 50 MB")
        loader.cancelPrefetch()
    }

    func testMovingTheSelectionAbandonsTheOldWindowAndStartsTheNewOne() async throws {
        let manifest = try parse(observationObject(hours: 72)).backend
        let probe = Probe()
        let loader = BackendRadarLoader(manifest: manifest, cache: TileMemoryCache(), trimsCache: false, fetch: { url in
            probe.add(url); try await Task.sleep(for: .milliseconds(25)); return Data(count: 1000)
        }, decode: { _ in Self.pixel })
        loader.prefetch(selected: 0) { true }
        try await Task.sleep(for: .milliseconds(120))
        loader.prefetch(selected: 800) { true }
        try await Task.sleep(for: .milliseconds(700))
        loader.cancelPrefetch()
        try await Task.sleep(for: .milliseconds(150))
        let oldWindow = Set(RadarPrefetchPolicy.order(selected: 0, count: 865, limit: 61).map { manifest.slots[$0].url })
        let newWindow = Set(RadarPrefetchPolicy.order(selected: 800, count: 865, limit: 61).map { manifest.slots[$0].url })
        let fetched = probe.started
        XCTAssertLessThan(Set(fetched).intersection(oldWindow).count, 35, "the rest of the abandoned window is not fetched")
        XCTAssertGreaterThanOrEqual(Set(fetched).intersection(newWindow).count, 10, "the new window is served")
        XCTAssertTrue(Set(fetched).isSubset(of: oldWindow.union(newWindow)), "nothing outside both windows")
        let before = probe.started.count
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertEqual(probe.started.count, before, "after cancel nothing more starts")
    }

    func testDecodedAndCompressedMemoryStayBoundedWhileScrubbingThroughAllSlots() throws {
        let cache = TileMemoryCache()
        let decoded = DecodedImageCache()
        for index in 0..<865 {   // worst case: every slot of the 72 h manifest ends up in the caches one after the other
            let url = URL(string: "https://radar.example.invalid/v1/radar/h/\(index).webp")!
            cache.insertTrusted(Data(count: 100_000), for: url)
            decoded.insert(Self.pixel, for: url)
            XCTAssertLessThanOrEqual(cache.byteCount, 50_000_000)
            XCTAssertLessThanOrEqual(decoded.count, RadarBackendPolicy.decodedImageLimit)
        }
        XCTAssertEqual(cache.count, 500)
    }

    // MARK: Measurement of the per-step work with 865 slots (printed, bounded generously)

    func testPerStepWorkWithFullSeventyTwoHourManifestIsCheap() throws {
        let object = observationObject(hours: 72, missing: Set(stride(from: 20, to: 860, by: 9)))
        let raw = try data(object)
        let clock = ContinuousClock()
        func ms(_ duration: Duration) -> Double { Double(duration.components.seconds) * 1000 + Double(duration.components.attoseconds) / 1e15 }

        var manifest: RadarLayerManifest!
        let parseTime = try clock.measure { manifest = try RadarLayerManifest.parse(raw, expected: .radarEU, layersBaseURL: base(.radarEU)) }
        var timeline: RadarTimeline!
        let timelineTime = clock.measure { timeline = manifest.timeline(at: reference) }
        let count = timeline.dates.count

        let stepTime = clock.measure {   // what one slider position costs: slot lookup, index, window, gap lines, manifest compare
            for index in stride(from: 0, to: count, by: 1) {
                let date = timeline.dates[index]
                let slot = manifest.backend.slot(at: date)
                _ = slot.flatMap { manifest.backend.slots.firstIndex(of: $0) }
                _ = RadarPrefetchPolicy.order(selected: index, count: count, limit: RadarBackendPolicy.maximumPrefetchSlots)
                _ = timeline.dates.firstIndex(of: timeline.referenceTime)
                _ = TimelineGapText.lines(for: index, gaps: timeline.gaps, calendar: berlin, locale: Locale(identifier: "de_DE"))
                _ = manifest.backend == manifest.backend
            }
        }
        let perStep = ms(stepTime) / Double(count)
        NSLog("MESSUNG 865-Slots: parse %.2f ms (%d Bytes), timeline+gaps %.2f ms, je Reglerposition %.4f ms (%d Positionen, %d Luecken)",
              ms(parseTime), raw.count, ms(timelineTime), perStep, count, timeline.gaps.inner.count)
        XCTAssertEqual(count, 865 - 94)
        XCTAssertLessThan(ms(parseTime), 500, "one parse per poll")
        XCTAssertLessThan(ms(timelineTime), 100)
        XCTAssertLessThan(perStep, 2.0, "well below a 16 ms frame at 60 Hz")
    }
    // MARK: One setting "Maximale Vergangenheit" for EVERY layer (Lino: applies to all maps)

    private static let observationLayers: [(RadarLayer, Int)] = [(.radarEU, 5), (.radarWorld, 10), (.lightning, 5), (.clouds, 10), (.cloudmask, 15), (.cloudmaskVis, 10)]
    private static let modelLayers: [RadarLayer] = [.pressure, .pressureEU, .temperature, .dewpoint, .humidity]
    private static let steps = [1, 2, 6, 12, 24, 48, 72]

    func testChosenPastCutsEveryObservationLayer() throws {
        for (layer, step) in Self.observationLayers {
            let manifest = try parse(observationObject(hours: 72, step: step, layer: layer.rawValue), layer: layer)
            for hours in Self.steps {
                let timeline = manifest.timeline(at: reference, pastHours: hours)
                XCTAssertEqual(timeline.dates.first, reference.addingTimeInterval(-Double(hours) * 3600), "\(layer.rawValue) \(hours) h: oldest = chosen past")
                XCTAssertEqual(timeline.dates.count, hours * 60 / step + 1, "\(layer.rawValue) \(hours) h")
                XCTAssertEqual(timeline.dates.last, reference)
                XCTAssertEqual(timeline.backend?.slots.map(\.time), timeline.dates, "overlay and prefetch see only the reachable slots (\(layer.rawValue) \(hours) h)")
            }
            XCTAssertEqual(manifest.timeline(at: reference).dates.count, 72 * 60 / step + 1, "without a choice nothing is cut")
        }
    }

    func testChosenPastCutsEveryModelLayerAndKeepsTheForecastHorizon() throws {
        for layer in Self.modelLayers {
            let manifest = try parse(modelObject(pastHours: 72, layer: layer.rawValue), layer: layer)
            for hours in Self.steps {
                let timeline = manifest.timeline(at: reference.addingTimeInterval(1800), pastHours: hours)
                XCTAssertEqual(timeline.dates.first, reference.addingTimeInterval(-Double(hours) * 3600), "\(layer.rawValue) \(hours) h")
                XCTAssertEqual(timeline.dates.count, hours + 49, "\(layer.rawValue) \(hours) h: past + latest run")
                XCTAssertEqual(timeline.dates.last, reference.addingTimeInterval(48 * 3600), "forecast horizon untouched")
                XCTAssertEqual(timeline.referenceTime, reference)
            }
        }
    }

    func testLeadingGapIsClippedToTheChosenPast() throws {
        // The source reaches back 24 h of the 72 h the server reports (lightning style).
        let manifest = try parse(observationObject(hours: 72, oldestAvailableHours: 24, layer: "lightning"), layer: .lightning)
        let oldest = reference.addingTimeInterval(-24 * 3600)
        for (hours, from, slots) in [(72, -72, 576), (48, -48, 288)] {
            let timeline = manifest.timeline(at: reference, pastHours: hours)
            XCTAssertEqual(timeline.dates.first, oldest, "\(hours) h: the oldest slot that exists")
            let gap = try XCTUnwrap(timeline.gaps.before(index: 0), "\(hours) h: the shortfall is named")
            XCTAssertEqual(gap.from, reference.addingTimeInterval(Double(from) * 3600), "\(hours) h: starts at the chosen past, not at the server window")
            XCTAssertEqual(gap.to, oldest.addingTimeInterval(-300))
            XCTAssertEqual(gap.slots, slots)
        }
        for hours in [24, 12, 2] {
            XCTAssertNil(manifest.timeline(at: reference, pastHours: hours).gaps.before(index: 0), "\(hours) h: the source delivers all that was chosen")
        }
        XCTAssertNotEqual(manifest.timeline(at: reference, pastHours: 72).gaps.gaps.first,
                          manifest.timeline(at: reference, pastHours: 48).gaps.gaps.first, "48 and 72 differ in the result")
    }

    func testModelLayerBuildUpGapFollowsTheChosenPast() throws {
        let manifest = try parse(modelObject(pastHours: 72, missingPast: Set(0..<62), layer: "temperature"), layer: .temperature)   // 10 hours exist
        for (hours, slots) in [(72, 62), (48, 38), (24, 14)] {
            let timeline = manifest.timeline(at: reference, pastHours: hours)
            XCTAssertEqual(timeline.dates.first, reference.addingTimeInterval(-10 * 3600), "\(hours) h")
            XCTAssertEqual(timeline.gaps.before(index: 0)?.slots, slots, "\(hours) h")
        }
        let six = manifest.timeline(at: reference, pastHours: 6)
        XCTAssertEqual(six.dates.first, reference.addingTimeInterval(-6 * 3600))
        XCTAssertNil(six.gaps.before(index: 0), "6 h are all there")
    }

    func testRadarGermanyHistoryGapIsClippedToo() throws {
        let latest = try RadarManifest.parse(data(latestRadarObject()), baseURL: radarBase)
        let history = try RadarHistory.parse(data(historyObject(hours: 72, oldestAvailableHours: 30)), baseURL: radarBase, now: reference.addingTimeInterval(200))
        let seventyTwo = RadarTimelineComposer.compose(latest: latest, history: history, hours: 72).timeline
        let fortyEight = RadarTimelineComposer.compose(latest: latest, history: history, hours: 48).timeline
        XCTAssertEqual(seventyTwo.gaps.before(index: 0)?.from, reference.addingTimeInterval(-72 * 3600))
        XCTAssertEqual(fortyEight.gaps.before(index: 0)?.from, reference.addingTimeInterval(-48 * 3600), "clipped to the chosen 48 h")
        XCTAssertEqual(fortyEight.dates.first, seventyTwo.dates.first, "same oldest slot: the source has 30 h")
    }

    func testOfferedHistoryHoursComeFromTheLayerNotFromAGuess() throws {
        XCTAssertEqual(try parse(observationObject(hours: 72)).offeredHistoryHours, 72, "history.hours")
        var old = observationObject(hours: 3, withHistory: false)   // today's backend: only history_hours
        XCTAssertEqual(try parse(old).offeredHistoryHours, 3)
        old.removeValue(forKey: "history_hours")                      // not even that: the span actually present
        XCTAssertEqual(try parse(old).offeredHistoryHours, 3)
        XCTAssertEqual(try parse(modelObject(pastHours: 72, withPast: false), layer: .temperature).offeredHistoryHours, 0, "nothing of the past yet")
        XCTAssertEqual(try parse(modelObject(pastHours: 72), layer: .temperature).offeredHistoryHours, 72)
    }

    @MainActor func testLayerStoreAppliesTheSettingToEveryLayerAndKeepsTheInstant() throws {
        let store = RadarLayerStore(radarBaseURL: radarBase, client: RadarLayerClient(radarBaseURL: radarBase, transport: { _ in throw URLError(.cancelled) }))
        XCTAssertNil(store.pastHours, "no choice: every layer shows what its own server window offers")
        let now = reference.addingTimeInterval(100)
        store.apply(.fresh(try parse(observationObject(hours: 72))), to: .radarEU, now: now)
        store.apply(.fresh(try parse(observationObject(hours: 72, step: 5, layer: "lightning"), layer: .lightning)), to: .lightning, now: now)
        store.apply(.fresh(try parse(modelObject(pastHours: 72, layer: "pressure"), layer: .pressure)), to: .pressure, now: now)
        XCTAssertEqual(store.snapshot(.radarEU).timeline?.dates.count, 865)
        XCTAssertEqual(store.snapshot(.lightning).timeline?.dates.count, 865)
        XCTAssertEqual(store.snapshot(.pressure).timeline?.dates.count, 72 + 49)
        store.setPastHours(48)
        XCTAssertEqual(store.snapshot(.radarEU).timeline?.dates.count, 577)
        XCTAssertEqual(store.snapshot(.lightning).timeline?.dates.count, 577)
        XCTAssertEqual(store.snapshot(.pressure).timeline?.dates.count, 48 + 49)
        XCTAssertEqual(store.snapshot(.radarEU).timeline?.dates[store.snapshot(.radarEU).selectedFrame], reference, "stays on now")
        store.setFrame(0, for: .radarEU)   // oldest slot of 48 h
        store.setPastHours(72)
        let wide = try XCTUnwrap(store.snapshot(.radarEU).timeline)
        XCTAssertEqual(wide.dates.count, 865)
        XCTAssertEqual(wide.dates[store.snapshot(.radarEU).selectedFrame], reference.addingTimeInterval(-48 * 3600), "the chosen instant is kept when the window grows")
        store.setPastHours(24)
        XCTAssertEqual(store.snapshot(.radarEU).selectedFrame, 0, "an instant outside the narrower window goes to its oldest slot")
        XCTAssertEqual(store.offeredHistoryHours(.radarEU), 72)
        XCTAssertNil(store.offeredHistoryHours(.clouds), "no data: not guessed")
    }

    @MainActor func testWeatherStoreHandsTheSettingToTheLayersAndReportsTheActiveMapsOffer() throws {
        let layers = RadarLayerStore(radarBaseURL: radarBase, client: RadarLayerClient(radarBaseURL: radarBase, transport: { _ in throw URLError(.cancelled) }))
        let defaults = UserDefaults(suiteName: "ShowerNowTests-\(UUID().uuidString)")!
        defaults.set(48, forKey: RadarPastWindow.defaultsKey)
        let store = WeatherStore(client: DWDClient(transport: { _ in throw URLError(.notConnectedToInternet) }), defaults: defaults, layers: layers)
        XCTAssertEqual(layers.pastHours, 48, "the stored choice reaches the layers at start")
        store.setPastHours(72)
        XCTAssertEqual(layers.pastHours, 72)
        layers.apply(.fresh(try parse(observationObject(hours: 48, layer: "lightning"), layer: .lightning)), to: .lightning, now: reference.addingTimeInterval(100))
        XCTAssertTrue(layers.select(.lightning))
        XCTAssertEqual(store.activeServerHistoryHours, 48, "the active layer's own offer")
        XCTAssertTrue(RadarPastWindow.isUnavailable(72, direct: false, serverHours: store.activeServerHistoryHours))
        XCTAssertFalse(RadarPastWindow.isUnavailable(48, direct: false, serverHours: store.activeServerHistoryHours))
    }

    // MARK: Default window from the backend (no stored choice), explicit choice wins, old backends

    @MainActor func testLayerWithoutChoiceReachesTheOldestSlotOfThe48Or72HourBackend() throws {
        for hours in [48, 72] {
            for (layer, step) in Self.observationLayers {
                let store = RadarLayerStore(radarBaseURL: radarBase, client: RadarLayerClient(radarBaseURL: radarBase, transport: { _ in throw URLError(.cancelled) }))
                store.apply(.fresh(try parse(observationObject(hours: hours, step: step, layer: layer.rawValue), layer: layer)), to: layer, now: reference.addingTimeInterval(100))
                let timeline = try XCTUnwrap(store.snapshot(layer).timeline)
                XCTAssertEqual(timeline.dates.first, reference.addingTimeInterval(-Double(hours) * 3600), "\(layer.rawValue) \(hours) h: first open reaches the oldest slot")
                XCTAssertEqual(timeline.dates.count, hours * 60 / step + 1, "\(layer.rawValue) \(hours) h")
            }
            for layer in Self.modelLayers {
                let store = RadarLayerStore(radarBaseURL: radarBase, client: RadarLayerClient(radarBaseURL: radarBase, transport: { _ in throw URLError(.cancelled) }))
                store.apply(.fresh(try parse(modelObject(pastHours: hours, layer: layer.rawValue), layer: layer)), to: layer, now: reference.addingTimeInterval(1800))
                XCTAssertEqual(store.snapshot(layer).timeline?.dates.first, reference.addingTimeInterval(-Double(hours) * 3600), "\(layer.rawValue) \(hours) h")
            }
        }
    }

    @MainActor func testExplicitChoiceWinsOverTheLayersOwnWindowAndStandardComesBack() throws {
        let store = RadarLayerStore(radarBaseURL: radarBase, client: RadarLayerClient(radarBaseURL: radarBase, transport: { _ in throw URLError(.cancelled) }))
        store.apply(.fresh(try parse(observationObject(hours: 72))), to: .radarEU, now: reference.addingTimeInterval(100))
        store.setPastHours(2)
        XCTAssertEqual(store.snapshot(.radarEU).timeline?.dates.count, 25, "an explicit 2 h is not the same as no choice")
        store.setPastHours(48)
        XCTAssertEqual(store.snapshot(.radarEU).timeline?.dates.count, 577)
        store.setPastHours(nil)
        XCTAssertNil(store.pastHours)
        XCTAssertEqual(store.snapshot(.radarEU).timeline?.dates.count, 865, "back to the standard: the layer's own window")
    }

    @MainActor func testOldBackendManifestsShowTheirActualSpanWithoutAChoice() throws {
        // Today's production: radar_eu 3 h, radar_world 24 h (10 min grid), model layer without past slots, no history block.
        let cases: [(RadarLayer, [String: Any], Int)] = [
            (.radarEU, observationObject(hours: 3, withHistory: false), 37),
            (.radarWorld, observationObject(hours: 24, step: 10, withHistory: false, layer: "radar_world"), 145),
            (.temperature, modelObject(pastHours: 0, withPast: false), 49)]
        for (layer, object, count) in cases {
            let store = RadarLayerStore(radarBaseURL: radarBase, client: RadarLayerClient(radarBaseURL: radarBase, transport: { _ in throw URLError(.cancelled) }))
            store.apply(.fresh(try parse(object, layer: layer)), to: layer, now: reference.addingTimeInterval(100))
            XCTAssertEqual(store.snapshot(layer).timeline?.dates.count, count, "\(layer.rawValue): the span that exists, neither cut nor stretched")
            XCTAssertNil(store.snapshot(layer).timeline?.gaps.before(index: 0), "no invented hint")
        }
    }

    // Radar Deutschland through the store: history.json decides the standard window.

    @MainActor private func radarStore(storedChoice: Int? = nil, historyHours: Int?, withBlock: Bool = true, oldestAvailableHours: Int? = nil,
                            rawDefaults: [String: Any] = [:]) throws -> (WeatherStore, RadarBackendTests.Script, UserDefaults) {
        let name = "ShowerNowTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        addTeardownBlock { UserDefaults(suiteName: name)?.removePersistentDomain(forName: name) }
        if let storedChoice { RadarPastWindow.save(storedChoice, to: defaults) }
        for (key, value) in rawDefaults { defaults.set(value, forKey: key) }
        let history: RadarBackendTests.Script.Reply = historyHours.map {
            .init(status: 200, body: (try? data(historyObject(hours: $0, oldestAvailableHours: oldestAvailableHours, withBlock: withBlock))) ?? Data(), etag: "\"h\"")
        } ?? .init(status: 404)
        let script = RadarBackendTests.Script([.init(status: 200, body: try data(latestRadarObject()), etag: "\"a\"")], history: [history])
        let backend = RadarBackendClient(baseURL: radarBase, transport: { try script.next($0) }, clock: { [reference] in reference.addingTimeInterval(300) })
        let store = WeatherStore(client: DWDClient(transport: { _ in throw URLError(.notConnectedToInternet) }), backend: backend, defaults: defaults)
        return (store, script, defaults)
    }

    @MainActor private func settle(_ store: WeatherStore, until condition: @MainActor () -> Bool) async {
        for _ in 0..<500 where !condition() { try? await Task.sleep(for: .milliseconds(10)) }
    }

    @MainActor func testFreshInstallReachesTheOldestSlotOfA48Or72HourRadarHistory() async throws {
        for hours in [48, 72] {
            let (store, script, _) = try radarStore(historyHours: hours)
            await store.refresh()
            XCTAssertNil(store.pastChoice, "nothing chosen yet")
            XCTAssertEqual(store.radarSource, .cache)
            XCTAssertEqual(store.timeline?.dates.first, reference.addingTimeInterval(-Double(hours) * 3600), "\(hours) h: first open reaches the oldest slot")
            XCTAssertEqual(store.pastHours, hours, "the effective window is the backend's")
            XCTAssertEqual(store.historyStatus, .loaded(hours: hours))
            XCTAssertEqual(script.historyRequests.count, 1, "one history request, as before")
            XCTAssertEqual(store.frameDate, reference, "still starts at now")
        }
    }

    @MainActor func testStoredChoiceWinsOverTheBackendWindowAlsoTwoHours() async throws {
        for (choice, history, expectedFirst) in [(2, 72, -2.0), (48, 72, -48.0), (72, 48, -48.0), (6, 48, -6.0)] {
            let (store, _, _) = try radarStore(storedChoice: choice, historyHours: history)
            await store.refresh()
            XCTAssertEqual(store.pastChoice, choice)
            XCTAssertEqual(store.pastHours, choice)
            XCTAssertEqual(store.timeline?.dates.first, reference.addingTimeInterval(expectedFirst * 3600),
                           "choice \(choice) h with a \(history) h backend: the choice decides (shows what exists)")
        }
    }

    @MainActor func testOldRadarBackendKeepsTodaysTwoHoursAndNeverGuessesMore() async throws {
        // history.json without the block (today's production), and no history.json at all.
        for historyHours in [48 as Int?, nil] {
            let (store, _, _) = try radarStore(historyHours: historyHours, withBlock: false)
            await store.refresh()
            XCTAssertNil(store.pastChoice)
            XCTAssertEqual(store.pastHours, RadarPastWindow.defaultHours, "without a block the standard stays 2 h")
            let first = try XCTUnwrap(store.timeline?.dates.first)
            XCTAssertEqual(first, reference.addingTimeInterval(historyHours == nil ? -55 * 60 : -2 * 3600), "history \(String(describing: historyHours))")
        }
    }

    @MainActor func testMigrationOnlyAStoredValidValueCountsAsAChoice() async throws {
        // Build 50/52 write radarPastHours only when the user picks a step: a stored value IS a choice (also 2).
        for (raw, expected) in [(2, 2 as Int?), (24, 24), (72, 72), (5, nil), (0, nil), (-1, nil)] {
            let (store, _, defaults) = try radarStore(historyHours: 72, rawDefaults: [RadarPastWindow.defaultsKey: raw])
            XCTAssertEqual(store.pastChoice, expected, "stored \(raw)")
            XCTAssertEqual(RadarPastWindow.choice(defaults), expected, "stored \(raw)")
            if expected == nil { XCTAssertEqual(defaults.integer(forKey: RadarPastWindow.defaultsKey), raw, "an unusable value is left alone, not rewritten") }
        }
        let (text, _, textDefaults) = try radarStore(historyHours: 72, rawDefaults: [RadarPastWindow.defaultsKey: "48"])
        XCTAssertEqual(text.pastChoice, 48, "a launch argument arrives as text")
        XCTAssertEqual(RadarPastWindow.choice(textDefaults), 48)
        let (corrupt, _, defaults) = try radarStore(historyHours: 72, rawDefaults: [RadarPastWindow.defaultsKey: "abc"])
        XCTAssertNil(corrupt.pastChoice)
        XCTAssertNil(RadarPastWindow.choice(defaults))
        let (never, _, none) = try radarStore(historyHours: 72)
        XCTAssertNil(never.pastChoice)
        XCTAssertNil(none.object(forKey: RadarPastWindow.defaultsKey), "starting the app writes nothing")
    }

    @MainActor func testPickingTheStepThatEqualsTheStandardStillStoresAChoiceAndStandardClearsIt() async throws {
        let (store, _, defaults) = try radarStore(historyHours: 72)
        await store.refresh()
        store.setPastHours(72)   // equals the effective window, but is now an explicit choice
        XCTAssertEqual(store.pastChoice, 72)
        XCTAssertEqual(defaults.integer(forKey: RadarPastWindow.defaultsKey), 72)
        XCTAssertEqual(store.layers.pastHours, 72)
        store.setPastHours(2)
        await settle(store) { store.timeline?.dates.first == self.reference.addingTimeInterval(-2 * 3600) }
        XCTAssertEqual(store.timeline?.dates.first, reference.addingTimeInterval(-2 * 3600))
        store.usePastDefault()
        XCTAssertNil(store.pastChoice)
        XCTAssertNil(defaults.object(forKey: RadarPastWindow.defaultsKey), "back to the standard: nothing stored")
        XCTAssertNil(store.layers.pastHours)
        await settle(store) { store.timeline?.dates.first == self.reference.addingTimeInterval(-72 * 3600) }
        XCTAssertEqual(store.timeline?.dates.first, reference.addingTimeInterval(-72 * 3600), "the 72 h of the backend again")
        XCTAssertEqual(store.pastHours, 72)
    }

    @MainActor func testStoreHandsAStoredChoiceToTheLayersAndNoChoiceAsStandard() throws {
        let (stored, _, _) = try radarStore(storedChoice: 24, historyHours: 72)
        XCTAssertEqual(stored.layers.pastHours, 24)
        let (fresh, _, _) = try radarStore(historyHours: 72)
        XCTAssertNil(fresh.layers.pastHours)
    }
}
