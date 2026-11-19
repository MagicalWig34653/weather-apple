import XCTest

/// Third rain map (world, NOAA satellite estimate): choice Deutschland / Europa / Welt in the native submenu, fixed estimate
/// note, short credit "NOAA", and the missing-data note that appears and disappears again. Layers come from the
/// `-UITestLayers all` stub (no network); screenshots are attached for the visual check.
@MainActor
final class RadarWorldUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    private func attach(_ name: String) {
        sleep(1)
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = UITestLaunch.app(language: .german, extra: ["-UITestLayers", "all"] + extra)
        app.launch()
        let menu = app.buttons["radar-layer-menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 20))
        sleep(2)
        // The stubbed layers are reported after the first probe: open and close the menu once.
        menu.tap()
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5)).tap()
        sleep(1)
        return app
    }

    private func choose(_ app: XCUIApplication, _ prefix: String) throws {
        let entry = try XCTUnwrap(openLayerEntry(app, group: "Regen", entry: prefix), "\(prefix) fehlt im Regen-Untermenü")
        XCTAssertTrue(entry.isEnabled, "\(prefix) wählbar")
        entry.tap()
        sleep(2)
    }

    /// The credit follows the layer switch with the manifest: wait for it instead of reading it once.
    private func waitForLabel(_ element: XCUIElement, _ label: String, timeout: TimeInterval = 10) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND label == %@", label), object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    private func note(_ app: XCUIApplication, _ kind: String) -> XCUIElement {
        app.descendants(matching: .any)["radar-world-note-\(kind)"]
    }

    func testRainSubmenuOffersGermanyEuropeWorldAndWorldShowsEstimateNote() throws {
        let app = launch()
        let menu = app.buttons["radar-layer-menu"]
        menu.tap()
        let rain = app.buttons.matching(NSPredicate(format: "label == %@", "Regen")).firstMatch
        XCTAssertTrue(rain.waitForExistence(timeout: 5))
        rain.tap()
        for prefix in ["Deutschland", "Europa", "Welt"] {
            let entry = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
            XCTAssertTrue(entry.waitForExistence(timeout: 5), prefix)
            XCTAssertTrue(entry.isEnabled, prefix)
        }
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "bald")).firstMatch.exists, "Welt nicht mehr 'bald'")
        // The rows are the system menu's own; the own control (capsule) keeps the 44 pt target.
        XCTAssertGreaterThanOrEqual(menu.frame.height, 44, "Trefferfläche Kartenwahl")
        attach("welt-1-regen-menue")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5)).tap()
        sleep(1)

        try choose(app, "Welt")
        XCTAssertTrue(app.sliders["Radarzeitpunkt"].waitForExistence(timeout: 10), "Zeitachse der Weltkarte")
        let estimate = note(app, "estimate")
        XCTAssertTrue(estimate.waitForExistence(timeout: 5), "Schätzhinweis fest eingeblendet")
        XCTAssertTrue(estimate.label.contains("Satellitendaten"), estimate.label)
        XCTAssertTrue(estimate.label.contains("ungenauer als Radar"), estimate.label)
        let credit = app.staticTexts["radar-attribution"]
        XCTAssertTrue(credit.waitForExistence(timeout: 10))
        XCTAssertEqual(credit.label, "NOAA", "kurze Quellzeile ohne Logo")
        let missingImage = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "fehlt")).firstMatch
        XCTAssertFalse(missingImage.exists, "kein Bild-fehlt-Hinweis: \(missingImage.exists ? missingImage.label : "")")
        XCTAssertTrue((menu.value as? String ?? "").contains("Welt"), "Kapsel nennt die Weltkarte")
        attach("welt-2-karte-schaetzhinweis")

        try choose(app, "Europa")
        XCTAssertTrue(estimate.waitForNonExistence(timeout: 5), "Hinweis verschwindet bei Europa")
        XCTAssertTrue(waitForLabel(app.staticTexts["radar-attribution"], "\u{00A9} EUMETNET"), "Quellzeile Europa")
        attach("welt-3-europa-unveraendert")

        try choose(app, "Deutschland")
        XCTAssertFalse(estimate.exists)
        XCTAssertTrue(app.staticTexts["radar-attribution"].waitForExistence(timeout: 10))
        XCTAssertTrue(waitForLabel(app.staticTexts["radar-attribution"], "\u{00A9} DWD"), "Quellzeile Deutschland")
        attach("welt-4-deutschland-unveraendert")
    }

    func testMissingWorldDataShowsNoteInsteadOfSilentFallbackThenRecoversAndNoteDisappears() throws {
        executionTimeAllowance = 170
        let start = Date()
        let app = launch(["-UITestWorldOutageAfter", "60", "-UITestWorldOutageFor", "25"])
        try choose(app, "Welt")
        XCTAssertTrue(note(app, "estimate").waitForExistence(timeout: 5))
        XCTAssertFalse(note(app, "unavailable").exists, "Daten vorhanden: kein Fehlerhinweis")
        XCTAssertLessThan(Date().timeIntervalSince(start), 55, "Welt vor dem Ausfall gewählt")
        // After the stub's outage (60 s after the first world request) the next reload gets a 404 for the world layer.
        let wait = 65 - Date().timeIntervalSince(start)
        if wait > 0 { Thread.sleep(forTimeInterval: wait) }
        let menu = app.buttons["radar-layer-menu"]
        menu.tap()
        let reload = app.buttons["Daten neu laden"]
        XCTAssertTrue(reload.waitForExistence(timeout: 5))
        reload.tap()
        let missing = note(app, "unavailable")
        XCTAssertTrue(missing.waitForExistence(timeout: 15), "Hinweis statt leerer Karte")
        XCTAssertTrue(missing.label.contains("nicht verfügbar"), missing.label)
        XCTAssertTrue(note(app, "estimate").exists, "Schätzhinweis bleibt")
        XCTAssertTrue((menu.value as? String ?? "").contains("Welt"), "kein stilles Zurückfallen auf Deutschland")
        XCTAssertFalse(app.staticTexts["radar-attribution"].exists, "keine Quellzeile ohne Bild")
        attach("welt-5-fehlt-hinweis")

        // Way back WITHOUT a layer change: once the stub serves the world again, the next reload brings the picture back.
        let back = 100 - Date().timeIntervalSince(start)
        if back > 0 { Thread.sleep(forTimeInterval: back) }
        menu.tap()
        XCTAssertTrue(reload.waitForExistence(timeout: 5))
        reload.tap()
        XCTAssertTrue(missing.waitForNonExistence(timeout: 15), "Fehlerhinweis verschwindet nach Erholung")
        XCTAssertTrue(note(app, "estimate").exists, "Schätzhinweis bleibt")
        XCTAssertTrue((menu.value as? String ?? "").contains("Welt"), "Welt bleibt gewählt")
        let credit = app.staticTexts["radar-attribution"]
        XCTAssertTrue(credit.waitForExistence(timeout: 10), "Quellzeile wieder da")
        XCTAssertEqual(credit.label, "NOAA")
        XCTAssertTrue(app.sliders["Radarzeitpunkt"].waitForExistence(timeout: 10), "Zeitachse wieder da")
        XCTAssertFalse(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "nicht verfügbar")).firstMatch.exists,
                       "kein Nicht-verfügbar-Hinweis mehr")
        attach("welt-5b-erholt")

        try choose(app, "Deutschland")
        XCTAssertTrue(missing.waitForNonExistence(timeout: 5), "Hinweis verschwindet nach Wechsel")
        XCTAssertFalse(note(app, "estimate").exists)
        attach("welt-6-hinweis-weg")
    }
}
