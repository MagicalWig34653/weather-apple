import XCTest

@MainActor
final class WeatherSmokeTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    func testTimelineSliderExposesAccessibilityValue() throws {
        let app = launchApp()
        let slider = app.sliders["Radarzeitpunkt"]
        guard slider.waitForExistence(timeout: 25) else { throw XCTSkip("Keine Live-Radarzeiten verfügbar") }
        XCTAssertEqual(slider.label, "Radarzeitpunkt")
        let before = slider.value as? String ?? ""
        let pattern = #"^(.+, )?\d{1,2}:\d{2}, (Messung|Vorhersage)$"#
        XCTAssertNotNil(before.range(of: pattern, options: .regularExpression), before)
        dragSlider(slider, to: 0.9)
        let after = slider.value as? String ?? ""
        XCTAssertNotEqual(before, after)
        XCTAssertNotNil(after.range(of: pattern, options: .regularExpression), after)
    }

    func testInformationExplainsPrivacyWithoutLocationPermission() throws {
        let app = launchApp()
        let information = app.buttons["Datenquellen und Datenschutz"]
        XCTAssertTrue(information.waitForExistence(timeout: 15))
        information.tap()

        XCTAssertTrue(app.navigationBars["Über Showers"].waitForExistence(timeout: 5))
        let privacy = app.buttons["info-row-privacy"]
        XCTAssertTrue(privacy.isHittable)
        privacy.tap()
        let explanation = app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH %@", "Kein Konto und keine")).firstMatch
        XCTAssertTrue(explanation.waitForExistence(timeout: 5))

        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["Fertig"].tap()
        XCTAssertTrue(information.waitForExistence(timeout: 5))
    }

    /// Every row of the info sheet opens its own page with its text.
    func testInformationSubpagesAreReachable() throws {
        let app = launchApp()
        let information = app.buttons["Datenquellen und Datenschutz"]
        XCTAssertTrue(information.waitForExistence(timeout: 15))
        information.tap()
        XCTAssertTrue(app.navigationBars["Über Showers"].waitForExistence(timeout: 5))
        let pages: [(row: String, page: String, text: String)] = [
            ("sources", "info-page-sources", "Karte und Ortssuche: Apple MapKit"),
            ("privacy", "info-page-privacy", "Kein Konto und keine"),
            ("widgets", "info-page-widgets", "Widgets verwenden deine gespeicherten Orte"),
            ("alerts", "info-page-alerts", "Einstellen kannst du Regenhinweise"),
            ("past", "info-page-past", "Wie weit die Zeitleiste"),
            ("support", "info-page-support", "Datenschutzerklärung"),
        ]
        for entry in pages {
            let row = app.buttons["info-row-\(entry.row)"]
            XCTAssertTrue(row.waitForExistence(timeout: 5), entry.row)
            row.tap()
            XCTAssertTrue(app.descendants(matching: .any)[entry.page].waitForExistence(timeout: 5), entry.page)
            let text = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", entry.text)).firstMatch
            for _ in 0..<6 where !text.exists { app.swipeUp() }
            XCTAssertTrue(text.exists, entry.text)
            app.navigationBars.buttons.firstMatch.tap()
        }
    }

    private func openInformation(window: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(de)", "-AppleLocale", "de_DE", "-UITestDeviceLinkWindow", window]
        app.launch()
        let information = app.buttons["Datenquellen und Datenschutz"]
        XCTAssertTrue(information.waitForExistence(timeout: 15))
        information.tap()
        XCTAssertTrue(app.navigationBars["Über Showers"].waitForExistence(timeout: 5))
        return app
    }

    /// No operator window: the section must not exist in the view hierarchy at all.
    func testOperatorDiagnosticsSectionIsAbsentWithoutWindow() throws {
        let app = openInformation(window: "closed")
        XCTAssertTrue(app.buttons["info-row-privacy"].isHittable)
        // Give the asynchronous status check time to (wrongly) insert the section.
        Thread.sleep(forTimeInterval: 2)
        XCTAssertFalse(app.descendants(matching: .any)["device-link-section"].exists)
        XCTAssertFalse(app.switches["device-link-toggle"].exists)
        XCTAssertFalse(app.staticTexts["Betreiber-Diagnose"].exists)
    }

    /// Simulated open operator window: section with switch and remaining time at the very bottom.
    func testOperatorDiagnosticsSectionAppearsWithOpenWindow() throws {
        let app = openInformation(window: "open")
        let toggle = app.descendants(matching: .any)["device-link-toggle"]
        for _ in 0..<15 where !toggle.exists { app.swipeUp(); Thread.sleep(forTimeInterval: 0.5) }
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["device-link-window"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["device-link-section"].exists)
        XCTAssertTrue(app.staticTexts["Betreiber-Diagnose"].exists)
    }

    func testRadarControlsOpenDetailsAndReturnToCurrentFrame() throws {
        let app = launchApp()
        let slider = app.sliders["Radarzeitpunkt"]
        guard slider.waitForExistence(timeout: 25) else {
            throw XCTSkip("Der Live-Kartendienst hat keine Radarzeitpunkte geliefert.")
        }
        dragSlider(slider, to: 1)
        XCTAssertTrue((slider.value as? String ?? "").contains("Vorhersage"))
        app.buttons["Jetzt"].tap()
        XCTAssertTrue((slider.value as? String ?? "").contains("Messung"))
        app.buttons["Radaranimation starten"].tap()
        XCTAssertTrue(app.buttons["Animation pausieren"].waitForExistence(timeout: 2))
        app.buttons["Animation pausieren"].tap()
        let details = app.buttons["forecast-details"]
        XCTAssertTrue(details.waitForExistence(timeout: 5))
        details.tap()
        XCTAssertTrue(app.buttons["Fertig"].waitForExistence(timeout: 5))
        let interpretation = app.staticTexts["Einordnung"]
        for _ in 0..<5 where !interpretation.isHittable { app.swipeUp() }
        XCTAssertTrue(interpretation.isHittable)
        XCTAssertTrue(app.staticTexts["Einordnung vorhandener Radardaten; keine zusätzliche Vorhersage oder amtliche Warnung."].exists)
        app.buttons["Fertig"].tap()
        XCTAssertTrue(slider.waitForExistence(timeout: 5))
    }

    func testLayerMenuTopRightOffersLayersAndReload() throws {
        let app = launchApp()
        let menu = app.buttons["radar-layer-menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 15))
        XCTAssertGreaterThanOrEqual(menu.frame.height, 44)
        XCTAssertGreaterThan(menu.frame.midX, app.frame.midX, "Die Ebenenwahl sitzt oben rechts.")
        XCTAssertLessThan(menu.frame.minY, 160)
        XCTAssertEqual(menu.value as? String, "Regenradar")
        XCTAssertFalse(app.buttons["Wetterdaten aktualisieren"].exists, "Kein eigener Neuladen-Knopf mehr.")
        menu.tap()
        XCTAssertTrue(app.buttons["Regenradar"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Daten neu laden"].exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "layer-menu-open"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testTimelineIsCompactAndNearBottom() throws {
        let app = launchApp()
        let slider = app.sliders["Radarzeitpunkt"]
        guard slider.waitForExistence(timeout: 25) else { throw XCTSkip("Keine Live-Radarzeiten verfügbar") }
        let play = app.buttons["Radaranimation starten"]
        let now = app.buttons["Jetzt"]
        XCTAssertGreaterThanOrEqual(play.frame.height, 44)
        XCTAssertGreaterThanOrEqual(play.frame.width, 44)
        XCTAssertGreaterThanOrEqual(now.frame.height, 44)
        XCTAssertLessThan(app.frame.maxY - play.frame.minY, 110, "Die gesamte untere Bedienung soll im unteren 110-Punkt-Bereich liegen.")
        XCTAssertLessThanOrEqual(play.frame.maxX, slider.frame.minX)
        XCTAssertLessThanOrEqual(slider.frame.maxX, now.frame.minX)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "timeline-normal"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        print("TIMELINE_NORMAL play=\(play.frame) slider=\(slider.frame) now=\(now.frame) screen=\(app.frame)")
    }

    func testTimelineAtMaximumDynamicTypeKeepsControlsSeparate() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(de)", "-AppleLocale", "de_DE", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let slider = app.sliders["Radarzeitpunkt"]
        guard slider.waitForExistence(timeout: 25) else { throw XCTSkip("Keine Live-Radarzeiten verfügbar") }
        let play = app.buttons["Radaranimation starten"]
        let now = app.buttons["Jetzt"]
        let label = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Messung")).firstMatch
        XCTAssertTrue(play.isHittable)
        XCTAssertTrue(now.isHittable)
        XCTAssertGreaterThanOrEqual(now.frame.height, 44)
        XCTAssertLessThanOrEqual(play.frame.maxX, slider.frame.minX)
        XCTAssertLessThanOrEqual(slider.frame.maxX, now.frame.minX)
        XCTAssertTrue(label.exists)
        XCTAssertLessThanOrEqual(label.frame.maxY, play.frame.minY)
        XCTAssertTrue(app.buttons["forecast-details"].isHittable)
        dragSlider(slider, to: 1)
        XCTAssertTrue((slider.value as? String ?? "").contains("Vorhersage"))
        now.tap()
        XCTAssertTrue((slider.value as? String ?? "").contains("Messung"))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "timeline-maximum-dynamic-type"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        print("TIMELINE_AXMAX play=\(play.frame) slider=\(slider.frame) now=\(now.frame) labelExists=\(label.exists)")
    }

    func testScrubBubbleSitsAboveSliderWithinScreenAtNormalAndMaximumTextSize() throws {
        for large in [false, true] {
            let app = XCUIApplication()
            app.launchArguments = ["-AppleLanguages", "(de)", "-AppleLocale", "de_DE", "-UITestShowScrubBubble"]
                + (large ? ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] : [])
            app.launch()
            let slider = app.sliders["Radarzeitpunkt"]
            guard slider.waitForExistence(timeout: 25) else { throw XCTSkip("Keine Live-Radarzeiten verfügbar") }
            // The enclosing timeline container overrides the identifier, so the bubble is found by its time-only label.
            let bubble = app.otherElements.matching(NSPredicate(format: "label MATCHES %@", "(.*, )?\\d{1,2}:\\d{2}( [AP]M)?")).firstMatch
            XCTAssertTrue(bubble.waitForExistence(timeout: 5), "Die Zeit-Bubble fehlt (large=\(large)).")
            XCTAssertLessThanOrEqual(bubble.frame.maxY, slider.frame.minY - 10, "Die Bubble liegt über dem Regler, nicht darauf (large=\(large)).")
            XCTAssertGreaterThanOrEqual(bubble.frame.minX, 0)
            XCTAssertLessThanOrEqual(bubble.frame.maxX, app.frame.maxX)
            if large {
                let frameLabel = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Messung")).firstMatch
                XCTAssertLessThanOrEqual(bubble.frame.maxY, frameLabel.frame.minY, "Die Bubble verdeckt die Zeitanzeige nicht.")
            }
            for control in [app.buttons["Radaranimation starten"], app.buttons["Jetzt"]] {
                XCTAssertFalse(bubble.frame.intersects(control.frame), "Die Bubble überlappt \(control.label) (large=\(large)).")
            }
            let shot = XCTAttachment(screenshot: app.screenshot())
            shot.name = large ? "scrub-bubble-maximum-type" : "scrub-bubble-normal"
            shot.lifetime = .keepAlways
            add(shot)
            app.terminate()
        }
    }

    func testGlowPlaysWhenEnteringForecastAndDoesNotBlockInput() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(de)", "-AppleLocale", "de_DE", "-UITestExposeGlow"]
        app.launch()
        let details = app.buttons["forecast-details"]
        XCTAssertTrue(details.waitForExistence(timeout: 15))
        XCTAssertFalse(app.descendants(matching: .any)["forecast-glow"].exists, "Kein Glow vor dem Betreten.")
        details.tap()
        let glow = app.descendants(matching: .any)["forecast-glow"]
        XCTAssertTrue(glow.waitForExistence(timeout: 3), "Der Glow erscheint beim Betreten der Prognose.")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "forecast-glow"
        shot.lifetime = .keepAlways
        add(shot)
        // Input still works while the glow runs.
        let done = app.buttons["Fertig"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        XCTAssertTrue(done.isHittable)
        done.tap()
        XCTAssertTrue(app.sliders["Radarzeitpunkt"].waitForExistence(timeout: 10) || app.buttons["forecast-details"].waitForExistence(timeout: 10))
        XCTAssertTrue(glow.waitForNonExistence(timeout: 5), "Der Glow endet von selbst.")
    }

    func testTappingPlaceMarkerJumpsToThePlace() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(de)", "-AppleLocale", "de_DE", "-UITestSeedPlaces"]
        app.launch()
        XCTAssertTrue(app.buttons["Ort auswählen: Teststadt Berlin"].waitForExistence(timeout: 15))
        let marker = app.descendants(matching: .any)["place-marker-Teststadt Süd"]
        XCTAssertTrue(marker.waitForExistence(timeout: 10), "Der Name des zweiten Ortes ist als Marker sichtbar.")
        XCTAssertGreaterThanOrEqual(marker.frame.height, 44)
        XCTAssertEqual(marker.label, "Zum Ort Teststadt Süd springen")
        // Tapping empty map changes nothing.
        app.otherElements["radar-map"].coordinate(withNormalizedOffset: CGVector(dx: 0.12, dy: 0.45)).tap()
        XCTAssertTrue(app.buttons["Ort auswählen: Teststadt Berlin"].exists)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "place-markers"
        shot.lifetime = .keepAlways
        add(shot)
        marker.tap()
        XCTAssertTrue(app.buttons["Ort auswählen: Teststadt Süd"].waitForExistence(timeout: 10), "Das Tippen wählt und zentriert den Ort.")
        XCTAssertTrue(app.descendants(matching: .any)["place-marker-Teststadt Berlin"].waitForExistence(timeout: 10),
                      "Der vorher gewählte Ort wird nun als Marker angeboten.")
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
        confirm(saveAlert)
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
        confirm(renameAlert)
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

    /// With the keyboard up, the first tap on an alert button can be swallowed (keyboard/autocorrect commit); retry once.
    private func confirm(_ alert: XCUIElement) {
        alert.buttons["Speichern"].tap()
        if !alert.waitForNonExistence(timeout: 2) { alert.buttons["Speichern"].tap() }
    }

    /// The timeline slider is an accessibility representation over a custom drag control, so
    /// `adjust(toNormalizedSliderPosition:)` cannot read scrubber attributes; drag on its frame instead.
    private func dragSlider(_ slider: XCUIElement, to position: CGFloat) {
        let start = slider.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: slider.coordinate(withNormalizedOffset: CGVector(dx: position, dy: 0.5)))
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
