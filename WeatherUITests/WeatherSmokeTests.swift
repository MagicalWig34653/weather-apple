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
        timeButton(app).tap()
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
        let now = timeButton(app)
        XCTAssertGreaterThanOrEqual(play.frame.height, 44)
        XCTAssertGreaterThanOrEqual(play.frame.width, 44)
        XCTAssertGreaterThanOrEqual(now.frame.height, 44)
        XCTAssertLessThan(app.frame.maxY - play.frame.minY, 110, "Die gesamte untere Bedienung soll im unteren 110-Punkt-Bereich liegen.")
        XCTAssertLessThanOrEqual(play.frame.maxX, slider.frame.minX)
        XCTAssertLessThanOrEqual(now.frame.maxY, slider.frame.minY + 1, "Die Zeitanzeige liegt über dem Regler.")
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
        let now = timeButton(app)
        XCTAssertTrue(play.isHittable)
        XCTAssertTrue(now.isHittable)
        XCTAssertGreaterThanOrEqual(now.frame.height, 44)
        XCTAssertLessThanOrEqual(play.frame.maxX, slider.frame.minX)
        XCTAssertLessThanOrEqual(now.frame.maxY, slider.frame.minY + 1, "Die Zeitanzeige liegt über dem Regler.")
        XCTAssertTrue(app.buttons["forecast-details"].isHittable)
        dragSlider(slider, to: 1)
        XCTAssertTrue((slider.value as? String ?? "").contains("Vorhersage"))
        now.tap()
        XCTAssertTrue((slider.value as? String ?? "").contains("Messung"))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "timeline-maximum-dynamic-type"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        print("TIMELINE_AXMAX play=\(play.frame) slider=\(slider.frame) now=\(now.frame)")
    }

    func testTimeShownOnceAndNoBubbleOrNowButton() throws {
        for large in [false, true] {
            let app = XCUIApplication()
            app.launchArguments = ["-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
                + (large ? ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] : [])
            app.launch()
            let slider = app.sliders["Radarzeitpunkt"]
            guard slider.waitForExistence(timeout: 25) else { throw XCTSkip("Keine Live-Radarzeiten verfügbar") }
            XCTAssertFalse(app.buttons["Jetzt"].exists, "Der Jetzt-Button ist entfallen (large=\(large)).")
            dragSlider(slider, to: 0.8)
            let times = app.descendants(matching: .any).matching(NSPredicate(format: "label MATCHES %@", "(.*[,·] )?\\d{1,2}:\\d{2}( [AP]M)?"))
            XCTAssertEqual(times.count, 1, "Die Zeit erscheint genau einmal (large=\(large)).")
            let time = timeButton(app)
            XCTAssertTrue(time.isHittable)
            XCTAssertFalse(time.frame.intersects(slider.frame), "Zeitanzeige und Regler überlappen nicht (large=\(large)).")
            let shot = XCTAttachment(screenshot: app.screenshot())
            shot.name = large ? "timeline-time-maximum-type" : "timeline-time-normal"
            shot.lifetime = .keepAlways
            add(shot)
            app.terminate()
        }
    }

    /// The always-visible time row; tapping it jumps back to "now". Found by its time-only label.
    private func timeButton(_ app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label MATCHES %@", "(.*[,·] )?\\d{1,2}:\\d{2}( [AP]M)?")).firstMatch
    }

    func testTimelineLayoutStaysStableBetweenMeasurementAndForecast() throws {
        for large in [false, true] {
            let app = XCUIApplication()
            app.launchArguments = ["-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
                + (large ? ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] : [])
            app.launch()
            let slider = app.sliders["Radarzeitpunkt"]
            guard slider.waitForExistence(timeout: 25) else { throw XCTSkip("Keine Live-Radarzeiten verfügbar") }
            let play = app.buttons["Radaranimation starten"]
            let now = timeButton(app)
            func frames() -> [CGRect] { [slider.frame, play.frame, now.frame] }
            now.tap()
            let reference = frames()
            dragSlider(slider, to: 1)
            XCTAssertTrue((slider.value as? String ?? "").contains("Vorhersage"))
            let forecast = frames()
            dragSlider(slider, to: 0)
            XCTAssertTrue((slider.value as? String ?? "").contains("Messung"))
            let past = frames()
            for (index, name) in ["slider", "play", "now"].enumerated() {
                XCTAssertEqual(forecast[index].origin.x, reference[index].origin.x, accuracy: 0.5, "\(name) bleibt stehen (Vorhersage, large=\(large))")
                XCTAssertEqual(forecast[index].width, reference[index].width, accuracy: 0.5, "\(name) Breite (Vorhersage, large=\(large))")
                XCTAssertEqual(past[index].origin.x, reference[index].origin.x, accuracy: 0.5, "\(name) bleibt stehen (Messung, large=\(large))")
                XCTAssertEqual(past[index].width, reference[index].width, accuracy: 0.5, "\(name) Breite (Messung, large=\(large))")
                XCTAssertEqual(past[index].origin.y, reference[index].origin.y, accuracy: 0.5, "\(name) Höhe/Position (Messung, large=\(large))")
            }
            app.terminate()
        }
    }

    func testNoGlowWhenOpeningForecastDetails() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(de)", "-AppleLocale", "de_DE", "-UITestExposeGlow"]
        app.launch()
        let details = app.buttons["forecast-details"]
        XCTAssertTrue(details.waitForExistence(timeout: 15))
        details.tap()
        let done = app.buttons["Fertig"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["forecast-glow"].exists, "Kein Glow beim Betreten der Prognose.")
        XCTAssertFalse(app.descendants(matching: .any)["scrub-glow"].exists)
        done.tap()
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

    /// Temperature and dew point appear only with a manifest (Debug stub `-UITestLayers d2`), the timeline stays usable,
    /// the legend names the model value; relative humidity (not offered by the stub server) stays hidden.
    func testTemperatureLayersAppearWithManifestAndKeepTimelineUsable() throws {
        for large in [false, true] {
            let app = XCUIApplication()
            app.launchArguments = ["-AppleLanguages", "(de)", "-AppleLocale", "de_DE", "-UITestLayers", "d2"]
                + (large ? ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] : [])
            app.launch()
            let menu = app.buttons["radar-layer-menu"]
            XCTAssertTrue(menu.waitForExistence(timeout: 15))
            func layerButton(_ prefix: String) -> XCUIElement {
                app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
            }
            let temperature = layerButton("Temperatur")
            var opened = false
            for _ in 0..<6 where !opened {
                menu.tap()
                opened = temperature.waitForExistence(timeout: 3)
                if !opened { app.buttons["Regenradar"].tap(); sleep(2) }
            }
            XCTAssertTrue(opened, "Temperatur erscheint, sobald der Server sie meldet (large=\(large)).")
            XCTAssertTrue(layerButton("Feuchte (Taupunkt)").exists)
            XCTAssertFalse(layerButton("Feuchte (relativ)").exists, "Relative Feuchte wird nicht angeboten (Server-Flag aus).")
            temperature.tap()
            let slider = app.sliders["Zeitpunkt Temperatur"]
            XCTAssertTrue(slider.waitForExistence(timeout: 10))
            XCTAssertTrue((slider.value as? String ?? "").contains("Modell"), slider.value as? String ?? "")
            if !large {
                dragSlider(slider, to: 0.9)
                let forecast = NSPredicate(format: "value CONTAINS %@", "Modellvorhersage")
                XCTAssertEqual(XCTWaiter().wait(for: [expectation(for: forecast, evaluatedWith: slider)], timeout: 5), .completed,
                               slider.value as? String ?? "")
            }
            // XXXL: the stub serves no images, so the (honest) missing-image banners crowd the layout and push the
            // slider partly off screen; the timeline itself is covered by the radar XXXL tests. Here only existence and value.
            let legendToggle = app.buttons["radar-legend-toggle"]
            XCTAssertTrue(legendToggle.isHittable)
            legendToggle.tap()
            let legend = app.descendants(matching: .any)["radar-legend"]
            let found = legend.waitForExistence(timeout: 5)
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = large ? "temperature-legend-xxxl" : "temperature-legend-normal"
            screenshot.lifetime = .keepAlways
            add(screenshot)
            XCTAssertTrue(found)
            XCTAssertTrue(app.staticTexts["Temperatur 2 m (Modell)"].exists)
            XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "kein Messwert")).firstMatch.exists)
        }
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

