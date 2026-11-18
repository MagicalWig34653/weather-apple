import XCTest

/// Refreshing indicator in the forecast header (only a spinner at the right edge of the pill; "Aktualisiere · Stand vor" lives in the accessibility label). Debug stub `-UITestForecast delayed|failed|behind` (no network for the forecast).
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

    /// Waits until the first forecast is shown (not the loading or unavailable text).
    private func waitForForecast(_ header: XCUIElement) {
        let predicate = NSPredicate(format: "NOT (label CONTAINS[c] 'geladen') AND NOT (label CONTAINS[c] 'loading') AND NOT (label CONTAINS[c] 'nicht verf') AND NOT (label CONTAINS[c] 'unavailable')")
        XCTAssertEqual(XCTWaiter().wait(for: [expectation(for: predicate, evaluatedWith: header)], timeout: 60), .completed, header.label)
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
            XCTAssertTrue(header.label.contains("Stand vor"), "the spoken label keeps the age: \(header.label)")
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
            shot(app, "forecast-normal-\(suffix)")
            app.terminate()
        }
    }

    /// Spinner at the right edge of the pill, chevron stays: screenshot, several spinner phases for the contrast
    /// measurement, and the position check.
    func testRefreshingSpinnerPlacement() throws {
        do {
            let app = UITestLaunch.app(extra: UITestLaunch.setAppearance(suffix == "dark" ? .dark : .light, extra: ["-UITestForecast", "delayed", "-UITestRadar", "fixture"]))
            app.launch()
            let header = app.buttons["forecast-details"]
            XCTAssertTrue(header.waitForExistence(timeout: 30))
            waitForForecast(header)
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
        XCTAssertFalse(header.label.contains("Ältere Prognose"))
        // The reason line stays visible; the radar fixture produces no radar notices that could displace it.
        let reason = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Ortsprognose'")).firstMatch
        XCTAssertTrue(reason.waitForExistence(timeout: 5), "reason line missing")
        XCTAssertFalse(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Radarkacheln' OR label CONTAINS 'lädt' OR label CONTAINS 'nicht geladen'")).firstMatch.exists)
        shot(app, "forecast-failed-\(suffix)")
        app.terminate()
    }

    func testServerBehindScreenshot() throws {
        // The stub's frozen clock sits 300 s after the expected run, so the check is always late enough.
        do {
            let app = launch("behind")
            let header = app.buttons["forecast-details"]
            XCTAssertTrue(header.waitForExistence(timeout: 30))
            XCTAssertTrue(waitForLabel(header, containing: "keinen neueren Stand", timeout: 30), "label: \(header.label)")
            XCTAssertFalse(header.label.contains("fehlgeschlagen"))
            shot(app, "forecast-server-behind-\(suffix)")
            app.terminate()
        }
    }
}
