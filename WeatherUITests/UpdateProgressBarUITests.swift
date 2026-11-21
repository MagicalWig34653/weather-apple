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

    // MARK: Leaving the app while an update runs ("abort" of the loop)

    /// Leaving the app (scene not `.active`) cancels the `.task(id: scenePhase)` loop. The stalled request itself is NOT cancelled
    /// (`DWDClient` shares its index/point task on purpose: "cancelling one consumer must not cancel another", and the consumer waits
    /// on `task.value`), so the load, and with it the bar, ends together with the request, never earlier. Verified by this test
    /// (stub `delayed`: the later index query answers after 40 s):
    ///   - the bar is still there after returning (no restart, a restarted load would run another 40 s),
    ///   - it ends about 40 s after the load began (not 40 s after the return),
    ///   - afterwards: no bar, hint text back, same height (no stuck bar).
    /// A first version assumed "leaving cancels the load, returning starts a new one" and went red on exactly that
    /// (end 34.9 s after the return instead of 40 s or more); see docs/status.md.
    func testBarSurvivesLeavingTheAppAndEndsTogetherWithTheRequest() throws {
        let app = launch("delayed")
        let header = header(app)
        XCTAssertTrue(header.waitForExistence(timeout: 30))
        waitForForecast(header)
        let heightBefore = header.frame.height
        startUpdate(app)
        XCTAssertEqual(barValue(app), "running")
        let firstSeen = Date()
        assertDarkIfNeeded(app)
        shot(app, "abbruch-1-vorher-balken-laeuft")
        XCTAssertTrue(header.label.contains("Aktualisiere"), header.label)
        sleep(2)
        XCUIDevice.shared.press(.home)   // frame 2 is the home screen the person lands on
        sleep(1)
        let home = XCUIScreen.main.screenshot()
        try? FileManager.default.createDirectory(atPath: shotDirectory, withIntermediateDirectories: true)
        try? home.pngRepresentation.write(to: URL(fileURLWithPath: shotDirectory).appendingPathComponent("abbruch-2-waehrend-app-verlassen-\(suffix == "dark" ? "dunkel" : "hell").png"))
        while Date().timeIntervalSince(firstSeen) < 8 { usleep(200_000) }   // load 1 and a possible restart are clearly apart
        app.activate()
        let returned = Date()
        XCTAssertEqual(barValue(app), "running", "the load carries on: the bar is still there after returning")
        XCTAssertEqual(header.frame.height, heightBefore, accuracy: 0.5, "no height change of the hint")
        assertDarkIfNeeded(app)
        shot(app, "abbruch-3-zurueck-balken-laeuft-weiter")
        assertBarGoneAndTextBack(app, timeout: 45)
        let afterReturn = Date().timeIntervalSince(returned)
        XCTAssertLessThan(afterReturn, 37, "ends with the original request (about 40 s after it began), not 40 s after the return: \(afterReturn)")
        XCTAssertGreaterThan(Date().timeIntervalSince(firstSeen), 30, "ends with the stalled request, not earlier")
        XCTAssertEqual(header.frame.height, heightBefore, accuracy: 0.5, "height unchanged after the end")
        XCTAssertFalse(header.label.isEmpty)
        sleep(1)
        assertDarkIfNeeded(app)
        shot(app, "abbruch-4-nachher-balken-weg")
        NSLog("ABORTRUN endedAfterReturn=\(afterReturn) sinceFirstSeen=\(Date().timeIntervalSince(firstSeen)) suffix=\(suffix)")
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

    // MARK: Manual reload ("Daten neu laden") shows the bar at once (stub, deterministic)

    /// The bar belongs to the manual path too: `refresh()` sets the loading flags synchronously. Stub `slowbehind` (later index queries
    /// answer after 6 s) makes the load long enough for the poll after the tap (about 1 s). Attributed to the tap only if no bar was
    /// there right before it and it shows within 3 s after it (the automatic loop starts its own loads at about 20 s intervals: retried).
    func testManualReloadShowsTheBarAtOnce() throws {
        // `MANUAL_RELOAD_STUB=current` (instant answers) is the deliberate red run: the poll cannot see such a short load.
        let app = launch(ProcessInfo.processInfo.environment["MANUAL_RELOAD_STUB"] ?? "slowbehind")
        let header = header(app)
        XCTAssertTrue(header.waitForExistence(timeout: 30))
        waitForForecast(header)
        let heightBefore = header.frame.height
        var attributed = false
        for attempt in 1...4 where !attributed {
            let gone = NSPredicate(format: "exists == false")
            XCTAssertEqual(XCTWaiter().wait(for: [expectation(for: gone, evaluatedWith: bar(app))], timeout: 30), .completed, "no bar before the tap (attempt \(attempt))")
            guard let reload = openLayerEntry(app, group: nil, entry: "Daten neu laden") else { return XCTFail("reload entry not found") }
            if bar(app).exists { app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5)).tap(); sleep(2); continue }   // the loop's own load: try again
            if attempt == 1 { assertDarkIfNeeded(app); shot(app, "9-manuell-vorher") }
            reload.tap()
            let tapped = Date()
            XCTAssertTrue(bar(app).waitForExistence(timeout: 3), "the manual reload shows the bar within 3 s of the tap")
            XCTAssertEqual(bar(app).value as? String, "running")
            XCTAssertLessThan(Date().timeIntervalSince(tapped), 4)
            XCTAssertTrue(header.label.contains("Aktualisiere"), header.label)
            XCTAssertEqual(header.frame.height, heightBefore, accuracy: 0.5, "no height change of the hint")
            assertDarkIfNeeded(app)
            shot(app, "9-manuell-waehrend-durchlaufend")
            assertBarGoneAndTextBack(app, timeout: 30)
            XCTAssertEqual(header.frame.height, heightBefore, accuracy: 0.5)
            attributed = true
        }
        XCTAssertTrue(attributed, "a manual reload could not be told apart from the loop's loads in 4 attempts")
        app.terminate()
    }

    // MARK: Real services (read only), no stub

    /// End to end against the real services (DWD forecast, Showers radar cache): GET requests only. Observes the bar during the
    /// start-up load and after "Daten neu laden". Needs network; skipped (not failed) when no load can be observed at all.
    func testRealServicesBarRunsThroughWithoutPercentAndEnds() throws {
        let app = UITestLaunch.app(extra: UITestLaunch.setAppearance(suffix == "dark" ? .dark : .light, extra: ["-UITestExposeProgress", "-UITestResetForecast"]))
        app.launch()
        defer { app.terminate() }
        let header = header(app)
        XCTAssertTrue(header.waitForExistence(timeout: 30))
        var observed: [String] = []
        var sawPercent = false
        let end = Date().addingTimeInterval(60)
        var seenBar = false
        while Date() < end {
            if bar(app).exists, let value = bar(app).value as? String {
                seenBar = true
                if observed.last != value { observed.append(value) }
                if percent(app).exists { sawPercent = true }
                if observed.count == 1, observed[0] == "running" { shot(app, "8-echtbetrieb-waehrend-durchlaufend"); NSLog("REALRUN bar frame \(bar(app).frame) screen \(app.frame)") }
            } else if seenBar { break }
            usleep(150_000)
        }
        NSLog("REALRUN start-up load observed=\(observed) percentSeen=\(sawPercent)")
        try XCTSkipIf(!seenBar, "no load observed (too fast or no network)")
        XCTAssertFalse(observed.contains { $0.hasPrefix("measured") }, "the real services report no total size: no measured value, got \(observed)")
        XCTAssertFalse(sawPercent, "no percent without a total size")
        XCTAssertFalse(bar(app).exists, "bar gone after the load")
        // Manual reload. What a poll after the tap can see: XCUITest returns from the tap only after the app is idle again (about 1 s in
        // the runs 21.11.2026), and the real manual reload answers from caches (run index and point cache 300 s, radar manifest by ETag)
        // within that time. So the bar of the manual reload is usually NOT observable here; that is a test window limit, not app
        // behaviour (the manual path shows the bar: `testManualReloadShowsTheBarAtOnce` with a stub, `testManualReloadShowsTheRunningBarAndEndsIt`
        // as unit test). Only a bar seen within 3 s after the tap counts as the manual reload; a later one is the automatic loop
        // (a new 5-minute run falls due, observed 07:23:26 in run 32: bar 16 s after the tap) and is reported separately.
        guard let reload = openLayerEntry(app, group: nil, entry: "Daten neu laden") else { return XCTFail("reload entry not found") }
        let beforeTap = Date()
        reload.tap()
        let tapped = Date()
        let tapReturnDelay = tapped.timeIntervalSince(beforeTap)   // the tap waits for the app to be idle again
        var manual: [String] = [], later: [String] = []
        var firstSeenAfter: TimeInterval?
        let manualEnd = tapped.addingTimeInterval(30)
        var seenAny = false
        while Date() < manualEnd {
            if bar(app).exists, let value = bar(app).value as? String {
                seenAny = true
                let elapsed = Date().timeIntervalSince(tapped)
                if firstSeenAfter == nil { firstSeenAfter = elapsed }
                if percent(app).exists { sawPercent = true }
                if elapsed <= 3 { if manual.last != value { manual.append(value) } } else if later.last != value { later.append(value) }
            } else if seenAny, Date().timeIntervalSince(tapped) > 3 { break }
            usleep(150_000)
        }
        NSLog("REALRUN manual reload: the tap returned after \(String(format: "%.2f", tapReturnDelay)) s, polling starts then; seen within 3 s=\(manual), later (automatic loop)=\(later), first seen at \(firstSeenAfter.map { String(format: "%.2f s", $0) } ?? "never") percentSeen=\(sawPercent)")
        XCTAssertFalse((manual + later).contains { $0.hasPrefix("measured") }, "got \(manual) \(later)")
        XCTAssertFalse(sawPercent)
        let gone = NSPredicate(format: "exists == false")
        XCTAssertEqual(XCTWaiter().wait(for: [expectation(for: gone, evaluatedWith: bar(app))], timeout: 45), .completed, "bar gone at the end")
    }
}
