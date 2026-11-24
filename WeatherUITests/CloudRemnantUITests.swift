import XCTest

/// Befund Build 56 (Dunkelmodus, Wolken, nach App-Neustart, aeltester Slot): ein scharf begrenztes Rechteck der unbedeckten Basiskarte
/// (gruenes Land) liegt ueber dem Wolkenbild; Kacheln des Wolken-Overlays bleiben nach dem Slotwechsel ungezeichnet. Pixelmessung:
/// Vor dem Wechsel zu Wolken wird die Karte aufgenommen; eine 24-px-Zelle des Kartenbereichs (ohne Pillen, Tasten, Zeitleiste) gilt
/// als unbedeckt, wenn sie von dieser Karte im Mittel um weniger als 8 von 255 abweicht. Ein Rechteck ist ein Teil unbedeckt, der
/// Rest bedeckt; es muss nach 5 s und 10 s verschwunden sein (Dauerzustand = Fehler).
///
/// Echtbackend (Produktion, nur lesend), kein Stub; laeuft nur mit `TEST_RUNNER_CLOUDREST_PROD=1`.
/// Optional: `CLOUDREST_RUNS` (Standard 5), `CLOUDREST_PATH=short|long` (long: Radar, Europa, Welt, Blitze vor Wolken wie im
/// 6-h-Test), `CLOUDREST_DIR` (Ablage der Bilder). Ergebniszeilen `CLOUDREST ...` im Log.
@MainActor
final class CloudRemnantUITests: XCTestCase {
    private var suffix: String {
        ProcessInfo.processInfo.environment["SHOT_SUFFIX"] ?? (XCUIDevice.shared.appearance == .dark ? "dark" : "light")
    }
    private var shotDir: String { ProcessInfo.processInfo.environment["CLOUDREST_DIR"] ?? "/private/tmp/claude-501/cloudrest-shots" }

    override func setUpWithError() throws {
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .portrait
        guard ProcessInfo.processInfo.environment["CLOUDREST_PROD"] != nil else {
            throw XCTSkip("Nur mit TEST_RUNNER_CLOUDREST_PROD=1 (liest die Produktion, nur Ansicht)")
        }
    }

    // MARK: Pixelmessung

    struct Measurement {
        var cells = 0, saturated = 0
        var box: (x0: Int, y0: Int, x1: Int, y1: Int)?
    }

    /// Zellen (24 px) im Kartenbereich (x 3...82 %, y 22...80 % des Bildes), in denen die Karte UNBEDECKT ist. Mit `base` (die Karte
    /// ohne Wolkenbild, gleicher Ausschnitt) heisst das: mittlere Abweichung der Zelle von der Karte unter 8 (von 255). Ohne `base`:
    /// hohe Farbsaettigung (Wolken sind grau; nur dunkel und bei grauem Wolkenbild zuverlaessig, bei Tageslicht ist das Wolkenbild bunt).
    nonisolated static func measure(_ image: UIImage, base: UIImage? = nil, threshold: Double = 0.30) -> Measurement {
        func pixels(_ image: UIImage) -> (px: [UInt8], w: Int, h: Int)? {
            guard let cg = image.cgImage else { return nil }
            let w = cg.width, h = cg.height
            var px = [UInt8](repeating: 0, count: w * h * 4)
            guard let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
            return (px, w, h)
        }
        guard let (px, w, h) = pixels(image) else { return Measurement() }
        let reference = base.flatMap(pixels)
        let cell = 24
        let x0 = Int(Double(w) * 0.03), x1 = Int(Double(w) * 0.82), y0 = Int(Double(h) * 0.22), y1 = Int(Double(h) * 0.80)
        var result = Measurement()
        var y = y0
        while y + cell <= y1 {
            var x = x0
            while x + cell <= x1 {
                var sum = 0.0
                for yy in stride(from: y, to: y + cell, by: 4) {
                    for xx in stride(from: x, to: x + cell, by: 4) {
                        let i = (yy * w + xx) * 4
                        if let reference, reference.w == w, reference.h == h {
                            sum += (abs(Double(px[i]) - Double(reference.px[i])) + abs(Double(px[i + 1]) - Double(reference.px[i + 1]))
                                    + abs(Double(px[i + 2]) - Double(reference.px[i + 2]))) / 3
                        } else {
                            let r = Double(px[i]), g = Double(px[i + 1]), b = Double(px[i + 2])
                            let mx = max(r, g, b), mn = min(r, g, b)
                            sum += mx > 0 ? (mx - mn) / mx : 0
                        }
                    }
                }
                let mean = sum / 36
                let uncovered = reference != nil ? mean < 8 : mean > threshold
                result.cells += 1
                if uncovered {
                    result.saturated += 1
                    if var b = result.box { b.x0 = min(b.x0, x); b.y0 = min(b.y0, y); b.x1 = max(b.x1, x + cell); b.y1 = max(b.y1, y + cell); result.box = b }
                    else { result.box = (x, y, x + cell, y + cell) }
                }
                x += cell
            }
            y += cell
        }
        return result
    }

