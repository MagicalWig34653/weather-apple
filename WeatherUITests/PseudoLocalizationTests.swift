import XCTest

/// L6: layout check with pseudo-localisation. `-NSDoubleLocalizedStrings YES` doubles every localised string
/// (about 100 % longer text), `-NSForceRightToLeftWritingDirection YES` with `-AppleTextDirection YES` mirrors
/// the layout. These are checks, not shipped content: the tests only open the main screens and attach screenshots
/// for the visual inspection of truncation (see docs/status.md). Plus an English test for the forecast details sheet.
@MainActor
final class PseudoLocalizationTests: XCTestCase {
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

    private func pseudoApp(language: UITestLaunch.Language, rtl: Bool, extra: [String] = []) -> XCUIApplication {
        var arguments = ["-NSDoubleLocalizedStrings", "YES"] + extra
        if rtl { arguments += ["-AppleTextDirection", "YES", "-NSForceRightToLeftWritingDirection", "YES"] }
        let app = UITestLaunch.app(language: language, extra: arguments)
        app.launch()
        return app
    }

    /// Closes the topmost sheet via its Done button (doubled text: "Done Done"), else by swiping down.
    private func closeSheet(_ app: XCUIApplication) {
        let done = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Done' OR label BEGINSWITH 'Fertig'")).firstMatch
        if done.exists { done.tap() } else { app.swipeDown() }
        sleep(2)
    }

    /// Opens radar, layer menu, details, places, info, notifications page and attaches a screenshot of each.
    private func walkMainScreens(_ app: XCUIApplication, prefix: String) {
        let menu = app.buttons["radar-layer-menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 20))
        sleep(4)
        attach(app, "\(prefix)-radar")
        menu.tap()
        sleep(1)
        attach(app, "\(prefix)-layer-menu")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.12, dy: 0.62)).tap()
        sleep(1)

        let details = app.buttons["forecast-details"]
        if details.waitForExistence(timeout: 5), details.isHittable {
            details.tap()
            sleep(3)
            attach(app, "\(prefix)-details")
            closeSheet(app)
        }

        let place = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Choose place' OR label BEGINSWITH 'Ort auswählen'")).firstMatch
        if place.waitForExistence(timeout: 5), place.isHittable {
            place.tap()
            sleep(2)
            attach(app, "\(prefix)-places")
            let add = app.buttons["region-new"]
            if add.waitForExistence(timeout: 3), add.isEnabled {
                add.tap()
                sleep(2)
                attach(app, "\(prefix)-region-new")
            }
            closeSheet(app)
        }

        let info = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Data sources' OR label BEGINSWITH 'Datenquellen'")).firstMatch
        if info.waitForExistence(timeout: 5), info.isHittable {
            info.tap()
            sleep(2)
            attach(app, "\(prefix)-info")
            let alerts = app.buttons["info-row-alerts"]
            if alerts.waitForExistence(timeout: 3) {
                alerts.tap()
                sleep(2)
                attach(app, "\(prefix)-notifications")
            }
        }
    }

    func testDoubleLengthEnglish() throws {
        walkMainScreens(pseudoApp(language: .english, rtl: false), prefix: "pseudo-en-double")
    }

    func testDoubleLengthGerman() throws {
        walkMainScreens(pseudoApp(language: .german, rtl: false), prefix: "pseudo-de-double")
    }

    func testRightToLeftMirrorEnglish() throws {
        walkMainScreens(pseudoApp(language: .english, rtl: true), prefix: "pseudo-en-rtl")
    }

    func testDoubleLengthWarningsEnglish() throws {
        let app = pseudoApp(language: .english, rtl: false, extra: ["-UITestWarnings", "fixture"])
        let button = app.buttons["radar-warnings-button"]
        XCTAssertTrue(button.waitForExistence(timeout: 20))
        button.tap()
        sleep(3)
        attach(app, "pseudo-en-double-warnings")
        let row = app.descendants(matching: .any).matching(identifier: "warning-row").firstMatch
        if row.waitForExistence(timeout: 5) {
            row.tap()
            sleep(2)
            attach(app, "pseudo-en-double-warning-detail")
        }
    }

    /// Normal English run (no pseudo-localisation): forecast details sheet.
    func testForecastDetailsAreEnglish() throws {
        let app = UITestLaunch.app(language: .english)
        app.launch()
        let details = app.buttons["forecast-details"]
        XCTAssertTrue(details.waitForExistence(timeout: 20))
        details.tap()
        let caption = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Average intensity in mm/h")).firstMatch
        XCTAssertTrue(caption.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5))
        for word in ["Fertig", "Niederschlag", "Prognose", "Durchschnittliche"] {
            XCTAssertFalse(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", word)).firstMatch.exists, "German text visible: \(word)")
        }
        attach(app, "en-details")
    }
}
