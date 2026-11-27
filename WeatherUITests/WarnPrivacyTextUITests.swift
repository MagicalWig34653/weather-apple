import XCTest

/// Karte 31A623B9, Frage 9B360945: Datenangaben im Warnungs-Dialog (de/en, hell/dunkel) und Satelliten-Quellzeile unter
/// dem Slider (EUMETSAT Data Policy Art. 6.3: "Contains modified EUMETSAT Meteosat data <Jahr>"). Bilder als Anhänge.
@MainActor
final class WarnPrivacyTextUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .portrait
    }

    override func tearDown() async throws { XCUIDevice.shared.appearance = .light }

    private func shot(_ app: XCUIApplication, _ name: String) {
        sleep(1)
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    private func warnDialog(_ language: UITestLaunch.Language, _ appearance: XCUIDevice.Appearance, _ tag: String) throws {
        let de = language == .german
        let app = UITestLaunch.app(language: language, extra: UITestLaunch.setAppearance(appearance, extra: ["-UITestWarnCapabilities", "push"]))
        app.launch()
        let info = app.buttons[de ? "Datenquellen und Datenschutz" : "Data sources and privacy"]
        XCTAssertTrue(info.waitForExistence(timeout: 15))
        info.tap()
        let row = app.buttons["info-row-alerts"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        let toggle = app.switches["warn-toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        // Footer: everything the server receives.
        let footer = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", de ? "Der Server erhält Kennungen der Warngebiete" : "The server receives warning area IDs")).firstMatch
        XCTAssertTrue(footer.waitForExistence(timeout: 5), "WARN_FOOTER nennt die Daten (\(tag))")
        XCTAssertTrue(footer.label.contains(de ? "Installationskennung" : "installation ID"), tag)
        shot(app, "warn-seite-\(tag)")
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        let text = alert.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: " ")
        for part in de ? ["Gerätetoken", "zufällige Installationskennung", "Mindeststufe", "zeitkritische Mitteilungen", "„Einschalten“ willigst du ein", "löscht die Warndaten auf dem Server"]
                       : ["device token", "random installation ID", "minimum level", "time-sensitive setting", "“Turn on” you consent", "deletes the warning data on the server"] {
            XCTAssertTrue(text.contains(part), "Dialog nennt „\(part)“ (\(tag)): \(text)")
        }
        shot(app, "warn-dialog-\(tag)")
        app.alerts.buttons[de ? "Abbrechen" : "Cancel"].tap()
        XCTAssertEqual(app.switches["warn-toggle"].value as? String, "0")
    }

    func testWarnDialogGermanLight() throws { try warnDialog(.german, .light, "de-hell") }
    func testWarnDialogGermanDark() throws { try warnDialog(.german, .dark, "de-dunkel") }
    func testWarnDialogEnglishLight() throws { try warnDialog(.english, .light, "en-hell") }
    func testWarnDialogEnglishDark() throws { try warnDialog(.english, .dark, "en-dunkel") }

    private func satelliteCredit(_ appearance: XCUIDevice.Appearance, _ tag: String, entry: String) throws {
        let app = UITestLaunch.app(language: .german, extra: UITestLaunch.setAppearance(appearance, extra: ["-UITestLayers", "all"]))
        app.launch()
        XCTAssertTrue(app.buttons["radar-layer-menu"].waitForExistence(timeout: 20))
        let item = try XCTUnwrap(openLayerEntry(app, group: nil, entry: entry))
        item.tap()
        let credit = app.staticTexts["radar-attribution"]
        XCTAssertTrue(credit.waitForExistence(timeout: 10))
        sleep(2)
        let window = app.windows.firstMatch.frame
        XCTAssertEqual(credit.label, "Contains modified EUMETSAT Meteosat data 2026", "Pflichtformel Art. 6.3 unter dem Slider (\(tag))")
        XCTAssertGreaterThanOrEqual(credit.frame.minX, window.minX, "Zeile links nicht abgeschnitten (\(tag))")
        XCTAssertLessThanOrEqual(credit.frame.maxX, window.maxX, "Zeile rechts nicht abgeschnitten (\(tag))")
        let slider = app.sliders.firstMatch
        if window.maxY - slider.frame.maxY >= 20 { XCTAssertGreaterThanOrEqual(credit.frame.minY, slider.frame.maxY - 1, "unter dem Slider (\(tag))") }
        let note = XCTAttachment(string: "credit \(credit.frame) window \(window) label=\(credit.label)")
        note.name = "zahlen-\(tag)"; note.lifetime = .keepAlways; add(note)
        shot(app, "quellzeile-\(tag)")
    }

    func testCloudsCreditLight() throws { try satelliteCredit(.light, "wolken-hell", entry: "Wolken") }
    func testCloudsCreditDark() throws { try satelliteCredit(.dark, "wolken-dunkel", entry: "Wolken") }
    func testSunCreditLight() throws { try satelliteCredit(.light, "sonne-hell", entry: "Sonne") }
}
