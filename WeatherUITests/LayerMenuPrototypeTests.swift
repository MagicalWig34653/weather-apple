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

    private func run(_ appearance: XCUIDevice.Appearance, _ suffix: String) throws {
        XCUIDevice.shared.appearance = appearance
        let app = UITestLaunch.app(language: .german)
        app.launch()
        let menu = app.buttons["radar-layer-menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 20))
        menu.tap()
        attach("1-hauptmenue-\(suffix)")
        // Untermenüs sind native Menü-Einträge; Zugriff über Beschriftung, weil die Kennungen je nach System fehlen.
        let rain = app.buttons["radar-layer-group-rain"].exists ? app.buttons["radar-layer-group-rain"]
            : app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Regenebenen")).firstMatch
        XCTAssertTrue(rain.waitForExistence(timeout: 5), "Untermenü Regenebenen fehlt")
        rain.tap()
        attach("2-regenebenen-\(suffix)")
        // Zurück zum Hauptmenü (System-Zurück oder Menü neu öffnen).
        app.terminate()
        app.launch()
        XCTAssertTrue(menu.waitForExistence(timeout: 20))
        menu.tap()
        let extra = app.buttons["radar-layer-group-extra"].exists ? app.buttons["radar-layer-group-extra"]
            : app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Zusatzebenen")).firstMatch
        XCTAssertTrue(extra.waitForExistence(timeout: 5), "Untermenü Zusatzebenen fehlt")
        extra.tap()
        attach("3-zusatzebenen-\(suffix)")
    }

    func testMenuScreenshotsLight() throws { try run(.light, "hell") }
    func testMenuScreenshotsDark() throws { try run(.dark, "dunkel") }
}
