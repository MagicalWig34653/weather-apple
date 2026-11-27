import XCTest

/// Setup wizard. `-UITestSetup` resets `setupVersion` and shows the wizard (without it UI tests never see it).
///
/// The push backend is ALWAYS replaced by an in-memory fake (`-UITestPush fake|fakedeny|system`, Debug only, see
/// `PushUITestStub`): no installation, no subscription and no token ever goes to the Showers server. Forecast, radar,
/// warnings and device link are stubbed as well. The counters of the fake are read through the invisible `setup-debug`
/// element ("enable=… installs=… subs=… authRequests=… enabled=…").
///
/// Not covered: the real push server, real APNs token delivery (the registrar is fake), delivery of a notification.
@MainActor
class SetupWizardTests: XCTestCase {
    var appearance: XCUIDevice.Appearance { .light }
    private var tag: String { appearance == .dark ? "dark" : "light" }

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    // MARK: Helpers

    private func launch(language: UITestLaunch.Language = .german, push: String = "fake", clean: Bool = true) -> XCUIApplication {
        var extra = ["-UITestSetup", "-UITestPush", push, "-UITestForecast", "current", "-UITestRadar", "fixture",
                     "-UITestWarnings", "empty", "-UITestWarnCapabilities", "none", "-UITestDeviceLinkWindow", "closed"]
        if clean { extra.append("-UITestSetupClean") }
        let app = UITestLaunch.app(language: language, extra: UITestLaunch.setAppearance(appearance, extra: extra))
        app.launch()
        return app
    }

    /// Attaches the screenshot and writes `<tag>-<name>.png` to the shots folder (if it exists). Returns the screenshot.
    @discardableResult
    private func shot(_ app: XCUIApplication, _ name: String) -> XCUIScreenshot {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "\(tag)-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
        let dir = "/private/tmp/claude-501/wiz-shots"
        if FileManager.default.fileExists(atPath: dir) {
            try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(tag)-\(name).png"))
        }
        return screenshot
    }

    /// Counters of the fake push backend.
    private func counters(_ app: XCUIApplication) -> [String: Int] {
        let element = app.descendants(matching: .any)["setup-debug"]
        XCTAssertTrue(element.waitForExistence(timeout: 10), "setup-debug element (stub active?)")
        var result: [String: Int] = [:]
        for part in element.label.split(separator: " ") {
            let pair = part.split(separator: "=")
            if pair.count == 2, let value = Int(pair[1]) { result[String(pair[0])] = value }
        }
        return result
    }

