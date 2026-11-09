import XCTest

/// L2: English radar screen (header, layer menu, timeline, legend). One test per concern; every screen is also
/// checked negatively for German words. Screenshots are attached for the visual check of English text lengths.
@MainActor
final class RadarEnglishTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    private func launch(extra: [String] = []) -> XCUIApplication {
        let app = UITestLaunch.app(language: .english, extra: extra)
        app.launch()
        return app
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    private func assertNoGerman(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let german = ["Regenradar", "Daten neu laden", "Kartenebene", "Aktuellen Standort verwenden", "Datenquellen und Datenschutz",
                      "Niederschlag", "Keine Daten", "Legende", "Prognose", "Radarzeitpunkt", "Fertig", "Abbrechen", "Ausgewählten Ort speichern oder umbenennen"]
        for word in german {
            let predicate = NSPredicate(format: "label CONTAINS %@", word)
            XCTAssertFalse(app.descendants(matching: .any).matching(predicate).firstMatch.exists, "German text visible: \(word)", file: file, line: line)
        }
    }

    func testHeaderControlsAndLayerMenuAreEnglish() throws {
        let app = launch()
        let menu = app.buttons["radar-layer-menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 15))
        XCTAssertEqual(menu.label, "Choose map layer")
        XCTAssertEqual(menu.value as? String, "Rain radar")
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Rain radar")).firstMatch.exists,
                      "caption under the place name in the header")
        XCTAssertTrue(app.buttons["Use current location"].exists)
        XCTAssertTrue(app.buttons["Data sources and privacy"].exists)
        XCTAssertTrue(app.buttons["Save or rename the selected place"].exists)
        XCTAssertTrue(app.buttons["radar-legend-toggle"].label.hasPrefix("Legend: "), app.buttons["radar-legend-toggle"].label)
        assertNoGerman(app)
        attach(app, "en-radar-header")
        menu.tap()
        XCTAssertTrue(app.buttons["Rain radar"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Reload data"].exists)
        for title in ["Pressure", "Lightning", "Clouds", "Sun"] {
            XCTAssertTrue(app.buttons[title].exists, title)
        }
        assertNoGerman(app)
        attach(app, "en-layer-menu")
    }

    func testTimelineAndPillAreEnglish() throws {
        let app = launch()
        let slider = app.sliders["Radar time"]
        guard slider.waitForExistence(timeout: 25) else { throw XCTSkip("No live radar times available") }
        let value = slider.value as? String ?? ""
        XCTAssertNotNil(value.range(of: #"^(.+, )?\d{1,2}:\d{2}[\s\x{202F}\x{00A0}]?([AP]M)?, (Measurement|Forecast)$"#, options: .regularExpression), value)
        let pill = app.descendants(matching: .any)["radar-frame-label"]
        XCTAssertTrue(pill.waitForExistence(timeout: 5))
        XCTAssertTrue(pill.label == "Play animation" || pill.label == "Pause animation", pill.label)
        assertNoGerman(app)
        attach(app, "en-timeline")
    }

    func testRadarLegendIsEnglish() throws {
        let app = launch()
        let toggle = app.buttons["radar-legend-toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 15))
        toggle.tap()
        XCTAssertTrue(app.descendants(matching: .any)["radar-legend"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Precipitation in mm/h"].exists)
        XCTAssertTrue(app.staticTexts["No data"].exists)
        XCTAssertTrue(app.staticTexts["0.1 \u{2013} 0.2"].exists, "decimal point in English")
        XCTAssertTrue(app.staticTexts["from 150"].exists)
        assertNoGerman(app)
        attach(app, "en-legend-radar")
    }

    func testTemperatureLayerLegendAndTimelineAreEnglish() throws {
        let app = launch(extra: ["-UITestLayers", "d2"])
        let menu = app.buttons["radar-layer-menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 15))
        let temperature = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Temperature")).firstMatch
        var opened = false
        for _ in 0..<6 where !opened {
            menu.tap()
            opened = temperature.waitForExistence(timeout: 3)
            if !opened { app.buttons["Rain radar"].tap(); sleep(2) }
        }
        XCTAssertTrue(opened, "Temperature appears once the server reports it")
        temperature.tap()
        let slider = app.sliders["Time slot, Temperature"]
        XCTAssertTrue(slider.waitForExistence(timeout: 10))
        XCTAssertTrue((slider.value as? String ?? "").contains("Model"), slider.value as? String ?? "")
        app.buttons["radar-legend-toggle"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["radar-legend"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Temperature 2 m (model)"].exists)
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "not a measurement")).firstMatch.exists)
        XCTAssertTrue(app.staticTexts["Forest"].exists || app.switches["forest-toggle"].exists)
        assertNoGerman(app)
        attach(app, "en-legend-temperature")
    }
}
