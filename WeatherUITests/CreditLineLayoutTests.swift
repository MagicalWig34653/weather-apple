import XCTest

/// Quellzeile unter dem Zeit-Slider: Lage (y) des Sliders und der Zeile, hell/dunkel, Wald an (lange Zeile), große Schrift.
/// Hängt Bilder und die Messwerte (Rahmen in Punkten) als Anhänge an. Die Zeile liegt, wo unter dem Slider Platz ist
/// (Geräte mit Home-Indikator), darunter; Geräte ohne Streifen darunter behalten sie über dem Slider.
@MainActor
final class CreditLineLayoutTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .portrait
    }

    override func tearDown() async throws { XCUIDevice.shared.appearance = .light }

    private func note(_ name: String, _ text: String) {
        let a = XCTAttachment(string: text)
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        sleep(1)
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    private func f(_ r: CGRect) -> String { String(format: "minY=%.1f maxY=%.1f height=%.1f minX=%.1f maxX=%.1f width=%.1f", r.minY, r.maxY, r.height, r.minX, r.maxX, r.width) }

    private func measure(_ app: XCUIApplication, tag: String, expectBelow: Bool) {
        let window = app.windows.firstMatch.frame
        let slider = app.sliders["radar-timeline"]
        let credit = app.staticTexts["radar-attribution"]
        XCTAssertTrue(slider.waitForExistence(timeout: 10))
        XCTAssertTrue(credit.waitForExistence(timeout: 10))
        let strip = window.maxY - slider.frame.maxY
        let pill = app.descendants(matching: .any)["radar-frame-label"]
        // Apples legal link ("Rechtl. Informationen"): its frame if the accessibility tree has it.
        let legal = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] 'Rechtl' OR label CONTAINS[c] 'Legal'")).firstMatch
        let legalText = legal.exists ? f(legal.frame) : "nicht im Accessibility-Baum"
        note("zahlen-\(tag)", "window \(f(window))\nslider \(f(slider.frame))\npill \(f(pill.frame))\ncredit \(f(credit.frame)) label=\(credit.label)\nrechtslink \(legalText)\nstreifen unter slider=\(String(format: "%.1f", strip))")
        // Baseline vor dem Umbau (18.11., 440x956): Pille y 794.7 bis 838.7 (normal), 701.0 bis 831.7 (AXXXL).
        let pillBaseline = ["440x956": 794.7]["\(Int(window.width))x\(Int(window.height))"]
        if let pillBaseline, !tag.hasSuffix("axxxl") { XCTAssertEqual(pill.frame.minY, pillBaseline, accuracy: 0.5, "Pille-y unverändert (\(tag))") }
        if tag.hasSuffix("axxxl"), Int(window.width) == 440 { XCTAssertEqual(pill.frame.minY, 701.0, accuracy: 0.5, "Pille-y unverändert (\(tag))") }
        // Der Rechtslink bleibt frei: höchstens die gerundete Pillenecke berührt seinen Rahmen (wie in der Baseline, 5 pt).
        if legal.exists { XCTAssertLessThanOrEqual(pill.frame.maxY - legal.frame.minY, 6, "Pille verdeckt den Rechtslink nicht (\(tag))") }
        // Der Slider behält seine Lage: gemessen vor dem Umbau (18.11.): 440x956 -> y 870, 375x667 -> y 615.
        let baseline = ["440x956": 870.0, "375x667": 615.0]["\(Int(window.width))x\(Int(window.height))"]
        if let baseline { XCTAssertEqual(slider.frame.minY, baseline, accuracy: 0.5, "Slider-y unverändert (\(tag))") }
        XCTAssertGreaterThanOrEqual(credit.frame.minX, window.minX, "Zeile links nicht abgeschnitten (\(tag))")
        XCTAssertLessThanOrEqual(credit.frame.maxX, window.maxX, "Zeile rechts nicht abgeschnitten (\(tag))")
        if expectBelow, strip >= 20 {
            XCTAssertGreaterThanOrEqual(credit.frame.minY, slider.frame.maxY - 1, "Quellzeile liegt unter dem Slider (\(tag))")
            XCTAssertLessThanOrEqual(credit.frame.maxY, window.maxY - 12, "Quellzeile über dem Home-Indikator (\(tag))")
        }
    }

    private func run(_ appearance: XCUIDevice.Appearance, _ suffix: String, expectBelow: Bool) throws {
        XCUIDevice.shared.appearance = appearance
        let app = UITestLaunch.app(language: .german, extra: ["-UITestLayers", "all"])
        app.launch()
        XCTAssertTrue(app.buttons["radar-layer-menu"].waitForExistence(timeout: 20))
        sleep(3)
        let size = app.windows.firstMatch.frame.size
        let device = "\(Int(size.width))x\(Int(size.height))"
        shot(app, "\(device)-\(suffix)-standard")
        measure(app, tag: "\(device)-\(suffix)-standard", expectBelow: expectBelow)
        // Lange Zeile: Temperatur mit Wald.
        let temperature = try XCTUnwrap(openLayerEntry(app, group: nil, entry: "Temperatur"))
        temperature.tap()
        XCTAssertTrue(app.sliders["Zeitpunkt Temperatur"].waitForExistence(timeout: 10))
        let legend = app.buttons["radar-legend-toggle"]
        XCTAssertTrue(legend.waitForExistence(timeout: 5))
        legend.tap()
        let toggle = app.switches["forest-toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        if toggle.value as? String != "1" { toggle.tap() }
        legend.tap()
        sleep(2)
        shot(app, "\(device)-\(suffix)-wald")
        measure(app, tag: "\(device)-\(suffix)-wald", expectBelow: expectBelow)
        XCTAssertEqual(app.staticTexts["radar-attribution"].label, "\u{00A9} DWD \u{00B7} \u{00A9} ESA WorldCover")
        // Wald wieder aus.
        legend.tap()
        if app.switches["forest-toggle"].waitForExistence(timeout: 5), app.switches["forest-toggle"].value as? String == "1" { app.switches["forest-toggle"].tap() }
        legend.tap()
    }

    func testLight() throws { try run(.light, "hell", expectBelow: true) }
    func testDark() throws { try run(.dark, "dunkel", expectBelow: true) }

    /// Größte Schrift: nichts abgeschnitten, Zeile nicht über Slider oder Home-Indikator.
    func testAccessibilitySize() throws {
        XCUIDevice.shared.appearance = .light
        let app = UITestLaunch.app(language: .german, extra: ["-UITestLayers", "all", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        app.launch()
        XCTAssertTrue(app.buttons["radar-layer-menu"].waitForExistence(timeout: 20))
        sleep(3)
        let size = app.windows.firstMatch.frame.size
        let device = "\(Int(size.width))x\(Int(size.height))"
        shot(app, "\(device)-axxxl")
        measure(app, tag: "\(device)-axxxl", expectBelow: true)
    }
}
