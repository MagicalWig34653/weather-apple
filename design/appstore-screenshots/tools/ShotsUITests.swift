import XCTest

// Eigenstaendiges UI-Test-Bundle nur fuer App-Store-Screenshots (nicht Teil von Weather.xcodeproj).
// Umgebung (TEST_RUNNER_*): SHOT_DIR, SHOT_MODE (sweep|main), SHOT_PREFIX.
@MainActor
final class ShotsUITests: XCTestCase {
    let env = ProcessInfo.processInfo.environment
    var dir: String { env["SHOT_DIR"] ?? "/tmp/shots" }
    var prefix: String { env["SHOT_PREFIX"] ?? "" }

    var isEN: Bool { (env["SHOT_LANG"] ?? "de") == "en" }
    /// Sichtbare Texte je Sprache (de, en).
    func t(_ de: String, _ en: String) -> String { isEN ? en : de }
    var placePrefix: String { t("Ort auswählen:", "Choose place:") }

    func snap(_ name: String) {
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let data = XCUIScreen.main.screenshot().pngRepresentation
        try? data.write(to: URL(fileURLWithPath: "\(dir)/\(prefix)\(name).png"))
    }

    func launch() -> XCUIApplication {
        let app = XCUIApplication(bundleIdentifier: "de.linolaske.showernow")
        app.launchArguments = ["-AppleLanguages", "(\(env["SHOT_LANG"] ?? "de"))", "-AppleLocale", env["SHOT_LOCALE"] ?? "de_DE"]
            + (env["SHOT_ARGS"] ?? "").split(separator: " ").map(String.init)
        app.launch()
        return app
    }

