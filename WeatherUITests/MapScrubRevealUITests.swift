import XCTest

/// Build 53: while the time slider is dragged, every control on top of the map (header, forecast pill, notices, map buttons,
/// legend) disappears; map, slider, time label and the source line stay. After lift, cancel (app to the background mid-drag)
/// everything is back; a tap or a still touch hides nothing.
/// The finger stays down on purpose: `press(forDuration:thenDragTo:withVelocity:thenHoldForDuration:)` holds it at the end point
/// and the probes run while it is still there (main run loop is spun by XCUITest while the call waits). Real touches, no stub.
/// Screenshots go to `B53_SHOT_DIR` (default `/private/tmp/claude-501/b53-shots`); `SHOT_SUFFIX=dark` names dark runs.
@MainActor
final class MapScrubRevealUITests: XCTestCase {
    private var suffix: String {
        ProcessInfo.processInfo.environment["SHOT_SUFFIX"] ?? (XCUIDevice.shared.appearance == .dark ? "dark" : "light")
    }
    private var shotDir: String { ProcessInfo.processInfo.environment["B53_SHOT_DIR"] ?? "/private/tmp/claude-501/b53-shots" }
    private var duringValue = ""
    private var backendURL: String? { ProcessInfo.processInfo.environment["B53_BACKEND_URL"] }

    override func setUpWithError() throws {
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .portrait
    }

