import XCTest

/// 48/72 hours of past on the time slider: oldest slot reachable with its own day and time, holes named and marked,
/// way back to "now". Debug stubs only (no network): `-UITestRadarHistoryHours 72` (radar Deutschland, `history.json` like the
/// backend of PR #4) and `-UITestLayers all -UITestHistoryHours 72` (layers with `history` block and `past_slots`).
/// Appearance comes from outside (`xcrun simctl ui <udid> appearance light|dark` plus `TEST_RUNNER_SHOT_SUFFIX`), screenshots go to
/// `/private/tmp/claude-501/hist-shots` for the visual check.
@MainActor
final class RadarHistoryUITests: XCTestCase {
    private var suffix: String {
        ProcessInfo.processInfo.environment["SHOT_SUFFIX"] ?? (XCUIDevice.shared.appearance == .dark ? "dark" : "light")
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    private func shot(_ app: XCUIApplication, _ name: String, darkLimit: Double = 0.45) {
        sleep(1)
        let dir = "/private/tmp/claude-501/hist-shots"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let screenshot = app.screenshot()
        let luminance = UITestLaunch.meanLuminance(screenshot.image)
        print("LUMA hist-\(name)-\(suffix)=\(luminance)")
        if suffix == "dark" { XCTAssertLessThan(luminance, darkLimit, "dark screenshot expected, luminance \(luminance)") }
        try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("hist-\(name)-\(suffix).png"))
    }

    private func launchRadar(hours: Int, extra: [String] = []) -> XCUIApplication {
        let app = UITestLaunch.app(extra: UITestLaunch.setAppearance(suffix == "dark" ? .dark : .light, extra: [
            "-UITestForecast", "current", "-UITestRadar", "fixture", "-UITestRadarHistoryHours", "\(hours)",
            "-radarPastHours", "\(hours)"] + extra))
        app.launch()
        return app
    }

