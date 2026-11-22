import CryptoKit
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

    /// Value and frame of the bar from ONE snapshot; nil once the bar is gone. `exists`, `.value` and `.frame` are separate queries:
    /// a bar that ends in between makes XCTest fail with "Failed to get matching snapshot" (a regular end of a real load, not an app error).
    private func barRead(_ app: XCUIApplication) -> (value: String?, frame: CGRect)? {
        guard let snapshot = try? bar(app).snapshot() else { return nil }
        return (snapshot.value as? String, snapshot.frame)
    }

    /// Polls the bar by atomic snapshot reads (about 0.1 s apart) until `accept` holds; nil on timeout.
    private func pollBar(_ app: XCUIApplication, timeout: TimeInterval,
                         until accept: ((value: String?, frame: CGRect)) -> Bool = { _ in true }) -> (value: String?, frame: CGRect)? {
        let end = Date().addingTimeInterval(timeout)
        repeat {
            if let read = barRead(app), accept(read) { return read }
            usleep(100_000)
        } while Date() < end
        return nil
    }

    /// True as soon as the bar is absent in two consecutive snapshot reads 0.25 s apart (one failed query is not the end of a load;
    /// a follow-on load that starts at once is not a gap either).
    private func pollBarGone(_ app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let end = Date().addingTimeInterval(timeout)
        repeat {
            if barRead(app) == nil {
                usleep(250_000)
                if barRead(app) == nil { return true }
            } else { usleep(100_000) }
        } while Date() < end
        return false
    }

    private enum ForecastState { case behind, refreshing, current, notShown }

    /// What the forecast header says right now (one snapshot of the header, the status text carries a fixed identifier or label).
    private func forecastState(_ app: XCUIApplication) -> ForecastState? {
        guard let snapshot = try? header(app).snapshot() else { return nil }
        let label = snapshot.label
        if app.descendants(matching: .any)["forecast-server-behind"].exists || label.contains("neueren Stand") { return .behind }
        if label.contains("Aktualisiere") { return .refreshing }
        if label.localizedCaseInsensitiveContains("geladen") || label.localizedCaseInsensitiveContains("nicht verf") { return .notShown }
        return .current
    }

    /// Non-asserting variant of `waitForForecast` (a start that must be repeated is not a failure).
    private func forecastShown(_ header: XCUIElement, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "NOT (label CONTAINS[c] 'geladen') AND NOT (label CONTAINS[c] 'nicht verf')")
        return XCTWaiter().wait(for: [expectation(for: predicate, evaluatedWith: header)], timeout: timeout) == .completed
    }

    /// Cold start of a stub run whose bar sequence is keyed on REQUEST COUNTS (stub: "later index queries", "point query > 1").
    /// At launch the app starts three loads at about the same time: the forecast of `store.refresh()` (WeatherApp.swift:55), the forecast
    /// of the loop `runForecastRefresh` (WeatherApp.swift:65 to 68) and the radar timeline (which also asks the run index). Which of
    /// them is index query no. 1 (fast, shows the 10 minute old run) and which one is no. 2 (slow or newer, measured) depends on
    /// scheduling.
    ///
    /// The ONLY start this helper repeats is the one whose forecast got the NEWER run at once (header settles as "current", no hint, no
    /// further load due): that is a state of the stub's counters (the forecast load took index query no. 2), the app shows the newer run
    /// correctly and there is no bar to test. Every repetition is logged (`STUBSTART ... newer run shown at once`).
    /// Decision 22.11.2026 (card D5875BAA, finding 3): the hint pill has 8 pt of padding above and below its text. ONE line keeps the
    /// minimum height of 48 pt (the loading bar's promise: rest, loading and done do not change the height); a TWO-line text grows the
    /// pill (the status text "Der Wetterdienst hat noch keinen neueren Stand" has two lines at standard size: 54 pt). Heights of two
    /// states therefore agree if they are equal, or if one is the one-line 48 pt and the other a two-line height (more than 48, at
    /// most 60 at standard size). Anything else (a bar that changes the height) still fails.
    private func assertPillHeight(_ now: CGFloat, _ before: CGFloat, _ message: String = "no height change of the hint",
                                  file: StaticString = #filePath, line: UInt = #line) {
        if abs(now - before) <= 0.5 { return }
        let (low, high) = (min(now, before), max(now, before))
        XCTAssertTrue(abs(low - 48) <= 0.5 && high > 48.5 && high <= 60, "\(message): \(before) -> \(now) (only one line <-> two lines may differ)", file: file, line: line)
    }

    /// Everything else is NOT healed by a restart and fails the test at once: no forecast, a start bar that does not end, and above all
    /// a start that settles on the old run ("server behind" / refreshing) while the planned bar does not come within 20 s. That is the
    /// app's own symptom (Build 56: a lost second load or a bar-less running request), no longer hidden by a cold start.
    /// Limits and waits of the assertions are not touched. The result is the running app with the expected bar value already seen,
    /// and the header height before the bar.
    ///  - `returnTrip`: the planned second load is the one a return from the background starts (stub `slowfresh`): the start must settle
    ///    (no bar, hint "server behind"), then one return; otherwise the second load is the loop's own (stub `measured`, 3 s after the first).
    private func launchUntilStubBar(_ mode: String, extra: [String] = [], expect value: String, returnTrip: Bool = false,
                                    attempts: Int = 4, onSettled: (XCUIApplication) -> Void = { _ in },
                                    onBar: (XCUIApplication) -> Void = { _ in },
                                    file: StaticString = #filePath, line: UInt = #line) -> (app: XCUIApplication, heightBefore: CGFloat) {
        var app: XCUIApplication!
        var notes: [String] = []
        for attempt in 1...attempts {
            app?.terminate()
            app = launch(mode, extra: extra)
            guard header(app).waitForExistence(timeout: 30), forecastShown(header(app), timeout: 60) else {
                XCTFail("stub '\(mode)' attempt \(attempt): no forecast shown after the cold start", file: file, line: line); return (app, 0)
            }
            if returnTrip, !pollBarGone(app, timeout: 30) {
                XCTFail("stub '\(mode)' attempt \(attempt): the start bar did not end within 30 s", file: file, line: line); return (app, 0)
            }
            let state = forecastState(app)
            if state == .current {
                notes.append("\(attempt): start settled as current (newer run shown at once)"); NSLog("STUBSTART \(mode) \(notes.last!)"); continue
            }
            if state == .notShown || (returnTrip && state == .refreshing) {
                XCTFail("stub '\(mode)' attempt \(attempt): unexpected start state \(String(describing: state))", file: file, line: line); return (app, 0)
            }
            let heightBefore = header(app).frame.height
            if returnTrip { onSettled(app); startUpdate(app) }
            guard pollBar(app, timeout: 20, until: { $0.value == value }) != nil else {
                XCTFail("stub '\(mode)' attempt \(attempt): no bar '\(value)' within 20 s, header \(String(describing: state)): the planned second load did not come (not repeated by a restart)", file: file, line: line)
                return (app, 0)
            }
            onBar(app)
            NSLog("STUBSTART \(mode) attempt \(attempt) of \(attempts) ok")
            return (app, heightBefore)
        }
        XCTFail("stub sequence '\(mode)' settled on the newer run in \(attempts) cold starts (no bar to test): \(notes)", file: file, line: line)
        return (app, 0)
    }

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
        // The loop starts the stalled load itself 3 s after the first. A bar that does not come is a failure (no return trip heals it).
        let appeared = barValue(app, timeout: 25)
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
    private func assertBarGeometry(_ app: XCUIApplication, heightBefore: CGFloat, barFrame: CGRect? = nil, file: StaticString = #filePath, line: UInt = #line) {
        // `barFrame`: frame already read atomically by the caller (the bar of a real load may end between two queries).
        guard let b = barFrame ?? barRead(app)?.frame else { return XCTFail("bar gone while reading its geometry", file: file, line: line) }
        let h = header(app).frame
        XCTAssertEqual(b.minX, h.minX, accuracy: 1.5, "bar starts at the left edge", file: file, line: line)
        XCTAssertEqual(b.width, h.width, accuracy: 1.5, "bar spans the whole width", file: file, line: line)
        XCTAssertEqual(b.maxY, h.maxY, accuracy: 1.5, "bar on the bottom edge", file: file, line: line)
        assertPillHeight(h.height, heightBefore, "no height change of the hint", file: file, line: line)
    }

    // MARK: Measured progress (stub reports sizes)

    func testMeasuredBarShowsFillPercentOnTheRightAndKeepsHintText() throws {
        // No background trip: the stub's stalled point query is shared and would be joined (unmeasured) by a repeated load.
        // The loop starts the next load by itself 3 s after the first one (stub `measured` shortens the pause); the stub then stalls it for 90 s.
        // `launchUntilStubBar` starts again if the stub's request counts did not give this sequence (see there).
        let started = launchUntilStubBar("measured", expect: "measured:50")
        let app = started.app, heightBefore = started.heightBefore
        let header = header(app)
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
        let app = launchUntilStubBar("measured", extra: ["-UITestReduceMotion"], expect: "measured:50").app
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
        // Settled start (no bar, hint "server behind"), then one return that starts the stalled load (6 s, lists the newer run).
        // `launchUntilStubBar` starts again if the stub's request counts gave another start (see there); "running" is seen on return.
        let started = launchUntilStubBar("slowfresh", expect: "running", returnTrip: true,
                                         onSettled: { app in self.assertDarkIfNeeded(app); self.shot(app, "1-vorher") },
                                         onBar: { app in self.shot(app, "2-waehrend-durchlaufend") })
        let app = started.app, heightBefore = started.heightBefore
        let header = header(app)
        assertBarGoneAndTextBack(app)
        assertPillHeight(header.frame.height, heightBefore)
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
        assertPillHeight(header.frame.height, heightBefore, "no height change of the hint")
        assertDarkIfNeeded(app)
        shot(app, "abbruch-3-zurueck-balken-laeuft-weiter")
        assertBarGoneAndTextBack(app, timeout: 45)
        let afterReturn = Date().timeIntervalSince(returned)
        XCTAssertLessThan(afterReturn, 37, "ends with the original request (about 40 s after it began), not 40 s after the return: \(afterReturn)")
        XCTAssertGreaterThan(Date().timeIntervalSince(firstSeen), 30, "ends with the stalled request, not earlier")
        assertPillHeight(header.frame.height, heightBefore, "height unchanged after the end")
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
        let sizeArguments = ["-UIPreferredContentSizeCategoryName", category]
        let app = mode == "measured" ? launchUntilStubBar(mode, extra: sizeArguments, expect: "measured:50").app : launch(mode, extra: sizeArguments)
        defer { app.terminate() }
        if mode == "measured" {
            assertBarValue(app, "measured:50", category)
        } else {
            XCTAssertTrue(header(app).waitForExistence(timeout: 30))
            waitForForecast(header(app))
            startUpdate(app); XCTAssertEqual(barValue(app), "running")
        }
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
            assertPillHeight(header.frame.height, heightBefore, "no height change of the hint")
            assertDarkIfNeeded(app)
            shot(app, "9-manuell-waehrend-durchlaufend")
            assertBarGoneAndTextBack(app, timeout: 30)
            assertPillHeight(header.frame.height, heightBefore)
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
        var shotTaken = false
        var ended = false
        while Date() < end {
            // One snapshot for value and frame: a snapshot that fails means the bar is gone (regular end once it was seen).
            if let read = barRead(app), let value = read.value {
                seenBar = true
                if observed.last != value { observed.append(value) }
                if percent(app).exists { sawPercent = true }
                // Screenshot and frame log only ONCE (frame from the snapshot); the screenshot does not query the bar, so an end during it is harmless.
                if !shotTaken, observed == ["running"] { shotTaken = true; NSLog("REALRUN bar frame \(read.frame) screen \(app.frame)"); shot(app, "8-echtbetrieb-waehrend-durchlaufend") }
            } else if seenBar {
                // The end counts when two reads 0.3 s apart both find no bar. One failed query, or a follow-on load of the loop that
                // starts at once (a NEW bar, not this one), is not the end of THIS load; the old `bar.exists` right after the loop
                // met exactly such a bar (run 15:28, light) and failed. A bar that does not end within the 60 s still fails below.
                usleep(300_000)
                if barRead(app) == nil { ended = true; break }
                continue
            }
            usleep(150_000)
        }
        NSLog("REALRUN start-up load observed=\(observed) percentSeen=\(sawPercent)")
        try XCTSkipIf(!seenBar, "no load observed (too fast or no network)")
        XCTAssertFalse(observed.contains { $0.hasPrefix("measured") }, "the real services report no total size: no measured value, got \(observed)")
        XCTAssertFalse(sawPercent, "no percent without a total size")
        XCTAssertTrue(ended, "bar gone after the load (no bar in two consecutive reads within 60 s), saw \(observed)")
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
            if let value = barRead(app)?.value {   // one snapshot: no race between exists and value
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

    // MARK: Real services, start-up bar as a real image sequence (read only, no stub)

    /// One screenshot, written to `shotDirectory` (names carry light/dark like `shot`), attached to the result and returned with its
    /// MD5 and the image itself (so the checks use exactly the frame that is saved). No image manipulation.
    private func capture(_ app: XCUIApplication, _ name: String) -> (md5: String, image: UIImage) {
        let screenshot = app.screenshot()
        let png = screenshot.pngRepresentation
        try? FileManager.default.createDirectory(atPath: shotDirectory, withIntermediateDirectories: true)
        try? png.write(to: URL(fileURLWithPath: shotDirectory).appendingPathComponent("\(name)-\(suffix == "dark" ? "dunkel" : "hell").png"))
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "\(name)-\(suffix == "dark" ? "dunkel" : "hell")"
        attachment.lifetime = .keepAlways
        add(attachment)
        return (Insecure.MD5.hash(data: png).map { String(format: "%02x", $0) }.joined(), screenshot.image)
    }

    /// PNG bytes of `rect` (points) of a screenshot, to show that two frames differ exactly there.
    private func cropped(_ image: UIImage, _ rect: CGRect) -> Data? {
        let s = image.scale
        let r = CGRect(x: rect.minX * s, y: rect.minY * s, width: rect.width * s, height: rect.height * s).integral
        return image.cgImage?.cropping(to: r).flatMap { UIImage(cgImage: $0).pngData() }
    }

    /// A frame with no bar and the facts read between the two bar checks around its screenshot.
    private struct IdleFrame { let md5: String; let image: UIImage; let label: String; let value: String; let headerHeight: CGFloat; let percentVisible: Bool }

    /// Screenshot of a settled screen: the bar is absent in two consecutive reads BEFORE the screenshot and absent again right AFTER it
    /// (the hint, value and percent are read between the two checks, so they belong to the same moment). A follow-on load of the loop
    /// that starts meanwhile is not an error: the screenshot is repeated once that bar has ended (up to `attempts`). nil: never settled.
    private func captureIdle(_ app: XCUIApplication, _ name: String, attempts: Int = 4) -> IdleFrame? {
        for attempt in 1...attempts {
            guard pollBarGone(app, timeout: 60) else { return nil }
            let frame = capture(app, name)
            let snapshot = try? header(app).snapshot()
            let percentVisible = percent(app).exists
            if barRead(app) == nil {
                return IdleFrame(md5: frame.md5, image: frame.image, label: snapshot?.label ?? "", value: snapshot?.value as? String ?? "",
                                 headerHeight: snapshot?.frame.height ?? 0, percentVisible: percentVisible)
            }
            NSLog("REALSEQ \(name): a bar started during the screenshot (attempt \(attempt) of \(attempts)), again")
        }
        return nil
    }

    /// Image sequence of the START-UP bar against the REAL services (DWD forecast, Showers radar cache), GET only, no stub:
    /// before (no bar), during (bar visible and running), after (bar gone, hint intact, height unchanged). All three are REAL app
    /// screenshots, pairwise different (MD5) and different exactly at the bar strip.
    ///
    /// Why two launches: the start-up load begins right after launch, so a cold start has NO bar-less frame before it (6 of 6 cold
    /// starts of run 15:29 to 15:38, light and dark: "bar already visible at the first look"; app launch and the first XCUITest query
    /// alone take longer than the start of the load). Every other real load is not observable: the manual reload and the return from the
    /// background answer from caches within the tap's or activation's idle wait of about 1 s; a loop load is a forecast-only request of
    /// well under a second. So the bar-less "before" cannot be taken inside the session that shows the start-up bar; no stub or
    /// artificial state is built to get it. Instead the sequence is the user's own: (1) session 1 starts, its start-up load ends, the
    /// screen settles: "before" (bar absent before and after the screenshot). (2) The app is closed and opened again
    /// (cold start, the same real services): "during" is the start-up bar of this launch, "after" the settled screen once it ended.
    /// What this does NOT prove: that no bar-less frame exists in the SAME session before the bar; that needs an app-side hook
    /// (a Debug-only launch argument that delays the start-up load) and is listed as an option in docs, not done here.
    ///
    /// No skipping: no bar after relaunch, a bar that does not end, a hint that stays on "Regenprognose wird geladen" or equal frames are failures.
    /// A frame whose validity cannot be shown (the bar ended during the 'during' screenshot) is taken again with another cold start
    /// (up to 3), because the load may be too short for one screenshot; every attempt is logged (`REALSEQ`).
    ///
    /// Environment (via `TEST_RUNNER_`): `SHOT_SUFFIX` hell/dark (default: appearance of the device), `UPDATE_PROGRESS_SHOTS` (directory).
    /// Files: `10-start-echt-1-vorher|2-waehrend|3-nachher-<hell|dunkel>.png`.
    func testRealServicesStartBarImageSequence() throws {
        let launchArguments = UITestLaunch.setAppearance(suffix == "dark" ? .dark : .light, extra: ["-UITestExposeProgress", "-UITestResetForecast"])
        let app = UITestLaunch.app(extra: launchArguments)
        defer { app.terminate() }

        // Session 1: start-up load, then the settled screen = "before".
        app.launch()
        guard header(app).waitForExistence(timeout: 30) else { return XCTFail("session 1: the forecast header does not exist after launch") }
        guard forecastShown(header(app), timeout: 60) else { return XCTFail("session 1: no forecast shown within 60 s (no network?)") }
        guard let before = captureIdle(app, "10-start-echt-1-vorher") else { return XCTFail("session 1: the screen did not settle without a bar within 60 s") }
        XCTAssertFalse(before.label.contains("Aktualisiere"), "session 1: hint while no bar: \(before.label)")
        XCTAssertFalse(before.percentVisible)
        let heightBefore = before.headerHeight
        assertDarkIfNeeded(app)

        // Session 2: cold start; "during" = the start-up bar of this launch.
        var during: (md5: String, image: UIImage)?
        var duringBar = CGRect.zero, duringHeader = CGRect.zero
        var firstValue: String?
        var attempts = 0
        while during == nil && attempts < 3 {
            attempts += 1
            app.terminate()
            app.launch()
            guard let first = pollBar(app, timeout: 60) else { NSLog("REALSEQ attempt \(attempts): no start-up bar within 60 s after relaunch"); continue }
            let candidate = capture(app, "10-start-echt-2-waehrend")
            let stillThere = barRead(app)
            let hintSnapshot = try? header(app).snapshot()
            let stillThereAfterHint = barRead(app)
            guard let stillThere, stillThereAfterHint != nil else { NSLog("REALSEQ attempt \(attempts): the bar ended during the 'during' screenshot (frame not valid), again"); continue }
            // Cold start with -UITestResetForecast: no forecast is shown yet, so the hint says "Regenprognose wird geladen …"
            // (Weather/Views/RadarScreen.swift:874, string RADAR_FORECAST_LOADING, Weather/Resources/de.lproj/Localizable.strings:235).
            // "Aktualisiere …" exists only with a forecast already shown (RadarScreen.swift:866 spoken label).
            XCTAssertTrue((hintSnapshot?.label ?? "").contains("Regenprognose wird geladen"), "hint during the load: \(hintSnapshot?.label ?? "nil")")
            during = candidate; duringBar = stillThere.frame; duringHeader = hintSnapshot?.frame ?? header(app).frame; firstValue = first.value
        }
        guard let during else { return XCTFail("no valid 'during' frame in \(attempts) cold starts (no bar seen, or it ended during every screenshot): sequence not capturable") }
        var values: [String] = [firstValue ?? ""]
        var sawPercent = false
        XCTAssertEqual(values.first, "running", "the bar runs without a number, got \(values)")
        assertBarGeometry(app, heightBefore: heightBefore, barFrame: duringBar)
        assertPillHeight(duringHeader.height, heightBefore, "no height change of the hint (before vs during)")
        // The bar strip is really drawn in the 'during' frame and not in the 'before' frame (same place).
        XCTAssertNotEqual(cropped(during.image, duringBar), cropped(before.image, duringBar), "bar strip differs between before and during")

        // End of the start-up load: two reads without a bar (a follow-on bar counts as its own load, not as a missing end).
        let end = Date().addingTimeInterval(60)
        var ended = false
        while Date() < end {
            if let read = barRead(app), let value = read.value {
                if values.last != value { values.append(value) }
                if percent(app).exists { sawPercent = true }
            } else {
                usleep(300_000)
                if barRead(app) == nil { ended = true; break }
                continue
            }
            usleep(150_000)
        }
        XCTAssertTrue(ended, "bar gone at the end of the start-up load (60 s), saw \(values)")
        waitForForecast(header(app))

        // After: the settled screen of the running app.
        guard let after = captureIdle(app, "10-start-echt-3-nachher") else { return XCTFail("the screen did not settle without a bar after the start-up load") }
        XCTAssertFalse(after.percentVisible)
        XCTAssertFalse(after.label.contains("Aktualisiere"), "hint text back: \(after.label)")
        XCTAssertEqual(after.value, "")
        assertPillHeight(after.headerHeight, heightBefore, "no height change of the hint (before vs after)")
        NSLog("REALSEQ cold starts for 'during'=\(attempts) heights before=\(heightBefore) during=\(duringHeader.height) after=\(after.headerHeight) values=\(values) percentSeen=\(sawPercent) md5 \(before.md5) \(during.md5) \(after.md5)")
        XCTAssertFalse(values.contains { $0.hasPrefix("measured") }, "the real services report no total size, got \(values)")
        XCTAssertFalse(sawPercent, "no percent without a total size")
        assertDarkIfNeeded(app)
        XCTAssertNotEqual(before.md5, during.md5, "before and during differ")
        XCTAssertNotEqual(during.md5, after.md5, "during and after differ")
        XCTAssertNotEqual(before.md5, after.md5, "before and after differ")
        XCTAssertNotEqual(cropped(after.image, duringBar), cropped(during.image, duringBar), "bar strip differs between during and after")
    }
}
