import XCTest

/// "Maximale Vergangenheit = 6 Stunden" must bound the time slider of EVERY layer, by touching the track AND by dragging, also after a
/// layer change and after an app restart (field report of build 53: "teils kann ich in Karten sehr lange zurueck gehen, obwohl ich nur
/// 6 h ausgewaehlt habe"). The forecast (the part right of "now") is not limited.
///
/// Real backend, no stub, read-only: the app talks to the production default (`https://showers.linolaske.de/v1`), so the numbers move
/// with the server stock. Runs only with `TEST_RUNNER_PWLIMIT_PROD=1`. Optional: `TEST_RUNNER_PWLIMIT_LAYERS=radar,welt,...`.
/// Result lines `PWLIMIT ...` go to the log; screenshots to `/private/tmp/claude-501/pw-shots`.
@MainActor
final class PastWindowLimitUITests: XCTestCase {
    private static let limitHours = 6.0
    private var suffix: String {
        ProcessInfo.processInfo.environment["SHOT_SUFFIX"] ?? (XCUIDevice.shared.appearance == .dark ? "dark" : "light")
    }

    private enum Pick {
        case radar, rain(String), entry(group: String?, String)
    }

    private let layers: [(key: String, pick: Pick)] = [
        ("radar", .radar), ("europa", .rain("Europa (OPERA)")), ("welt", .rain("Welt (NOAA)")), ("blitze", .entry(group: nil, "Blitze")),
        ("wolken", .entry(group: nil, "Wolken")), ("sonne", .entry(group: nil, "Sonne")), ("temperatur", .entry(group: nil, "Temperatur")),
        ("taupunkt", .entry(group: "Feuchtigkeit", "Taupunkt")), ("feuchte", .entry(group: "Feuchtigkeit", "Relativ")),
        ("luftdruck", .entry(group: "Luftdruck", "Deutschland")),
    ]

    override func setUpWithError() throws {
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .portrait
        guard ProcessInfo.processInfo.environment["PWLIMIT_PROD"] != nil else { throw XCTSkip("Nur mit TEST_RUNNER_PWLIMIT_PROD=1 (liest die Produktion, nur Ansicht)") }
    }

    // MARK: Helpers