final class WarnSettingsUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func openAlerts(capabilities: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(de)", "-AppleLocale", "de_DE", "-UITestWarnCapabilities", capabilities]
        app.launch()
        let information = app.buttons["Datenquellen und Datenschutz"]
        XCTAssertTrue(information.waitForExistence(timeout: 15))
        information.tap()
        let row = app.buttons["info-row-alerts"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(app.otherElements["info-page-alerts"].waitForExistence(timeout: 5)
                      || app.collectionViews["info-page-alerts"].waitForExistence(timeout: 5))
        return app
    }

    func testNoWarningsSectionWithoutCapability() throws {
        let app = openAlerts(capabilities: "none")
        XCTAssertTrue(app.staticTexts["push-status"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.switches["warn-toggle"].exists)
        XCTAssertFalse(app.staticTexts["warn-disclaimer"].exists)
    }

    func testWarningsSectionWithCapabilityShowsDisclaimerAndConfirmation() throws {
        let app = openAlerts(capabilities: "push")
        let toggle = app.switches["warn-toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Kein Ersatz für amtliche Warnkanäle (WarnWetter-App, NINA)."].exists)
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        // The explanation (with the disclaimer) comes before the system permission prompt; cancel keeps the switch off.
        XCTAssertTrue(app.buttons["Einschalten"].waitForExistence(timeout: 5))
        app.buttons["Abbrechen"].tap()
        XCTAssertEqual(app.switches["warn-toggle"].value as? String, "0")
        XCTAssertFalse(app.switches["warn-time-sensitive"].exists)
    }
}

