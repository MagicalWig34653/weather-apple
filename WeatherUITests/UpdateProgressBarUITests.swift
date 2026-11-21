import XCTest

/// Progress bar on the bottom edge of the forecast header (Debug stubs `-UITestForecast measured|delayed|slowbehind|slowfresh|slowfailed`).
/// These are STUB runs, not end-to-end against the real services. Image sequences go to
/// `UPDATE_PROGRESS_SHOTS` (environment, default `/private/tmp/claude-501/lb56-shots`), names carry light/dark.
@MainActor
final class UpdateProgressBarUITests: XCTestCase {
    private var suffix: String {
        ProcessInfo.processInfo.environment["SHOT_SUFFIX"] ?? (XCUIDevice.shared.appearance == .dark ? "dark" : "light")
    }
    private var shotDirectory: String {
        ProcessInfo.processInfo.environment["UPDATE_PROGRESS_SHOTS"] ?? "/private/tmp/claude-501/lb56-shots"
    }

    private func launch(_ mode: String, extra: [String] = []) -> XCUIApplication {
        let app = UITestLaunch.app(extra: UITestLaunch.setAppearance(suffix == "dark" ? .dark : .light,
                                                                     extra: ["-UITestForecast", mode, "-UITestRadar", "fixture", "-UITestResetForecast"] + extra))
        app.launch()
        return app
    }

    private func header(_ app: XCUIApplication) -> XCUIElement { app.buttons["forecast-details"] }
    private func bar(_ app: XCUIApplication) -> XCUIElement { app.descendants(matching: .any)["update-progress-bar"] }
    private func percent(_ app: XCUIApplication) -> XCUIElement { app.staticTexts["update-progress-percent"] }

    private func waitForForecast(_ header: XCUIElement) {
        let predicate = NSPredicate(format: "NOT (label CONTAINS[c] 'geladen') AND NOT (label CONTAINS[c] 'nicht verf')")
        XCTAssertEqual(XCTWaiter().wait(for: [expectation(for: predicate, evaluatedWith: header)], timeout: 60), .completed, header.label)
    }

    /// Returning to the app starts a load at once (the shown run is older than the expected one).
    private func startUpdate(_ app: XCUIApplication) {
        XCUIDevice.shared.press(.home)
        sleep(1)
        app.activate()
    }

    private func barValue(_ app: XCUIApplication, timeout: TimeInterval = 30) -> String? {
        let element = bar(app)
        if element.waitForExistence(timeout: timeout) { return element.value as? String }
        add(XCTAttachment(screenshot: app.screenshot()))   // no bar: keep the screen for the failure report
        return nil
    }

