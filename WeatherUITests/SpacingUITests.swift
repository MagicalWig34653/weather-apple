import XCTest

/// Spacing assertions on the map screen (card D5875BAA, feedback on the Build 56 screenshots: "a bit of spacing problems").
/// Measured on frames of the accessibility tree and on the screenshot, light and dark (`SPACING_APPEARANCE=dark`), never by eye.
/// `SpacingAuditUITests` records the measurements behind these tests.
@MainActor
final class SpacingUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .portrait
    }

    private var dark: Bool { ProcessInfo.processInfo.environment["SPACING_APPEARANCE"] == "dark" }
    private var outDir: String { ProcessInfo.processInfo.environment["SPACING_OUT"] ?? "/private/tmp/claude-501/spacing-shots" }

    private func launch(category: String, extra: [String]) -> XCUIApplication {
        let args = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategory\(category)"] + extra
        let app = UITestLaunch.app(extra: UITestLaunch.setAppearance(dark ? .dark : .light, extra: args))
        app.launch()
        XCTAssertTrue(app.buttons["radar-legend-toggle"].waitForExistence(timeout: 30), "map did not appear")
        _ = app.sliders.firstMatch.waitForExistence(timeout: 30)
        sleep(3)
        return app
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
        let tag = "\(name)-\(dark ? "dark" : "light")"
        try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: outDir).appendingPathComponent("\(tag).png"))
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement { app.descendants(matching: .any).matching(identifier: id).firstMatch }

    // MARK: Time pill at the accessibility sizes: content centred, same side margin as the slider card

    /// Vertical centre of the dark/bright text ink in the middle 40 % of `frame` (points) minus the frame's centre, measured on the
    /// screenshot (the pill hides its children from the accessibility tree). `nil` if there is no ink.
    private func inkOffset(_ screenshot: XCUIScreenshot, frame: CGRect, screenWidth: CGFloat) -> CGFloat? {
        guard let cg = screenshot.image.cgImage else { return nil }
        let scale = CGFloat(cg.width) / screenWidth
        let x0 = Int((frame.minX + frame.width * 0.3) * scale), x1 = Int((frame.minX + frame.width * 0.7) * scale)
        let y0 = Int((frame.minY + 12) * scale), y1 = Int((frame.maxY - 12) * scale)
        guard x1 > x0, y1 > y0 else { return nil }
        var pixels = [UInt8](repeating: 0, count: cg.width * cg.height * 4)
        guard let context = CGContext(data: &pixels, width: cg.width, height: cg.height, bitsPerComponent: 8, bytesPerRow: cg.width * 4,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
        func luminance(_ x: Int, _ y: Int) -> Double {
            let i = (y * cg.width + x) * 4
            return (0.2126 * Double(pixels[i]) + 0.7152 * Double(pixels[i + 1]) + 0.0722 * Double(pixels[i + 2])) / 255
        }
        var samples: [Double] = []
        for y in stride(from: y0, to: y1, by: 3) { for x in stride(from: x0, to: x1, by: 3) { samples.append(luminance(x, y)) } }
        let background = samples.sorted()[samples.count / 2]
        var top = Int.max, bottom = -1
        for y in y0..<y1 { for x in x0..<x1 where abs(luminance(x, y) - background) > 0.35 { top = min(top, y); bottom = max(bottom, y) } }
        guard bottom >= 0 else { return nil }
        return (CGFloat(top + bottom) / 2 / scale) - frame.midY
    }

    private func timePill(category: String, _ context: String) {
        let app = launch(category: category, extra: ["-UITestForecast", "current", "-UITestRadar", "fixture"])
        defer { app.terminate() }
        let pill = app.buttons["radar-frame-label"]
        XCTAssertTrue(pill.waitForExistence(timeout: 20), "\(context): time pill missing")
        let screenshot = app.screenshot()
        shot(app, "zeitpille-\(context)")
        let frame = pill.frame, screen = app.frame
        let offset = inkOffset(screenshot, frame: frame, screenWidth: screen.width)
        print("SPACING_TIMEPILL \(context) frame=\(frame) inkOffset=\(offset.map { "\($0)" } ?? "nil") marginL=\(frame.minX) marginR=\(screen.width - frame.maxX)")
        if let offset { XCTAssertLessThanOrEqual(abs(offset), 6, "\(context): the time sits \(offset) pt off the pill's vertical centre (pill \(frame))") }
        else { XCTFail("\(context): no text found in the time pill") }
        XCTAssertGreaterThanOrEqual(frame.minX, 11.5, "\(context): time pill \(frame.minX) pt from the left edge (slider card: 12)")
        XCTAssertGreaterThanOrEqual(screen.width - frame.maxX, 11.5, "\(context): time pill \(screen.width - frame.maxX) pt from the right edge")
    }

    func testTimePillStandardSize() { timePill(category: "L", "L") }
    func testTimePillAccessibilityXXXL() { timePill(category: "AccessibilityXXXL", "AXXXL") }
    func testTimePillAccessibilityM() { timePill(category: "AccessibilityM", "AXM") }

    // MARK: Header at the accessibility sizes: same leading edge as the cards below

    /// At the accessibility sizes the place capsule and the layer menu are stacked. The stack was centred in the screen (left edge 48 pt on a
    /// 402 pt wide iPhone, 264 pt on an iPad) while the forecast pill and the notes below start at 16 pt: three different left edges.
    private func headerAlignment(category: String, stacked: Bool, _ context: String) {
        let app = launch(category: category, extra: ["-UITestForecast", "current", "-UITestRadar", "fixture"])
        defer { app.terminate() }
        let place = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Ort auswählen:")).firstMatch
        let menu = app.buttons["radar-layer-menu"], pill = app.buttons["forecast-details"]
        XCTAssertTrue(place.waitForExistence(timeout: 20) && menu.exists && pill.exists, "\(context): header controls missing")
        shot(app, "kopfzeile-\(context)")
        print("SPACING_HEADER \(context) place=\(place.frame) menu=\(menu.frame) pill=\(pill.frame)")
        XCTAssertEqual(place.frame.minX, pill.frame.minX, accuracy: 1, "\(context): place capsule starts at \(place.frame.minX), the forecast pill at \(pill.frame.minX)")
        // Standard sizes: the layer menu sits at the right of the place capsule (not stacked below it).
        if stacked { XCTAssertEqual(menu.frame.minX, pill.frame.minX, accuracy: 1, "\(context): layer menu starts at \(menu.frame.minX), the forecast pill at \(pill.frame.minX)") }
    }

    func testHeaderLeadingEdgeStandardSize() { headerAlignment(category: "L", stacked: false, "L") }
    func testHeaderLeadingEdgeAccessibilityM() { headerAlignment(category: "AccessibilityM", stacked: true, "AXM") }
    func testHeaderLeadingEdgeAccessibilityXXXL() { headerAlignment(category: "AccessibilityXXXL", stacked: true, "AXXXL") }

    // MARK: Forecast pill: inner padding with two lines, fixed height with one line (decision 22.11.2026, card D5875BAA)

    /// The pill keeps 48 pt with ONE text line (the loading bar's "no height change" promise); with TWO lines it grows by 8 pt of
    /// padding above and below the text instead of letting the text touch the edge (it had 5 pt at L, 0 at AXXXL).
    private func pillPadding(category: String, forecast: String, singleLine: Bool?, _ context: String) {
        let app = launch(category: category, extra: ["-UITestForecast", forecast, "-UITestRadar", "fixture", "-UITestResetForecast", "-radarPastHours", "2"])   // 2 = default: a choice stored by an earlier test must not add the short-history note
        defer { app.terminate() }
        let pill = app.buttons["forecast-details"]
        XCTAssertTrue(pill.waitForExistence(timeout: 20), "\(context): forecast pill missing")
        if forecast == "failed" { sleep(10) }
        let text = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'forecast-' AND identifier != 'forecast-details' AND identifier != 'forecast-refresh-spinner'")).firstMatch
        XCTAssertTrue(text.waitForExistence(timeout: 10), "\(context): forecast text missing")
        shot(app, "prognose-pille-\(context)")
        let p = pill.frame, t = text.frame
        let above = t.minY - p.minY, below = p.maxY - t.maxY
        print("SPACING_PILL \(context) pill=\(p) text=\(t) above=\(above) below=\(below)")
        if let singleLine {
            // 20 pt lines at L; a second line adds at least 15 pt.
            XCTAssertEqual(t.height < 30, singleLine, "\(context): text height \(t.height) does not have the expected line count")
            if singleLine { XCTAssertEqual(p.height, 48, accuracy: 0.5, "\(context): one-line pill must stay 48 pt, is \(p.height)") }
        }
        XCTAssertGreaterThanOrEqual(above, 7.5, "\(context): only \(above) pt above the text (pill \(p), text \(t))")
        XCTAssertGreaterThanOrEqual(below, 7.5, "\(context): only \(below) pt below the text (pill \(p), text \(t))")
    }

    func testPillOneLineStaysFixedHeightStandardSize() { pillPadding(category: "L", forecast: "current", singleLine: true, "L-einzeilig") }
    /// Build 57 text decision (23.11.2026, "Option 3"): the status "server behind" shows the short text "Noch kein neuerer Stand", ONE line at L
    /// (measured 18 pt text, 48 pt pill, 15 pt above and below), so the 54 pt two-line state at L no longer exists. The two-line rule itself
    /// (a two-line text grows the pill, 8 pt padding) is still checked where two-line text exists: the accessibility sizes below
    /// (AXXXL: 117 pt of text, pill 133 pt). Here: at L the pill stays one line and 48 pt, with at least 7.5 pt of air.
    func testPillServerBehindIsOneLineAtStandardSize() { pillPadding(category: "L", forecast: "behind", singleLine: true, "L-behind-einzeilig") }
    func testPillServerBehindKeepsPaddingXXL() { pillPadding(category: "XXL", forecast: "behind", singleLine: nil, "XXL-behind") }
    func testPillTwoLinesHaveInnerPaddingAccessibilityM() { pillPadding(category: "AccessibilityM", forecast: "behind", singleLine: nil, "AXM-zweizeilig") }
    func testPillMultiLineHasInnerPaddingAccessibilityL() { pillPadding(category: "AccessibilityL", forecast: "behind", singleLine: nil, "AXL-mehrzeilig") }
    func testPillMultiLineHasInnerPaddingAccessibilityXXL() { pillPadding(category: "AccessibilityXXL", forecast: "behind", singleLine: nil, "AXXL-mehrzeilig") }
    func testPillTwoLinesHaveInnerPaddingAccessibilityXXXL() { pillPadding(category: "AccessibilityXXXL", forecast: "behind", singleLine: nil, "AXXXL-zweizeilig") }

    // MARK: Top block at the accessibility sizes: controls stay on screen and do not overlap

    private func columnButtons(_ app: XCUIApplication) -> [(name: String, frame: CGRect)] {
        ["Aktuellen Standort verwenden", "Datenquellen und Datenschutz"].compactMap { label in
            let b = app.buttons[label]; return b.exists ? (label, b.frame) : nil
        } + ["radar-legend-toggle", "radar-warnings-button", "radar-read-center"].compactMap { id in
            let b = app.buttons[id]; return b.exists ? (id, b.frame) : nil
        }
    }

    /// Frames of the controls below the top block: slider card, play pill and the button column. Nothing outside the screen, no overlap
    /// of the column with the pill, hit areas at least 44 pt.
    private func assertControlsVisibleAndApart(_ app: XCUIApplication, _ context: String) {
        let screen = app.frame
        let pill = app.buttons["radar-frame-label"], slider = app.sliders.firstMatch
        XCTAssertTrue(pill.exists && slider.exists, "\(context): time pill or slider missing")
        let place = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Ort auswählen:")).firstMatch
        XCTAssertGreaterThanOrEqual(place.frame.minY, 0, "\(context): place capsule starts above the screen (\(place.frame))")
        XCTAssertLessThanOrEqual(slider.frame.maxY, screen.height + 0.5, "\(context): slider reaches below the screen (\(slider.frame))")
        XCTAssertLessThanOrEqual(pill.frame.maxY, slider.frame.minY + 0.5, "\(context): play pill \(pill.frame) overlaps the slider \(slider.frame)")
        let columns = columnButtons(app)
        XCTAssertGreaterThanOrEqual(columns.count, 3, "\(context): button column incomplete: \(columns.map(\.name))")
        for (name, f) in columns {
            XCTAssertGreaterThanOrEqual(f.minY, 0, "\(context): \(name) above the screen (\(f))")
            XCTAssertLessThanOrEqual(f.maxY, screen.height + 0.5, "\(context): \(name) outside the screen (\(f))")
            XCTAssertLessThanOrEqual(f.maxY, pill.frame.minY + 0.5, "\(context): \(name) \(f) overlaps the play pill \(pill.frame)")
            XCTAssertGreaterThanOrEqual(min(f.width, f.height), 44, "\(context): \(name) hit area \(f)")
        }
        let sorted = columns.map(\.frame).sorted { $0.minY < $1.minY }
        for (a, b) in zip(sorted, sorted.dropFirst()) { XCTAssertLessThanOrEqual(a.maxY, b.minY + 0.5, "\(context): column buttons overlap (\(a) / \(b))") }
    }

    /// Stub scenario of the hint stack (stub forecast `current`, stub history 72 h; NOT a real server): temperature layer at the oldest slot
    /// shows the gap note and "this map only reaches back N hours", plus warnings (fixture) in the button column.
    private func hintStackScene(category: String, legend: Bool, _ context: String) {
        let app = launch(category: category, extra: ["-UITestForecast", "current", "-UITestLayers", "all", "-UITestHistoryHours", "72", "-radarPastHours", "72",
                                                      "-UITestWarnings", "fixture"])
        defer { app.terminate() }
        let menu = app.buttons["radar-layer-menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 30), "\(context): layer menu missing")
        sleep(2)
        menu.tap()
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5)).tap()
        sleep(1)
        guard let entry = openLayerEntry(app, group: nil, entry: "Temperatur") else { return XCTFail("\(context): temperature layer not offered") }
        entry.tap()
        sleep(3)
        let slider = app.sliders.firstMatch
        XCTAssertTrue(slider.waitForExistence(timeout: 20), "\(context): slider missing")
        let width = Double(slider.frame.width)
        slider.coordinate(withNormalizedOffset: CGVector(dx: 20 / width, dy: 0.5)).press(forDuration: 0.05)
        sleep(3)
        let gap = element(app, "radar-gap-note"), short = element(app, "radar-history-short-note")
        let notes = [gap, short].filter { $0.exists }
        print("SPACING_HINTS \(context) gap=\(gap.exists) short=\(short.exists)")
        if legend {
            let toggle = app.buttons["radar-legend-toggle"]
            if toggle.exists { toggle.tap(); sleep(2) }
        }
        shot(app, "hinweisstapel\(legend ? "-legende" : "")-\(context)")
        assertControlsVisibleAndApart(app, context)
        // The notes are still reachable: inline (own frame, not behind the column) or in the forecast details sheet.
        if notes.isEmpty {
            app.buttons["forecast-details"].tap(); sleep(2)
            XCTAssertTrue(element(app, "radar-gap-note").waitForExistence(timeout: 5) && element(app, "radar-history-short-note").exists,
                          "\(context): notes neither on the map nor in the details sheet")
            shot(app, "hinweisstapel-blatt-\(context)")
        } else {
            let column = columnButtons(app).map(\.frame).min { $0.minY < $1.minY }
            let panel = legend ? element(app, "radar-legend") : nil
            for note in notes {
                let f = note.frame
                if let column, f.maxX > column.minX { XCTAssertLessThanOrEqual(f.maxY, column.minY + 0.5, "\(context): note \(f) overlaps the button column \(column)") }
                if let panel, panel.exists { XCTAssertTrue(f.intersection(panel.frame).isNull || f.intersection(panel.frame).height < 1, "\(context): note \(f) overlaps the legend \(panel.frame)") }
            }
        }
        if legend {
            let panel = element(app, "radar-legend")
            XCTAssertTrue(panel.exists, "\(context): legend missing")
            XCTAssertLessThanOrEqual(panel.frame.maxY, app.buttons["radar-frame-label"].frame.minY + 0.5, "\(context): legend \(panel.frame) reaches into the play pill")
            XCTAssertGreaterThanOrEqual(panel.frame.minY, app.buttons["forecast-details"].frame.maxY - 0.5, "\(context): legend \(panel.frame) covers the forecast pill")
        }
    }

    func testHintStackKeepsControlsVisibleAccessibilityXXXL() { hintStackScene(category: "AccessibilityXXXL", legend: false, "AXXXL") }
    func testHintStackKeepsControlsVisibleAccessibilityM() { hintStackScene(category: "AccessibilityM", legend: false, "AXM") }
    func testHintStackKeepsControlsVisibleXXXL() { hintStackScene(category: "XXXL", legend: false, "XXXL") }
    func testHintStackWithLegendAccessibilityXXXL() { hintStackScene(category: "AccessibilityXXXL", legend: true, "AXXXL") }

    // MARK: Official warnings sheet: defined inset between the header (filter, data state) and the list (card E6FF22E4, TestFlight 28.11.)

    /// The data state belongs to the header: 8 pt of header below it, then 12 pt list inset (the same as between two cards) before the
    /// first card ("Alle") or the first place title ("Meine Orte"). Before: 8 pt ("Alle": card on the header edge) and 16 pt.
    private func warningListInset(category: String, _ context: String) {
        let app = launch(category: category, extra: ["-UITestForecast", "current", "-UITestRadar", "fixture", "-UITestWarnings", "many", "-radarPastHours", "2"])
        defer { app.terminate() }
        for (segment, name, id) in [("Alle", "alle", "warning-row"), ("Meine Orte", "meine-orte", "warn-group-header")] {
            // Opened anew for each segment: the list keeps its scroll position across a segment switch.
            app.buttons["radar-warnings-button"].tap()
            let stand = app.staticTexts["warn-stand"]
            XCTAssertTrue(stand.waitForExistence(timeout: 10), "\(context) \(name): data state missing")
            app.buttons[segment].tap(); sleep(2)
            defer { app.buttons["Fertig"].tap(); sleep(2) }
            let first = element(app, id)
            XCTAssertTrue(first.waitForExistence(timeout: 5), "\(context) \(name): list is empty")
            shot(app, "warnungen-\(name)-oben-\(context)")
            // The "dark" evidence must really be dark (a fresh simulator can stay light despite the launch settings).
            if dark { XCTAssertLessThan(UITestLaunch.meanLuminance(app.screenshot().image), 0.45, "\(context) \(name): dark run shows a light screen") }
            let before = stand.frame, gap = first.frame.minY - before.maxY
            print("SPACING_WARNINGS \(context) \(name) stand=\(before) first=\(first.frame) gap=\(gap)")
            XCTAssertEqual(gap, 20, accuracy: 1, "\(context) \(name): \(gap) pt between the data state and the first list element (header 8 + list inset 12)")
            // Scrolled: the list moves, the header with the data state stays.
            let row = element(app, "warning-row"), rowTop = row.frame.minY
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)), withVelocity: .slow, thenHoldForDuration: 0.3)
            sleep(2)
            shot(app, "warnungen-\(name)-gescrollt-\(context)")
            XCTAssertTrue(!row.exists || row.frame.minY < rowTop - 50, "\(context) \(name): list did not scroll")
            XCTAssertEqual(stand.frame.minY, before.minY, accuracy: 0.5, "\(context) \(name): the data state moved with the list")
        }
    }

    func testWarningListInsetStandardSize() { warningListInset(category: "L", "L") }
    func testWarningListInsetAccessibilityXXXL() { warningListInset(category: "AccessibilityXXXL", "AXXXL") }

    /// Rain radar legend (14 rows) at the largest size: between forecast pill and play pill, not over them.
    func testRadarLegendFitsBetweenPillsAccessibilityXXXL() {
        let app = launch(category: "AccessibilityXXXL", extra: ["-UITestForecast", "current", "-UITestRadar", "fixture", "-UITestWarnings", "fixture", "-radarPastHours", "2"])
        defer { app.terminate() }
        app.buttons["radar-legend-toggle"].tap(); sleep(2)
        shot(app, "radar-legende-AXXXL")
        let panel = element(app, "radar-legend")
        XCTAssertTrue(panel.exists, "legend missing")
        XCTAssertLessThanOrEqual(panel.frame.maxY, app.buttons["radar-frame-label"].frame.minY + 0.5, "legend \(panel.frame) reaches into the play pill \(app.buttons["radar-frame-label"].frame)")
        XCTAssertGreaterThanOrEqual(panel.frame.minY, app.buttons["forecast-details"].frame.maxY - 0.5, "legend \(panel.frame) covers the forecast pill \(app.buttons["forecast-details"].frame)")
        assertControlsVisibleAndApart(app, "radar-legende-AXXXL")
    }
}
