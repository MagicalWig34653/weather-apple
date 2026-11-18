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

    /// Hauptliste, Untermenüs Regen, Luftdruck und Feuchtigkeit; dann Temperatur aktiv (Haken), Darstellung mit Wald, Legende.
    private func run(_ appearance: XCUIDevice.Appearance, _ suffix: String) throws {
        XCUIDevice.shared.appearance = appearance
        let app = UITestLaunch.app(language: .german, extra: ["-UITestLayers", "d2"])
        app.launch()
        let menu = app.buttons["radar-layer-menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 20))
        sleep(3)
        // Layers appear once the server (fixture) reported them: the main list is shown after a re-open.
        menu.tap(); closeMenu(app); sleep(2)
        menu.tap()
        attach("1-hauptliste-\(suffix)")
        XCTAssertFalse(app.buttons["radar-layer-quick-radar"].exists, "keine Symbolreihe")
        closeMenu(app)
        open(app, menu, group: "Regen")
        attach("2-regen-\(suffix)")
        closeMenu(app)
        open(app, menu, group: "Luftdruck")
        attach("3-luftdruck-\(suffix)")
        closeMenu(app)
        open(app, menu, group: "Feuchtigkeit")
        attach("4-feuchtigkeit-\(suffix)")
        closeMenu(app)
        let temperature = try XCTUnwrap(openLayerEntry(app, group: nil, entry: "Temperatur"), "Temperatur fehlt")
        temperature.tap()
        XCTAssertTrue(app.sliders["Zeitpunkt Temperatur"].waitForExistence(timeout: 10))
        sleep(2)
        menu.tap()
        attach("5-hauptliste-temperatur-aktiv-\(suffix)")
        let display = group(app, "Darstellung")
        XCTAssertTrue(display.waitForExistence(timeout: 5), "Untermenü Darstellung fehlt")
        display.tap()
        attach("6-darstellung-\(suffix)")
        let forest = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Wald")).firstMatch
        XCTAssertTrue(forest.waitForExistence(timeout: 5), "Wald-Schalter fehlt")
        forest.tap()
        attach("7-darstellung-wald-an-\(suffix)")
        closeMenu(app)
        let legend = app.buttons["radar-legend-toggle"]
        if legend.waitForExistence(timeout: 5) {
            legend.tap()
            XCTAssertTrue(app.descendants(matching: .any)["radar-legend"].waitForExistence(timeout: 5))
            XCTAssertEqual(app.switches["forest-toggle"].value as? String, "1", "Wald-Schalter im Menü hat den Wald eingeschaltet")
            attach("8-legende-wald-\(suffix)")
            // Wald zurücksetzen (die Einstellung bleibt sonst auf dem Gerät und verfälscht andere Tests).
            app.switches["forest-toggle"].tap()
        }
    }

    func testMenuScreenshotsLight() throws { try run(.light, "hell") }
    func testMenuScreenshotsDark() throws { try run(.dark, "dunkel") }
}