    /// The bar starts as `running` and turns `measured` as soon as the requests have reported their sizes: wait for that value.
    private func assertBarValue(_ app: XCUIApplication, _ expected: String, _ message: String = "", file: StaticString = #filePath, line: UInt = #line) {
        // The loop normally starts the stalled load itself 3 s after the first; if the app's loop did not (observed once under heavy
        // machine load: header ended on "server behind"), one return from the background restarts it.
        var appeared = barValue(app, timeout: 25)
        if appeared == nil { startUpdate(app); appeared = barValue(app, timeout: 60) }
        XCTAssertNotNil(appeared, "bar appears \(message)", file: file, line: line)
        let reached = NSPredicate(format: "value == %@", expected)
        XCTAssertEqual(XCTWaiter().wait(for: [expectation(for: reached, evaluatedWith: bar(app))], timeout: 15), .completed,
                       "bar value \(expected), is \(String(describing: bar(app).value)) \(message)", file: file, line: line)
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        try? FileManager.default.createDirectory(atPath: shotDirectory, withIntermediateDirectories: true)
        try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: shotDirectory).appendingPathComponent("\(name)-\(suffix == "dark" ? "dunkel" : "hell").png"))
    }

    /// The bar strip (bottom edge of the pill) as PNG bytes, to compare two moments.
    private func strip(_ app: XCUIApplication, of bar: XCUIElement) -> Data? {
        let image = app.screenshot().image
        let f = bar.frame, s = image.scale
        let rect = CGRect(x: f.minX * s, y: f.minY * s, width: f.width * s, height: f.height * s).integral
        return image.cgImage?.cropping(to: rect).flatMap { UIImage(cgImage: $0).pngData() }
    }

    /// Mean luminance (0...1) of 40 equal columns of the bar strip, from the screenshot (proves the bar is really DRAWN, not only in the accessibility tree).
    private func columnLuminance(_ app: XCUIApplication, of bar: XCUIElement) -> [Double] {
        let image = app.screenshot().image
        let f = bar.frame, s = image.scale
        let rect = CGRect(x: f.minX * s, y: f.minY * s, width: f.width * s, height: f.height * s).integral
        guard let cropped = image.cgImage?.cropping(to: rect) else { return [] }
        let columns = 40
        var pixels = [UInt8](repeating: 0, count: columns * 4)
        guard let context = CGContext(data: &pixels, width: columns, height: 1, bitsPerComponent: 8, bytesPerRow: columns * 4,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return [] }
        context.interpolationQuality = .medium
        context.draw(cropped, in: CGRect(x: 0, y: 0, width: columns, height: 1))
        return (0..<columns).map { (0.2126 * Double(pixels[$0 * 4]) + 0.7152 * Double(pixels[$0 * 4 + 1]) + 0.0722 * Double(pixels[$0 * 4 + 2])) / 255 }
    }

    private func assertDarkIfNeeded(_ app: XCUIApplication) {
        if suffix == "dark" { XCTAssertLessThan(UITestLaunch.meanLuminance(app.screenshot().image), 0.45, "dark screenshot expected") }
    }

    /// Bar over the WHOLE width of the bottom edge, same height of the pill as without the bar.
    private func assertBarGeometry(_ app: XCUIApplication, heightBefore: CGFloat, file: StaticString = #filePath, line: UInt = #line) {
        let h = header(app).frame, b = bar(app).frame
        XCTAssertEqual(b.minX, h.minX, accuracy: 1.5, "bar starts at the left edge", file: file, line: line)
        XCTAssertEqual(b.width, h.width, accuracy: 1.5, "bar spans the whole width", file: file, line: line)
        XCTAssertEqual(b.maxY, h.maxY, accuracy: 1.5, "bar on the bottom edge", file: file, line: line)
        XCTAssertEqual(h.height, heightBefore, accuracy: 0.5, "no height change of the hint", file: file, line: line)
    }

    // MARK: Measured progress (stub reports sizes)

    func testMeasuredBarShowsFillPercentOnTheRightAndKeepsHintText() throws {
        let app = launch("measured")
        let header = header(app)
        XCTAssertTrue(header.waitForExistence(timeout: 30))
        waitForForecast(header)
        let heightBefore = header.frame.height
        // No background trip: the stub's stalled point query is shared and would be joined (unmeasured) by a repeated load.
        // The loop starts the next load by itself 3 s after the first one (stub `measured` shortens the pause); the stub then stalls it for 90 s.
        XCTAssertEqual(barValue(app, timeout: 60), "measured:50", "fill = progress (100 + 100 of 100 + 300 bytes)")
        assertBarGeometry(app, heightBefore: heightBefore)
        // Drawn: the filled left half differs clearly from the unfilled right half (fill 50 %).
        let columns = columnLuminance(app, of: bar(app))
        let left = columns[6..<16].reduce(0, +) / 10, right = columns[24..<34].reduce(0, +) / 10
        XCTAssertGreaterThan(abs(left - right), 0.12, "filled half vs unfilled half: \(left) / \(right)")
        XCTAssertTrue(percent(app).waitForExistence(timeout: 5), "percent in the hint")
        XCTAssertTrue(percent(app).label.contains("50"), percent(app).label)
        XCTAssertGreaterThan(percent(app).frame.minX, header.frame.midX, "percent on the right")
        XCTAssertLessThanOrEqual(percent(app).frame.maxX, header.frame.maxX, "percent inside the pill")
        XCTAssertTrue((header.value as? String ?? "").contains("50"), "VoiceOver value is the percent: \(String(describing: header.value))")
        XCTAssertTrue(header.label.contains("Aktualisiere"), "hint text unchanged: \(header.label)")
        assertDarkIfNeeded(app)
        shot(app, "3-waehrend-messbar-50-prozent")
        app.terminate()
    }

    // MARK: Unmeasurable (no total) runs through

    func testUnmeasuredBarRunsThroughWithoutPercentAndMoves() throws {
        let app = launch("delayed")
        let header = header(app)
        XCTAssertTrue(header.waitForExistence(timeout: 30))
        waitForForecast(header)
        let heightBefore = header.frame.height
        startUpdate(app)
        XCTAssertEqual(barValue(app), "running")
        assertBarGeometry(app, heightBefore: heightBefore)
        XCTAssertFalse(percent(app).exists, "no percent without a total size")
        XCTAssertEqual(header.value as? String ?? "", "", "no value without a measurable total")
        XCTAssertTrue(header.label.contains("Aktualisiere"), header.label)
        let frames = (0..<4).compactMap { _ -> Data? in usleep(230_000); return strip(app, of: bar(app)) }
        XCTAssertEqual(frames.count, 4)
        XCTAssertGreaterThan(Set(frames).count, 1, "the running segment moves (strip changes between moments)")
        let drawn = (0..<6).map { _ -> Double in usleep(150_000); let c = columnLuminance(app, of: bar(app)); return (c.max() ?? 0) - (c.min() ?? 0) }
        XCTAssertGreaterThan(drawn.max() ?? 0, 0.12, "a segment is drawn on the track: \(drawn)")
        assertDarkIfNeeded(app)
        shot(app, "2-waehrend-durchlaufend")
        app.terminate()
    }

    // MARK: Reduce Motion

    func testReducedMotionUnmeasuredBarIsStatic() throws {
        let app = launch("delayed", extra: ["-UITestReduceMotion"])
        let header = header(app)
        XCTAssertTrue(header.waitForExistence(timeout: 30))
        waitForForecast(header)
        startUpdate(app)
        XCTAssertEqual(barValue(app), "running-static")
        XCTAssertFalse(percent(app).exists)
        let frames = (0..<4).compactMap { _ -> Data? in usleep(230_000); return strip(app, of: bar(app)) }
        XCTAssertEqual(frames.count, 4)
        XCTAssertEqual(Set(frames).count, 1, "nothing moves with Reduce Motion")
        shot(app, "4-reduce-motion-durchlaufend-statisch")
        app.terminate()
    }

    func testReducedMotionMeasuredBarKeepsFillAndPercent() throws {
        let app = launch("measured", extra: ["-UITestReduceMotion"])
        let header = header(app)
        XCTAssertTrue(header.waitForExistence(timeout: 30))
        waitForForecast(header)
        assertBarValue(app, "measured:50")
        XCTAssertTrue(percent(app).waitForExistence(timeout: 5))
        let frames = (0..<3).compactMap { _ -> Data? in usleep(230_000); return strip(app, of: bar(app)) }
        XCTAssertEqual(Set(frames).count, 1, "fill stays still")
        shot(app, "5-reduce-motion-messbar")
        app.terminate()
    }

    // MARK: End states (bar gone)

    private func assertBarGoneAndTextBack(_ app: XCUIApplication, timeout: TimeInterval = 40, file: StaticString = #filePath, line: UInt = #line) {
        let gone = NSPredicate(format: "exists == false")
        XCTAssertEqual(XCTWaiter().wait(for: [expectation(for: gone, evaluatedWith: bar(app))], timeout: timeout), .completed, "bar gone", file: file, line: line)
        XCTAssertFalse(percent(app).exists, file: file, line: line)
        XCTAssertFalse(header(app).label.contains("Aktualisiere"), header(app).label, file: file, line: line)
        XCTAssertEqual(header(app).value as? String ?? "", "", file: file, line: line)
    }

    func testBarEndsAfterSuccessWithNewData() throws {
        let app = launch("slowfresh")
        let header = header(app)
        XCTAssertTrue(header.waitForExistence(timeout: 30))
        waitForForecast(header)
        let heightBefore = header.frame.height
        assertDarkIfNeeded(app)
        shot(app, "1-vorher")
        startUpdate(app)
        XCTAssertEqual(barValue(app), "running")
        shot(app, "2-waehrend-durchlaufend")
        assertBarGoneAndTextBack(app)
        XCTAssertEqual(header.frame.height, heightBefore, accuracy: 0.5)
        sleep(1)
        assertDarkIfNeeded(app)
        shot(app, "6-nachher-erfolg")
        app.terminate()
    }

    func testBarEndsAfterUnchangedAnswer() throws {
        let app = launch("slowbehind")
        let header = header(app)
        XCTAssertTrue(header.waitForExistence(timeout: 30))
        waitForForecast(header)
        startUpdate(app)
        XCTAssertEqual(barValue(app), "running")
        assertBarGoneAndTextBack(app)
        app.terminate()
    }

    func testBarEndsAfterFailure() throws {
        let app = launch("slowfailed")
        let header = header(app)
        XCTAssertTrue(header.waitForExistence(timeout: 30))
        waitForForecast(header)
        startUpdate(app)
        XCTAssertEqual(barValue(app), "running")
        assertBarGoneAndTextBack(app, timeout: 60)
        app.terminate()
    }

    // MARK: Hint text does not wrap or change height because of the percent

    /// Frame heights of the hint (pill) and of its text block while an update runs, with or without a measured total.
    private func hintHeights(mode: String, category: String) -> (header: CGFloat, text: CGFloat) {
        let app = launch(mode, extra: ["-UIPreferredContentSizeCategoryName", category])
        defer { app.terminate() }
        XCTAssertTrue(header(app).waitForExistence(timeout: 30))
        waitForForecast(header(app))
        if mode == "measured" { assertBarValue(app, "measured:50", category) } else { startUpdate(app); XCTAssertEqual(barValue(app), "running") }
        let text = app.descendants(matching: .any)["forecast-refreshing"]
        XCTAssertTrue(text.waitForExistence(timeout: 5), "hint text block (refreshing) \(category)")
        if mode == "measured" {
            XCTAssertEqual(bar(app).frame.width, header(app).frame.width, accuracy: 1.5, "bar spans the width at \(category)")
            XCTAssertTrue((header(app).value as? String ?? "").contains("50"), "\(category): percent is spoken as the header's value")
            if category.contains("Accessibility") {
                XCTAssertFalse(percent(app).exists, "accessibility size: percent not drawn (would add a line)")
            } else {
                XCTAssertTrue(percent(app).waitForExistence(timeout: 5), category)
                XCTAssertLessThanOrEqual(percent(app).frame.maxX, header(app).frame.maxX, "percent inside the pill")
                XCTAssertGreaterThan(percent(app).frame.minX, header(app).frame.midX, "percent on the right")
            }
            shot(app, "7-schriftgroesse-\(category.replacingOccurrences(of: "UICTContentSizeCategory", with: "").lowercased())")
        }
        NSLog("HINTHEIGHT mode=\(mode) category=\(category) suffix=\(suffix) header=\(header(app).frame.height) text=\(text.frame.height) percentShown=\(percent(app).exists)")
        return (header(app).frame.height, text.frame.height)
    }

    func testPercentKeepsHintTextAndHeightStable() throws {
        for category in ["UICTContentSizeCategoryL", "UICTContentSizeCategoryXXL", "UICTContentSizeCategoryAccessibilityXXXL"] {
            let without = hintHeights(mode: "delayed", category: category)
            let with = hintHeights(mode: "measured", category: category)
            XCTAssertEqual(with.header, without.header, accuracy: 0.5, "\(category): hint height with/without percent")
            XCTAssertEqual(with.text, without.text, accuracy: 0.5, "\(category): the hint text keeps its line count with the percent")
        }
    }
}
