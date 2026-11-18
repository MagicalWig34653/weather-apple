import XCTest

/// Setup wizard: `-UITestSetup` resets `setupVersion` and shows the wizard (without it UI tests never see it).
/// The system prompts are never answered here; the flow only uses "Später"/"Überspringen".
@MainActor
final class SetupWizardTests: XCTestCase {
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

    func testWizardWalkthroughWithLaterAndFinish() {
        let app = UITestLaunch.app(language: .german, extra: ["-UITestSetup"])
        app.launch()
        if !app.staticTexts["Willkommen bei Showers"].waitForExistence(timeout: 15) { print(app.debugDescription) }
        XCTAssertTrue(app.staticTexts["Willkommen bei Showers"].exists)
        attach(app, "1-welcome")
        app.buttons["setup-primary"].tap()
        // Optional steps depend on the simulator state; never answer a system prompt, always use "Später".
        var shots = 1
        while !app.staticTexts["Fertig"].exists, app.buttons["setup-later"].waitForExistence(timeout: 5), shots < 6 {
            shots += 1
            attach(app, "step-\(shots)")
            app.buttons["setup-later"].tap()
        }
        XCTAssertTrue(app.staticTexts["Fertig"].waitForExistence(timeout: 5))
        attach(app, "5-done")
        app.buttons["setup-primary"].tap()
        XCTAssertFalse(app.buttons["setup-primary"].waitForExistence(timeout: 2))
    }

    /// Screenshot run for review (clean simulator, appearance set with `simctl ui`): attaches one image per step.
    func testScreenshotsAllSteps() {
        let app = UITestLaunch.app(language: .german, extra: ["-UITestSetup"])
        app.launch()
        XCTAssertTrue(app.staticTexts["Willkommen bei Showers"].waitForExistence(timeout: 30))
        attach(app, "01-willkommen")
        // One way to skip per screen: welcome has "Überspringen" only, later steps "Später" only.
        XCTAssertTrue(app.buttons["setup-skip-all"].exists)
        XCTAssertFalse(app.buttons["setup-later"].exists)
        app.buttons["setup-primary"].tap()
        let found = app.staticTexts["Dein Standort"].waitForExistence(timeout: 8)
        attach(app, "02-standort")
        XCTAssertTrue(found)
        XCTAssertTrue(app.buttons["setup-later"].exists)
        XCTAssertFalse(app.buttons["setup-skip-all"].exists)
        app.buttons["setup-later"].tap()
        XCTAssertTrue(app.staticTexts["Deine Orte"].waitForExistence(timeout: 5))
        attach(app, "03-orte")
        let field = app.textFields["setup-search"]
        field.tap()
        field.typeText("Berlin\n")
        let result = app.buttons.matching(identifier: "setup-result").firstMatch
        if result.waitForExistence(timeout: 10) {
            attach(app, "03b-orte-suche")
            result.tap()
            Thread.sleep(forTimeInterval: 1.5)
        }
        attach(app, "03c-orte-gespeichert")
        app.buttons["setup-primary"].tap()
        XCTAssertTrue(app.staticTexts["Regenhinweis"].waitForExistence(timeout: 5))
        attach(app, "04-regenhinweis")
        // Opt-in: nothing preselected, button disabled until a place is ticked, then an explicit consent dialog.
        XCTAssertFalse(app.buttons["setup-primary"].isEnabled)
        let toggle = app.switches.matching(identifier: "setup-alert-place").firstMatch
        if toggle.waitForExistence(timeout: 5) {
            XCTAssertEqual(toggle.value as? String, "0")
            toggle.tap()
            attach(app, "04b-regenhinweis-ausgewaehlt")
            XCTAssertTrue(app.buttons["setup-primary"].isEnabled)
            app.buttons["setup-primary"].tap()
            XCTAssertTrue(app.alerts["Regenhinweis aktivieren?"].waitForExistence(timeout: 5))
            attach(app, "04c-zustimmung")
            app.alerts.buttons["Abbrechen"].tap()
        }
        app.buttons["setup-later"].tap()
        XCTAssertTrue(app.staticTexts["Fertig"].waitForExistence(timeout: 5))
        attach(app, "05-fertig")
    }

    func testSkipAllEndsSetup() {
        let app = UITestLaunch.app(language: .german, extra: ["-UITestSetup"])
        app.launch()
        XCTAssertTrue(app.buttons["setup-skip-all"].waitForExistence(timeout: 15))
        app.buttons["setup-skip-all"].tap()
        XCTAssertFalse(app.buttons["setup-skip-all"].waitForExistence(timeout: 2))
    }

    func testEnglishWelcome() {
        let app = UITestLaunch.app(language: .english, extra: ["-UITestSetup"])
        app.launch()
        XCTAssertTrue(app.staticTexts["Welcome to Showers"].waitForExistence(timeout: 30))
        XCTAssertFalse(app.staticTexts["Willkommen bei Showers"].exists)
    }
}