    private func waitForCounter(_ app: XCUIApplication, _ key: String, _ value: Int, timeout: TimeInterval = 15) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if counters(app)[key] == value { return true }
            Thread.sleep(forTimeInterval: 0.3)
        }
        return false
    }

    /// Launch with the real notification authorizer. Seen on a freshly erased simulator: the very first launch of a fresh install
    /// never answers `UNUserNotificationCenter.notificationSettings()` (wizard never appears, nothing in the app log); a second launch
    /// is fine. So: one relaunch if the welcome screen is missing after 20 s. Documented as simulator behaviour, not hidden.
    private func launchSystem() -> XCUIApplication {
        var app = launch(push: "system")
        if !app.staticTexts["Willkommen bei Showers"].waitForExistence(timeout: 20) {
            app.terminate()
            app = launch(push: "system")
        }
        return app
    }

    /// Welcome -> (Standort: only if the simulator has not decided yet; answered with "Später") -> Orte.
    private func toPlaces(_ app: XCUIApplication) {
        XCTAssertTrue(app.staticTexts["Willkommen bei Showers"].waitForExistence(timeout: 30))
        app.buttons["setup-primary"].tap()
        if app.staticTexts["Dein Standort"].waitForExistence(timeout: 5) { app.buttons["setup-later"].tap() }
        XCTAssertTrue(app.staticTexts["Deine Orte"].waitForExistence(timeout: 8))
    }

    /// Types "Teststadt" in the places search (fixed stub result), saves it and continues to the rain alert step.
    private func addTestPlaceAndContinue(_ app: XCUIApplication) {
        let field = app.textFields["setup-search"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Teststadt\n")
        let result = app.buttons.matching(identifier: "setup-result").firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 10), "fixed search result")
        shot(app, "03b-orte-suche")
        result.tap()
        XCTAssertTrue(app.staticTexts["Teststadt"].waitForExistence(timeout: 5))
        shot(app, "03c-orte-gespeichert")
        app.buttons["setup-primary"].tap()
        XCTAssertTrue(app.staticTexts["Regenhinweis"].waitForExistence(timeout: 5))
    }

    /// Switch value as XCUITest reports it: "1"/"0" as String, on some runs as a number (Build 61 log: `Optional(1)`).
    /// Only exactly on/off counts; anything else is nil (fails the caller).
    nonisolated static func switchState(_ value: Any?) -> Bool? {
        NSPredicate(format: "value == '1'").evaluate(with: ["value": value as Any]) ? true : nil
    }

    /// Waits until the switch reports exactly `on` (String or number); fails with the last raw value and its type.
    private func waitForSwitch(_ toggle: XCUIElement, on: Bool, timeout: TimeInterval = 5, _ context: String) {
        let deadline = Date().addingTimeInterval(timeout)
        while Self.switchState(toggle.value) != on, Date() < deadline { Thread.sleep(forTimeInterval: 0.2) }
        let raw = toggle.value
        XCTAssertEqual(Self.switchState(raw), on, "\(context): \(String(describing: raw)) (\(raw.map { "\(type(of: $0))" } ?? "nil"))")
    }

    func testSwitchStateAcceptsStringAndNumber() {
        XCTAssertEqual(Self.switchState("1"), true)
        XCTAssertEqual(Self.switchState("0"), false)
        XCTAssertEqual(Self.switchState(NSNumber(value: 1)), true, "number 1 (Build 61) is on")
        XCTAssertEqual(Self.switchState(NSNumber(value: 0)), false)
        XCTAssertEqual(Self.switchState(1), true)
        XCTAssertEqual(Self.switchState(true), true)
        XCTAssertNil(Self.switchState(nil))
        XCTAssertNil(Self.switchState("2"))
        XCTAssertNil(Self.switchState(""))
        XCTAssertNil(Self.switchState(NSNumber(value: 2)))
    }

    private func selectTestPlace(_ app: XCUIApplication) {
        let toggle = app.switches.matching(identifier: "setup-alert-place").firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), "place toggle")
        waitForSwitch(toggle, on: false, timeout: 0, "nothing preselected")
        // The row is a labelled toggle: tap the switch itself (right edge of the row), not the label.
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        waitForSwitch(toggle, on: true, "toggle on")
    }

    /// "Nichts ist vorgewählt" only before a choice; with a place ticked the note is about the pending confirmation.
    private func assertNote(_ app: XCUIApplication, selected: Bool) {
        let none = app.staticTexts["setup-alert-note-none"], pending = app.staticTexts["setup-alert-note-pending"]
        XCTAssertTrue((selected ? pending : none).waitForExistence(timeout: 5), "note for selected=\(selected)")
        XCTAssertFalse((selected ? none : pending).exists, "wrong note for selected=\(selected)")
        if selected { XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Nichts ist vorgewählt'")).firstMatch.exists, "no 'nothing preselected' text with a selection") }
        let text = (selected ? pending : none).label
        XCTAssertEqual(text.contains("Nichts ist vorgewählt"), !selected)
        if selected { XCTAssertEqual(text, "Der Regenhinweis wird erst nach deiner Bestätigung eingeschaltet.") }
    }

    /// Notification state as the app sees it (`auth=` in the `setup-debug` label: unknown, notDetermined, denied, authorized).
    private func authState(_ app: XCUIApplication) -> String {
        let label = app.descendants(matching: .any)["setup-debug"].label
        return label.split(separator: " ").first { $0.hasPrefix("auth=") }.map { String($0.dropFirst(5)) } ?? "?"
    }

    /// Denied state: only the denial message, neither the pending nor the "nothing preselected" note.
    private func assertOnlyDeniedMessage(_ app: XCUIApplication) {
        XCTAssertFalse(app.staticTexts["setup-alert-note-pending"].exists, "no pending note after denial")
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'erst nach deiner Bestätigung'")).firstMatch.exists)
        XCTAssertFalse(app.staticTexts["setup-alert-note-none"].exists, "no 'nothing preselected' note after denial")
    }

    private func assertNothingRegistered(_ app: XCUIApplication, _ context: String) {
        let c = counters(app)
        for key in ["enable", "registers", "installs", "subs", "authRequests", "enabled"] {
            XCTAssertEqual(c[key], 0, "\(key) must stay 0 (\(context)): \(c)")
        }
    }

    private func requestConsentDialog(_ app: XCUIApplication) -> XCUIElement {
        app.buttons["setup-primary"].tap()
        let dialog = app.alerts["Regenhinweis aktivieren?"]
        XCTAssertTrue(dialog.waitForExistence(timeout: 5), "consent dialog")
        return dialog
    }

    // MARK: Walkthrough

    func testWizardWalkthroughWithLaterAndFinish() {
        let app = launch(clean: false)
        XCTAssertTrue(app.staticTexts["Willkommen bei Showers"].waitForExistence(timeout: 30))
        app.buttons["setup-primary"].tap()
        // Optional steps depend on the simulator state; always use "Später" (never answers a system prompt).
        var steps = 0
        while !app.staticTexts["Fertig"].exists, app.buttons["setup-later"].waitForExistence(timeout: 5), steps < 6 {
            steps += 1
            app.buttons["setup-later"].tap()
        }
        XCTAssertTrue(app.staticTexts["Fertig"].waitForExistence(timeout: 5))
        app.buttons["setup-primary"].tap()
        XCTAssertFalse(app.buttons["setup-primary"].waitForExistence(timeout: 2))
    }

    func testSkipAllEndsSetup() {
        let app = launch()
        XCTAssertTrue(app.buttons["setup-skip-all"].waitForExistence(timeout: 30))
        app.buttons["setup-skip-all"].tap()
        XCTAssertFalse(app.buttons["setup-skip-all"].waitForExistence(timeout: 2))
    }

    /// "Einrichtung erneut starten" in the information sheet: the sheet closes and the wizard comes back.
    func testRestartFromInformationSheet() {
        let app = launch()
        XCTAssertTrue(app.buttons["setup-skip-all"].waitForExistence(timeout: 30))
        app.buttons["setup-skip-all"].tap()
        XCTAssertTrue(app.buttons["setup-skip-all"].waitForNonExistence(timeout: 5))
        let info = app.buttons["Datenquellen und Datenschutz"]
        XCTAssertTrue(info.waitForExistence(timeout: 15))
        info.tap()
        XCTAssertTrue(app.navigationBars["Über Showers"].waitForExistence(timeout: 8))
        let restart = app.buttons["setup-restart"]
        for _ in 0..<5 where !restart.isHittable { app.swipeUp() }
        XCTAssertTrue(restart.isHittable, "restart row in the information sheet")
        shot(app, "10a-info-einrichtung")
        restart.tap()
        XCTAssertTrue(app.staticTexts["Willkommen bei Showers"].waitForExistence(timeout: 8), "wizard shown again")
        XCTAssertTrue(app.buttons["setup-skip-all"].isHittable)
        XCTAssertFalse(app.navigationBars["Über Showers"].exists, "information sheet closed")
        shot(app, "10b-neustart-willkommen")
        app.buttons["setup-skip-all"].tap()
        XCTAssertTrue(app.buttons["radar-layer-menu"].waitForExistence(timeout: 8), "back on the radar")
    }

    func testEnglishWelcome() {
        let app = launch(language: .english)
        XCTAssertTrue(app.staticTexts["Welcome to Showers"].waitForExistence(timeout: 30))
        XCTAssertFalse(app.staticTexts["Willkommen bei Showers"].exists)
    }

    // MARK: Screenshots (every step, light and dark)

    func testScreenshotsAllSteps() {
        let app = launch()
        XCTAssertTrue(app.staticTexts["Willkommen bei Showers"].waitForExistence(timeout: 30))
        let welcome = shot(app, "01-willkommen")
        let luminance = UITestLaunch.meanLuminance(welcome.image)
        if appearance == .dark { XCTAssertLessThan(luminance, 0.45, "dark appearance reached the app (\(luminance))") }
        else { XCTAssertGreaterThan(luminance, 0.55, "light appearance (\(luminance))") }
        // One way to skip per screen: welcome has "Überspringen" only, later steps "Später" only.
        XCTAssertTrue(app.buttons["setup-skip-all"].exists)
        XCTAssertFalse(app.buttons["setup-later"].exists)
        app.buttons["setup-primary"].tap()
        XCTAssertTrue(app.staticTexts["Dein Standort"].waitForExistence(timeout: 8), "location step needs a simulator without a location decision")
        shot(app, "02-standort")
        XCTAssertTrue(app.buttons["setup-later"].exists)
        XCTAssertFalse(app.buttons["setup-skip-all"].exists)
        app.buttons["setup-later"].tap()
        XCTAssertTrue(app.staticTexts["Deine Orte"].waitForExistence(timeout: 5))
        shot(app, "03-orte")
        addTestPlaceAndContinue(app)
        // Rain alert: nothing preselected, button off until a place is ticked, then an explicit consent dialog.
        XCTAssertFalse(app.buttons["setup-primary"].isEnabled)
        assertNote(app, selected: false)
        shot(app, "04a-regenhinweis-ohne-auswahl")
        selectTestPlace(app)
        XCTAssertTrue(app.buttons["setup-primary"].isEnabled)
        assertNote(app, selected: true)
        shot(app, "04b-regenhinweis-mit-auswahl")
        let dialog = requestConsentDialog(app)
        shot(app, "04c-zustimmungsdialog")
        dialog.buttons["Abbrechen"].tap()
        XCTAssertTrue(dialog.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Regenhinweis"].exists)
        assertNote(app, selected: true)
        shot(app, "04d-nach-abbrechen")
        XCTAssertEqual(counters(app)["enable"], 0)
        let dialogAgain = requestConsentDialog(app)
        dialogAgain.buttons["Weiter"].tap()
        XCTAssertTrue(app.staticTexts["Fertig"].waitForExistence(timeout: 15))
        shot(app, "05-fertig-nach-zustimmung")
        let c = counters(app)
        XCTAssertEqual(c["enable"], 1)
        XCTAssertEqual(c["enabled"], 1)
    }

    /// Cancel / "Später" path in light and dark: nothing is enabled, nothing goes to the (fake) server.
    func testScreenshotLaterPathEnablesNothing() {
        let app = launch()
        toPlaces(app)
        addTestPlaceAndContinue(app)
        selectTestPlace(app)
        app.buttons["setup-later"].tap()
        XCTAssertTrue(app.staticTexts["Fertig"].waitForExistence(timeout: 5))
        shot(app, "06-fertig-nach-spaeter")
        let c = counters(app)
        XCTAssertEqual(c["enable"], 0)
        XCTAssertEqual(c["enabled"], 0)
        XCTAssertEqual(c["installs"], 0)
        XCTAssertEqual(c["subs"], 0)
        XCTAssertEqual(c["authRequests"], 0)
    }

    // MARK: E2E (complete flow, fake push backend)

    func testE2EConsentFlowCancelThenConfirm() {
        let app = launch()
        toPlaces(app)
        addTestPlaceAndContinue(app)
        XCTAssertFalse(app.buttons["setup-primary"].isEnabled, "no place ticked: button off")
        XCTAssertEqual(counters(app)["enable"], 0)
        selectTestPlace(app)
        let dialog = requestConsentDialog(app)
        XCTAssertTrue(dialog.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Teststadt'")).firstMatch.exists)
        XCTAssertTrue(dialog.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Installationskennung'")).firstMatch.exists)
        dialog.buttons["Abbrechen"].tap()
        XCTAssertTrue(dialog.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Regenhinweis"].exists, "cancel stays on the step")
        var c = counters(app)
        XCTAssertEqual(c["enable"], 0, "Abbrechen must not call push.enable")
        XCTAssertEqual(c["authRequests"], 0)
        XCTAssertEqual(c["subs"], 0)
        XCTAssertEqual(c["installs"], 0, "Abbrechen: no installation registered")
        XCTAssertEqual(c["enabled"], 0)
        let again = requestConsentDialog(app)
        again.buttons["Weiter"].tap()
        XCTAssertTrue(app.staticTexts["Fertig"].waitForExistence(timeout: 15))
        XCTAssertTrue(waitForCounter(app, "subs", 1), "subscription reached the fake server exactly once")
        c = counters(app)
        XCTAssertEqual(c["enable"], 1, "Weiter calls push.enable exactly once")
        XCTAssertEqual(c["enabled"], 1)
        XCTAssertEqual(c["installs"], 1)
        XCTAssertEqual(c["authRequests"], 1)
        app.buttons["setup-primary"].tap()
        XCTAssertFalse(app.buttons["setup-primary"].waitForExistence(timeout: 2))
    }

    func testE2EDeniedPermissionStaysOnStepWithMessage() {
        let app = launch(push: "fakedeny")
        toPlaces(app)
        addTestPlaceAndContinue(app)
        selectTestPlace(app)
        requestConsentDialog(app).buttons["Weiter"].tap()
        XCTAssertTrue(app.staticTexts["Mitteilungen sind für Showers in den Systemeinstellungen ausgeschaltet."].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Regenhinweis"].exists, "denied: stays on the step")
        assertOnlyDeniedMessage(app)
        XCTAssertFalse(app.descendants(matching: .any)["setup-working"].exists, "denied: the waiting indicator is gone")
        XCTAssertTrue(app.buttons["setup-primary"].isEnabled, "denied: the button works again")
        shot(app, "04e-verweigert")
        let c = counters(app)
        XCTAssertEqual(c["enable"], 1)
        XCTAssertEqual(c["enabled"], 0)
        XCTAssertEqual(c["subs"], 0, "denied permission: nothing registered")
        XCTAssertEqual(c["installs"], 0)
    }

    // MARK: First start without a system answer (notificationSettings() never or only late answers)

    /// The coordinator waits at most 2 s for the notification state; the wizard must appear although the status never
    /// answers. Unknown is not consent: the rain alert step is shown, nothing preselected, nothing registered.
    func testFirstStartWithoutSystemAnswerShowsWizard() {
        let app = launch(push: "fakehang")
        let launched = Date()
        XCTAssertTrue(app.staticTexts["Willkommen bei Showers"].waitForExistence(timeout: 6), "wizard within the 2 s deadline (+ margin)")
        let elapsed = Date().timeIntervalSince(launched)
        add(XCTAttachment(string: String(format: "welcome after %.1f s", elapsed)))
        shot(app, "09a-erststart-ohne-systemantwort")
        XCTAssertEqual(authState(app), "unknown")
        toPlaces(app)
        addTestPlaceAndContinue(app)
        waitForSwitch(app.switches.matching(identifier: "setup-alert-place").firstMatch, on: false, timeout: 0, "nothing preselected")
        XCTAssertFalse(app.buttons["setup-primary"].isEnabled)
        assertNote(app, selected: false)
        shot(app, "09b-regenhinweis-ohne-systemantwort")
        XCTAssertEqual(authState(app), "unknown")
        assertNothingRegistered(app, "no system answer")
    }

    /// Build 61: the status never answered, so `push.enable` waited forever (no iOS dialog, button stuck). After the 2 s
    /// deadline the system prompt is asked anyway; the waiting indicator appears and disappears again, the step ends with the
    /// denial message (the fake prompt refuses), nothing is registered.
    func testEnableWithoutSystemStatusAnswerAsksAndStopsWaiting() {
        let app = launch(push: "fakehang")
        toPlaces(app)
        addTestPlaceAndContinue(app)
        selectTestPlace(app)
        requestConsentDialog(app).buttons["Weiter"].tap()
        let spinner = app.descendants(matching: .any)["setup-working"]
        XCTAssertTrue(spinner.waitForExistence(timeout: 2), "waiting indicator appears while the status is awaited")
        shot(app, "10a-warten-ohne-systemantwort")
        XCTAssertTrue(spinner.waitForNonExistence(timeout: 12), "waiting indicator disappears after the deadline")
        XCTAssertTrue(app.staticTexts["Mitteilungen sind für Showers in den Systemeinstellungen ausgeschaltet."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Regenhinweis"].exists, "stays on the step")
        XCTAssertTrue(app.buttons["setup-primary"].isEnabled, "the button works again")
        shot(app, "10b-nach-frist-ohne-systemantwort")
        let c = counters(app)
        XCTAssertEqual(c["enable"], 1)
        XCTAssertEqual(c["authRequests"], 1, "system prompt asked after the deadline: \(c)")
        for key in ["enabled", "registers", "installs", "subs"] { XCTAssertEqual(c[key], 0, "\(key): \(c)") }
    }

    /// Neither the status nor the permission request answers (cold simulator, see Build 61): the indicator still goes away,
    /// the step says that iOS did not answer, nothing is registered.
    func testEnableWhenSystemNeverAnswersEndsWithMessage() {
        let app = launch(push: "fakestuck")
        toPlaces(app)
        addTestPlaceAndContinue(app)
        selectTestPlace(app)
        requestConsentDialog(app).buttons["Weiter"].tap()
        let spinner = app.descendants(matching: .any)["setup-working"]
        XCTAssertTrue(spinner.waitForExistence(timeout: 2), "waiting indicator appears")
        XCTAssertTrue(spinner.waitForNonExistence(timeout: 20), "waiting indicator disappears although nothing answers")
        XCTAssertTrue(app.staticTexts[Self.noAnswer].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Regenhinweis"].exists, "stays on the step")
        XCTAssertTrue(app.buttons["setup-primary"].isEnabled, "the button works again")
        shot(app, "11-ios-antwortet-nicht")
        let c = counters(app)
        XCTAssertEqual(c["authRequests"], 1, "\(c)")
        for key in ["enabled", "registers", "installs", "subs"] { XCTAssertEqual(c[key], 0, "\(key): \(c)") }
    }

    private static let noAnswer = "iOS hat nicht auf die Anfrage nach Mitteilungen geantwortet. Bitte versuche es gleich noch einmal."

    /// The status answers "allowed" only after 6 s (after the deadline): the state updates, but nothing is ticked or enabled.
    func testLateSystemAnswerKeepsNoConsent() {
        let app = launch(push: "fakelate")
        XCTAssertTrue(app.staticTexts["Willkommen bei Showers"].waitForExistence(timeout: 5), "wizard before the late answer")
        toPlaces(app)
        addTestPlaceAndContinue(app)
        let deadline = Date().addingTimeInterval(15)
        while authState(app) != "authorized", Date() < deadline { Thread.sleep(forTimeInterval: 0.5) }
        XCTAssertEqual(authState(app), "authorized", "late answer arrived")
        XCTAssertTrue(app.staticTexts["Regenhinweis"].exists)
        waitForSwitch(app.switches.matching(identifier: "setup-alert-place").firstMatch, on: false, timeout: 0, "late answer ticks nothing")
        XCTAssertFalse(app.buttons["setup-primary"].isEnabled)
        assertNote(app, selected: false)
        assertNothingRegistered(app, "late answer")
    }

    /// Real `UNUserNotificationCenter` on the first launch of a fresh install (run first after `simctl erase`): the wizard
    /// must appear without a relaunch. Attaches when (if at all) the real status answered, as evidence for the cause.
    func testSystemFirstLaunchShowsWizardWithoutRelaunch() {
        let app = launch(push: "system")
        let launched = Date()
        XCTAssertTrue(app.staticTexts["Willkommen bei Showers"].waitForExistence(timeout: 8), "wizard on the first launch without relaunch")
        var log = [String(format: "welcome after %.1f s, auth=%@", Date().timeIntervalSince(launched), authState(app))]
        var last = authState(app)
        while Date().timeIntervalSince(launched) < 30 {
            let now = authState(app)
            if now != last { log.append(String(format: "%.1f s: auth=%@", Date().timeIntervalSince(launched), now)); last = now }
            Thread.sleep(forTimeInterval: 0.5)
        }
        log.append("after 30 s: auth=\(last)")
        let text = log.joined(separator: "\n")
        let attachment = XCTAttachment(string: text)
        attachment.name = "system-auth-timeline"
        attachment.lifetime = .keepAlways
        add(attachment)
        print("SYSTEM-AUTH-TIMELINE\n\(text)")
        assertNothingRegistered(app, "system first launch")
    }

    // MARK: E2E with the real iOS permission dialogs (fake backend, real system prompts)

    private func answerSystemAlert(preferring labels: [String], exact: Bool = false, timeout: TimeInterval = 15, name: String) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let alert = springboard.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: timeout), "system dialog \(name)")
        shot(springboard, name)
        for label in labels {
            let button = alert.buttons.matching(NSPredicate(format: exact ? "label ==[c] %@" : "label CONTAINS[c] %@", label)).firstMatch
            if button.exists { button.tap(); return }
        }
        XCTFail("no button matching \(labels) in system dialog \(name): \(alert.debugDescription)")
    }

    /// Needs a simulator where Showers has no location and no notification decision (fresh install).
    func testE2ESystemDialogsLocationAndNotifications() {
        let app = launchSystem()
        XCTAssertTrue(app.staticTexts["Willkommen bei Showers"].waitForExistence(timeout: 30))
        app.buttons["setup-primary"].tap()
        XCTAssertTrue(app.staticTexts["Dein Standort"].waitForExistence(timeout: 8), "needs undecided location")
        app.buttons["setup-primary"].tap()
        answerSystemAlert(preferring: ["While Using", "Verwenden", "Allow", "Erlauben"], name: "07a-system-standort")
        XCTAssertTrue(app.staticTexts["Deine Orte"].waitForExistence(timeout: 15))
        addTestPlaceAndContinue(app)
        selectTestPlace(app)
        let dialog = requestConsentDialog(app)
        // Before consent no system dialog may be up.
        XCTAssertFalse(XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch.exists)
        dialog.buttons["Weiter"].tap()
        answerSystemAlert(preferring: ["Allow", "Erlauben"], exact: true, name: "07b-system-mitteilungen")
        XCTAssertTrue(app.staticTexts["Fertig"].waitForExistence(timeout: 15))
        XCTAssertTrue(waitForCounter(app, "subs", 1))
        let c = counters(app)
        XCTAssertEqual(c["enable"], 1)
        XCTAssertEqual(c["enabled"], 1)
        shot(app, "07c-fertig-nach-system-zustimmung")
    }

    func testE2ESystemNotificationDenied() {
        let app = launchSystem()
        toPlaces(app)
        addTestPlaceAndContinue(app)
        selectTestPlace(app)
        requestConsentDialog(app).buttons["Weiter"].tap()
        // An open system dialog is never timed out: leave it longer than the 5 s limit for a missing answer.
        XCTAssertTrue(XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch.waitForExistence(timeout: 15), "system dialog")
        Thread.sleep(forTimeInterval: 9)
        XCTAssertTrue(app.descendants(matching: .any)["setup-working"].exists, "still waiting while the dialog is open")
        XCTAssertFalse(app.staticTexts[Self.noAnswer].exists, "no give-up behind an open dialog")
        answerSystemAlert(preferring: ["Don’t Allow", "Don't Allow", "Nicht erlauben"], exact: true, name: "08a-system-mitteilungen-nein")
        XCTAssertTrue(app.staticTexts["Mitteilungen sind für Showers in den Systemeinstellungen ausgeschaltet."].waitForExistence(timeout: 10))
        assertOnlyDeniedMessage(app)
        let c = counters(app)
        XCTAssertEqual(c["enabled"], 0)
        XCTAssertEqual(c["subs"], 0)
        XCTAssertEqual(c["installs"], 0)
    }
}

/// Same tests in dark appearance (mean luminance of the welcome screen is checked).
@MainActor
final class SetupWizardDarkTests: SetupWizardTests {
    override var appearance: XCUIDevice.Appearance { .dark }
}
