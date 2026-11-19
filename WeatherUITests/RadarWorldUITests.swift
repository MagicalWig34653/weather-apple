import XCTest

/// Third rain map (world, NOAA satellite estimate): choice Deutschland / Europa / Welt in the native submenu, fixed estimate
/// note, short credit "NOAA", and the missing-data note that appears and disappears again. Layers come from the
/// `-UITestLayers all` stub (no network); screenshots are attached for the visual check.
@MainActor
final class RadarWorldUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    private func attach(_ name: String) {
        sleep(1)
        let screenshot = XCUIScreen.main.screenshot()
        print("LUMA \(name)=\(UITestLaunch.meanLuminance(screenshot.image))")
        let shot = XCTAttachment(screenshot: screenshot)
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = UITestLaunch.app(language: .german, extra: ["-UITestLayers", "all"] + extra)
        app.launch()
        let menu = app.buttons["radar-layer-menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 20))
        sleep(2)
        // The stubbed layers are reported after the first probe: open and close the menu once.
        menu.tap()
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5)).tap()
        sleep(1)
        return app
    }

    /// Taps an entry of the rain submenu; retried when the system menu swallowed the tap (menu still open afterwards).
    private func choose(_ app: XCUIApplication, _ prefix: String) throws {
        let menu = app.buttons["radar-layer-menu"]
        let rain = app.buttons.matching(NSPredicate(format: "label == %@", "Regen")).firstMatch
        let entry = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
        for _ in 0..<4 {
            menu.tap()
            // Exactly the group "Regen" (not "Luftdruck", whose entries are also called Deutschland/Europa).
            if rain.waitForExistence(timeout: 3) { rain.tap() }
            if entry.waitForExistence(timeout: 3), entry.isEnabled {
                entry.tap()
                if entry.waitForNonExistence(timeout: 3) { sleep(2); return }
            }
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5)).tap()
            sleep(2)
        }
        XCTFail("\(prefix) ließ sich nicht wählen")
    }

    /// The credit follows the layer switch with the manifest: wait for it instead of reading it once.
    private func waitForLabel(_ element: XCUIElement, _ label: String, timeout: TimeInterval = 10) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND label == %@", label), object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    /// "Daten neu laden" exactly once: the native menu sometimes swallows the tap and stays open (seen in the dark run
    /// 19.11.: menu still open, no reload, no note). The entry is tapped again only while the menu is still open, i.e. the
    /// action has not run yet; afterwards exactly one reload has been triggered.
    private func reloadOnce(_ app: XCUIApplication) {
        let menu = app.buttons["radar-layer-menu"]
        let reload = app.buttons["Daten neu laden"]
        for _ in 0..<3 {
            if !reload.exists { menu.tap() }
            guard reload.waitForExistence(timeout: 5) else { continue }
            reload.tap()
            if reload.waitForNonExistence(timeout: 3) { return }
        }
        XCTFail("Daten neu laden ließ sich nicht auslösen")
    }

    private func note(_ app: XCUIApplication, _ kind: String) -> XCUIElement {
        app.descendants(matching: .any)["radar-world-note-\(kind)"]
    }

    func testRainSubmenuOffersGermanyEuropeWorldAndWorldShowsEstimateNote() throws {
        let app = launch()
        let menu = app.buttons["radar-layer-menu"]
        menu.tap()
        let rain = app.buttons.matching(NSPredicate(format: "label == %@", "Regen")).firstMatch
        XCTAssertTrue(rain.waitForExistence(timeout: 5))
        rain.tap()
        for prefix in ["Deutschland", "Europa", "Welt"] {
            let entry = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
            XCTAssertTrue(entry.waitForExistence(timeout: 5), prefix)
            XCTAssertTrue(entry.isEnabled, prefix)
        }
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "bald")).firstMatch.exists, "Welt nicht mehr 'bald'")
        // The rows are the system menu's own; the own control (capsule) keeps the 44 pt target.
        XCTAssertGreaterThanOrEqual(menu.frame.height, 44, "Trefferfläche Kartenwahl")
        attach("welt-1-regen-menue")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5)).tap()
        sleep(1)

        try choose(app, "Welt (NOAA)")
        XCTAssertTrue(app.sliders["Radarzeitpunkt"].waitForExistence(timeout: 10), "Zeitachse der Weltkarte")
        let estimate = note(app, "estimate")
        XCTAssertTrue(estimate.waitForExistence(timeout: 5), "Schätzhinweis fest eingeblendet")
        XCTAssertTrue(estimate.label.contains("Satellitendaten"), estimate.label)
        XCTAssertTrue(estimate.label.contains("ungenauer als Radar"), estimate.label)
        let credit = app.staticTexts["radar-attribution"]
        XCTAssertTrue(credit.waitForExistence(timeout: 10))
        XCTAssertEqual(credit.label, "NOAA", "kurze Quellzeile ohne Logo")
        let missingImage = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "fehlt")).firstMatch
        XCTAssertFalse(missingImage.exists, "kein Bild-fehlt-Hinweis: \(missingImage.exists ? missingImage.label : "")")
        XCTAssertEqual(menu.value as? String, "Regenradar Welt, aus Satellitendaten geschätzt, ungenauer", "VoiceOver-Name mit Schätzhinweis")
        let worldName = menu.staticTexts["Regenradar Welt"]
        XCTAssertTrue(worldName.exists, "sichtbarer Kartenname Regenradar Welt")
        XCTAssertLessThanOrEqual(worldName.frame.maxX, menu.frame.maxX, "Name innerhalb der Kapsel")
        let worldWidth = worldName.frame.width
        attach("welt-2-karte-schaetzhinweis")
        legend(app, "legende-welt")

        try choose(app, "Europa (OPERA)")
        XCTAssertTrue(estimate.waitForNonExistence(timeout: 5), "Hinweis verschwindet bei Europa")
        XCTAssertTrue(waitForLabel(app.staticTexts["radar-attribution"], "\u{00A9} EUMETNET"), "Quellzeile Europa")
        // Width check (Lino: "Regenradar sollte von der Breite passen"); the smallest phone is covered by RadarWorldWidthUITests.
        let europeName = menu.staticTexts["Regenradar Europa"]
        XCTAssertTrue(europeName.exists)
        // Both names may be scaled down by the capsule (minimum 0.7): record the widths, the screenshot shows any truncation.
        XCTAssertGreaterThan(worldWidth, 0)
        print("WIDTH world=\(worldWidth) europe=\(europeName.frame.width) capsule=\(menu.frame.width) screen=\(app.frame.width)")
        attach("welt-3-europa-unveraendert")
        legend(app, "legende-europa")

        try choose(app, "Deutschland (DWD)")
        XCTAssertFalse(estimate.exists)
        XCTAssertTrue(app.staticTexts["radar-attribution"].waitForExistence(timeout: 10))
        XCTAssertTrue(waitForLabel(app.staticTexts["radar-attribution"], "\u{00A9} DWD"), "Quellzeile Deutschland")
        attach("welt-4-deutschland-unveraendert")
        legend(app, "legende-deutschland")
    }

    /// Opens the legend of the active layer for a screenshot (legends unchanged by decision 19.11.) and closes it again.
    private func legend(_ app: XCUIApplication, _ name: String) {
        let toggle = app.buttons["radar-legend-toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.tap()
        XCTAssertTrue(app.descendants(matching: .any)["radar-legend"].waitForExistence(timeout: 5), name)
        attach(name)
        toggle.tap()
        sleep(1)
    }

    func testMissingWorldDataShowsNoteInsteadOfSilentFallbackThenRecoversAndNoteDisappears() throws {
        executionTimeAllowance = 180
        let start = Date()
        let app = launch(["-UITestOutageLayer", "radar_world", "-UITestOutageAfter", "60", "-UITestOutageFor", "25"])
        try choose(app, "Welt (NOAA)")
        XCTAssertTrue(note(app, "estimate").waitForExistence(timeout: 5))
        XCTAssertFalse(note(app, "unavailable").exists, "Daten vorhanden: kein Fehlerhinweis")
        XCTAssertLessThan(Date().timeIntervalSince(start), 55, "Welt vor dem Ausfall gewählt")
        // After the stub's outage (60 s after the first world request) the next reload gets a 404 for the world layer.
        let wait = 65 - Date().timeIntervalSince(start)
        if wait > 0 { Thread.sleep(forTimeInterval: wait) }
        let menu = app.buttons["radar-layer-menu"]
        reloadOnce(app)
        let missing = note(app, "unavailable")
        XCTAssertTrue(missing.waitForExistence(timeout: 15), "Hinweis statt leerer Karte")
        XCTAssertTrue(missing.label.hasPrefix("Regenradar Welt ist derzeit nicht verfügbar"), missing.label)
        XCTAssertTrue(note(app, "estimate").exists, "Schätzhinweis bleibt")
        XCTAssertTrue((menu.value as? String ?? "").contains("Welt"), "kein stilles Zurückfallen auf Deutschland")
        XCTAssertFalse(app.staticTexts["radar-attribution"].exists, "keine Quellzeile ohne Bild")
        let unavailable = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "nicht verfügbar"))
        // The note's container and its text expose the same label: count distinct texts.
        let texts = Set(unavailable.allElementsBoundByIndex.map(\.label))
        XCTAssertEqual(texts.count, 1, "genau ein Fehlerhinweis: \(texts)")
        XCTAssertFalse(app.descendants(matching: .any)["radar-slot-status"].exists, "keine zweite Pille über der Zeitachse")
        XCTAssertTrue(app.descendants(matching: .any)["radar-timeline"].exists, "Zeitachse bleibt als leere Leiste")
        XCTAssertTrue(app.staticTexts["Keine Zeiten für Regenradar Welt"].exists, "leerer Zeitachsen-Zustand")
        attach("welt-5-fehlt-hinweis")

        // Way back WITHOUT a layer change: once the stub serves the world again, the next reload brings the picture back.
        let back = 100 - Date().timeIntervalSince(start)
        if back > 0 { Thread.sleep(forTimeInterval: back) }
        reloadOnce(app)
        XCTAssertTrue(missing.waitForNonExistence(timeout: 15), "Fehlerhinweis verschwindet nach Erholung")
        XCTAssertTrue(note(app, "estimate").exists, "Schätzhinweis bleibt")
        XCTAssertTrue((menu.value as? String ?? "").contains("Welt"), "Welt bleibt gewählt")
        let credit = app.staticTexts["radar-attribution"]
        XCTAssertTrue(credit.waitForExistence(timeout: 10), "Quellzeile wieder da")
        XCTAssertEqual(credit.label, "NOAA")
        XCTAssertTrue(app.sliders["Radarzeitpunkt"].waitForExistence(timeout: 10), "Zeitachse wieder da")
        XCTAssertFalse(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "nicht verfügbar")).firstMatch.exists,
                       "kein Nicht-verfügbar-Hinweis mehr")
        attach("welt-5b-erholt")

        try choose(app, "Deutschland (DWD)")
        XCTAssertTrue(missing.waitForNonExistence(timeout: 5), "Hinweis verschwindet nach Wechsel")
        XCTAssertFalse(note(app, "estimate").exists)
        attach("welt-6-hinweis-weg")
    }

    func testMissingEuropeDataKeepsEuropeWithOneNoteThenRecovers() throws {
        executionTimeAllowance = 180
        let start = Date()
        let app = launch(["-UITestOutageLayer", "radar_eu", "-UITestOutageAfter", "90", "-UITestOutageFor", "40"])
        try choose(app, "Europa (OPERA)")
        let menu = app.buttons["radar-layer-menu"]
        XCTAssertTrue(waitForLabel(app.staticTexts["radar-attribution"], "\u{00A9} EUMETNET"), "Europa mit Daten")
        let missing = app.descendants(matching: .any)["radar-eu-note-unavailable"]
        XCTAssertFalse(missing.exists, "Daten vorhanden: kein Fehlerhinweis")
        XCTAssertFalse(note(app, "estimate").exists, "kein Schätzhinweis bei Europa")
        XCTAssertLessThan(Date().timeIntervalSince(start), 85, "Europa vor dem Ausfall gewählt")
        attach("europa-1-vorher")
        let wait = 95 - Date().timeIntervalSince(start)
        if wait > 0 { Thread.sleep(forTimeInterval: wait) }
        reloadOnce(app)
        XCTAssertTrue(missing.waitForExistence(timeout: 15), "Hinweis statt stillem Rückfall")
        XCTAssertTrue(missing.label.hasPrefix("Regenradar Europa ist derzeit nicht verfügbar"), missing.label)
        XCTAssertTrue((menu.value as? String ?? "").contains("Europa"), "Europa bleibt gewählt: \(menu.value ?? "")")
        XCTAssertFalse(app.staticTexts["radar-attribution"].exists, "keine Quellzeile ohne Bild")
        let texts = Set(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "nicht verfügbar"))
            .allElementsBoundByIndex.map(\.label))
        XCTAssertEqual(texts.count, 1, "genau ein Fehlerhinweis: \(texts)")
        XCTAssertFalse(app.descendants(matching: .any)["radar-slot-status"].exists, "keine zweite Pille über der Zeitachse")
        XCTAssertTrue(app.staticTexts["Keine Zeiten für Regenradar Europa"].exists, "Zeitachse bleibt als leere Leiste")
        attach("europa-2-ausfall")

        let back = 135 - Date().timeIntervalSince(start)
        if back > 0 { Thread.sleep(forTimeInterval: back) }
        reloadOnce(app)
        XCTAssertTrue(missing.waitForNonExistence(timeout: 15), "Hinweis verschwindet nach Erholung")
        XCTAssertTrue((menu.value as? String ?? "").contains("Europa"), "ohne Ebenenwechsel")
        XCTAssertTrue(waitForLabel(app.staticTexts["radar-attribution"], "\u{00A9} EUMETNET"), "Quellzeile wieder da")
        XCTAssertTrue(app.sliders["Radarzeitpunkt"].waitForExistence(timeout: 10), "Zeitachse wieder da")
        attach("europa-3-erholt")
    }

    /// Today's production backend has no `radar_world`: the entry stays visible as "Welt (NOAA) (bald)", cannot be chosen,
    /// the map keeps the chosen layer (no silent switch, no empty map), Europe and Germany stay selectable.
    func testBackendWithoutWorldLayerShowsWorldAsSoonAndNotSelectable() throws {
        let app = launch(["-UITestWithoutLayer", "radar_world"])
        let menu = app.buttons["radar-layer-menu"]
        menu.tap()
        let rain = app.buttons.matching(NSPredicate(format: "label == %@", "Regen")).firstMatch
        XCTAssertTrue(rain.waitForExistence(timeout: 5))
        rain.tap()
        // The native menu exposes the visible row text.
        let world = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Welt (NOAA)")).firstMatch
        XCTAssertTrue(world.waitForExistence(timeout: 5), "Eintrag bleibt sichtbar")
        XCTAssertEqual(world.label, "Welt (NOAA) (bald)", "klare Erklärung im Eintrag")
        XCTAssertFalse(world.isEnabled, "nicht wählbar")
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Europa (OPERA)")).firstMatch.isEnabled)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Deutschland (DWD)")).firstMatch.isEnabled)
        attach("ohne-welt-1-menue")
        world.tap()
        sleep(1)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5)).tap()
        sleep(1)
        XCTAssertEqual(menu.value as? String, "Regenradar", "Deutschland bleibt aktiv, kein Wechsel")
        XCTAssertFalse(app.descendants(matching: .any)["radar-world-note-unavailable"].exists, "kein Welt-Hinweis")
        XCTAssertFalse(app.descendants(matching: .any)["radar-world-note-estimate"].exists)
        XCTAssertTrue(waitForLabel(app.staticTexts["radar-attribution"], "\u{00A9} DWD"), "Deutschland-Karte mit Quelle, keine leere Karte")
        try choose(app, "Europa (OPERA)")
        XCTAssertTrue(waitForLabel(app.staticTexts["radar-attribution"], "\u{00A9} EUMETNET"), "Europa unverändert")
        attach("ohne-welt-2-europa")
    }

    // MARK: - Status notes after a cancelled, a failed and an unchanged layer fetch

    /// Labels of every status note about missing data (not available / server unreachable / stale / unreadable).
    private func statusNotes(_ app: XCUIApplication) -> Set<String> {
        // Only the map notes ("Regenradar Welt/Europa ..."): the forecast status button ("Prognose nicht verfügbar", live DWD
        // request) is a different, unrelated status and may appear without a stub.
        let predicate = NSPredicate(format: "(label BEGINSWITH %@ OR label BEGINSWITH %@) AND (label CONTAINS %@ OR label CONTAINS %@ OR label CONTAINS %@ OR label CONTAINS %@)",
                                    "Regenradar Welt", "Regenradar Europa",
                                    "nicht verfügbar", "nicht erreichbar", "keine aktuellen Daten", "nicht lesbar")
        return Set(app.descendants(matching: .any).matching(predicate).allElementsBoundByIndex.map(\.label))
    }

    private func wait(until seconds: TimeInterval, since start: Date) {
        let rest = seconds - Date().timeIntervalSince(start)
        if rest > 0 { Thread.sleep(forTimeInterval: rest) }
    }

    /// A cancelled fetch (no manifest before: the layer was just reported "not available") shows no "Server nicht erreichbar" note:
    /// the existing single note stays, the layer stays chosen (no switch to the radar), and one follow-up fetch restores the map.
    /// Stub timeline (seconds after the first request): 404 from 55 to 75, cancelled fetches from 75 to 110, then normal.
    private func cancelledFetchCase(layer: String, choosePrefix: String, name: String, noteID: String, shot: String) throws {
        executionTimeAllowance = 180
        let start = Date()
        let app = launch(["-UITestOutageLayer", layer, "-UITestFault", "404:55:75", "-UITestFault", "cancel:75:110"])
        try choose(app, choosePrefix)
        let menu = app.buttons["radar-layer-menu"]
        let missing = app.descendants(matching: .any)[noteID]
        XCTAssertTrue(app.sliders["Radarzeitpunkt"].waitForExistence(timeout: 10), "Zeitachse vorher")
        XCTAssertTrue((menu.value as? String ?? "").contains(name.replacingOccurrences(of: "Regenradar ", with: "")), "gewählt")
        XCTAssertTrue(statusNotes(app).isEmpty, "Daten vorhanden: kein Hinweis \(statusNotes(app))")
        XCTAssertLessThan(Date().timeIntervalSince(start), 50, "Ebene vor dem Ausfall gewählt")
        attach("\(shot)-1-vorher")

        // Phase 1: layer reported "not available" (404): the usual single note, no manifest any more.
        wait(until: 65, since: start)
        reloadOnce(app)
        XCTAssertTrue(missing.waitForExistence(timeout: 15), "Hinweis nach 404")
        XCTAssertTrue(missing.label.hasPrefix("\(name) ist derzeit nicht verfügbar"), missing.label)
        XCTAssertEqual(statusNotes(app).count, 1, "genau ein Hinweis: \(statusNotes(app))")
        attach("\(shot)-2-ausfall-404")

        // Phase 2: the next fetch is cancelled. Nothing changes: still the one 404 note, NO "Server nicht erreichbar", no switch.
        wait(until: 90, since: start)
        reloadOnce(app)
        sleep(4)   // the old code turned the note into "Server nicht erreichbar" right after the cancelled fetch
        let notes = statusNotes(app)
        XCTAssertEqual(notes.count, 1, "genau ein Hinweis nach Abbruch: \(notes)")
        XCTAssertFalse(notes.contains { $0.contains("nicht erreichbar") }, "kein 'Server nicht erreichbar' nach Abbruch: \(notes)")
        XCTAssertTrue(missing.exists && missing.label.hasPrefix("\(name) ist derzeit nicht verfügbar"), "Hinweis unverändert")
        XCTAssertTrue((menu.value as? String ?? "").contains(name.replacingOccurrences(of: "Regenradar ", with: "")), "Auswahl bleibt, kein Wechsel auf Radar: \(menu.value ?? "")")
        XCTAssertTrue(app.staticTexts["Keine Zeiten für \(name)"].exists, "Zeitachse unverändert leer")
        attach("\(shot)-3-abbruch")

        // Phase 3: one follow-up fetch, no layer change: note gone, picture and timeline back.
        wait(until: 120, since: start)
        reloadOnce(app)
        XCTAssertTrue(missing.waitForNonExistence(timeout: 15), "Hinweis nach genau einem Folgeabruf weg")
        XCTAssertTrue(statusNotes(app).isEmpty, "kein Hinweis mehr: \(statusNotes(app))")
        XCTAssertTrue((menu.value as? String ?? "").contains(name.replacingOccurrences(of: "Regenradar ", with: "")), "ohne Ebenenwechsel")
        XCTAssertTrue(app.sliders["Radarzeitpunkt"].waitForExistence(timeout: 10), "Zeitachse wieder da")
        XCTAssertTrue(app.staticTexts["radar-attribution"].waitForExistence(timeout: 10), "Quellzeile wieder da")
        attach("\(shot)-4-erholt")
    }

    func testCancelledFetchOfWorldShowsNoUnreachableNoteKeepsSelectionAndRecovers() throws {
        try cancelledFetchCase(layer: "radar_world", choosePrefix: "Welt (NOAA)", name: "Regenradar Welt",
                               noteID: "radar-world-note-unavailable", shot: "abbruch-welt")
    }

    func testCancelledFetchOfEuropeShowsNoUnreachableNoteKeepsSelectionAndRecovers() throws {
        try cancelledFetchCase(layer: "radar_eu", choosePrefix: "Europa (OPERA)", name: "Regenradar Europa",
                               noteID: "radar-eu-note-unavailable", shot: "abbruch-europa")
    }

    /// A real failure (network unreachable, no fresh manifest left) still shows exactly one "Server nicht erreichbar" note; one
    /// follow-up fetch removes it again without a layer change. Stub (seconds after the first request): 404 from 50 to 65 (no
    /// manifest any more), network failure from 65 to 90, then normal.
    private func realFailureCase(layer: String, choosePrefix: String, name: String, noteID: String, shot: String) throws {
        executionTimeAllowance = 170
        let start = Date()
        let app = launch(["-UITestOutageLayer", layer, "-UITestFault", "404:50:65", "-UITestFault", "offline:65:90"])
        try choose(app, choosePrefix)
        let menu = app.buttons["radar-layer-menu"]
        let short = name.replacingOccurrences(of: "Regenradar ", with: "")
        let missing = app.descendants(matching: .any)[noteID]
        XCTAssertTrue(app.sliders["Radarzeitpunkt"].waitForExistence(timeout: 10), "Zeitachse vorher")
        XCTAssertTrue(statusNotes(app).isEmpty, "Daten vorhanden: kein Hinweis")
        XCTAssertLessThan(Date().timeIntervalSince(start), 45, "Ebene vor dem Ausfall gewählt")
        attach("\(shot)-1-vorher")

        wait(until: 58, since: start)
        reloadOnce(app)
        XCTAssertTrue(missing.waitForExistence(timeout: 15), "Hinweis nach 404")
        XCTAssertEqual(statusNotes(app).count, 1, "genau ein Hinweis: \(statusNotes(app))")

        wait(until: 75, since: start)
        reloadOnce(app)
        sleep(3)
        let notes = statusNotes(app)
        XCTAssertEqual(notes.count, 1, "genau ein Hinweis bei echtem Ausfall: \(notes)")
        XCTAssertTrue(missing.exists && missing.label.hasPrefix("\(name): Server nicht erreichbar"), "echter Ausfall zeigt den Hinweis: \(notes)")
        XCTAssertTrue((menu.value as? String ?? "").contains(short), "Auswahl bleibt")
        attach("\(shot)-2-ausfall")

        wait(until: 100, since: start)
        reloadOnce(app)
        XCTAssertTrue(missing.waitForNonExistence(timeout: 15), "Hinweis nach einem Folgeabruf weg")
        XCTAssertTrue(statusNotes(app).isEmpty, "kein Hinweis mehr: \(statusNotes(app))")
        XCTAssertTrue((menu.value as? String ?? "").contains(short), "ohne Ebenenwechsel")
        XCTAssertTrue(app.sliders["Radarzeitpunkt"].waitForExistence(timeout: 10), "Zeitachse da")
        attach("\(shot)-3-erholt")
    }

    /// The same manifest fetched twice (second answer `304`): exactly the usual notes, no flicker, selection and timeline unchanged.
    private func unchangedFetchCase(layer: String, choosePrefix: String, name: String, shot: String, expectedNotes: Int) throws {
        executionTimeAllowance = 150
        let app = launch(["-UITestETag", "1"])
        _ = layer
        try choose(app, choosePrefix)
        let menu = app.buttons["radar-layer-menu"]
        let short = name.replacingOccurrences(of: "Regenradar ", with: "")
        let slider = app.sliders["Radarzeitpunkt"]
        XCTAssertTrue(slider.waitForExistence(timeout: 10), "Zeitachse vorher")
        sleep(2)
        let value = slider.value as? String ?? "", credit = app.staticTexts["radar-attribution"].label
        func noteIDs() -> Set<String> {
            let predicate = NSPredicate(format: "identifier BEGINSWITH %@ OR identifier BEGINSWITH %@", "radar-world-note-", "radar-eu-note-")
            return Set(app.descendants(matching: .any).matching(predicate).allElementsBoundByIndex.map(\.identifier))
        }
        let notesBefore = noteIDs()
        XCTAssertEqual(notesBefore.count, expectedNotes, "Hinweise vorher: \(notesBefore)")
        XCTAssertTrue(statusNotes(app).isEmpty)
        attach("\(shot)-1-vorher")
        for round in 1...2 {
            reloadOnce(app)
            sleep(3)
            XCTAssertEqual(noteIDs(), notesBefore, "Hinweise unverändert nach Abruf \(round)")
            XCTAssertTrue(statusNotes(app).isEmpty, "kein Fehlerhinweis nach Abruf \(round): \(statusNotes(app))")
            XCTAssertTrue((menu.value as? String ?? "").contains(short), "Auswahl unverändert")
            XCTAssertEqual(slider.value as? String, value, "Zeitachse unverändert nach Abruf \(round)")
            XCTAssertEqual(app.staticTexts["radar-attribution"].label, credit, "Quellzeile unverändert")
            attach("\(shot)-\(round + 1)-nach-abruf-\(round)")
        }
    }

    func testRealFailureOfWorldShowsOneNoteThenRecoversWithOneFetch() throws {
        try realFailureCase(layer: "radar_world", choosePrefix: "Welt (NOAA)", name: "Regenradar Welt",
                            noteID: "radar-world-note-unavailable", shot: "ausfall-welt")
    }

    func testRealFailureOfEuropeShowsOneNoteThenRecoversWithOneFetch() throws {
        try realFailureCase(layer: "radar_eu", choosePrefix: "Europa (OPERA)", name: "Regenradar Europa",
                            noteID: "radar-eu-note-unavailable", shot: "ausfall-europa")
    }

    func testUnchangedFetchOfWorldKeepsNoteSelectionAndTimeline() throws {
        try unchangedFetchCase(layer: "radar_world", choosePrefix: "Welt (NOAA)", name: "Regenradar Welt", shot: "unveraendert-welt", expectedNotes: 1)
    }

    func testUnchangedFetchOfEuropeKeepsSelectionAndTimeline() throws {
        try unchangedFetchCase(layer: "radar_eu", choosePrefix: "Europa (OPERA)", name: "Regenradar Europa", shot: "unveraendert-europa", expectedNotes: 0)
    }

    // MARK: - Integration against a local backend (skipped unless the host script sets the sync folder)

    /// Runs only with `TEST_RUNNER_B52_BACKEND_SYNC=<folder>` and `TEST_RUNNER_B52_BACKEND_URL=http://127.0.0.1:<port>/v1/radar/`:
    /// a host script restarts a LOCAL backend with another `LAYERS` set when this test writes `<phase>.req` and answers with
    /// `<phase>.ack`. No network beyond localhost is touched by the app; the test is skipped in every normal run.
    func testIntegrationAgainstLocalBackendWorldEuropeOutageAndWithoutWorld() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let sync = environment["B52_BACKEND_SYNC"], let url = environment["B52_BACKEND_URL"] else {
            throw XCTSkip("Nur mit lokalem Backend (B52_BACKEND_SYNC, B52_BACKEND_URL)")
        }
        executionTimeAllowance = 180
        func request(_ phase: String) {
            FileManager.default.createFile(atPath: "\(sync)/\(phase).req", contents: Data())
            let deadline = Date().addingTimeInterval(120)
            while !FileManager.default.fileExists(atPath: "\(sync)/\(phase).ack"), Date() < deadline { Thread.sleep(forTimeInterval: 1) }
            XCTAssertTrue(FileManager.default.fileExists(atPath: "\(sync)/\(phase).ack"), "Backend-Phase \(phase)")
        }
        func start() -> XCUIApplication {
            let app = UITestLaunch.app(language: .german, extra: ["-radar-backend-url", url])
            app.launch()
            XCTAssertTrue(app.buttons["radar-layer-menu"].waitForExistence(timeout: 20))
            sleep(3)
            app.buttons["radar-layer-menu"].tap()
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5)).tap()
            sleep(1)
            return app
        }
        var app = start()
        let menu = app.buttons["radar-layer-menu"]

        try choose(app, "Welt (NOAA)")
        XCTAssertTrue(app.sliders["Radarzeitpunkt"].waitForExistence(timeout: 15), "Welt mit echtem Slot: Zeitachse")
        XCTAssertTrue(note(app, "estimate").waitForExistence(timeout: 5), "Schätzhinweis")
        XCTAssertFalse(note(app, "unavailable").exists, "Daten vorhanden: kein Fehlerhinweis")
        XCTAssertTrue(app.staticTexts["radar-attribution"].waitForExistence(timeout: 10), "Quellzeile Welt")
        print("BACKEND welt credit=\(app.staticTexts["radar-attribution"].label) value=\(menu.value ?? "")")
        attach("backend-1-welt")

        try choose(app, "Europa (OPERA)")
        XCTAssertTrue(waitForLabel(app.staticTexts["radar-attribution"], "\u{00A9} EUMETNET", timeout: 15), "Europa mit Daten")
        XCTAssertTrue(app.sliders["Radarzeitpunkt"].waitForExistence(timeout: 10))
        attach("backend-2-europa-vorher")

        request("eu-aus")   // backend without radar_eu: 404
        reloadOnce(app)
        let missing = app.descendants(matching: .any)["radar-eu-note-unavailable"]
        XCTAssertTrue(missing.waitForExistence(timeout: 15), "Hinweis bei Europa-Ausfall")
        XCTAssertEqual(statusNotes(app).count, 1, "genau ein Hinweis: \(statusNotes(app))")
        XCTAssertTrue((menu.value as? String ?? "").contains("Europa"), "Europa bleibt gewählt")
        attach("backend-3-europa-ausfall")

        request("eu-an")   // radar_eu is back
        reloadOnce(app)
        XCTAssertTrue(missing.waitForNonExistence(timeout: 15), "Hinweis nach einem Folgeabruf weg")
        XCTAssertTrue(app.sliders["Radarzeitpunkt"].waitForExistence(timeout: 10), "Zeitachse wieder da")
        XCTAssertTrue((menu.value as? String ?? "").contains("Europa"), "ohne Ebenenwechsel")
        XCTAssertTrue(statusNotes(app).isEmpty)
        attach("backend-4-europa-erholt")

        request("ohne-welt")   // production state today: no radar_world
        app.terminate()
        app = start()
        app.buttons["radar-layer-menu"].tap()
        let rain = app.buttons.matching(NSPredicate(format: "label == %@", "Regen")).firstMatch
        XCTAssertTrue(rain.waitForExistence(timeout: 5))
        rain.tap()
        let world = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Welt (NOAA)")).firstMatch
        XCTAssertTrue(world.waitForExistence(timeout: 5))
        XCTAssertEqual(world.label, "Welt (NOAA) (bald)")
        XCTAssertFalse(world.isEnabled, "nicht wählbar")
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Europa (OPERA)")).firstMatch.isEnabled)
        attach("backend-5-ohne-welt-menue")
        request("ende")
    }
}
