import XCTest

/// "Maximale Vergangenheit = 6 Stunden" must bound the time slider of EVERY layer, by touching the track AND by dragging, also after a
/// layer change and after an app restart (field report of build 53: "teils kann ich in Karten sehr lange zurueck gehen, obwohl ich nur
/// 6 h ausgewaehlt habe"). The forecast (the part right of "now") is not limited.
///
/// Real backend, no stub, read-only: the app talks to the production default (`https://showers.linolaske.de/v1`), so the numbers move
/// with the server stock. The anchor "now" of every layer is NOT read from the slider label: the test fetches the layer's manifest itself
/// (GET only, `latest.json`) and takes the slot the app uses as "now" (observation: newest slot not after `reference_time`; model:
/// last slot, `past_slots` included, not after the clock). Hours back = anchor minus oldest reachable slot, tolerance unchanged (6.01).
/// What the layer switch selected is checked and printed separately (`PWLIMIT start ...`): it must be the anchor slot, not a forecast slot.
/// A layer switch is verified through the layer button's value; a switch that did not happen is reported as such, never measured. Runs only with `TEST_RUNNER_PWLIMIT_PROD=1`. Optional: `TEST_RUNNER_PWLIMIT_LAYERS=radar,welt,...`.
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

    /// `manifest`: path below `/v1/` of the layer's `latest.json`; `spoken`: part of the layer button's value once the layer is active
    /// (`RadarLayer.spokenName`; the German radar is exactly "Regenradar").
    private let layers: [(key: String, pick: Pick, manifest: String, spoken: String)] = [
        ("radar", .radar, "radar", "Regenradar"), ("europa", .rain("Europa (OPERA)"), "layers/radar_eu", "Europa"),
        ("welt", .rain("Welt (NOAA)"), "layers/radar_world", "Welt"), ("blitze", .entry(group: nil, "Blitze"), "layers/lightning", "Blitze"),
        ("wolken", .entry(group: nil, "Wolken"), "layers/clouds", "Wolken"), ("sonne", .entry(group: nil, "Sonne"), "layers/cloudmask", "Sonne"),
        ("temperatur", .entry(group: nil, "Temperatur"), "layers/temperature", "Temperatur"),
        ("taupunkt", .entry(group: "Feuchtigkeit", "Taupunkt"), "layers/dewpoint", "Taupunkt"),
        ("feuchte", .entry(group: "Feuchtigkeit", "Relativ"), "layers/humidity", "Relative Feuchte"),
        ("luftdruck", .entry(group: "Luftdruck", "Deutschland"), "layers/pressure", "Luftdruck"),
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

    // MARK: Independent anchor from the production manifest (GET only)

    private final class Box: @unchecked Sendable { var data: Data?; var status = 0 }

    /// `https://showers.linolaske.de/v1/<path>/latest.json`, read-only GET; `nil` if it cannot be read.
    private func fetchManifest(_ path: String) -> [String: Any]? {
        guard let url = URL(string: "https://showers.linolaske.de/v1/\(path)/latest.json") else { return nil }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.httpMethod = "GET"
        let box = Box(), done = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: request) { data, response, _ in
            box.data = data; box.status = (response as? HTTPURLResponse)?.statusCode ?? 0
            done.signal()
        }.resume()
        guard done.wait(timeout: .now() + 25) == .success, box.status == 200, let data = box.data else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    /// The slot the app treats as "now" and the grid step: observation layers and the German radar: newest slot not after `reference_time`;
    /// model layers: last slot (`past_slots` and `slots`) not after `now` (`RadarLayer.nowSlotTime`).
    private func anchor(path: String, now: Date = Date()) -> (time: Date, step: TimeInterval, kind: String)? {
        guard let object = fetchManifest(path) else { return nil }
        let iso = ISO8601DateFormatter()
        func time(_ item: Any) -> Date? { ((item as? [String: Any])?["time"] as? String).flatMap(iso.date(from:)) }
        let times = (((object["past_slots"] as? [Any]) ?? []) + ((object["slots"] as? [Any]) ?? [])).compactMap(time).sorted()
        let kind = path == "radar" ? "observation" : ((object["kind"] as? String) ?? "")
        let step = Double((object["step_minutes"] as? Int) ?? 5) * 60
        if kind == "observation" {
            guard let reference = (object["reference_time"] as? String).flatMap(iso.date(from:)) else { return nil }
            return (times.last(where: { $0 <= reference }) ?? reference, step, kind)
        }
        guard let slot = times.last(where: { $0 <= now }) ?? times.first else { return nil }
        return (slot, step, kind)
    }

    /// The label's date, the day-less form meaning the anchor's day (the app names the day only when it is not the timeline's reference day).
    private func date(of label: String, anchor: Date) -> Date? { Self.date(of: label, reference: anchor) }

    /// Selects the layer and VERIFIES the switch through the layer button's value (retries; the native menu sometimes swallows a tap).
    /// `true`: the layer is active; `false`: it cannot be selected (not offered or greyed out); `nil`: the entry was tapped but the layer did not change.
    private func selectVerified(_ app: XCUIApplication, key: String, pick: Pick, spoken: String) -> Bool? {
        let menu = app.buttons["radar-layer-menu"]
        func active() -> Bool {
            let value = (menu.value as? String) ?? ""
            return key == "radar" ? value == "Regenradar" : value.contains(spoken)
        }
        for _ in 0..<3 {
            if active() { sleep(2); return true }
            guard select(app, pick) else { return false }
            let end = Date().addingTimeInterval(8)
            while Date() < end && !active() { usleep(300_000) }
            if active() { sleep(2); return true }
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5)).tap()   // close a menu that stayed open
            sleep(1)
        }
        return nil
    }

    // MARK: The measurement

    /// One layer: switch (verified), the slot the switch selected, oldest by touching the track, oldest by dragging; both against the
    /// anchor taken from the manifest. Forecast not measured.
    private func measure(_ app: XCUIApplication, item: (key: String, pick: Pick, manifest: String, spoken: String), phase: String) {
        let key = item.key
        let selected = selectVerified(app, key: key, pick: item.pick, spoken: item.spoken)
        guard selected == true else {
            let button = (app.buttons["radar-layer-menu"].value as? String) ?? "?"
            if selected == nil {
                XCTFail("\(phase) \(key): the layer switch did not happen (layer button: \(button)), nothing measured")
                print("PWLIMIT phase=\(phase) layer=\(key) WECHSEL NICHT ERFOLGT (button=\(button)), nicht gemessen")
            } else {
                print("PWLIMIT phase=\(phase) layer=\(key) nicht waehlbar (nicht angeboten oder ausgegraut)")
            }
            return
        }
        let slider = slider(app)
        sleep(1)
        let now = value(slider)   // the slot the switch selected
        guard let reference = anchor(path: item.manifest) else {
            XCTFail("\(phase) \(key): manifest \(item.manifest) not readable (production, GET)")
            return
        }
        let iso = ISO8601DateFormatter()
        // Selection start (own check): the switch must open at the anchor slot ("now"), never at a forecast slot.
        let startDate = date(of: now, anchor: reference.time)
        let startIsForecast = now.localizedCaseInsensitiveContains("vorhersage")
        let startOffset = startDate.map { $0.timeIntervalSince(reference.time) / 60 }
        print("PWLIMIT start phase=\(phase) layer=\(key) label=[\(now)] zeit=\(startDate.map { iso.string(from: $0) } ?? "?") vorhersage=\(startIsForecast ? "ja" : "nein") anker=\(iso.string(from: reference.time)) abweichung_min=\(startOffset.map { String(format: "%.0f", $0) } ?? "?")")
        // Observation layers: two grid steps (the app polls every few minutes); model layers: the exact slot (a minute of rounding).
        let startTolerance = reference.kind == "observation" ? 2 * reference.step / 60 : 1.0
        XCTAssertFalse(startIsForecast, "\(phase) \(key): the layer switch selected a FORECAST slot: \(now)")
        if let startOffset { XCTAssertLessThanOrEqual(abs(startOffset), startTolerance, "\(phase) \(key): the layer switch did not open at now (anchor \(iso.string(from: reference.time))): \(now)") }
        else { XCTFail("\(phase) \(key): start label not readable: \(now)") }
        jump(slider, fraction: 1)
        jump(slider, fraction: 1)
        jump(slider, fraction: 0)
        let touched = value(slider)
        shot(app, "\(phase)-\(key)-aeltester-tippen")
        dragToOldest(slider)
        let dragged = value(slider)
        shot(app, "\(phase)-\(key)-aeltester-ziehen")
        // Anchor for the hours: the manifest's slot. Only when the app opened a little BEHIND it (it polls every few minutes, so a newer
        // slot may exist that it has not fetched yet; at most two grid steps, start checked above) the slot it opened at is the anchor.
        var hoursAnchor = reference.time
        if let startDate, let startOffset, startOffset < 0, reference.kind == "observation", abs(startOffset) <= startTolerance { hoursAnchor = startDate }
        func back(_ label: String) -> Double? { date(of: label, anchor: reference.time).map { hoursAnchor.timeIntervalSince($0) / 3600 } }
        let touchHours = back(touched), dragHours = back(dragged)
        let labelHours = hours(from: touched, to: now)   // old way (slider label as anchor), for comparison only
        func f(_ x: Double?) -> String { x.map { String(format: "%.2f", $0) } ?? "?" }
        print("PWLIMIT phase=\(phase) layer=\(key) auswahl=6h anker=\(iso.string(from: hoursAnchor)) anker_manifest=\(iso.string(from: reference.time)) jetzt=[\(now)] aeltester_tippen=[\(touched)] stunden=\(f(touchHours)) aeltester_ziehen=[\(dragged)] stunden=\(f(dragHours)) stunden_anzeige=\(f(labelHours))")
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
        for item in layers where only?.contains(item.key) ?? true { measure(app, item: item, phase: "sitzung") }
        app.terminate()

        app = launch()
        for item in layers where only?.contains(item.key) ?? true { measure(app, item: item, phase: "neustart") }
        app.terminate()
    }
}
