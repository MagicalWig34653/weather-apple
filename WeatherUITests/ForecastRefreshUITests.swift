import XCTest

/// Refreshing indicator in the forecast header (only a spinner at the right edge of the pill; "Aktualisiere …" lives in the accessibility label; no "Stand vor" in the header in any state). Debug stub `-UITestForecast delayed|failed|behind` (no network for the forecast).
/// Screenshots for the manual check go to `/private/tmp/claude-501/daten-aktuell-shots` (skipped if not writable).
@MainActor
final class ForecastRefreshUITests: XCTestCase {
    /// Appearance is set from outside with `xcrun simctl ui <udid> appearance light|dark`; names follow the real appearance.
    /// `XCUIDevice.appearance` reports `.unspecified` for the simulator setting, so the script passes it as `TEST_RUNNER_SHOT_SUFFIX`.
    private var suffix: String {
        ProcessInfo.processInfo.environment["SHOT_SUFFIX"] ?? (XCUIDevice.shared.appearance == .dark ? "dark" : "light")
    }

    private func launch(_ mode: String, language: UITestLaunch.Language = .german) -> XCUIApplication {
        let app = UITestLaunch.app(language: language, extra: UITestLaunch.setAppearance(suffix == "dark" ? .dark : .light, extra: ["-UITestForecast", mode, "-UITestRadar", "fixture"]))
        app.launch()
        return app
    }

    /// First load without a forecast (stub `firstload` delays the first request): the loading circle sits at the right edge of the pill.
    func testFirstLoadShowsSpinnerAtPillEdge() throws {
        let app = launch("firstload")
        let header = app.buttons["forecast-details"]
        XCTAssertTrue(header.waitForExistence(timeout: 30))
        let spinner = app.descendants(matching: .any)["forecast-refresh-spinner"]
        XCTAssertTrue(spinner.waitForExistence(timeout: 10), "spinner during the first load: \(header.label)")
        let gap = header.frame.maxX - spinner.frame.maxX
        XCTAssertGreaterThanOrEqual(gap, 0, "spinner inside the pill")
        XCTAssertLessThanOrEqual(gap, 24, "spinner at the right edge, gap \(gap) pt")
        let luminance = UITestLaunch.meanLuminance(app.screenshot().image)
        if suffix == "dark" { XCTAssertLessThan(luminance, 0.45, "dark screenshot expected, luminance \(luminance)") }
        shot(app, "forecast-firstload-\(suffix)")
        // After the load the spinner is gone.
        waitForForecast(header)
        XCTAssertFalse(app.descendants(matching: .any)["forecast-refresh-spinner"].exists, "no spinner after the first load")
        app.terminate()
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let dir = "/private/tmp/claude-501/daten-aktuell-shots"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
    }

