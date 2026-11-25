import XCTest

/// Contrast of the controls over a data field that colours the whole map brightly (temperature, clouds, dew point, humidity),
/// measured DIRECTLY in the screenshot at the pixels of each element (fixed stub images, frozen clock, no live data).
///
/// Method (documented in the nachweis): crop the screenshot to the element's frame; per pixel the WCAG relative luminance
/// (sRGB linearised); background = median luminance of the crop; foreground = mean luminance of the 3 % extreme pixels on the
/// side AWAY from the background (dark mode: the brightest pixels, white text and icons; light mode: the darkest pixels) or, for coloured controls (`deviation`), the 3 % that differ most. Contrast ratio = (L_light + 0.05) / (L_dark + 0.05).
/// Thresholds: 4.5 : 1 for text, 3 : 1 for controls (icons, slider track) and large text. Lines `CONTRAST ...` go to the log.
/// Set `TEST_RUNNER_CONTRAST_MEASURE=1` to only record (no assertion).
enum ContrastProbe {
    struct Result { let foreground: Double, background: Double, ratio: Double }

    private static func linear(_ value: UInt8) -> Double {
        let c = Double(value) / 255
        return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }

    /// `rect` in points of the screenshot's coordinate space (the image's `scale` converts to pixels).
    static func measure(_ image: UIImage, rect: CGRect, deviation: Bool = false, lightText: Bool) -> Result? {
        guard let cg = image.cgImage else { return nil }
        let scale = image.scale
        let pixelRect = CGRect(x: rect.minX * scale, y: rect.minY * scale, width: rect.width * scale, height: rect.height * scale)
            .integral.intersection(CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
        guard pixelRect.width >= 2, pixelRect.height >= 2, let crop = cg.cropping(to: pixelRect) else { return nil }
        let width = crop.width, height = crop.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.draw(crop, in: CGRect(x: 0, y: 0, width: width, height: height))
        var lum = [Double](); lum.reserveCapacity(width * height)
        for i in stride(from: 0, to: pixels.count, by: 4) {
            lum.append(0.2126 * linear(pixels[i]) + 0.7152 * linear(pixels[i + 1]) + 0.0722 * linear(pixels[i + 2]))
        }
        let sorted = lum.sorted()
        let median = sorted[sorted.count / 2]
        let count = max(1, lum.count * 3 / 100)
        let far: [Double]
        if deviation { far = Array(lum.sorted { abs($0 - median) > abs($1 - median) }.prefix(count)) }
        else if lightText { far = Array(sorted.suffix(count)) }
        else { far = Array(sorted.prefix(count)) }
        let foreground = far.reduce(0, +) / Double(far.count)
        let (light, dark) = (max(foreground, median), min(foreground, median))
        return Result(foreground: foreground, background: median, ratio: (light + 0.05) / (dark + 0.05))
    }
}

extension ContrastProbe {
    /// Median relative luminance of a rectangle (points of the screenshot's space).
    static func medianLuminance(_ image: UIImage, rect: CGRect) -> Double? {
        guard let cg = image.cgImage else { return nil }
        let scale = image.scale
        let pixelRect = CGRect(x: rect.minX * scale, y: rect.minY * scale, width: max(rect.width * scale, 1), height: max(rect.height * scale, 1))
            .integral.intersection(CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
        guard pixelRect.width >= 1, pixelRect.height >= 1, let crop = cg.cropping(to: pixelRect) else { return nil }
        let width = crop.width, height = crop.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.draw(crop, in: CGRect(x: 0, y: 0, width: width, height: height))
        func linear(_ value: UInt8) -> Double { let c = Double(value) / 255; return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        var lum = [Double]()
        for i in stride(from: 0, to: pixels.count, by: 4) { lum.append(0.2126 * linear(pixels[i]) + 0.7152 * linear(pixels[i + 1]) + 0.0722 * linear(pixels[i + 2])) }
        return lum.sorted()[lum.count / 2]
    }

    /// WCAG ratio between a thin line and the glass next to it: the line's own pixel band against a band of the same width `gap` points away.
    static func lineContrast(_ image: UIImage, line: CGRect, background: CGRect) -> Result? {
        guard let fg = medianLuminance(image, rect: line), let bg = medianLuminance(image, rect: background) else { return nil }
        return Result(foreground: fg, background: bg, ratio: (max(fg, bg) + 0.05) / (min(fg, bg) + 0.05))
    }
}

@MainActor
final class LayerContrastUITests: XCTestCase {
    private var suffix: String {
        ProcessInfo.processInfo.environment["SHOT_SUFFIX"] ?? (XCUIDevice.shared.appearance == .dark ? "dark" : "light")
    }
    private var measureOnly: Bool { ProcessInfo.processInfo.environment["CONTRAST_MEASURE"] != nil }

    override func setUpWithError() throws {
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .portrait
    }

    private struct Element {
        let name: String
        let identifier: String?
        let text: String?       // a static text inside (its own frame)
        let threshold: Double
        var deviation = false
    }

    private static let elements: [Element] = [
        Element(name: "Zeitstempel (Pille)", identifier: "radar-frame-label", text: nil, threshold: 4.5),
        Element(name: "Menükapsel Ebene (Text)", identifier: nil, text: "TITLE", threshold: 4.5),
        Element(name: "Ort: Name (Text)", identifier: nil, text: "Berlin", threshold: 4.5),
        Element(name: "Ort: Untertitel (Text)", identifier: nil, text: "Regenradar", threshold: 4.5),
        Element(name: "Regenleiste am Ort (Text)", identifier: nil, text: "Regen am ausgewählten Ort", threshold: 4.5),
        Element(name: "Hinweiszeile Lücke (Text)", identifier: "radar-gap-note", text: nil, threshold: 4.5),
        Element(name: "Legendenzeile roter Strich (Text)", identifier: "radar-gap-legend", text: nil, threshold: 4.5),
        Element(name: "Credit-Zeile (Text)", identifier: "radar-attribution", text: nil, threshold: 4.5),
        Element(name: "Legendenschalter (Symbol)", identifier: "radar-legend-toggle", text: nil, threshold: 3.0),
        Element(name: "Warnungen-Knopf (Symbol)", identifier: "radar-warnings-button", text: nil, threshold: 3.0),
        Element(name: "Info-Knopf (Symbol)", identifier: "INFO", text: nil, threshold: 3.0),
        Element(name: "Regler: Spur (farbig)", identifier: "radar-timeline", text: nil, threshold: 3.0, deviation: true),
        Element(name: "Regler: Spur leer (Linie)", identifier: "radar-timeline", text: "TRACK", threshold: 3.0),
        Element(name: "Regler: Zeitlinie (Linie)", identifier: "radar-timeline", text: "TIMELINE", threshold: 3.0),
    ]

    private func jump(_ slider: XCUIElement, fraction: Double) {
        let width = Double(slider.frame.width)
        let x = min(max((20 + fraction * (width - 40)) / width, 0.004), 0.996)
        slider.coordinate(withNormalizedOffset: CGVector(dx: x, dy: 0.5)).press(forDuration: 0.05)
        usleep(500_000)
    }

    private func chooseRain(_ app: XCUIApplication, _ prefix: String) throws {
        let menu = app.buttons["radar-layer-menu"]
        let rain = app.buttons.matching(NSPredicate(format: "label == %@", "Regen")).firstMatch
        let entry = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
        for _ in 0..<4 {
            menu.tap()
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

    /// One layer in the current appearance: every element measured on the same screenshot. The oldest slot of the 72 h history is
    /// shown so that the hole note ("Davor fehlen Daten") exists wherever the source reaches back less far.
    private func measureLayer(_ name: String, group: String?, entry prefix: String?) throws {
        let app = UITestLaunch.app(extra: UITestLaunch.setAppearance(suffix == "dark" ? .dark : .light, extra: [
            "-UITestForecast", "current", "-UITestRadar", "fixture", "-UITestRadarHistoryHours", "72", "-UITestLayers", "all",
            "-UITestHistoryHours", "72", "-radarPastHours", "72"]))
        app.launch()
        let menu = app.buttons["radar-layer-menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 30))
        sleep(2)
        menu.tap()
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5)).tap()
        sleep(1)
        if let prefix, prefix.hasPrefix("RAIN|") {
            try chooseRain(app, String(prefix.dropFirst(5)))
        } else if let prefix {
            let entry = try XCTUnwrap(openLayerEntry(app, group: group, entry: prefix), "\(prefix) wählbar")
            entry.tap()
        }
        let slider = app.sliders.firstMatch
        XCTAssertTrue(slider.waitForExistence(timeout: 40))
        jump(slider, fraction: 0)
        sleep(4)
        let screenshot = app.screenshot()
        let dir = "/private/tmp/claude-501/hist-shots"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("contrast-\(name)-\(suffix).png"))
        for item in Self.elements {
            let query: XCUIElement
            if item.identifier == "INFO" { query = app.buttons["Datenquellen und Datenschutz"] }
            else if let id = item.identifier { query = app.descendants(matching: .any).matching(identifier: id).firstMatch }
            else if item.text == "TITLE" { query = app.buttons["radar-layer-menu"].staticTexts.firstMatch }
            else { query = app.staticTexts.matching(NSPredicate(format: "label == %@", item.text!)).firstMatch }
            let measured: ContrastProbe.Result?
            if item.text == "TRACK" || item.text == "TIMELINE" {
                // Thin lines of the slider card: the unfilled 4 pt track at the card's centre line, the 2 pt past/future line 7 pt below it;
                // measured on the right part (oldest slot: the thumb is at the left end), against glass 9 pt above (track) or 15 pt below (line).
                let card = query.frame
                let x = card.minX + card.width * 0.62, width = card.width * 0.2
                if item.text == "TRACK" {
                    measured = ContrastProbe.lineContrast(screenshot.image, line: CGRect(x: x, y: card.midY - 1, width: width, height: 2),
                                                          background: CGRect(x: x, y: card.midY - 10, width: width, height: 2))
                } else {
                    measured = ContrastProbe.lineContrast(screenshot.image, line: CGRect(x: x, y: card.midY + 6.5, width: width, height: 1),
                                                          background: CGRect(x: x, y: card.midY + 14, width: width, height: 2))
                }
            } else if query.exists {
                measured = ContrastProbe.measure(screenshot.image, rect: query.frame, deviation: item.deviation, lightText: suffix == "dark")
            } else { measured = nil }
            guard query.exists, let result = measured else {
                print("CONTRAST \(name) | \(item.name) | nicht vorhanden")
                continue
            }
            let pass = result.ratio >= item.threshold
            print(String(format: "CONTRAST %@ | %@ | fg=%.3f bg=%.3f ratio=%.2f schwelle=%.1f %@", name, item.name, result.foreground, result.background,
                         result.ratio, item.threshold, pass ? "ok" : "UNTER"))
            if !measureOnly { XCTAssertGreaterThanOrEqual(result.ratio, item.threshold, "\(name): \(item.name) \(suffix)") }
        }
        app.terminate()
    }

    /// The surface: the German radar of the frozen fixture (a few rain cells), no data layer chosen.
    func testContrastRadarGermany() throws { try measureLayer("radar-de", group: nil, entry: nil) }
    func testContrastEurope() throws { try measureLayer("europa", group: nil, entry: "RAIN|Europa (OPERA)") }
    func testContrastWorld() throws { try measureLayer("welt", group: nil, entry: "RAIN|Welt (NOAA)") }
    func testContrastLightning() throws { try measureLayer("blitze", group: nil, entry: "Blitze") }
    func testContrastPressure() throws { try measureLayer("luftdruck", group: "Luftdruck", entry: "Deutschland") }
    func testContrastTemperature() throws { try measureLayer("temperatur", group: nil, entry: "Temperatur") }
    func testContrastClouds() throws { try measureLayer("wolken", group: nil, entry: "Wolken") }
    func testContrastDewpoint() throws { try measureLayer("taupunkt", group: "Feuchtigkeit", entry: "Taupunkt") }
    func testContrastHumidity() throws { try measureLayer("feuchte", group: "Feuchtigkeit", entry: "Relativ") }
}