    private func launchLayers(hours: Int) -> XCUIApplication {
        let app = UITestLaunch.app(extra: UITestLaunch.setAppearance(suffix == "dark" ? .dark : .light, extra: [
            "-UITestForecast", "current", "-UITestLayers", "all", "-UITestHistoryHours", "\(hours)"]))
        app.launch()
        let menu = app.buttons["radar-layer-menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 30))
        sleep(2)
        menu.tap()   // the stubbed layers are reported after the first probe
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5)).tap()
        sleep(1)
        return app
    }

    private func slider(_ app: XCUIApplication) -> XCUIElement {
        let slider = app.sliders.firstMatch
        XCTAssertTrue(slider.waitForExistence(timeout: 40), "time slider")
        return slider
    }

    private func value(_ slider: XCUIElement) -> String { (slider.value as? String) ?? "" }

    /// Waits until the slider value satisfies `predicate` (the map and labels follow with a short delay).
    private func waitValue(_ slider: XCUIElement, _ predicate: (String) -> Bool, timeout: TimeInterval = 15) -> Bool {
        let end = Date().addingTimeInterval(timeout)
        while Date() < end {
            if predicate(value(slider)) { return true }
            usleep(300_000)
        }
        return predicate(value(slider))
    }


    /// The slider is an accessibility representation over a custom drag control, so `adjust(toNormalizedSliderPosition:)` does not
    /// work. A touch on the track jumps there (like a normal slider): `fraction` 0 = oldest slot, 1 = newest (clamped at the ends).
    private func jump(_ slider: XCUIElement, fraction: Double) {
        let width = Double(slider.frame.width)
        let x = min(max((20 + fraction * (width - 40)) / width, 0.004), 0.996)
        slider.coordinate(withNormalizedOffset: CGVector(dx: x, dy: 0.5)).press(forDuration: 0.05)
        usleep(500_000)
    }

    /// Touches around `fraction` in steps of a fraction of a slot until `found` is true (a hole sits between two single slots).
    @discardableResult
    private func seek(_ slider: XCUIElement, near fraction: Double, slots: Int, found: () -> Bool) -> Bool {
        let step = 0.4 / Double(max(slots - 1, 1))
        for k in 0..<24 {
            let offset = Double((k + 1) / 2) * step * (k % 2 == 0 ? 1 : -1)
            // A touch within 22 pt of the thumb keeps the current slot (grab radius): go to the far end first, then to the target.
            slider.coordinate(withNormalizedOffset: CGVector(dx: fraction < 0.5 ? 0.99 : 0.01, dy: 0.5)).press(forDuration: 0.05)
            jump(slider, fraction: fraction + offset)
            if found() { return true }
        }
        return false
    }

    /// Entry of the nested "Regen" submenu (exact group label: "Regen am ausgewählten Ort" is another button).
    private func chooseRain(_ app: XCUIApplication, _ prefix: String) throws {
        let menu = app.buttons["radar-layer-menu"]
        let rain = app.buttons.matching(NSPredicate(format: "label == %@", "Regen")).firstMatch
        let entry = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
        for _ in 0..<4 {
            menu.tap()
            if rain.waitForExistence(timeout: 3) { rain.tap() }
            if entry.waitForExistence(timeout: 3), entry.isEnabled {
                entry.tap()
                if entry.waitForNonExistence(timeout: 3) { sleep(2); return }
            }
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5)).tap()
            sleep(2)
        }
        XCTFail("\(prefix) ließ sich nicht wählen")
    }

    private func gapNote(_ app: XCUIApplication) -> XCUIElement { app.descendants(matching: .any).matching(identifier: "radar-gap-note").firstMatch }

    // MARK: Radar Deutschland, 72 hours

    func testRadarSeventyTwoHoursOldestSlotHoleAndWayBack() throws {
        let app = launchRadar(hours: 72)
        let slider = slider(app)
        XCTAssertTrue(waitValue(slider) { $0.hasSuffix("Messung") || $0.contains("Messung") }, "starts at now: \(value(slider))")
        let nowValue = value(slider)
        XCTAssertFalse(gapNote(app).exists, "no hole next to now")
        shot(app, "radar72-1-jetzt")

        // Oldest slot: reference 2026-11-18 08:40 UTC minus 72 h = Sunday 15 Nov, 09:40 in Berlin.
        jump(slider, fraction: 0)
        XCTAssertTrue(waitValue(slider) { $0.hasPrefix("So. 15. Nov., 09:40, Messung") }, "oldest slot: \(value(slider))")
        XCTAssertFalse(gapNote(app).exists, "the source reaches back the full 72 h: no note at the oldest slot")
        shot(app, "radar72-2-aeltester-slot")

        // The hole of 6 times: slot before (index 424) or after (index 425) it names it. 882 slots in total (845 + 37).
        // 72 h: history 845 slots (hole 6 + 1 missing) + 37 latest = 876 positions; the 6-hole lies in the middle of history.
        XCTAssertTrue(seek(slider, near: 0.48, slots: 876) { value(slider).contains("fehlen Daten") }, "a slot next to a hole: \(value(slider))")
        XCTAssertTrue(gapNote(app).waitForExistence(timeout: 10), "note next to the hole: \(value(slider))")
        XCTAssertTrue(gapNote(app).label.contains("fehlen Daten"), "note text: \(gapNote(app).label)")
        XCTAssertTrue(value(slider).contains("fehlen Daten"), "VoiceOver value names the hole: \(value(slider))")
        shot(app, "radar72-3-luecke")

        // Back to now: the pill's long press jumps there.
        app.buttons["radar-frame-label"].press(forDuration: 0.8)
        XCTAssertTrue(waitValue(slider) { $0 == nowValue }, "back at now: \(value(slider)) vs \(nowValue)")
        XCTAssertTrue(gapNote(app).waitForNonExistence(timeout: 10))
        shot(app, "radar72-4-zurueck")
        app.terminate()
    }

    // MARK: Setting "Maximale Vergangenheit": 72 hours

    private func openInfoSheet(_ app: XCUIApplication) {
        let info = app.buttons["Datenquellen und Datenschutz"]
        XCTAssertTrue(info.waitForExistence(timeout: 30))
        info.tap()
    }

    /// The step 72 is offered; it is selectable when the server reports 72 hours (history.json) and greyed out when it reports 48.
    func testSeventyTwoHoursSelectableOnlyWhereTheServerDeliversThem() throws {
        for (serverHours, selectable) in [(72, true), (48, false)] {
            let app = launchRadar(hours: serverHours)
            XCTAssertTrue(waitValue(slider(app)) { $0.contains("Messung") })
            openInfoSheet(app)
            let entry = app.buttons["Maximale Vergangenheit"]
            XCTAssertTrue(entry.waitForExistence(timeout: 10), "entry Maximale Vergangenheit")
            entry.tap()
            let row = app.descendants(matching: .any).matching(identifier: "past-hours-72").firstMatch
            _ = row.waitForExistence(timeout: 5)
            if !row.exists { shot(app, "einstellung-fehlt-server\(serverHours)") }
            XCTAssertTrue(row.waitForExistence(timeout: 10), "72 h row exists: \(app.debugDescription.prefix(1500))")
            XCTAssertEqual(row.isEnabled, selectable, "server delivers \(serverHours) h: 72 selectable = \(selectable)")
            XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "past-hours-48").firstMatch.isEnabled)
            shot(app, "einstellung-server\(serverHours)")
            app.terminate()
        }
    }

    // MARK: A source that reaches back less far

    func testRadarShorterSourceShowsTheOldestRealSlotAndNamesWhatIsMissing() throws {
        let app = launchRadar(hours: 72, extra: ["-UITestRadarOldest", "30"])
        let slider = slider(app)
        XCTAssertTrue(waitValue(slider) { $0.contains("Messung") })
        jump(slider, fraction: 0)
        XCTAssertTrue(gapNote(app).waitForExistence(timeout: 10), "leading hole named at the oldest slot: \(value(slider))")
        XCTAssertTrue(gapNote(app).label.hasPrefix("Davor fehlen Daten"), gapNote(app).label)
        // Oldest slot = reference minus 30 h = Tuesday 17 Nov, 03:40 in Berlin.
        XCTAssertTrue(value(slider).hasPrefix("Di. 17. Nov., 03:40, Messung"), value(slider))
        shot(app, "radar-quelle-kurz-aeltester-slot")
        app.terminate()
    }

    // MARK: Layers

    func testObservationLayerSeventyTwoHoursHoleAndOldestSlot() throws {
        let app = launchLayers(hours: 72)
        try chooseRain(app, "Europa (OPERA)")
        let slider = slider(app)
        XCTAssertTrue(waitValue(slider) { $0.contains("Messung") }, value(slider))
        shot(app, "europa72-1-jetzt")
        jump(slider, fraction: 0)
        XCTAssertTrue(waitValue(slider) { $0.contains("Messung") }, "oldest: \(value(slider))")
        // Newest slot is within the current 5 min; the oldest lies 72 h before it, so on another day than now.
        shot(app, "europa72-2-aeltester-slot")
        XCTAssertTrue(seek(slider, near: 0.5, slots: 859) { value(slider).contains("fehlen Daten") }, "a slot next to a hole: \(value(slider))")
        XCTAssertTrue(gapNote(app).waitForExistence(timeout: 10), "hole named: \(value(slider))")
        shot(app, "europa72-3-luecke")
        app.terminate()
    }

    func testModelLayerShowsPastAsModelNotForecastAndNamesTheBuildUp() throws {
        let app = launchLayers(hours: 72)
        let entry = try XCTUnwrap(openLayerEntry(app, group: nil, entry: "Temperatur"), "Temperatur wählbar")
        entry.tap()
        let slider = slider(app)
        XCTAssertTrue(waitValue(slider) { $0.contains("Modell") }, value(slider))
        shot(app, "temperatur72-1-jetzt", darkLimit: 0.65)   // the stub's opaque warm temperature field stays bright in dark mode
        jump(slider, fraction: 0)
        XCTAssertTrue(gapNote(app).waitForExistence(timeout: 10), "the past builds up: the missing part before it is named: \(value(slider))")
        XCTAssertTrue(value(slider).contains(", Modell."), "the past is a model value, not a forecast: \(value(slider))")
        XCTAssertFalse(value(slider).contains("Vorhersage"), value(slider))
        shot(app, "temperatur72-2-aeltester-slot-aufbau", darkLimit: 0.65)   // the stub's opaque warm temperature field stays bright in dark mode
        jump(slider, fraction: 1)
        XCTAssertTrue(waitValue(slider) { $0.contains("Modellvorhersage") }, "the forecast stays separate: \(value(slider))")
        shot(app, "temperatur72-3-vorhersage-ende", darkLimit: 0.65)   // the stub's opaque warm temperature field stays bright in dark mode
        app.terminate()
    }

    // MARK: Measurement: scrubbing across a full 72 h timeline

    func testScrubbingAcrossFullSeventyTwoHourTimelineIsMeasured() throws {
        let app = launchRadar(hours: 72)
        let slider = slider(app)
        XCTAssertTrue(waitValue(slider) { $0.contains("Messung") })
        let options = XCTMeasureOptions(); options.iterationCount = 5
        measure(metrics: [XCTClockMetric(), XCTCPUMetric(application: app), XCTMemoryMetric(application: app)], options: options) {
            slider.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.5))
                .press(forDuration: 0.05, thenDragTo: slider.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.5)))
            slider.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.5))
                .press(forDuration: 0.05, thenDragTo: slider.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.5)))
        }
        XCTAssertTrue(app.state == .runningForeground, "the app is still running after scrubbing 10 full passes")
        app.terminate()
    }

    // MARK: Integration against a LOCAL backend on the state of PR #4 (skipped unless the host script gives the URL)

    /// Runs only with `TEST_RUNNER_HIST_BACKEND_URL=http://127.0.0.1:<port>/v1/radar/` (and `TEST_RUNNER_HIST_HOURS=48|72`):
    /// the app talks to a local backend built from `feature/history-hours-all` (fecb9c9), NOT the production backend.
    /// Per layer: value at "now", at the oldest slot (slider left end) and the gap note there; lines `HISTINT ...` go to the log.
    func testIntegrationAgainstLocalBackendOnPR4() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let url = environment["HIST_BACKEND_URL"] else { throw XCTSkip("Nur mit lokalem Backend (HIST_BACKEND_URL)") }
        executionTimeAllowance = 600
        let hours = environment["HIST_HOURS"] ?? "48"
        let layers = (environment["HIST_LAYERS"] ?? "Regen|Deutschland (DWD),Regen|Europa (OPERA),Regen|Welt (NOAA),|Blitze,Luftdruck|Deutschland").split(separator: ",").map(String.init)
        let app = UITestLaunch.app(extra: UITestLaunch.setAppearance(suffix == "dark" ? .dark : .light, extra: [
            "-radar-backend-url", url, "-radarPastHours", hours]))
        app.launch()
        let menu = app.buttons["radar-layer-menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 30))
        sleep(4)
        menu.tap()
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5)).tap()
        sleep(1)
        for item in layers {
            let parts = item.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
            let group = parts[0].isEmpty ? nil : parts[0]
            if group == "Regen" {
                try chooseRain(app, parts[1])
            } else {
                guard let entry = openLayerEntry(app, group: group, entry: parts[1]) else { print("HISTINT layer=\(parts[1]) nicht angeboten"); continue }
                entry.tap()
            }
            let slider = slider(app)
            sleep(3)
            let now = value(slider)
            jump(slider, fraction: 0)
            sleep(3)
            let oldest = value(slider)
            let note = gapNote(app).exists ? gapNote(app).label : "-"
            print("HISTINT hours=\(hours) layer=\(parts[1]) jetzt=\(now) | aeltester=\(oldest) | hinweis=\(note)")
            shot(app, "integration\(hours)-\(parts[1].filter { $0.isLetter })-aeltester")
            jump(slider, fraction: 1)
            sleep(2)
            shot(app, "integration\(hours)-\(parts[1].filter { $0.isLetter })-ende")
        }
        app.terminate()
    }
}