final class WarningsUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func launch(mode: String?, xxxl: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        var args = ["-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
        if let mode { args += ["-UITestWarnings", mode] }
        if xxxl { args += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launchArguments = args
        app.launch()
        return app
    }

    private func openSheet(_ app: XCUIApplication) {
        let button = app.buttons["radar-warnings-button"]
        XCTAssertTrue(button.waitForExistence(timeout: 15))
        sleep(1)
        app.screenshot().writeForW5("radar")
        button.tap()
        XCTAssertTrue(app.navigationBars["Amtliche Warnungen"].waitForExistence(timeout: 5))
    }

    func testNoEntryWithoutCapability() throws {
        let app = launch(mode: nil)
        app.launchArguments += []
        XCTAssertTrue(app.buttons["Datenquellen und Datenschutz"].waitForExistence(timeout: 15))
        sleep(2)
        XCTAssertFalse(app.buttons["radar-warnings-button"].exists)
    }

    func testListShowsWarningWithSourceAndDetailKeepsDWDText() throws {
        let app = launch(mode: "fixture")
        openSheet(app)
        // "Meine Orte" is the standard (stubbed place Berlin): only the thunderstorm and frost warning apply.
        let row = app.descendants(matching: .any).matching(identifier: "warning-row").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("Stufe 3"))
        XCTAssertTrue(row.label.contains("Quelle: Deutscher Wetterdienst"))
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "warning-row").count, 2)
        XCTAssertTrue(app.staticTexts["Kein Ersatz für amtliche Warnkanäle (WarnWetter-App, NINA)."].exists)
        app.screenshot().writeForW5("liste")
        // Scope "Alle" adds the level 4 warning of another district.
        app.buttons["Alle"].tap()
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "warning-row").count, 3)
        app.descendants(matching: .any).matching(identifier: "warning-row").containing(NSPredicate(format: "label CONTAINS 'GEWITTER'")).firstMatch.tap()
        XCTAssertEqual(app.staticTexts["warning-headline"].label, "Amtliche UNWETTERWARNUNG vor GEWITTER")
        XCTAssertEqual(app.staticTexts["warning-text"].label,
                       "Es treten Gewitter auf. Dabei gibt es Windböen bis 70 km/h (Bft 8) sowie Starkregen um 25 l/qm in einer Stunde.")
        XCTAssertTrue(app.staticTexts["warning-instruction"].label.hasPrefix("ACHTUNG! Hinweis auf mögliche Gefahren"))
        XCTAssertTrue(app.staticTexts["warning-source"].label.hasPrefix("Quelle: Deutscher Wetterdienst, ausgegeben"))
        app.screenshot().writeForW5("detail")
    }

    func testOfflineWithoutCacheIsHonest() throws {
        let app = launch(mode: "offline")
        openSheet(app)
        let text = app.staticTexts["warn-empty"]
        XCTAssertTrue(text.waitForExistence(timeout: 5))
        XCTAssertTrue(text.label.contains("nicht abrufbar"))
        XCTAssertFalse(text.label.hasPrefix("Keine aktiven"))
        XCTAssertTrue(app.buttons["Erneut versuchen"].exists)
    }

    func testStaleDataShowsNotice() throws {
        let app = launch(mode: "stale")
        openSheet(app)
        XCTAssertTrue(app.staticTexts["warn-stale"].waitForExistence(timeout: 5))
    }

    func testEmptyState() throws {
        let app = launch(mode: "empty")
        openSheet(app)
        XCTAssertTrue(app.staticTexts["warn-empty"].waitForExistence(timeout: 5))
    }

    func testMapModeShowsMap() throws {
        let app = launch(mode: "fixture")
        openSheet(app)
        app.buttons["Karte"].tap()
        XCTAssertTrue(app.maps["warn-map"].waitForExistence(timeout: 5) || app.otherElements["warn-map"].waitForExistence(timeout: 5))
        sleep(2)
        app.screenshot().writeForW5("karte")
    }

    func testAccessibilityXXXL() throws {
        let app = launch(mode: "fixture", xxxl: true)
        openSheet(app)
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "warning-row").firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Fertig"].isHittable)
        app.screenshot().writeForW5("liste-xxxl")
    }
}

private extension XCUIScreenshot {
    /// Screenshots for the manual check (directory from `W5_SHOTS`, otherwise skipped).
    func writeForW5(_ name: String) {
        guard let dir = ProcessInfo.processInfo.environment["W5_SHOTS"] ?? (try? String(contentsOfFile: "/tmp/w5-shots-dir"))?.trimmingCharacters(in: .whitespacesAndNewlines),
              !dir.isEmpty else { return }
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try? pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("w5-\(name).png"))
    }
}