    private func launch(extra: [String] = []) -> XCUIApplication {
        let app = UITestLaunch.app(language: .german, extra: UITestLaunch.setAppearance(suffix == "dark" ? .dark : .light,
            extra: ["-UITestForecast", "current", "-UITestRadar", "fixture", "-UITestLayers", "all"] + extra))
        app.launch()
        XCTAssertTrue(app.buttons["radar-layer-menu"].waitForExistence(timeout: 25))
        XCTAssertTrue(app.sliders["Radarzeitpunkt"].waitForExistence(timeout: 25), "Zeitachse")
        sleep(3)
        // The stubbed layers are reported after the first probe: open and close the menu once.
        app.buttons["radar-layer-menu"].tap()
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5)).tap()
        sleep(1)
        return app
    }

    private func choose(_ app: XCUIApplication, _ prefix: String) {
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

    private func shot(_ app: XCUIApplication, _ name: String) {
        try? FileManager.default.createDirectory(atPath: shotDir, withIntermediateDirectories: true)
        let screenshot = app.screenshot()
        let luminance = UITestLaunch.meanLuminance(screenshot.image)
        print("LUMA b53-\(suffix)-\(name)=\(luminance)")
        if suffix == "dark" { XCTAssertLessThan(luminance, 0.45, "dunkles Bild erwartet, Helligkeit \(luminance)") }
        try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: shotDir).appendingPathComponent("b53-\(suffix)-\(name).png"))
    }

    // MARK: Elements

    /// Everything on top of the map that must go while dragging (only the ones a state offers are asserted).
    private func chrome(_ app: XCUIApplication) -> [(name: String, element: XCUIElement)] {
        [("Ort", app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Ort auswählen:")).firstMatch),
         ("Kartenwahl", app.buttons["radar-layer-menu"]),
         ("Prognose", app.buttons["forecast-details"]),
         ("Ort speichern", app.buttons["Ausgewählten Ort speichern oder umbenennen"]),
         ("Standort", app.buttons["Aktuellen Standort verwenden"]),
         ("Legende", app.buttons["radar-legend-toggle"]),
         ("Info", app.buttons["Datenquellen und Datenschutz"])]
    }

    private func slider(_ app: XCUIApplication) -> XCUIElement { app.sliders["Radarzeitpunkt"] }
    private func timeLabel(_ app: XCUIApplication) -> XCUIElement { app.descendants(matching: .any)["radar-frame-label"] }

    private func assertChromeVisible(_ app: XCUIApplication, _ moment: String, file: StaticString = #filePath, line: UInt = #line) {
        for item in chrome(app) {
            XCTAssertTrue(item.element.exists && item.element.isHittable, "\(item.name) sichtbar und bedienbar (\(moment))", file: file, line: line)
        }
        XCTAssertTrue(slider(app).isHittable, "Zeitregler (\(moment))", file: file, line: line)
        XCTAssertTrue(timeLabel(app).exists, "Zeitwert (\(moment))", file: file, line: line)
    }

    private func assertChromeGone(_ app: XCUIApplication, _ moment: String, file: StaticString = #filePath, line: UInt = #line) {
        for item in chrome(app) {
            XCTAssertFalse(item.element.exists && item.element.isHittable, "\(item.name) weg und nicht antippbar (\(moment))", file: file, line: line)
        }
        for id in ["radar-world-note-estimate", "radar-eu-note-unavailable", "radar-world-note-unavailable", "radar-legend"] {
            let note = app.descendants(matching: .any)[id]
            XCTAssertFalse(note.exists && note.isHittable, "\(id) weg (\(moment))", file: file, line: line)
        }
        XCTAssertTrue(slider(app).exists, "Zeitregler bleibt (\(moment))", file: file, line: line)
        XCTAssertTrue(timeLabel(app).exists, "Zeitwert bleibt (\(moment))", file: file, line: line)
    }

    /// Finger down on the slider, drag to `to`, hold there for `hold` seconds. `probes` run `at` seconds after the start, finger still down.
    private func dragAndHold(_ app: XCUIApplication, from: CGFloat = 0.25, to: CGFloat = 0.7, hold: TimeInterval = 7,
                             probes: [(at: TimeInterval, run: @MainActor () -> Void)]) {
        let slider = slider(app)
        for probe in probes {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(probe.at))
                probe.run()
            }
        }
        slider.coordinate(withNormalizedOffset: CGVector(dx: from, dy: 0.5))
            .press(forDuration: 0.2, thenDragTo: slider.coordinate(withNormalizedOffset: CGVector(dx: to, dy: 0.5)),
                   withVelocity: .default, thenHoldForDuration: hold)
    }

    // MARK: Cases

    /// Drag, hold, lift: before / during (controls gone, slider and time stay) / after (everything back).
    private func dragCase(_ name: String, prepare: (XCUIApplication) -> Void = { _ in }, legendOpen: Bool = false) {
        executionTimeAllowance = 180
        let app = launch(extra: backendURL.map { ["-radar-backend-url", $0] } ?? [])
        prepare(app)
        if legendOpen {
            app.buttons["radar-legend-toggle"].tap()
            XCTAssertTrue(app.descendants(matching: .any)["radar-legend"].waitForExistence(timeout: 5))
            sleep(1)
        }
        assertChromeVisible(app, "vorher")
        let before = timeLabel(app).value as? String ?? ""
        let sliderBefore = slider(app).value as? String ?? ""
        shot(app, "\(name)-1-vorher")
        duringValue = ""
        dragAndHold(app, probes: [(3.0, { [self] in
            assertChromeGone(app, "während des Ziehens")
            duringValue = timeLabel(app).value as? String ?? ""
            shot(app, "\(name)-2-waehrend")
        })])
        // The finger is up again: everything returns on its own.
        XCTAssertTrue(app.buttons["radar-layer-menu"].waitForExistence(timeout: 3), "Kartenwahl wieder da")
        assertChromeVisible(app, "nachher")
        if legendOpen { XCTAssertTrue(app.descendants(matching: .any)["radar-legend"].exists, "Legende wieder da") }
        XCTAssertNotEqual(duringValue, before, "der Zeitwert folgt dem Finger")
        XCTAssertNotEqual(slider(app).value as? String, sliderBefore, "der Regler hat sich bewegt")
        shot(app, "\(name)-3-nachher")
    }

    func testDragHidesChromeInGermanyRadarAndLiftRestoresIt() { dragCase("deutschland") }

    func testDragHidesChromeInWorldRadarWithNoteAndLiftRestoresIt() {
        dragCase("welt", prepare: { [self] app in
            choose(app, "Welt (NOAA)")
            XCTAssertTrue(app.descendants(matching: .any)["radar-world-note-estimate"].waitForExistence(timeout: 8), "Schätzhinweis vorher")
        })
    }

    func testDragHidesOpenLegendAndLiftRestoresIt() { dragCase("legende", legendOpen: true) }

    func testDragHidesChromeInEuropeRadar() { dragCase("europa", prepare: { [self] app in choose(app, "Europa (OPERA)") }) }

    /// Cancel: the app goes to the background in the middle of the drag (the system cancels the touch, no lift event).
    func testBackgroundMidDragRestoresEverything() {
        executionTimeAllowance = 180
        let app = launch()
        assertChromeVisible(app, "vorher")
        shot(app, "abbruch-1-vorher")
        dragAndHold(app, hold: 8, probes: [
            (3.0, { [self] in assertChromeGone(app, "während des Ziehens"); shot(app, "abbruch-2-waehrend") }),
            (4.5, { XCUIDevice.shared.press(.home) })])
        sleep(1)
        app.activate()
        XCTAssertTrue(app.buttons["radar-layer-menu"].waitForExistence(timeout: 10), "Kartenwahl nach der Rückkehr")
        sleep(1)
        assertChromeVisible(app, "nach Abbruch")
        shot(app, "abbruch-3-nachher")
    }

    /// A tap, and a still touch without movement, hide nothing (no flicker) and leave nothing hidden.
    func testTapAndStillTouchHideNothing() {
        executionTimeAllowance = 180
        let app = launch()
        let slider = slider(app)
        slider.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        assertChromeVisible(app, "direkt nach Tipp")
        dragAndHold(app, from: 0.4, to: 0.4, hold: 3, probes: [(1.5, { [self] in assertChromeVisible(app, "stillen Berührung") })])
        assertChromeVisible(app, "nach stiller Berührung")
        shot(app, "tipp-nachher")
    }
}
