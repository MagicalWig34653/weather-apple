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
