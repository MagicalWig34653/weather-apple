import XCTest

/// "Aktualisiere …" in the forecast header. Debug stub `-UITestForecast delayed|failed|behind` (no network for the forecast).
/// Screenshots for the manual check go to `/private/tmp/claude-501/daten-aktuell-shots` (skipped if not writable).
final class ForecastRefreshUITests: XCTestCase {
    /// Appearance is set from outside with `xcrun simctl ui <udid> appearance light|dark`; names follow the real appearance.
    /// `XCUIDevice.appearance` reports `.unspecified` for the simulator setting, so the script passes it as `TEST_RUNNER_SHOT_SUFFIX`.
    private var suffix: String {
        ProcessInfo.processInfo.environment["SHOT_SUFFIX"] ?? (XCUIDevice.shared.appearance == .dark ? "dark" : "light")
    }

    private func launch(_ mode: String, language: UITestLaunch.Language = .german) -> XCUIApplication {
        let app = UITestLaunch.app(language: language, extra: ["-UITestForecast", mode])
        app.launch()
        return app
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let dir = "/private/tmp/claude-501/daten-aktuell-shots"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
    }

    private func waitForLabel(_ element: XCUIElement, containing text: String, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        return XCTWaiter().wait(for: [expectation(for: predicate, evaluatedWith: element)], timeout: timeout) == .completed
    }

    /// Waits until the first forecast is shown (not the loading or unavailable text).
    private func waitForForecast(_ header: XCUIElement) {
        let predicate = NSPredicate(format: "NOT (label CONTAINS[c] 'geladen') AND NOT (label CONTAINS[c] 'loading') AND NOT (label CONTAINS[c] 'nicht verf') AND NOT (label CONTAINS[c] 'unavailable')")
        XCTAssertEqual(XCTWaiter().wait(for: [expectation(for: predicate, evaluatedWith: header)], timeout: 30), .completed, header.label)
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
            XCTAssertEqual(XCTWaiter().wait(for: [expectation(for: loaded, evaluatedWith: header)], timeout: 30), .completed, header.label)
            // Returning: the shown run is older than the expected one, so the load starts at once; the stub delays it.
            backgroundAndReturn(app)
            XCTAssertTrue(waitForLabel(header, containing: "Aktualisiere", timeout: 30), "indicator visible: \(header.label)")
            XCTAssertTrue(header.label.contains("Stand vor"), "the age stays: \(header.label)")
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
            XCTAssertEqual(XCTWaiter().wait(for: [expectation(for: loaded, evaluatedWith: header)], timeout: 30), .completed, header.label)
            sleep(2)
            for text in ["Aktualisiere", "fehlgeschlagen", "keinen neueren Stand", "Ältere Prognose"] {
                XCTAssertFalse(header.label.contains(text), header.label)
            }
            shot(app, "forecast-normal-\(suffix)")
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
        shot(app, "forecast-failed-\(suffix)")
        app.terminate()
    }

    func testServerBehindScreenshot() throws {
        // Needs a check at or after N + 260 s, which holds for about 2/3 of every 5-minute slot.
        let slotOffset = (Date().timeIntervalSince1970 - 165).truncatingRemainder(dividingBy: 300)
        try XCTSkipIf(slotOffset < 110, "Zu früh im Takt-Fenster für den Hinweis \"noch keinen neueren Stand\".")
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