    func testSweep() throws {
        let app = launch()
        let slider = app.sliders[t("Radarzeitpunkt", "Radar time")]
        XCTAssertTrue(slider.waitForExistence(timeout: 40))
        sleep(8)
        let ps = (env["SHOT_POS"] ?? "0,0.15,0.3,0.45,0.6,0.75,0.9,1").split(separator: ",").compactMap { Double($0) }
        for p in ps {
            slider.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5)).press(forDuration: 0.1, thenDragTo: slider.coordinate(withNormalizedOffset: CGVector(dx: max(p, 0.02), dy: 0.5)))
            sleep(6)
            let v = (slider.value as? String ?? "").replacingOccurrences(of: ":", with: "h").replacingOccurrences(of: ", ", with: "_").replacingOccurrences(of: " ", with: "")
            snap("sweep-\(Int(p * 100))-\(v)")
        }
    }

    /// Sucht SHOT_CITY ueber die Ortssuche, waehlt den ersten Treffer und speichert ihn (Lesezeichen) unter diesem Namen.
    func testAddPlace() throws {
        let city = env["SHOT_CITY"] ?? "Stadt"
        let app = launch()
        let header = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", placePrefix)).firstMatch
        XCTAssertTrue(header.waitForExistence(timeout: 30))
        header.tap()
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        field.typeText(city + "\n")
        let result = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", city)).element(boundBy: 0)
        XCTAssertTrue(result.waitForExistence(timeout: 15))
        snap("search-\(city)")
        result.tap()
        sleep(3)
        let save = app.buttons[t("Ausgewählten Ort speichern oder umbenennen", "Save or rename the selected place")]
        XCTAssertTrue(save.waitForExistence(timeout: 10))
        save.tap()
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        let tf = alert.textFields.firstMatch
        tf.tap()
        let existing = tf.value as? String ?? ""
        tf.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count) + city)
        alert.buttons[t("Speichern", "Save")].tap()
        if !alert.waitForNonExistence(timeout: 2) { alert.buttons[t("Speichern", "Save")].tap() }
        sleep(2)
        snap("added-\(city)")
    }

    // MARK: Motive

    func select(_ app: XCUIApplication, _ city: String) {
        let header = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", placePrefix)).firstMatch
        XCTAssertTrue(header.waitForExistence(timeout: 40))
        if header.label.hasSuffix(city) { return }
        header.tap()
        let row = app.buttons.matching(NSPredicate(format: "label == %@", city)).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
        sleep(2)
    }

    /// Zieht den Zeitregler auf die Position SHOT_POS (0...1); mit radarPastHours=48 liegt 0.30 bei Mo 2.11. 09:15 (Regenband ueber Niedersachsen).
    func seek(_ app: XCUIApplication, pos: Double) {
        let slider = app.sliders[t("Radarzeitpunkt", "Radar time")]
        XCTAssertTrue(slider.waitForExistence(timeout: 40))
        sleep(10)
        slider.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5)).press(forDuration: 0.1, thenDragTo: slider.coordinate(withNormalizedOffset: CGVector(dx: pos, dy: 0.5)))
        sleep(1)
    }

    /// Fuer das Vorschauvideo: Regler auf SHOT_POS ziehen, dann langsam (SHOT_VELOCITY pt/s) bis SHOT_TO ziehen; Marken (Unix-Zeit) in SHOT_DIR.
    func testPreviewTour() throws {
        let app = launch()
        select(app, env["SHOT_PLACE"] ?? "Hannover")
        let from = Double(env["SHOT_POS"] ?? "0.22") ?? 0.22, to = Double(env["SHOT_TO"] ?? "0.42") ?? 0.42
        seek(app, pos: from)
        sleep(4)
        let slider = app.sliders[t("Radarzeitpunkt", "Radar time")]
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try? "\(Date().timeIntervalSince1970)".write(toFile: "\(dir)/tour-start.txt", atomically: true, encoding: .utf8)
        let v = Double(env["SHOT_VELOCITY"] ?? "8") ?? 8
        slider.coordinate(withNormalizedOffset: CGVector(dx: from, dy: 0.5)).press(forDuration: 0.5, thenDragTo: slider.coordinate(withNormalizedOffset: CGVector(dx: to, dy: 0.5)), withVelocity: XCUIGestureVelocity(rawValue: CGFloat(v)), thenHoldForDuration: 2)
        try? "\(Date().timeIntervalSince1970)".write(toFile: "\(dir)/tour-end.txt", atomically: true, encoding: .utf8)
    }

    /// Radar mit Regen: SHOT_PLACE, SHOT_SLOT 
    func testRain() throws {
        let app = launch()
        select(app, env["SHOT_PLACE"] ?? "Hannover")
        seek(app, pos: Double(env["SHOT_POS"] ?? "0.30") ?? 0.30)
        sleep(6)
        snap(env["SHOT_NAME"] ?? "rain")
    }

    func testLayer() throws {
        let app = launch()
        select(app, env["SHOT_PLACE"] ?? "Hannover")
        sleep(5)
        let menu = app.buttons["radar-layer-menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 20))
        menu.tap()
        sleep(1)
        if env["SHOT_MENUSHOT"] == "1" { snap("menu") }
        let item = app.buttons[env["SHOT_LAYER"] ?? "Wolken"]
        XCTAssertTrue(item.waitForExistence(timeout: 5))
        item.tap()
        sleep(12)
        if let pos = env["SHOT_POS"].flatMap({ Double($0) }) {
            let slider = app.sliders.firstMatch
            XCTAssertTrue(slider.waitForExistence(timeout: 10))
            slider.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5)).press(forDuration: 0.1, thenDragTo: slider.coordinate(withNormalizedOffset: CGVector(dx: pos, dy: 0.5)))
            sleep(12)
        }
        snap(env["SHOT_NAME"] ?? "layer")
    }

    func testSheets() throws {
        let app = launch()
        select(app, env["SHOT_PLACE"] ?? "Hannover")
        sleep(6)
        app.buttons["forecast-details"].tap()
        sleep(5)
        snap("forecast")
        app.buttons[t("Fertig", "Done")].tap()
        sleep(2)
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", placePrefix)).firstMatch.tap()
        sleep(3)
        snap("places")
        app.swipeDown()
        sleep(2)
        app.buttons[t("Datenquellen und Datenschutz", "Data sources and privacy")].tap()
        sleep(4)
        snap("info")
    }

    func testInfo() throws {
        let app = launch()
        select(app, env["SHOT_PLACE"] ?? "Hannover")
        sleep(6)
        app.buttons[t("Datenquellen und Datenschutz", "Data sources and privacy")].tap()
        XCTAssertTrue(app.navigationBars[t("Über Showers", "About Showers")].waitForExistence(timeout: 10))
        sleep(3)
        snap(env["SHOT_NAME"] ?? "info")
    }

    /// Orte-Sheet (ohne Push-Unterseite)
    func testPlaces() throws {
        let app = launch()
        select(app, env["SHOT_PLACE"] ?? "Hannover")
        sleep(6)
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", placePrefix)).firstMatch.tap()
        XCTAssertTrue(app.navigationBars[t("Deine Orte", "Your Places")].waitForExistence(timeout: 10))
        sleep(2)
        snap(env["SHOT_NAME"] ?? "places")
    }

    // MARK: Neue Motive (Store-Screenshots 2026-11, nur Deutsch: die englische Oberflaeche ist nicht vollstaendig lokalisiert)

    func openLayer(_ app: XCUIApplication, prefix: String) {
        let menu = app.buttons["radar-layer-menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 20))
        menu.tap()
        let item = app.buttons.matching(NSPredicate(format: "label BEGINSWITH[c] %@ OR label CONTAINS[c] %@", prefix, prefix)).firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 8), "Ebene \(prefix) fehlt im Menue")
        item.tap()
    }

    func dragSlider(_ app: XCUIApplication, _ pos: Double) {
        let slider = app.sliders.firstMatch
        XCTAssertTrue(slider.waitForExistence(timeout: 20))
        slider.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5)).press(forDuration: 0.1, thenDragTo: slider.coordinate(withNormalizedOffset: CGVector(dx: pos, dy: 0.5)))
    }

    /// SHOT_SCENE: radar | details | temp | humidity | warnings | regionnew | alerts | places
    func testScene() throws {
        let app = launch()
        let scene = env["SHOT_SCENE"] ?? "radar"
        let name = env["SHOT_NAME"] ?? scene
        let pos = Double(env["SHOT_POS"] ?? "")
        select(app, env["SHOT_PLACE"] ?? "Hamburg")
        switch scene {
        case "radar":
            sleep(8)
            dragSlider(app, pos ?? 0.84)
            sleep(8)
        case "details":
            sleep(8)
            if let pos { dragSlider(app, pos); sleep(6) }
            app.buttons["forecast-details"].tap()
            sleep(5)
        case "temp", "humidity":
            sleep(4)
            openLayer(app, prefix: scene == "temp" ? t("Temperatur", "Temperature") : t("Feuchte (relativ)", "Humidity (relative)"))
            sleep(14)
            if let pos { dragSlider(app, pos); sleep(12) }
            let legend = app.buttons["radar-legend-toggle"]
            if env["SHOT_FOREST"] == "1" {
                legend.tap()
                sleep(2)
                app.descendants(matching: .any)["forest-toggle"].switches.firstMatch.tap()
                sleep(3)
                legend.tap()
                sleep(6)
            }
            if env["SHOT_LEGEND"] == "1" { legend.tap(); sleep(2) }
            if env["SHOT_READ"] == "1" {
                let read = app.buttons["radar-read-center"]
                XCTAssertTrue(read.waitForExistence(timeout: 20), "Wertabfrage-Knopf fehlt")
                read.tap()
                sleep(4)
            }
        case "warnings":
            let b = app.buttons["radar-warnings-button"]
            XCTAssertTrue(b.waitForExistence(timeout: 20))
            sleep(3)
            b.tap()
            XCTAssertTrue(app.navigationBars[t("Amtliche Warnungen", "Official warnings")].waitForExistence(timeout: 8))
            sleep(3)
        case "regionnew":
            app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", placePrefix)).firstMatch.tap()
            XCTAssertTrue(app.navigationBars[t("Deine Orte", "Your Places")].waitForExistence(timeout: 10))
            sleep(3)
            snap(name + "-places")
            let add = app.buttons["region-new"]
            if !add.exists { app.swipeUp() }
            XCTAssertTrue(add.waitForExistence(timeout: 5))
            add.tap()
            sleep(6)
        case "menu":
            sleep(4)
            app.buttons["radar-layer-menu"].tap()
            sleep(2)
        case "alerts":
            app.buttons[t("Datenquellen und Datenschutz", "Data sources and privacy")].tap()
            let row = app.buttons["info-row-alerts"]
            XCTAssertTrue(row.waitForExistence(timeout: 8))
            row.tap()
            sleep(4)
        default: break
        }
        snap(name)
    }
}
