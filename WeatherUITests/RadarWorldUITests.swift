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
            XCTAssertGreaterThanOrEqual(entry.frame.height, 44, "Trefferfläche \(prefix)")
        }
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "bald")).firstMatch.exists, "Welt nicht mehr 'bald'")
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
        XCTAssertFalse(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "fehlt")).firstMatch.exists, "kein Bild-fehlt-Hinweis")
        XCTAssertTrue((menu.value as? String ?? "").contains("Welt"), "Kapsel nennt die Weltkarte")
        attach("welt-2-karte-schaetzhinweis")

        try choose(app, "Europa")
        XCTAssertTrue(estimate.waitForNonExistence(timeout: 5), "Hinweis verschwindet bei Europa")
        XCTAssertEqual(app.staticTexts["radar-attribution"].label, "\u{00A9} EUMETNET")
        attach("welt-3-europa-unveraendert")

        try choose(app, "Deutschland")
        XCTAssertFalse(estimate.exists)
        XCTAssertTrue(app.staticTexts["radar-attribution"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["radar-attribution"].label, "\u{00A9} DWD")
        attach("welt-4-deutschland-unveraendert")
    }

    func testMissingWorldDataShowsNoteInsteadOfSilentFallbackAndNoteDisappears() throws {
        let app = launch(["-UITestWorldOutageAfter", "30"])
        try choose(app, "Welt")
        XCTAssertTrue(note(app, "estimate").waitForExistence(timeout: 5))
        XCTAssertFalse(note(app, "unavailable").exists, "Daten vorhanden: kein Fehlerhinweis")
        // After the stub's outage the next reload gets a 404 for the world layer.
        sleep(32)
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

        try choose(app, "Deutschland")
        XCTAssertTrue(missing.waitForNonExistence(timeout: 5), "Hinweis verschwindet nach Wechsel")
        XCTAssertFalse(note(app, "estimate").exists)
        attach("welt-6-hinweis-weg")
    }
}
