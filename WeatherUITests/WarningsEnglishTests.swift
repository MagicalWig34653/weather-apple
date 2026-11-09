import XCTest

/// L4: English warnings screens (stub `-UITestWarnCapabilities push` for the settings, `-UITestWarnings fixture`
/// for the list). The official DWD text stays German and keeps its source line.
@MainActor
final class WarningsEnglishTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func assertNoGerman(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let german = ["Amtliche Warnungen", "Meine Orte", "Stufe 3", "Stand der Daten", "Abbrechen", "Einschalten", "Warnungen als", "Erneut versuchen", "Keine aktiven"]
        for word in german {
            let predicate = NSPredicate(format: "label CONTAINS %@", word)
            XCTAssertFalse(app.descendants(matching: .any).matching(predicate).firstMatch.exists, "German text visible: \(word)", file: file, line: line)
        }
    }

    func testWarningSettingsAreEnglish() throws {
        let app = UITestLaunch.app(language: .english, extra: ["-UITestWarnCapabilities", "push"])
        app.launch()
        let info = app.buttons["Data sources and privacy"]
        XCTAssertTrue(info.waitForExistence(timeout: 15))
        info.tap()
        let row = app.buttons["info-row-alerts"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        let toggle = app.switches["warn-toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        XCTAssertEqual(toggle.label, "Warnings as notifications")
        XCTAssertTrue(app.staticTexts["Not a replacement for official warning channels (WarnWetter app, NINA)."].exists)
        assertNoGerman(app)
        attach(app, "en-warn-settings")
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertTrue(app.alerts["Turn on warnings?"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.alerts.buttons["Turn on"].exists)
        attach(app, "en-warn-confirm")
        app.alerts.buttons["Cancel"].tap()
        XCTAssertEqual(app.switches["warn-toggle"].value as? String, "0")
    }

    func testWarningListKeepsGermanDWDTextAndEnglishChrome() throws {
        let app = UITestLaunch.app(language: .english, extra: ["-UITestWarnings", "fixture"])
        app.launch()
        let button = app.buttons["radar-warnings-button"]
        XCTAssertTrue(button.waitForExistence(timeout: 15))
        button.tap()
        XCTAssertTrue(app.navigationBars["Official warnings"].waitForExistence(timeout: 5))
        let row = app.descendants(matching: .any).matching(identifier: "warning-row").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("Level 3"))
        XCTAssertTrue(row.label.contains("Source: Deutscher Wetterdienst"))
        XCTAssertTrue(app.staticTexts["warn-stand"].label.hasPrefix("Data as of:"))
        assertNoGerman(app)
        attach(app, "en-warn-list")
        // The official DWD wording is passed on unchanged (German), with the language note and the source line.
        row.tap()
        XCTAssertEqual(app.staticTexts["warning-headline"].label, "Amtliche UNWETTERWARNUNG vor GEWITTER")
        XCTAssertEqual(app.staticTexts["warning-text"].label,
                       "Es treten Gewitter auf. Dabei gibt es Windböen bis 70 km/h (Bft 8) sowie Starkregen um 25 l/qm in einer Stunde.")
        XCTAssertTrue(app.staticTexts["warning-source"].label.hasPrefix("Source: Deutscher Wetterdienst, issued"))
        XCTAssertTrue(app.staticTexts["Official text only available in German."].exists)
        attach(app, "en-warn-detail")
    }
}