    /// Mehr gesaettigte Zellen (ca. 10 % des Kartenbereichs) gelten als sichtbare unbedeckte Karte.
    nonisolated static let remnantCells = 250

    /// `.loading`: fast der ganze Kartenbereich unbedeckt (das Bild des Slots ist noch nicht da, kurz nach dem Wechsel erwartet).
    /// `.rectangle`: ein Teil unbedeckt, der Rest bedeckt (der Befund). `.clean`: Wolkenbild ohne sichtbare Karte.
    enum Verdict { case clean, loading, rectangle }
    nonisolated static func verdict(_ m: Measurement) -> Verdict {
        if m.saturated <= remnantCells { return .clean }
        return Double(m.saturated) >= 0.85 * Double(m.cells) ? .loading : .rectangle
    }

    // MARK: Bedienung

    private func launch() -> XCUIApplication {
        let app = UITestLaunch.app(extra: UITestLaunch.setAppearance(suffix == "dark" ? .dark : .light, extra: []))
        app.launch()
        let menu = app.buttons["radar-layer-menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 40))
        sleep(6)
        menu.tap()   // Ebenen werden nach der ersten Abfrage gemeldet
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5)).tap()
        sleep(1)
        return app
    }

    private func chooseSixHours(_ app: XCUIApplication) {
        let info = app.buttons["Datenquellen und Datenschutz"]
        XCTAssertTrue(info.waitForExistence(timeout: 30))
        info.tap()
        let entry = app.buttons["Maximale Vergangenheit"]
        XCTAssertTrue(entry.waitForExistence(timeout: 10))
        entry.tap()
        let row = app.descendants(matching: .any).matching(identifier: "past-hours-6").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "past-hours-6")
        row.tap()
        sleep(1)
        for _ in 0..<3 where app.sliders.firstMatch.isHittable == false {
            app.swipeDown(velocity: .fast)
            sleep(1)
        }
    }

    private func layerValue(_ app: XCUIApplication) -> String { (app.buttons["radar-layer-menu"].value as? String) ?? "" }

    private func chooseRain(_ app: XCUIApplication, _ prefix: String) -> Bool {
        let menu = app.buttons["radar-layer-menu"]
        let rain = app.buttons.matching(NSPredicate(format: "label == %@", "Regen")).firstMatch
        let entry = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
        for _ in 0..<4 {
            menu.tap()
            if rain.waitForExistence(timeout: 3) { rain.tap() }
            if entry.waitForExistence(timeout: 3), entry.isEnabled {
                entry.tap()
                if entry.waitForNonExistence(timeout: 3) { sleep(3); return true }
            }
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5)).tap()
            sleep(2)
        }
        return false
    }

    private func chooseClouds(_ app: XCUIApplication) -> Bool {
        for _ in 0..<3 {
            if layerValue(app).contains("Wolken") { return true }
            guard let entry = openLayerEntry(app, group: nil, entry: "Wolken", attempts: 3), entry.isEnabled else { return false }
            entry.tap()
            let end = Date().addingTimeInterval(8)
            while Date() < end && !layerValue(app).contains("Wolken") { usleep(300_000) }
            if layerValue(app).contains("Wolken") { return true }
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5)).tap()
            sleep(1)
        }
        return false
    }

    private func jump(_ slider: XCUIElement, fraction: Double, settle: UInt32 = 2) {
        let width = Double(slider.frame.width)
        let x = min(max((20 + fraction * (width - 40)) / width, 0.004), 0.996)
        slider.coordinate(withNormalizedOffset: CGVector(dx: x, dy: 0.5)).press(forDuration: 0.05)
        if settle > 0 { sleep(settle) }
    }

    /// Ein Bild, gemessen; als Datei abgelegt, wenn auffaellig oder `keep`.
    @discardableResult
    private func frame(_ app: XCUIApplication, run: Int, phase: String, label: String, keep: Bool, base: UIImage?) -> Measurement {
        let shot = XCUIScreen.main.screenshot()
        let m = Self.measure(shot.image, base: base)
        let verdict = Self.verdict(m)
        let flagged = verdict != .clean
        if flagged || keep {
            try? FileManager.default.createDirectory(atPath: shotDir, withIntermediateDirectories: true)
            let name = "\(suffix)-lauf\(run)-\(phase)-\(label)\(flagged ? "-REST" : "").png"
            try? shot.pngRepresentation.write(to: URL(fileURLWithPath: shotDir).appendingPathComponent(name))
        }
        let box = m.box.map { "\($0.x0),\($0.y0),\($0.x1),\($0.y1)" } ?? "-"
        print("CLOUDREST run=\(run) mode=\(suffix) phase=\(phase) t=\(label) zellen=\(m.cells) gesaettigt=\(m.saturated) box=\(box) urteil=\(verdict)")
        return m
    }

    /// Zaehlt nur, was bleibt: nach 5 s und 10 s ist das Wolkenbild des Slots (Ladezeit ca. 0,2 s) laengst da. Bilder direkt nach dem
    /// Tippen (t0, t2) werden gemessen und protokolliert, zaehlen aber nicht (kurzes Nachladen ist erwartet).
    nonisolated static func isDefect(_ m: Measurement, label: String) -> Bool {
        (label == "t5" || label == "t10") && verdict(m) != .clean
    }

    /// Wolken waehlen, aeltester Slot per Tippen, danach Bilder direkt und nach 2/5/10 s.
    private func cloudsToOldest(_ app: XCUIApplication, run: Int, phase: String, longPath: Bool) -> Int {
        if longPath {
            _ = chooseRain(app, "Europa (OPERA)")
            _ = chooseRain(app, "Welt (NOAA)")
            if let blitze = openLayerEntry(app, group: nil, entry: "Blitze", attempts: 3), blitze.isEnabled { blitze.tap(); sleep(3) }
        }
        sleep(2)
        let base = XCUIScreen.main.screenshot().image   // Karte ohne Wolkenbild (Regenradar bzw. Blitze, kaum Bildinhalt)
        XCTAssertTrue(chooseClouds(app), "\(phase) lauf \(run): Wolken nicht waehlbar (Ebene: \(layerValue(app)))")
        sleep(3)
        let slider = app.sliders.firstMatch
        XCTAssertTrue(slider.waitForExistence(timeout: 40), "Zeitleiste")
        jump(slider, fraction: 1)
        jump(slider, fraction: 1)
        jump(slider, fraction: 0, settle: 0)
        let t0 = Date()
        var defects = 0
        if Self.isDefect(frame(app, run: run, phase: phase, label: "t0", keep: run == 1, base: base), label: "t0") { defects += 1 }
        for seconds in [2.0, 5.0, 10.0] {
            let wait = seconds - Date().timeIntervalSince(t0)
            if wait > 0 { usleep(UInt32(wait * 1_000_000)) }
            let label = "t\(Int(seconds))"
            let defect = Self.isDefect(frame(app, run: run, phase: phase, label: label, keep: run == 1, base: base), label: label)
            if defect { defects += 1 }
        }
        // Bleibt das Rechteck stehen: heilt es mit der Zeit (30 s, 60 s) ohne Eingriff?
        if defects > 0, Self.verdict(Self.measure(XCUIScreen.main.screenshot().image, base: base)) != .clean {
            for seconds in [30.0, 60.0] {
                let wait = seconds - Date().timeIntervalSince(t0)
                if wait > 0 { usleep(UInt32(wait * 1_000_000)) }
                frame(app, run: run, phase: phase, label: "t\(Int(seconds))", keep: true, base: base)
            }
            // Heilt eine Beruehrung der Karte (4 pt hin und zurueck)? Unterscheidet "Kachel nie gezeichnet" von "Anzeige nicht aufgefrischt".
            let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            from.press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.505)))
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.505)).press(forDuration: 0.1, thenDragTo: from)
            sleep(2)
            frame(app, run: run, phase: phase, label: "nach-beruehrung", keep: true, base: base)
        }
        return defects
    }

    /// Radar -> Wolken -> aeltester Slot -> App-Neustart -> Wolken, `CLOUDREST_RUNS` mal.
    func testCloudsShowNoBaseMapRectangleAfterLayerChangeAndRestart() throws {
        let runs = Int(ProcessInfo.processInfo.environment["CLOUDREST_RUNS"] ?? "") ?? 5
        let longPath = ProcessInfo.processInfo.environment["CLOUDREST_PATH"] == "long"
        var flaggedFrames = 0
        for run in 1...runs {
            var app = launch()
            chooseSixHours(app)
            flaggedFrames += cloudsToOldest(app, run: run, phase: "sitzung", longPath: longPath)
            app.terminate()
            app = launch()
            flaggedFrames += cloudsToOldest(app, run: run, phase: "neustart", longPath: longPath)
            app.terminate()
        }
        print("CLOUDREST summe runs=\(runs) mode=\(suffix) pfad=\(longPath ? "long" : "short") auffaellige_bilder=\(flaggedFrames)")
        XCTAssertEqual(flaggedFrames, 0, "Wolkenbild mit sichtbarer unbedeckter Karte (Rechteck) in \(flaggedFrames) Bildern")
    }
}