    private func shot(_ app: XCUIApplication, _ name: String) {
        sleep(1)
        let dir = "/private/tmp/claude-501/pw-shots"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name)-\(suffix).png"))
    }

    private func launch(reset: Bool = false) -> XCUIApplication {
        let app = UITestLaunch.app(extra: UITestLaunch.setAppearance(suffix == "dark" ? .dark : .light, extra: []))
        app.launch()
        let menu = app.buttons["radar-layer-menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 40))
        sleep(6)
        menu.tap()   // layers are reported after the first probe
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5)).tap()
        sleep(1)
        return app
    }

    private func slider(_ app: XCUIApplication) -> XCUIElement {
        let slider = app.sliders.firstMatch
        XCTAssertTrue(slider.waitForExistence(timeout: 40), "time slider")
        return slider
    }

    private func value(_ slider: XCUIElement) -> String { (slider.value as? String) ?? "" }

    /// A touch on the track jumps there: 0 = oldest slot, 1 = newest.
    private func jump(_ slider: XCUIElement, fraction: Double) {
        let width = Double(slider.frame.width)
        let x = min(max((20 + fraction * (width - 40)) / width, 0.004), 0.996)
        slider.coordinate(withNormalizedOffset: CGVector(dx: x, dy: 0.5)).press(forDuration: 0.05)
        sleep(2)
    }

    /// Manual dragging: from the thumb at the right end over the whole track to the left end.
    private func dragToOldest(_ slider: XCUIElement) {
        slider.coordinate(withNormalizedOffset: CGVector(dx: 0.99, dy: 0.5)).press(forDuration: 0.05)   // thumb to the far end first
        slider.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: slider.coordinate(withNormalizedOffset: CGVector(dx: 0.0, dy: 0.5)))
        sleep(2)
    }

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

    /// Returns false if the layer is not selectable (not offered / greyed out).
    private func select(_ app: XCUIApplication, _ pick: Pick) -> Bool {
        switch pick {
        case .radar:
            if app.buttons["radar-layer-menu"].exists, app.sliders.firstMatch.exists, (value(app.sliders.firstMatch)).contains("Messung") { return true }
            return chooseRain(app, "Deutschland (DWD)")
        case .rain(let prefix): return chooseRain(app, prefix)
        case .entry(let group, let prefix):
            guard let entry = openLayerEntry(app, group: group, entry: prefix, attempts: 3), entry.isEnabled else { return false }
            entry.tap()
            sleep(3)
            return true
        }
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
        for _ in 0..<3 where app.sliders.firstMatch.isHittable == false {   // close the sheet
            app.swipeDown(velocity: .fast)
            sleep(1)
        }
    }

    // MARK: Reading the slider value as "hours before now"

    private static let months = ["jan", "feb", "mär", "apr", "mai", "jun", "jul", "aug", "sep", "okt", "nov", "dez"]

    /// "09:50, Messung" (the reference day) or "So. 15. Nov., 09:50, Messung" -> the date, relative to `reference` (its day, its year).
    static func date(of value: String, reference: Date) -> Date? {
        let pattern = #"^(?:\p{L}+\.,? (\d{1,2})\. (\p{L}{3})\p{L}*\.?, )?(\d{1,2}):(\d{2})"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)) else { return nil }
        func group(_ i: Int) -> String? { Range(match.range(at: i), in: value).map { String(value[$0]) } }
        let calendar = Calendar.current
        var parts = calendar.dateComponents([.year, .month, .day], from: reference)
        if let day = group(1).flatMap(Int.init), let month = group(2).flatMap({ months.firstIndex(of: $0.lowercased()) }) {
            if month + 1 > (parts.month ?? 1) { parts.year = (parts.year ?? 2026) - 1 }
            parts.day = day
            parts.month = month + 1
        }
        parts.hour = group(3).flatMap(Int.init)
        parts.minute = group(4).flatMap(Int.init)
        return calendar.date(from: parts)
    }

    private func hours(from older: String, to newer: String) -> Double? {
        let reference = Date()
        guard let a = Self.date(of: older, reference: reference), let b = Self.date(of: newer, reference: reference) else { return nil }
        return b.timeIntervalSince(a) / 3600
    }

    // MARK: The measurement

    /// One layer: value at now, oldest by touching the track, oldest by dragging; both must stay within the limit. Forecast not measured.
    private func measure(_ app: XCUIApplication, key: String, pick: Pick, phase: String) {
        guard select(app, pick) else {
            print("PWLIMIT phase=\(phase) layer=\(key) nicht waehlbar (nicht angeboten oder ausgegraut)")
            return
        }
        let slider = slider(app)
        sleep(3)
        let now = value(slider)
        jump(slider, fraction: 1)
        jump(slider, fraction: 1)
        // "Now" = the newest measurement / current model hour: where the slider opens. Model layers continue into the forecast to the right.
        jump(slider, fraction: 0)
        let touched = value(slider)
        shot(app, "\(phase)-\(key)-aeltester-tippen")
        dragToOldest(slider)
        let dragged = value(slider)
        shot(app, "\(phase)-\(key)-aeltester-ziehen")
        let touchHours = hours(from: touched, to: now), dragHours = hours(from: dragged, to: now)
        print("PWLIMIT phase=\(phase) layer=\(key) auswahl=6h jetzt=[\(now)] aeltester_tippen=[\(touched)] stunden=\(touchHours.map { String(format: "%.2f", $0) } ?? "?") aeltester_ziehen=[\(dragged)] stunden=\(dragHours.map { String(format: "%.2f", $0) } ?? "?")")
        let tolerance = 0.01
        if let touchHours { XCTAssertLessThanOrEqual(touchHours, Self.limitHours + tolerance, "\(phase) \(key): touching the track reaches \(touchHours) h back: \(touched)") }
        else { XCTFail("\(phase) \(key): value not readable: \(touched)") }
        if let dragHours { XCTAssertLessThanOrEqual(dragHours, Self.limitHours + tolerance, "\(phase) \(key): dragging reaches \(dragHours) h back: \(dragged)") }
        jump(slider, fraction: 1)
    }

    private func selectedKeys() -> Set<String>? {
        ProcessInfo.processInfo.environment["PWLIMIT_LAYERS"].map { Set($0.split(separator: ",").map(String.init)) }
    }

    /// Choose 6 h once, walk through the layers, then restart the app without any argument (the stored choice decides) and walk again.
    func testSixHoursBoundTheSliderOfEveryLayerAfterLayerChangeAndRestart() throws {
        let only = selectedKeys()
        var app = launch()
        chooseSixHours(app)
        for item in layers where only?.contains(item.key) ?? true { measure(app, key: item.key, pick: item.pick, phase: "sitzung") }
        app.terminate()

        app = launch()
        for item in layers where only?.contains(item.key) ?? true { measure(app, key: item.key, pick: item.pick, phase: "neustart") }
        app.terminate()
    }
}
