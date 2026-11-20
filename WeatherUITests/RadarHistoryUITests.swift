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

    private func shot(_ app: XCUIApplication, _ name: String) {
        sleep(1)
        let dir = "/private/tmp/claude-501/hist-shots"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let screenshot = app.screenshot()
        let luminance = UITestLaunch.meanLuminance(screenshot.image)
        print("LUMA hist-\(name)-\(suffix)=\(luminance)")
        if suffix == "dark" { XCTAssertLessThan(luminance, 0.45, "dark screenshot expected, luminance \(luminance)") }
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

    private func gapNote(_ app: XCUIApplication) -> XCUIElement { app.descendants(matching: .any)["radar-gap-note"] }

    // MARK: Radar Deutschland, 72 hours

    func testRadarSeventyTwoHoursOldestSlotHoleAndWayBack() throws {
        let app = launchRadar(hours: 72)
        let slider = slider(app)
        XCTAssertTrue(waitValue(slider) { $0.hasSuffix("Messung") || $0.contains("Messung") }, "starts at now: \(value(slider))")
        let nowValue = value(slider)
        XCTAssertFalse(gapNote(app).exists, "no hole next to now")
        shot(app, "radar72-1-jetzt")

        // Oldest slot: reference 2026-11-18 08:40 UTC minus 72 h = Sunday 15 Nov, 09:40 in Berlin.
        slider.adjust(toNormalizedSliderPosition: 0)
        XCTAssertTrue(waitValue(slider) { $0.hasPrefix("So. 15. Nov., 09:40, Messung") }, "oldest slot: \(value(slider))")
        XCTAssertFalse(gapNote(app).exists, "the source reaches back the full 72 h: no note at the oldest slot")
        shot(app, "radar72-2-aeltester-slot")

        // The hole of 6 times: slot before (index 424) or after (index 425) it names it. 882 slots in total (845 + 37).
        slider.adjust(toNormalizedSliderPosition: 424.5 / 881)
        XCTAssertTrue(gapNote(app).waitForExistence(timeout: 10), "note next to the hole: \(value(slider))")
        XCTAssertTrue(gapNote(app).label.contains("fehlen Daten"), "note text: \(gapNote(app).label)")
        XCTAssertTrue(value(slider).contains("fehlen Daten"), "VoiceOver value names the hole: \(value(slider))")
        shot(app, "radar72-3-luecke")

        // Back to now: the pill's long press jumps there.
        app.otherElements["radar-frame-label"].press(forDuration: 0.8)
        XCTAssertTrue(waitValue(slider) { $0 == nowValue }, "back at now: \(value(slider)) vs \(nowValue)")
        XCTAssertTrue(gapNote(app).waitForNonExistence(timeout: 10))
        shot(app, "radar72-4-zurueck")
        app.terminate()
    }

    // MARK: A source that reaches back less far

    func testRadarShorterSourceShowsTheOldestRealSlotAndNamesWhatIsMissing() throws {
        let app = launchRadar(hours: 72, extra: ["-UITestRadarOldest", "30"])
        let slider = slider(app)
        XCTAssertTrue(waitValue(slider) { $0.contains("Messung") })
        slider.adjust(toNormalizedSliderPosition: 0)
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
        let entry = try XCTUnwrap(openLayerEntry(app, group: "Regen", entry: "Europa"), "Europa wählbar")
        entry.tap()
        let slider = slider(app)
        XCTAssertTrue(waitValue(slider) { $0.contains("Messung") }, value(slider))
        shot(app, "europa72-1-jetzt")
        slider.adjust(toNormalizedSliderPosition: 0)
        XCTAssertTrue(waitValue(slider) { $0.contains("Messung") && !$0.contains("fehlen") }, "oldest: \(value(slider))")
        // Newest slot is within the current 5 min; the oldest lies 72 h before it, so on another day than now.
        shot(app, "europa72-2-aeltester-slot")
        slider.adjust(toNormalizedSliderPosition: 427.5 / 857)
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
        shot(app, "temperatur72-1-jetzt")
        slider.adjust(toNormalizedSliderPosition: 0)
        XCTAssertTrue(gapNote(app).waitForExistence(timeout: 10), "the past builds up: the missing part before it is named: \(value(slider))")
        XCTAssertTrue(value(slider).contains(", Modell."), "the past is a model value, not a forecast: \(value(slider))")
        XCTAssertFalse(value(slider).contains("Vorhersage"), value(slider))
        shot(app, "temperatur72-2-aeltester-slot-aufbau")
        slider.adjust(toNormalizedSliderPosition: 1)
        XCTAssertTrue(waitValue(slider) { $0.contains("Modellvorhersage") }, "the forecast stays separate: \(value(slider))")
        shot(app, "temperatur72-3-vorhersage-ende")
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
        let layers = (environment["HIST_LAYERS"] ?? "Regen|Deutschland (DWD),Regen|Europa (OPERA),|Blitze,Luftdruck|Deutschland").split(separator: ",").map(String.init)
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
            guard let entry = openLayerEntry(app, group: group, entry: parts[1]) else { print("HISTINT layer=\(parts[1]) nicht angeboten"); continue }
            entry.tap()
            let slider = slider(app)
            sleep(3)
            let now = value(slider)
            slider.adjust(toNormalizedSliderPosition: 0)
            sleep(3)
            let oldest = value(slider)
            let note = gapNote(app).exists ? gapNote(app).label : "-"
            print("HISTINT hours=\(hours) layer=\(parts[1]) jetzt=\(now) | aeltester=\(oldest) | hinweis=\(note)")
            shot(app, "integration\(hours)-\(parts[1].filter { $0.isLetter })-aeltester")
            slider.adjust(toNormalizedSliderPosition: 1)
            sleep(2)
            shot(app, "integration\(hours)-\(parts[1].filter { $0.isLetter })-ende")
        }
        app.terminate()
    }
}
