import XCTest

/// Kartenwahl-Prototyp: natives Menü mit verschachtelten Untermenüs. Hängt Vollbild-Screenshots (hell/dunkel) an,
/// weil das Systemmenü im Elementbaum der App nicht abgebildet wird. Nur für die Sichtprüfung, keine Logikprüfung.
@MainActor
final class LayerMenuPrototypeTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    override func tearDown() async throws {
        XCUIDevice.shared.appearance = .light
    }

    private func attach(_ name: String) {
        sleep(1)
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func group(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label == %@", name)).firstMatch
    }

    private func closeMenu(_ app: XCUIApplication) {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5)).tap()
        sleep(1)
    }

    private func open(_ app: XCUIApplication, _ menu: XCUIElement, group name: String?) {
        menu.tap()
        guard let name else { return }
        let entry = group(app, name)
        XCTAssertTrue(entry.waitForExistence(timeout: 5), "Untermenü \(name) fehlt")
        entry.tap()
    }

    private func launchAll(_ suffix: String, _ appearance: XCUIDevice.Appearance) -> (XCUIApplication, XCUIElement) {
        XCUIDevice.shared.appearance = appearance
        let app = UITestLaunch.app(language: .german, extra: ["-UITestLayers", "all"])
        app.launch()
        let menu = app.buttons["radar-layer-menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 20))
        sleep(3)
        // Die Ebenen erscheinen, sobald die Fixture sie gemeldet hat: nach einmal Öffnen und Schließen ist die Liste vollständig.
        menu.tap(); closeMenu(app); sleep(2)
        return (app, menu)
    }

    /// 6 Bilder je Erscheinungsbild: Hauptliste, Regen, Luftdruck, Feuchtigkeit, Karte mit Quellzeile, Karte mit Temperatur (echter Layer).
    private func run(_ appearance: XCUIDevice.Appearance, _ suffix: String) throws {
        let (app, menu) = launchAll(suffix, appearance)
        menu.tap()
        XCTAssertTrue(group(app, "Luftdruck").waitForExistence(timeout: 5))
        XCTAssertTrue(group(app, "Feuchtigkeit").exists)
        XCTAssertFalse(app.buttons["radar-layer-quick-radar"].exists, "keine Symbolreihe")
        XCTAssertFalse(group(app, "Darstellung").exists, "Darstellung entfällt")
        XCTAssertTrue(app.buttons["Daten neu laden"].exists, "Daten neu laden am Ende des Menüs")
        attach("1-hauptliste-\(suffix)")
        closeMenu(app)
        open(app, menu, group: "Regen")
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Europa")).firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "nicht verfügbar")).firstMatch.exists, "alle Ebenen angeboten")
        attach("2-regen-\(suffix)")
        closeMenu(app)
        open(app, menu, group: "Luftdruck")
        attach("3-luftdruck-\(suffix)")
        closeMenu(app)
        open(app, menu, group: "Feuchtigkeit")
        attach("4-feuchtigkeit-\(suffix)")
        closeMenu(app)
        let credit = app.staticTexts["radar-attribution"]
        XCTAssertTrue(credit.waitForExistence(timeout: 10))
        XCTAssertEqual(credit.label, "\u{00A9} DWD", "kurze Quellzeile statt Kapsel")
        XCTAssertLessThanOrEqual(credit.frame.height, 20, "eine Zeile")
        attach("5-karte-quellzeile-\(suffix)")
        let temperature = try XCTUnwrap(openLayerEntry(app, group: nil, entry: "Temperatur"), "Temperatur fehlt")
        temperature.tap()
        XCTAssertTrue(app.sliders["Zeitpunkt Temperatur"].waitForExistence(timeout: 10))
        sleep(4)
        XCTAssertFalse(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "fehlt")).firstMatch.exists, "kein Bild-fehlt-Hinweis")
        attach("6-karte-temperatur-aktiv-\(suffix)")
    }

    /// Beleg: Wald ist im Legendenpanel bedienbar (Menü hat keine Darstellung mehr), die Quellzeile nennt ihn kurz,
    /// der Info-Bildschirm hat die vollen Quellenangaben, und die Legende ist scrollbar (nichts nur abgeschnitten).
    private func runForestAndInfo(_ appearance: XCUIDevice.Appearance, _ suffix: String) throws {
        let (app, _) = launchAll(suffix, appearance)
        let temperature = try XCTUnwrap(openLayerEntry(app, group: nil, entry: "Temperatur"), "Temperatur fehlt")
        temperature.tap()
        XCTAssertTrue(app.sliders["Zeitpunkt Temperatur"].waitForExistence(timeout: 10))
        let legend = app.buttons["radar-legend-toggle"]
        XCTAssertTrue(legend.waitForExistence(timeout: 5))
        legend.tap()
        let panel = app.descendants(matching: .any)["radar-legend"]
        XCTAssertTrue(panel.waitForExistence(timeout: 5))
        let toggle = app.switches["forest-toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), "Wald-Schalter im Legendenpanel")
        if toggle.value as? String != "0" { toggle.tap(); sleep(1) }
        toggle.tap()
        XCTAssertEqual(toggle.value as? String, "1")
        sleep(2)
        let credit = app.staticTexts["radar-attribution"]
        XCTAssertEqual(credit.label, "\u{00A9} DWD \u{00B7} \u{00A9} ESA WorldCover", "Waldquelle kurz auf der Karte")
        attach("7-legende-wald-\(suffix)")
        panel.swipeUp()
        sleep(1)
        let source = app.staticTexts["forest-attribution"]
        XCTAssertTrue(source.waitForExistence(timeout: 3) && source.isHittable, "Waldquelle in der Legende nach dem Scrollen erreichbar")
        attach("7b-legende-gescrollt-\(suffix)")
        panel.swipeDown()
        toggle.tap()
        XCTAssertEqual(toggle.value as? String, "0", "Wald wieder aus")
        legend.tap()
        // Info-Bildschirm: volle Quellenangaben.
        app.buttons["Datenquellen und Datenschutz"].tap()
        // Row of the information list (not the map button of the same name behind the sheet).
        let sources = app.collectionViews.staticTexts["Datenquellen"].firstMatch
        XCTAssertTrue(sources.waitForExistence(timeout: 8), "Zeile Datenquellen")
        sources.tap()
        let full = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Quelle: Deutscher Wetterdienst")).firstMatch
        XCTAssertTrue(full.waitForExistence(timeout: 5), "volle Quellenangabe im Info-Bildschirm")
        XCTAssertTrue(app.descendants(matching: .any)["layer-source-radar_eu"].waitForExistence(timeout: 3), "Quelle Regen Europa (Manifest-Text)")
        attach("8-info-quellen-\(suffix)")
    }

    func testMenuScreenshotsLight() throws { try run(.light, "hell") }
    func testMenuScreenshotsDark() throws { try run(.dark, "dunkel") }
    func testForestAndInfoLight() throws { try runForestAndInfo(.light, "hell") }
    func testForestAndInfoDark() throws { try runForestAndInfo(.dark, "dunkel") }
}
