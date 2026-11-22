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
}
