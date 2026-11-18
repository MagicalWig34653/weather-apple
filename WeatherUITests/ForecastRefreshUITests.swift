import XCTest

/// "Aktualisiere …" in the forecast header. Debug stub `-UITestForecast delayed|failed|behind` (no network for the forecast).
/// Screenshots for the manual check go to `/private/tmp/claude-501/daten-aktuell-shots` (skipped if not writable).
final class ForecastRefreshUITests: XCTestCase {
    private func launch(_ mode: String, dark: Bool, language: UITestLaunch.Language = .german) -> XCUIApplication {
        var extra = ["-UITestForecast", mode]
        if dark { extra += ["-AppleInterfaceStyle", "Dark"] }
        let app = UITestLaunch.app(language: language, extra: extra)
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

    private func backgroundAndReturn(_ app: XCUIApplication) {
        XCUIDevice.shared.press(.home)
        sleep(1)
        app.activate()
    }

    func testRefreshingIndicatorShowsWhileForecastIsShown() throws {
        for dark in [false, true] {
            let app = launch("delayed", dark: dark)
            let header = app.buttons["forecast-details"]
            XCTAssertTrue(header.waitForExistence(timeout: 30))
            // The first forecast loads at once (summary line, no indicator yet).
            let loaded = NSPredicate(format: "label != '' AND NOT (label CONTAINS 'geladen') AND NOT (label CONTAINS 'nicht verfügbar')")
            XCTAssertEqual(XCTWaiter().wait(for: [expectation(for: loaded, evaluatedWith: header)], timeout: 30), .completed, header.label)
            // Returning: the shown run is older than the expected one, so the load starts at once; the stub delays it.
            backgroundAndReturn(app)
            XCTAssertTrue(waitForLabel(header, containing: "Aktualisiere", timeout: 20), "indicator visible: \(header.label)")
            XCTAssertTrue(header.label.contains("Stand vor"), "the age stays: \(header.label)")
            XCTAssertFalse(header.label.contains("Ältere Prognose"))
            XCTAssertFalse(header.label.contains("fehlgeschlagen"))
            shot(app, "forecast-refreshing-\(dark ? "dark" : "light")")
            app.terminate()
        }
    }

    func testCurrentForecastShowsNoStatus() throws {
        for dark in [false, true] {
            let app = launch("current", dark: dark)
            let header = app.buttons["forecast-details"]
            XCTAssertTrue(header.waitForExistence(timeout: 30))
            let loaded = NSPredicate(format: "label != '' AND NOT (label CONTAINS 'geladen') AND NOT (label CONTAINS 'nicht verfügbar')")
            XCTAssertEqual(XCTWaiter().wait(for: [expectation(for: loaded, evaluatedWith: header)], timeout: 30), .completed, header.label)
            sleep(2)
            for text in ["Aktualisiere", "fehlgeschlagen", "keinen neueren Stand", "Ältere Prognose"] {
                XCTAssertFalse(header.label.contains(text), header.label)
            }
            shot(app, "forecast-normal-\(dark ? "dark" : "light")")
            app.terminate()
        }
    }

    func testRefreshingIndicatorEnglish() throws {
        let app = launch("delayed", dark: false, language: .english)
        let header = app.buttons["forecast-details"]
        XCTAssertTrue(header.waitForExistence(timeout: 30))
        sleep(4)
        backgroundAndReturn(app)
        XCTAssertTrue(waitForLabel(header, containing: "Updating", timeout: 20), "indicator visible: \(header.label)")
    }

    func testFailedUpdateShowsFailureOnlyAfterRepeat() throws {
        for dark in [false, true] {
            let app = launch("failed", dark: dark)
            let header = app.buttons["forecast-details"]
            XCTAssertTrue(header.waitForExistence(timeout: 30))
            sleep(4)
            backgroundAndReturn(app) // first failing load (index 503), repeat after 20 s
            XCTAssertFalse(waitForLabel(header, containing: "fehlgeschlagen", timeout: 4), "no failure after the first error: \(header.label)")
            XCTAssertFalse(header.label.contains("Ältere Prognose"))
            XCTAssertTrue(waitForLabel(header, containing: "fehlgeschlagen", timeout: 90), "failure after the repeat: \(header.label)")
            shot(app, "forecast-failed-\(dark ? "dark" : "light")")
            app.terminate()
        }
    }

    func testServerBehindScreenshot() throws {
        // Needs a check at or after N + 260 s, which holds for about 2/3 of every 5-minute slot.
        let slotOffset = (Date().timeIntervalSince1970 - 165).truncatingRemainder(dividingBy: 300)
        try XCTSkipIf(slotOffset < 110, "Zu früh im Takt-Fenster für den Hinweis \"noch keinen neueren Stand\".")
        for dark in [false, true] {
            let app = launch("behind", dark: dark)
            let header = app.buttons["forecast-details"]
            XCTAssertTrue(header.waitForExistence(timeout: 30))
            XCTAssertTrue(waitForLabel(header, containing: "keinen neueren Stand", timeout: 30), "label: \(header.label)")
            XCTAssertFalse(header.label.contains("fehlgeschlagen"))
            shot(app, "forecast-server-behind-\(dark ? "dark" : "light")")
            app.terminate()
        }
    }
}