    /// Screenshot of the refreshing header plus the caption frame (bottom part of the header) for `tools/contrast_measure.swift`.
    private func contrastShot(_ app: XCUIApplication, _ name: String, header: XCUIElement) {
        let dir = "/private/tmp/claude-501/daten-aktuell-contrast"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
        let f = header.frame
        let caption: [String: Any] = ["label": "caption", "type": 48, "x": f.minX + 14, "y": f.minY + f.height * 0.62,
                                       "w": f.width - 48, "h": f.height * 0.34]
        let root: [String: Any] = ["screen": ["w": app.frame.width, "h": app.frame.height], "elements": [caption]]
        if let data = try? JSONSerialization.data(withJSONObject: root) {
            try? data.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).json"))
        }
    }

    /// Refreshing caption at three text sizes (extra small, standard, accessibility XXXL) for the contrast measurement.
    func testRefreshingCaptionAtDynamicTypeSizes() throws {
        for (label, category) in [("xs", "UICTContentSizeCategoryXS"), ("std", "UICTContentSizeCategoryL"), ("axxxl", "UICTContentSizeCategoryAccessibilityXXXL")] {
            let app = UITestLaunch.app(extra: ["-UITestForecast", "delayed", "-UITestRadar", "fixture", "-UIPreferredContentSizeCategoryName", category])
            app.launch()
            let header = app.buttons["forecast-details"]
            XCTAssertTrue(header.waitForExistence(timeout: 30))
            waitForForecast(header)
            backgroundAndReturn(app)
            XCTAssertTrue(waitForLabel(header, containing: "Aktualisiere", timeout: 30), "\(label): \(header.label)")
            sleep(1)
            contrastShot(app, "contrast-refreshing-\(label)-\(suffix)", header: header)
            app.terminate()
        }
    }

    private func waitForLabel(_ element: XCUIElement, containing text: String, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        return XCTWaiter().wait(for: [expectation(for: predicate, evaluatedWith: element)], timeout: timeout) == .completed
    }

    /// Cold start with the precondition "start settled": the forecast is shown and NO load runs (no spinner, no bar, no "Aktualisiere").
    /// Why a helper: the stub's clock is frozen (08:50, shown run 08:40), so a newer run is always "expected" and in about 25 to 35 %
    /// of the cold starts the loop starts a real reload right after the start-up load (loop round 1: `needsRefresh` -> index query no. 2
    /// -> stub `delayed` 40 s / `slowfailed` / `slowbehind` 6 s). Before the Build 56 fix `refresh()` switched `isForecastLoading` off
    /// unconditionally in its `defer`, which hid that running reload by chance; now the spinner correctly stays while a request runs.
    /// Trace: forecast shown at about 2.6 to 3.0 s, the loop's first round starts at 3.2 s at the latest, so 4 s after the forecast
    /// the early reload is either running (restart, up to `attempts`, each logged as `SETTLE`) or did not happen. No assertion, wait or
    /// tolerance of the tests is changed; a start that never settles fails with the list of attempts. Returns nil after the failure.
    private func launchSettled(_ mode: String, attempts: Int = 4, file: StaticString = #filePath, line: UInt = #line) -> XCUIApplication? {
        var notes: [String] = []
        for attempt in 1...attempts {
            let app = launch(mode)
            let header = app.buttons["forecast-details"]
            guard header.waitForExistence(timeout: 30) else { app.terminate(); notes.append("\(attempt): no header"); continue }
            waitForForecast(header)
            sleep(4)
            // One snapshot per element (a spinner that ends in between must not fail the query).
            let spinnerRunning = (try? app.descendants(matching: .any)["forecast-refresh-spinner"].snapshot()) != nil
            let barRunning = (try? app.descendants(matching: .any)["update-progress-bar"].snapshot()) != nil
            let hintRefreshing = ((try? header.snapshot())?.label ?? "").contains("Aktualisiere")
            if !spinnerRunning && !barRunning && !hintRefreshing {
                NSLog("SETTLE \(mode) attempt \(attempt) of \(attempts) ok")
                return app
            }
            notes.append("\(attempt): early startup reload running (spinner \(spinnerRunning), bar \(barRunning), hint \(hintRefreshing))")
            NSLog("SETTLE \(mode) attempt \(attempt): early startup reload running")
            app.terminate()
        }
        XCTFail("stub '\(mode)': start did not settle in \(attempts) cold starts: \(notes)", file: file, line: line)
        return nil
    }

    /// Waits until the first forecast is shown (not the loading or unavailable text).
    private func waitForForecast(_ header: XCUIElement) {
        let predicate = NSPredicate(format: "NOT (label CONTAINS[c] 'geladen') AND NOT (label CONTAINS[c] 'loading') AND NOT (label CONTAINS[c] 'nicht verf') AND NOT (label CONTAINS[c] 'unavailable')")
        XCTAssertEqual(XCTWaiter().wait(for: [expectation(for: predicate, evaluatedWith: header)], timeout: 60), .completed, header.label)
    }

    /// The header (pill) never shows or speaks the age, in no state (Lino 18.11.2026: "Stand vor..." weg).
    private func assertNoAge(_ header: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(header.label.contains("Stand vor"), "age in the header: \(header.label)", file: file, line: line)
    }

    private func backgroundAndReturn(_ app: XCUIApplication) {
        XCUIDevice.shared.press(.home)
        sleep(1)
        app.activate()
    }

    func testRefreshingIndicatorShowsWhileForecastIsShown() throws {
        do {
            let app = launch("delayed")
            let header = app.buttons["forecast-details"]
            XCTAssertTrue(header.waitForExistence(timeout: 30))
            // The first forecast loads at once (summary line, no indicator yet).
            let loaded = NSPredicate(format: "label != '' AND NOT (label CONTAINS 'geladen') AND NOT (label CONTAINS 'nicht verfügbar')")
            XCTAssertEqual(XCTWaiter().wait(for: [expectation(for: loaded, evaluatedWith: header)], timeout: 60), .completed, header.label)
            // Returning: the shown run is older than the expected one, so the load starts at once; the stub delays it.
            backgroundAndReturn(app)
            XCTAssertTrue(waitForLabel(header, containing: "Aktualisiere", timeout: 30), "indicator visible: \(header.label)")
            XCTAssertFalse(header.label.contains("Stand vor"), "no age in the header, also not spoken: \(header.label)")
            // No visible second line: there is no separate static text that starts with the age.
            XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Stand vor'")).firstMatch.exists, "no visible age line while refreshing")
            XCTAssertFalse(header.label.contains("Ältere Prognose"))
            XCTAssertFalse(header.label.contains("fehlgeschlagen"))
            shot(app, "forecast-refreshing-\(suffix)")
            app.terminate()
        }
    }

    func testCurrentForecastShowsNoStatus() throws {
        do {
            let app = launch("current")
            let header = app.buttons["forecast-details"]
            XCTAssertTrue(header.waitForExistence(timeout: 30))
            let loaded = NSPredicate(format: "label != '' AND NOT (label CONTAINS 'geladen') AND NOT (label CONTAINS 'nicht verfügbar')")
            XCTAssertEqual(XCTWaiter().wait(for: [expectation(for: loaded, evaluatedWith: header)], timeout: 60), .completed, header.label)
            sleep(2)
            XCTAssertFalse(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Radar für' OR label CONTAINS 'Radarkacheln' OR label CONTAINS 'Historie nicht'")).firstMatch.exists, "radar fixture must load cleanly")
            for text in ["Aktualisiere", "fehlgeschlagen", "keinen neueren Stand", "Ältere Prognose"] {
                XCTAssertFalse(header.label.contains(text), header.label)
            }
            assertNoAge(header)
            shot(app, "forecast-normal-\(suffix)")
            fixShot(app, "kopf-normal")
            app.terminate()
        }
    }

    /// Spinner at the right edge of the pill, chevron stays: screenshot, several spinner phases for the contrast
    /// measurement, and the position check.
    /// Stub `delayedreturn` (not `delayed`): the start-up reload of the loop (frozen clock, see `launchSettled`) is answered at once, so
    /// "start settled" holds in every cold start, not only in about half of them (Build 57 measurement: 9 of 17 starts early with `delayed`,
    /// four in a row in the full runs). The load that stalls is still the one this test triggers by going to the background and back;
    /// all assertions (no spinner before, label, spinner at the right edge, right half) are unchanged.
    func testRefreshingSpinnerPlacement() throws {
        do {
            guard let app = launchSettled("delayedreturn") else { return }
            let header = app.buttons["forecast-details"]
            XCTAssertFalse(app.descendants(matching: .any)["forecast-refresh-spinner"].exists, "no spinner while the forecast is current")
            backgroundAndReturn(app)
            XCTAssertTrue(waitForLabel(header, containing: "Aktualisiere", timeout: 30), "\(header.label)")
            let spinner = app.descendants(matching: .any)["forecast-refresh-spinner"]
            XCTAssertTrue(spinner.waitForExistence(timeout: 10), "spinner queryable")
            // The spinner sits at the RIGHT EDGE of the pill, not in the text flow.
            let gap = header.frame.maxX - spinner.frame.maxX
            XCTAssertGreaterThanOrEqual(gap, 0, "spinner inside the pill")
            XCTAssertLessThanOrEqual(gap, 24, "spinner at the right edge, gap \(gap) pt")
            XCTAssertGreaterThan(spinner.frame.minX, header.frame.midX, "spinner in the right half")
            sleep(1)
            shot(app, "forecast-refreshing-\(suffix)-d5")
            // Several phases of the spinning symbol for the worst-case contrast.
            let dir = "/private/tmp/claude-501/daten-aktuell-phases"
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            for k in 0..<8 {
                let name = "\(suffix)-\(k)"
                try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
                let f = spinner.frame
                let root: [String: Any] = ["screen": ["w": app.frame.width, "h": app.frame.height], "cx": f.midX, "cy": f.midY]
                if let data = try? JSONSerialization.data(withJSONObject: root) { try? data.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).json")) }
                usleep(130_000)
            }
            app.terminate()
        }
    }

    func testRefreshingIndicatorEnglish() throws {
        let app = launch("delayed", language: .english)
        let header = app.buttons["forecast-details"]
        XCTAssertTrue(header.waitForExistence(timeout: 30))
        waitForForecast(header)
        backgroundAndReturn(app)
        XCTAssertTrue(waitForLabel(header, containing: "Updating", timeout: 20), "indicator visible: \(header.label)")
    }

    /// One failing load (stub `failonce`) must not show a failure or "Ältere Prognose"; the next load recovers.
    func testSingleFailureShowsNoFailureMessage() throws {
        let app = launch("failonce")
        let header = app.buttons["forecast-details"]
        XCTAssertTrue(header.waitForExistence(timeout: 30))
        waitForForecast(header)
        backgroundAndReturn(app) // the load on return fails once, then the repeat succeeds
        let failure = NSPredicate(format: "label CONTAINS 'fehlgeschlagen' OR label CONTAINS 'Ältere Prognose'")
        let seen = XCTWaiter().wait(for: [expectation(for: failure, evaluatedWith: header)], timeout: 30)
        XCTAssertEqual(seen, .timedOut, "no failure message after a single failure: \(header.label)")
        app.terminate()
    }

    /// Repeated failures (stub `failed`) end in "Aktualisierung fehlgeschlagen", never in "Ältere Prognose".
    func testRepeatedFailureShowsFailureMessage() throws {
        let app = launch("failed")
        let header = app.buttons["forecast-details"]
        XCTAssertTrue(header.waitForExistence(timeout: 30))
        waitForForecast(header)
        backgroundAndReturn(app)
        // Poll once a second and keep the label history, so a miss says what the header showed.
        var history: [String] = []
        var found = false
        for _ in 0..<120 {
            let label = header.label
            if history.last != label { history.append(label) }
            if label.contains("fehlgeschlagen") { found = true; break }
            sleep(1)
        }
        XCTAssertTrue(found, "failure after the repeats, labels seen: \(history)")
        assertNoAge(header)
        XCTAssertFalse(header.label.contains("Ältere Prognose"))
        // The reason line stays visible; the radar fixture produces no radar notices that could displace it.
        let reason = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Ortsprognose'")).firstMatch
        XCTAssertTrue(reason.waitForExistence(timeout: 5), "reason line missing")
        XCTAssertFalse(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Radarkacheln' OR label CONTAINS 'lädt' OR label CONTAINS 'nicht geladen'")).firstMatch.exists)
        shot(app, "forecast-failed-\(suffix)")
        app.terminate()
    }

    // MARK: The spinner ends (Build 49: it kept spinning)

    /// Before / during / after pictures for the review (light and dark).
    private func fixShot(_ app: XCUIApplication, _ name: String) {
        let dir = "/private/tmp/claude-501/ladekreis-shots"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name)-\(suffix).png"))
    }

    /// The load on return brings no newer run (stub `slowbehind`, 6 s): spinner while it runs, gone afterwards.
    func testSpinnerEndsWhenLoadBringsNothingNewer() throws {
        guard let app = launchSettled("slowbehind") else { return }
        let header = app.buttons["forecast-details"]
        let spinner = app.descendants(matching: .any)["forecast-refresh-spinner"]
        XCTAssertFalse(spinner.exists, "no spinner before the load")
        assertNoAge(header)
        fixShot(app, "nothing-newer-1-before")
        backgroundAndReturn(app)
        XCTAssertTrue(spinner.waitForExistence(timeout: 10), "spinner while the load runs: \(header.label)")
        assertNoAge(header)
        fixShot(app, "nothing-newer-2-during")
        XCTAssertTrue(spinner.waitForNonExistence(timeout: 20), "spinner must end when the load ends: \(header.label)")
        XCTAssertTrue(waitForLabel(header, containing: "keinen neueren Stand", timeout: 5), header.label)
        sleep(3)
        XCTAssertFalse(spinner.exists, "spinner stays away after the load")
        assertNoAge(header)
        fixShot(app, "nothing-newer-3-after")
        app.terminate()
    }

    /// The load on return fails (stub `slowfailedreturn` = `slowfailed` from the first trip to the background on, about 13 s with the client's repeats): the spinner ends with the
    /// failed load and stays away while the app waits for the repeat; the failure text comes after the repeat as before.
    func testSpinnerEndsWhenLoadFails() throws {
        guard let app = launchSettled("slowfailedreturn") else { return }
        let header = app.buttons["forecast-details"]
        let spinner = app.descendants(matching: .any)["forecast-refresh-spinner"]
        XCTAssertFalse(spinner.exists, "no spinner before the load")
        assertNoAge(header)
        fixShot(app, "failed-1-before")
        backgroundAndReturn(app)
        XCTAssertTrue(spinner.waitForExistence(timeout: 10), "spinner while the load runs: \(header.label)")
        assertNoAge(header)
        fixShot(app, "failed-2-during")
        XCTAssertTrue(spinner.waitForNonExistence(timeout: 18), "spinner must end with the failed load: \(header.label)")
        XCTAssertFalse(header.label.contains("fehlgeschlagen"), "first failure: no failure text yet: \(header.label)")
        sleep(3)
        XCTAssertFalse(spinner.exists, "no spinner while waiting for the repeat")
        assertNoAge(header)
        fixShot(app, "failed-3-after-first-failure")
        XCTAssertTrue(waitForLabel(header, containing: "fehlgeschlagen", timeout: 60), "failure text after the repeat: \(header.label)")
        XCTAssertTrue(spinner.waitForNonExistence(timeout: 5), "no spinner with the failure text")
        assertNoAge(header)
        fixShot(app, "failed-4-after-confirmed-failure")
        app.terminate()
    }

    // MARK: Build 53: not ready run is no failure, real failure shows and recovers (fix 5d0c741)

    /// Before / during / after pictures of the refresh fix (`B53_SHOT_DIR`, default `/private/tmp/claude-501/b53-refresh-shots`).
    private func refreshShot(_ app: XCUIApplication, _ name: String) {
        let dir = ProcessInfo.processInfo.environment["B53_SHOT_DIR"] ?? "/private/tmp/claude-501/b53-refresh-shots"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let screenshot = app.screenshot()
        let luminance = UITestLaunch.meanLuminance(screenshot.image)
        print("LUMA b53-refresh-\(name)-\(suffix)=\(luminance)")
        if suffix == "dark" { XCTAssertLessThan(luminance, 0.45, "dark screenshot expected, luminance \(luminance)") }
        try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("b53-refresh-\(name)-\(suffix).png"))
    }

    /// Case 1 (stub `rununavailable`): the index lists a newer run, its first two loads answer "InvalidDimensionValue" (HTTP 200,
    /// run not ready), the third delivers it. With the fix no failure text may appear at any time; the header recovers to the
    /// normal state. On Build 52 code the second load confirms a failure and "Aktualisierung fehlgeschlagen" appears.
    func testNotReadyRunShowsNoFailureAndRecoversToNewRun() throws {
        executionTimeAllowance = 180
        let app = launch("rununavailable")
        let header = app.buttons["forecast-details"]
        XCTAssertTrue(header.waitForExistence(timeout: 30))
        waitForForecast(header)
        refreshShot(app, "nicht-bereit-1-vorher")
        backgroundAndReturn(app)
        var history: [String] = []
        var failureSeen: String?
        var shotDuring = false
        let start = Date()
        while Date().timeIntervalSince(start) < 80 {
            let label = header.label
            if history.last != label { history.append(label) }
            if label.contains("fehlgeschlagen") || label.contains("Ältere Prognose") { failureSeen = label }
            // 35 s after the return: on old code the confirmed failure is on screen, with the fix the quiet state.
            if !shotDuring, Date().timeIntervalSince(start) >= 35 { shotDuring = true; refreshShot(app, "nicht-bereit-2-waehrend") }
            sleep(1)
        }
        print("HEADER-HISTORY nicht-bereit: \(history)")
        XCTAssertNil(failureSeen, "no failure text for a not ready run, labels seen: \(history)")
        XCTAssertFalse(header.label.contains("fehlgeschlagen") || header.label.contains("keinen neueren Stand") || header.label.contains("Aktualisiere"),
                       "recovered to the new run: \(header.label), labels seen: \(history)")
        assertNoAge(header)
        refreshShot(app, "nicht-bereit-3-nachher")
        app.terminate()
    }

    /// Case 2 (stub `failrecover`): two failing loads confirm the failure ("Aktualisierung fehlgeschlagen"); the third load
    /// succeeds with the newer run and the failure text is gone again.
    func testConfirmedFailureShowsMessageThenRecoveryClearsIt() throws {
        executionTimeAllowance = 180
        let app = launch("failrecover")
        let header = app.buttons["forecast-details"]
        XCTAssertTrue(header.waitForExistence(timeout: 30))
        waitForForecast(header)
        refreshShot(app, "fehler-1-vorher")
        backgroundAndReturn(app)
        var history: [String] = []
        var found = false
        for _ in 0..<90 {
            let label = header.label
            if history.last != label { history.append(label) }
            if label.contains("fehlgeschlagen") { found = true; break }
            sleep(1)
        }
        XCTAssertTrue(found, "failure after the repeat, labels seen: \(history)")
        refreshShot(app, "fehler-2-waehrend")
        assertNoAge(header)
        // Recovery: the next load succeeds, the failure text goes away.
        XCTAssertTrue(waitForLabelWithout(header, "fehlgeschlagen", timeout: 90), "failure text must go after recovery: \(header.label)")
        sleep(2)
        XCTAssertFalse(header.label.contains("fehlgeschlagen") || header.label.contains("keinen neueren Stand") || header.label.contains("Aktualisiere"), header.label)
        assertNoAge(header)
        refreshShot(app, "fehler-3-nachher")
        print("HEADER-HISTORY fehler: \(history)")
        app.terminate()
    }

    private func waitForLabelWithout(_ element: XCUIElement, _ text: String, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "NOT (label CONTAINS %@)", text)
        return XCTWaiter().wait(for: [expectation(for: predicate, evaluatedWith: element)], timeout: timeout) == .completed
    }

    func testServerBehindScreenshot() throws {
        // The stub's frozen clock sits 300 s after the expected run, so the check is always late enough.
        do {
            let app = launch("behind")
            let header = app.buttons["forecast-details"]
            XCTAssertTrue(header.waitForExistence(timeout: 30))
            XCTAssertTrue(waitForLabel(header, containing: "keinen neueren Stand", timeout: 30), "label: \(header.label)")
            XCTAssertFalse(header.label.contains("fehlgeschlagen"))
            assertNoAge(header)
            shot(app, "forecast-server-behind-\(suffix)")
            app.terminate()
        }
    }
}
