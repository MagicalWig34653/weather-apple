import XCTest

/// Orte-Bildschirm: sichtbare Zeilenhöhe (Zelle) bleibt kompakt, die Trefferfläche von Ortszeile und Regenhinweis-Glocke
/// bleibt mindestens 44 pt. Messwerte (Accessibility-Frames) gehen als `PLACES_LAYOUT ...` ins Log; Bilder nach
/// `/private/tmp/claude-501/orte-out/<tag>.png`, falls der Ordner existiert.
@MainActor
final class PlacesLayoutTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .portrait
    }

    private func replaceText(in field: XCUIElement, with text: String) {
        field.tap()
        let existing = field.value as? String ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count) + text)
    }

    private func save(_ app: XCUIApplication, _ tag: String) {
        let shot = app.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = tag; attachment.lifetime = .keepAlways
        add(attachment)
        let dir = "/private/tmp/claude-501/orte-out"
        guard FileManager.default.fileExists(atPath: dir) else { return }
        try? shot.pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(tag).png"))
    }

    private func measure(size: String?, tag: String, seedPush: Bool = false) {
        let name = "Layout-\(UUID().uuidString.prefix(6))"
        var extra: [String] = []
        if let size { extra += ["-UIPreferredContentSizeCategoryName", size] }
        if seedPush { extra += ["-UITestPushSeed"] }
        let app = UITestLaunch.app(language: .german, extra: extra)
        app.launch()
        let map = app.otherElements["radar-map"]
        XCTAssertTrue(map.waitForExistence(timeout: 20))
        map.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.42)).press(forDuration: 1)
        XCTAssertTrue(app.buttons["Ort auswählen: Kartenpunkt"].waitForExistence(timeout: 8))
        app.buttons["Ausgewählten Ort speichern oder umbenennen"].tap()
        let alert = app.alerts["Ort speichern"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        replaceText(in: alert.textFields.firstMatch, with: name)
        alert.buttons["Speichern"].tap()
        if !alert.waitForNonExistence(timeout: 2) { alert.buttons["Speichern"].tap() }
        let selector = app.buttons["Ort auswählen: \(name)"]
        XCTAssertTrue(selector.waitForExistence(timeout: 8))
        selector.tap()
        XCTAssertTrue(app.navigationBars["Deine Orte"].waitForExistence(timeout: 5))
        sleep(1)

        let row = app.buttons.matching(NSPredicate(format: "label == %@", name)).firstMatch
        let ownCell = app.cells.containing(NSPredicate(format: "label == %@", name)).firstMatch
        let bell = ownCell.buttons["place-push"].firstMatch
        let location = app.buttons["Aktuellen Standort verwenden"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(bell.exists)
        // Zelle der Ortszeile (enthält Glocke) und Zelle darunter ("Aktuellen Standort verwenden").
        let cell = ownCell
        let nextCell = app.cells.containing(.button, identifier: "Aktuellen Standort verwenden").firstMatch
        if seedPush { _ = nextCell.waitForExistence(timeout: 1) }
        record("\(tag) row=\(row.frame) bell=\(bell.frame) cell=\(cell.frame) locationButton=\(location.exists ? location.frame : .zero) locationCell=\(nextCell.exists ? nextCell.frame : .zero)")
        let pitch = nextCell.exists ? nextCell.frame.minY - cell.frame.minY : 0
        record("\(tag) cellHeight=\(cell.frame.height) rowH=\(row.frame.height) bellH=\(bell.frame.height) bellW=\(bell.frame.width) pitchToNextCell=\(pitch)")
        save(app, tag)
        if seedPush {
            bell.tap()
            _ = app.navigationBars["Regenhinweis"].waitForExistence(timeout: 5)
            let picker = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Empfindlichkeit")).firstMatch
            for _ in 0..<8 where !picker.exists { app.swipeUp() }
            XCTAssertTrue(picker.waitForExistence(timeout: 5))
            record("\(tag) sensitivity label='\(picker.label)' value='\(picker.value as? String ?? "")' frame=\(picker.frame) screen=\(app.frame)")
            save(app, tag + "-empfindlichkeit")
            // Der Text darf nicht umbrechen: eine Textzeile (Höhe unter 3 Zeilen Standardschrift) und volle Breite sichtbar.
            XCTAssertLessThanOrEqual(picker.frame.maxX, app.frame.width + 0.5, "\(tag): Empfindlichkeit läuft aus dem Bild")
            app.navigationBars.buttons.firstMatch.tap()
            if row.waitForExistence(timeout: 3) {
                row.swipeLeft()
                if app.buttons["Löschen"].waitForExistence(timeout: 2) { app.buttons["Löschen"].tap() }
            }
            app.terminate()
            return
        }

        // Dieselbe Prüfung wie in AccessibilityAuditTests, aber mit gespeichertem Ort ("Hit area is too small").
        try? app.performAccessibilityAudit(for: .hitRegion) { issue in
            let label = issue.element?.label ?? ""
            if issue.element?.elementType == .map || ["Legal", "Legal Information", "Rechtl. Informationen", "Apple Maps"].contains(label) { return true }
            XCTFail("\(tag): \(issue.compactDescription) [\(label)] \(issue.element?.frame ?? .zero)")
            return false
        }
        XCTAssertGreaterThanOrEqual(row.frame.height, 43.99, "\(tag): Ortszeile Trefferhöhe")
        XCTAssertGreaterThanOrEqual(bell.frame.height, 43.99, "\(tag): Glocke Trefferhöhe")
        XCTAssertGreaterThanOrEqual(bell.frame.width, 43.99, "\(tag): Glocke Trefferbreite")
        if let limit = Self.maxCellHeight[tag] { XCTAssertLessThanOrEqual(cell.frame.height, limit, "\(tag): Zeilenhöhe sichtbar zu groß") }
        if let limit = Self.maxPitch[tag] { XCTAssertLessThanOrEqual(pitch, limit, "\(tag): Zeilenabstand zu groß") }

        // Aufräumen: nur den eigenen Testort löschen.
        row.swipeLeft()
        if app.buttons["Löschen"].waitForExistence(timeout: 2) { app.buttons["Löschen"].tap() }
        app.terminate()
    }

    private func record(_ line: String) { print("PLACES_LAYOUT \(line)") }

    /// Obergrenzen aus der Messung auf 6c4cbc3 (vor Build 48), siehe docs/status.md.
    /// Std 52, XS 49 (Build 48 mit `.frame(minHeight: 44)`: 74).
    static let maxCellHeight: [String: Double] = ["std": 52.5, "xs": 49.5]
    static let maxPitch: [String: Double] = [:]

    func testLayoutStandard() { measure(size: nil, tag: "std") }
    func testSensitivityStandard() { measure(size: nil, tag: "sens-std", seedPush: true) }
    func testSensitivityXSmall() { measure(size: "UICTContentSizeCategoryXS", tag: "sens-xs", seedPush: true) }
    func testSensitivityAXXXL() { measure(size: "UICTContentSizeCategoryAccessibilityXXXL", tag: "sens-axxxl", seedPush: true) }
    func testLayoutXSmall() { measure(size: "UICTContentSizeCategoryXS", tag: "xs") }
}
