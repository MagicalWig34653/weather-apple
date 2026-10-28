import XCTest

@MainActor
final class WeatherSmokeTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    func testInformationExplainsPrivacyWithoutLocationPermission() throws {
        let app = launchApp()
        let information = app.buttons["Datenquellen und Datenschutz"]
        XCTAssertTrue(information.waitForExistence(timeout: 15))
        information.tap()

        XCTAssertTrue(app.navigationBars["Über Weather"].waitForExistence(timeout: 5))
        let privacy = app.staticTexts["Datenschutz"]
        for _ in 0..<5 where !privacy.isHittable { app.swipeUp() }
        XCTAssertTrue(privacy.isHittable)
        let explanation = app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH %@", "Kein Konto, kein eigener Server")).firstMatch
        XCTAssertTrue(explanation.exists)

        app.buttons["Fertig"].tap()
        XCTAssertTrue(information.waitForExistence(timeout: 5))
    }

    func testNewMapPlaceCanBeSavedRenamedPersistedAndDeleted() throws {
        let app = launchApp()
        let suffix = UUID().uuidString.prefix(8)
        let originalName = "UITest-\(suffix)"
        let renamedName = "UITest-neu-\(suffix)"
        var createdNames = [originalName, renamedName]
        defer { removeCreatedPlaces(in: app, named: createdNames) }

        // A fresh map point gets a new place ID, so saving never renames an existing user place.
        let map = app.otherElements["radar-map"]
        XCTAssertTrue(map.waitForExistence(timeout: 15))
        // Keep the real long press on free map space, away from the selected-place pin.
        map.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.42)).press(forDuration: 1)
        XCTAssertTrue(app.buttons["Ort auswählen: Kartenpunkt"].waitForExistence(timeout: 5))

        app.buttons["Ausgewählten Ort speichern oder umbenennen"].tap()
        let saveAlert = app.alerts["Ort speichern"]
        XCTAssertTrue(saveAlert.waitForExistence(timeout: 5))
        replaceText(in: saveAlert.textFields.firstMatch, with: originalName)
        saveAlert.buttons["Speichern"].tap()
        XCTAssertTrue(app.buttons["Ort auswählen: \(originalName)"].waitForExistence(timeout: 5))

        openPlaces(in: app)
        let originalRow = placeButton(in: app, named: originalName)
        XCTAssertTrue(originalRow.waitForExistence(timeout: 5))
        originalRow.swipeRight()
        let renameAlert = app.alerts["Ort umbenennen"]
        // A full leading swipe can invoke the only action immediately.
        if !renameAlert.waitForExistence(timeout: 1) {
            let renameAction = app.buttons["Umbenennen"]
            XCTAssertTrue(renameAction.waitForExistence(timeout: 5))
            renameAction.tap()
        }
        XCTAssertTrue(renameAlert.waitForExistence(timeout: 5))
        replaceText(in: renameAlert.textFields.firstMatch, with: renamedName)
        renameAlert.buttons["Speichern"].tap()
        let renamedRow = placeButton(in: app, named: renamedName)
        XCTAssertTrue(renamedRow.waitForExistence(timeout: 5))
        renamedRow.tap()
        XCTAssertTrue(app.buttons["Ort auswählen: \(renamedName)"].waitForExistence(timeout: 5))

        app.terminate()
        app.launch()
        openPlaces(in: app)
        let persistedRow = placeButton(in: app, named: renamedName)
        XCTAssertTrue(persistedRow.waitForExistence(timeout: 5), "Der gespeicherte Ort muss nach App-Neustart bestehen bleiben.")
        persistedRow.swipeLeft()
        // A full trailing swipe may already have performed deletion.
        if app.buttons["Löschen"].exists { app.buttons["Löschen"].tap() }
        XCTAssertTrue(placeButton(in: app, named: renamedName).waitForNonExistence(timeout: 5))
        createdNames.removeAll()
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
        app.launch()
        return app
    }

    private func openPlaces(in app: XCUIApplication) {
        let title = app.navigationBars["Deine Orte"]
        if title.exists { return }
        let button = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Ort auswählen:")).firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        button.tap()
        XCTAssertTrue(title.waitForExistence(timeout: 5))
    }

    private func placeButton(in app: XCUIApplication, named name: String) -> XCUIElement {
        // The map header is also exposed behind the sheet as "Ort auswählen: <name>".
        // Exact equality selects only this test's saved-place row, never that header.
        app.buttons.matching(NSPredicate(format: "label == %@", name)).firstMatch
    }

    private func replaceText(in field: XCUIElement, with text: String) {
        field.tap()
        let existing = field.value as? String ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count) + text)
    }

    private func removeCreatedPlaces(in app: XCUIApplication, named names: [String]) {
        guard !names.isEmpty else { return }
        // Only names with this test's random suffix are ever considered for removal.
        if app.state != .runningForeground { app.launch() }
        for alert in app.alerts.allElementsBoundByIndex where alert.exists {
            if alert.buttons["Abbrechen"].exists { alert.buttons["Abbrechen"].tap() }
        }
        let selector = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Ort auswählen:")).firstMatch
        if !app.navigationBars["Deine Orte"].exists {
            guard selector.waitForExistence(timeout: 5) else { return }
            selector.tap()
        }
        for name in names {
            let row = placeButton(in: app, named: name)
            if row.exists {
                row.swipeLeft()
                if app.buttons["Löschen"].exists { app.buttons["Löschen"].tap() }
            }
        }
    }
}
