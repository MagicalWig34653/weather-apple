import XCTest

/// L3: English places sheet, region creation, info sheet and notifications page. Screenshots are attached for the
/// visual check of English text lengths; each screen is also checked negatively for German words.
@MainActor
final class PlacesEnglishTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    private func launch() -> XCUIApplication {
        let app = UITestLaunch.app(language: .english)
        app.launch()
        return app
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func assertNoGerman(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let german = ["Deine Orte", "Region hinzufügen", "Regenhinweis", "Mitteilungen", "Datenschutz", "Fertig", "Abbrechen", "Über Showers",
                      "Regionen", "Gespeicherte", "Einstellungen", "Vorlaufzeit", "Löschen", "Zeitkritisch"]
        for word in german {
            let predicate = NSPredicate(format: "label CONTAINS %@", word)
            XCTAssertFalse(app.descendants(matching: .any).matching(predicate).firstMatch.exists, "German text visible: \(word)", file: file, line: line)
        }
    }

    private func openPlaces(_ app: XCUIApplication) {
        let button = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Choose place:")).firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 15))
        button.tap()
        XCTAssertTrue(app.navigationBars["Your Places"].waitForExistence(timeout: 5))
    }

    func testPlacesSheetAndRegionCreationAreEnglish() throws {
        let app = launch()
        openPlaces(app)
        XCTAssertTrue(app.buttons["Use current location"].exists)
        XCTAssertTrue(app.staticTexts["Regions"].exists || app.staticTexts["REGIONS"].exists)
        XCTAssertTrue(app.buttons["Done"].exists)
        assertNoGerman(app)
        attach(app, "en-places")
        let add = app.buttons["region-new"]
        guard add.waitForExistence(timeout: 5), add.isEnabled else { return }
        XCTAssertEqual(add.label, "Add Region")
        add.tap()
        XCTAssertTrue(app.navigationBars["New Region"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Trigger"].exists || app.buttons["Trigger"].exists || app.pickers["Trigger"].exists || app.descendants(matching: .any)["Trigger"].exists)
        assertNoGerman(app)
        attach(app, "en-region-new")
        let create = app.buttons["region-add"]
        if create.isEnabled {
            create.tap()
            XCTAssertTrue(app.alerts["Enable Rain Alert for Region?"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.alerts.buttons["Read Privacy Policy"].exists)
            XCTAssertTrue(app.alerts.buttons["Cancel"].exists)
            attach(app, "en-region-confirm")
            app.alerts.buttons["Cancel"].tap()
        }
    }

    func testInformationSheetAndAlertsPageAreEnglish() throws {
        let app = launch()
        let info = app.buttons["Data sources and privacy"]
        XCTAssertTrue(info.waitForExistence(timeout: 15))
        info.tap()
        XCTAssertTrue(app.navigationBars["About Showers"].waitForExistence(timeout: 5))
        assertNoGerman(app)
        attach(app, "en-info")
        let pages: [(String, String, String)] = [
            ("sources", "info-page-sources", "Current radar images:"),
            ("privacy", "info-page-privacy", "No account and no analytics"),
            ("widgets", "info-page-widgets", "Widgets use your saved places"),
            ("alerts", "info-page-alerts", "You can set up rain alerts"),
            ("past", "info-page-past", "How far back the timeline"),
            ("support", "info-page-support", "Privacy Policy"),
        ]
        for (row, _, text) in pages {
            let button = app.buttons["info-row-\(row)"]
            XCTAssertTrue(button.waitForExistence(timeout: 5), row)
            button.tap()
            let match = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
            XCTAssertTrue(match.waitForExistence(timeout: 5), text)
            attach(app, "en-info-\(row)")
            app.navigationBars.buttons.firstMatch.tap()
        }
        let alerts = app.buttons["info-row-alerts"]
        alerts.tap()
        XCTAssertTrue(app.staticTexts["push-status"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["push-status"].label, "Notifications: off")
    }
}
