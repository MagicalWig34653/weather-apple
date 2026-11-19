import XCTest
import CoreLocation
@testable import Weather

final class SetupPlanTests: XCTestCase {
    private func snapshot(location: SetupLocationState = .notDetermined, notifications: PushAuthorization = .notDetermined,
                          places: Int = 0, alerts: Int = 0) -> SetupSnapshot {
        SetupSnapshot(location: location, notifications: notifications, savedPlaceCount: places, rainAlertCount: alerts)
    }

    // MARK: Erststart

    func testFreshInstallShowsAllFiveSteps() {
        let decision = SetupPlan.decide(completedVersion: 0, snapshot: snapshot())
        XCTAssertEqual(decision, .show(mode: .firstRun, steps: [.welcome, .location, .places, .rainAlert, .done]))
    }

    func testAnyDecidedPermissionCountsAsExistingUser() {
        // Schon entschiedene Schritte fallen weg; wer etwas entschieden hat, ist kein Erststart mehr.
        let decision = SetupPlan.decide(completedVersion: 0, snapshot: snapshot(location: .denied))
        XCTAssertEqual(decision, .show(mode: .migration, steps: [.places, .rainAlert]))
    }

    func testCompletedCurrentVersionNeverShows() {
        XCTAssertEqual(SetupPlan.decide(completedVersion: SetupPlan.currentVersion, snapshot: snapshot()), .alreadyDone)
        XCTAssertEqual(SetupPlan.decide(completedVersion: 99, snapshot: snapshot()), .alreadyDone)
    }

    // MARK: Migration bestehender TestFlight-Nutzer

    func testExistingUserWithPlaceAndLocationSeesOnlyRainAlert() {
        let decision = SetupPlan.decide(completedVersion: 0, snapshot: snapshot(location: .allowed, places: 2))
        XCTAssertEqual(decision, .show(mode: .migration, steps: [.rainAlert]))
    }

    func testExistingUserWithEverythingDecidedOrActiveHasNothingOpen() {
        let active = snapshot(location: .allowed, notifications: .authorized, places: 1, alerts: 1)
        XCTAssertEqual(SetupPlan.decide(completedVersion: 0, snapshot: active), .nothingOpen)
        let denied = snapshot(location: .denied, notifications: .denied, places: 1)
        XCTAssertEqual(SetupPlan.decide(completedVersion: 0, snapshot: denied), .nothingOpen)
    }

    func testExistingUserWithoutPlacesGetsPlacesStep() {
        let decision = SetupPlan.decide(completedVersion: 0, snapshot: snapshot(location: .allowed, notifications: .denied))
        XCTAssertEqual(decision, .show(mode: .migration, steps: [.places]))
    }

    func testAuthorizedNotificationsWithoutSubscriptionKeepsRainAlertOpen() {
        let decision = SetupPlan.decide(completedVersion: 0, snapshot: snapshot(location: .allowed, notifications: .authorized, places: 1))
        XCTAssertEqual(decision, .show(mode: .migration, steps: [.rainAlert]))
    }

    /// „Unbekannt“ (Systemabfrage hat nicht rechtzeitig geantwortet) ist keine Ablehnung: der Schritt bleibt offen.
    func testDeniedClosesButUnknownKeepsRainAlertStep() {
        XCTAssertFalse(SetupPlan.isOpen(.rainAlert, snapshot: snapshot(notifications: .denied, places: 1)))
        XCTAssertTrue(SetupPlan.isOpen(.rainAlert, snapshot: snapshot(notifications: .unknown, places: 1)))
        XCTAssertTrue(SetupPlan.isOpen(.rainAlert, snapshot: snapshot(notifications: .notDetermined, places: 1)))
    }

    func testMigrationNeverShowsWelcomeOrDone() {
        let decision = SetupPlan.decide(completedVersion: 0, snapshot: snapshot(location: .allowed, places: 1))
        guard case .show(_, let steps) = decision else { return XCTFail("expected steps") }
        XCTAssertFalse(steps.contains(.welcome))
        XCTAssertFalse(steps.contains(.done))
    }

    // MARK: Neue Schritte in späteren Versionen

    func testHigherVersionShowsOnlyStepsIntroducedLater() {
        let steps = SetupPlan.steps(mode: .update(from: 1), snapshot: snapshot(), version: 2, introduced: { $0 == .rainAlert ? 2 : 1 })
        XCTAssertEqual(steps, [.rainAlert])
    }

    func testDecideTreatsOlderCompletedVersionAsUpdate() {
        // Mit currentVersion 1 gibt es noch kein "älter als aktuell, aber > 0".
        XCTAssertEqual(SetupPlan.currentVersion, 1)
    }

    // MARK: Manueller Neustart

    func testManualRestartAlwaysFramesWithWelcomeAndDone() {
        let all = snapshot(location: .allowed, notifications: .authorized, places: 1, alerts: 1)
        XCTAssertEqual(SetupPlan.steps(mode: .manual, snapshot: all), [.welcome, .done])
        XCTAssertEqual(SetupPlan.steps(mode: .manual, snapshot: snapshot()), [.welcome, .location, .places, .rainAlert, .done])
    }

    // MARK: Schrittfunktion je Kombination

    func testStepsMatchRulesForEveryCombination() {
        for location in [SetupLocationState.notDetermined, .allowed, .denied] {
            for notifications in [PushAuthorization.unknown, .notDetermined, .denied, .authorized] {
                for places in [0, 1] {
                    for alerts in [0, 1] {
                        let s = snapshot(location: location, notifications: notifications, places: places, alerts: alerts)
                        let steps = SetupPlan.steps(mode: .firstRun, snapshot: s)
                        XCTAssertEqual(steps.first, .welcome)
                        XCTAssertEqual(steps.last, .done)
                        XCTAssertEqual(steps.contains(.location), location == .notDetermined)
                        XCTAssertEqual(steps.contains(.places), places == 0)
                        // Unknown (no system answer in time) keeps the step; only a refusal closes it.
                        XCTAssertEqual(steps.contains(.rainAlert), notifications != .denied && alerts == 0)
                    }
                }
            }
        }
    }

    // MARK: Speicherung

    func testProgressStoresVersionInDefaults() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "SetupPlanTests-\(UUID().uuidString)"))
        let progress = SetupProgress(defaults: defaults)
        XCTAssertEqual(progress.completedVersion, 0)
        progress.markCompleted()
        XCTAssertEqual(progress.completedVersion, SetupPlan.currentVersion)
        XCTAssertEqual(defaults.integer(forKey: "setupVersion"), SetupPlan.currentVersion)
        progress.reset()
        XCTAssertEqual(progress.completedVersion, 0)
    }

    func testLocationStateMapsAuthorizationStatus() {
        XCTAssertEqual(SetupLocationState(.notDetermined), .notDetermined)
        XCTAssertEqual(SetupLocationState(.authorizedWhenInUse), .allowed)
        XCTAssertEqual(SetupLocationState(.authorizedAlways), .allowed)
        XCTAssertEqual(SetupLocationState(.denied), .denied)
        XCTAssertEqual(SetupLocationState(.restricted), .denied)
    }

    // MARK: Regenhinweis nur mit ausdrücklicher Zustimmung

    func testConsentStartsEmptyAndCannotRequest() {
        let consent = SetupAlertConsent()
        XCTAssertTrue(consent.selected.isEmpty)
        XCTAssertFalse(consent.canRequest)
        XCTAssertFalse(consent.confirmed)
    }

    @MainActor func testEnableNeverCalledWithoutConfirmation() async {
        var consent = SetupAlertConsent()
        let id = UUID()
        consent.set(id, on: true)
        var calls = 0
        let enabled = await consent.enableConfirmed(in: [id]) { _ in calls += 1; return true }
        XCTAssertEqual(enabled, 0)
        XCTAssertEqual(calls, 0)
    }

    @MainActor func testConfirmWithoutSelectionDoesNothing() async {
        var consent = SetupAlertConsent()
        consent.confirm()
        XCTAssertFalse(consent.confirmed)
    }

    @MainActor func testEnableOnlyForSelectedPlacesAfterConfirmation() async {
        var consent = SetupAlertConsent()
        let a = UUID(), b = UUID(), c = UUID()
        consent.set(a, on: true)
        consent.set(c, on: true)
        consent.confirm()
        var called: [UUID] = []
        let enabled = await consent.enableConfirmed(in: [a, b, c]) { called.append($0); return true }
        XCTAssertEqual(enabled, 2)
        XCTAssertEqual(called, [a, c])
    }

    @MainActor func testChangingSelectionRevokesConfirmation() async {
        var consent = SetupAlertConsent()
        let a = UUID(), b = UUID()
        consent.set(a, on: true)
        consent.confirm()
        consent.set(b, on: true)
        XCTAssertFalse(consent.confirmed)
        var calls = 0
        _ = await consent.enableConfirmed(in: [a, b]) { _ in calls += 1; return true }
        XCTAssertEqual(calls, 0)
    }

    func testAtMostThreePlaces() {
        var consent = SetupAlertConsent()
        for _ in 0..<5 { consent.set(UUID(), on: true) }
        XCTAssertEqual(consent.selected.count, 3)
    }

    @MainActor func testDeselectingEverythingAfterConfirmationNeverEnables() async {
        var consent = SetupAlertConsent()
        let a = UUID()
        consent.set(a, on: true)
        consent.confirm()
        consent.set(a, on: false)
        XCTAssertFalse(consent.canRequest)
        XCTAssertFalse(consent.confirmed)
        consent.confirm()
        XCTAssertFalse(consent.confirmed)
        var calls = 0
        let enabled = await consent.enableConfirmed(in: [a]) { _ in calls += 1; return true }
        XCTAssertEqual(enabled, 0)
        XCTAssertEqual(calls, 0)
    }

    @MainActor func testEnableCountsOnlySuccessfulPlaces() async {
        var consent = SetupAlertConsent()
        let a = UUID(), b = UUID()
        consent.set(a, on: true)
        consent.set(b, on: true)
        consent.confirm()
        let enabled = await consent.enableConfirmed(in: [a, b]) { $0 == a }
        XCTAssertEqual(enabled, 1)
    }

    // MARK: Texte (kein stilles Überspringen: fehlendes Bundle oder Schlüssel macht den Test rot)

    private func strings(_ lang: String) throws -> [String: String] {
        let bundlePath = try XCTUnwrap(Bundle.main.path(forResource: lang, ofType: "lproj"), "\(lang).lproj not found in the app bundle")
        let path = try XCTUnwrap(Bundle(path: bundlePath)?.path(forResource: "Localizable", ofType: "strings"), "Localizable.strings (\(lang)) not found")
        return try XCTUnwrap(NSDictionary(contentsOfFile: path) as? [String: String], "Localizable.strings (\(lang)) unreadable")
    }

    func testPrivacyTextsNoLongerClaimLocationStaysOnDevice() throws {
        for lang in ["de", "en"] {
            let dict = try strings(lang)
            let location = try XCTUnwrap(dict["SETUP_LOCATION_BODY"], lang)
            XCTAssertFalse(location.contains(lang == "de" ? "bleibt auf dem Gerät" : "stays on the device"), lang)
            XCTAssertTrue(location.contains(lang == "de" ? "Deutschen Wetterdienst" : "German Weather Service"), lang)
            let alert = try XCTUnwrap(dict["SETUP_ALERT_BODY"], lang)
            XCTAssertTrue(alert.contains(lang == "de" ? "Installationskennung" : "installation ID"), lang)
            XCTAssertTrue(alert.contains(lang == "de" ? "ausschalten" : "turn this off"), lang)
        }
    }

    /// Alle Einwilligungstexte nennen Installationskennung, Widerruf (Ausschalten, Löschen) und den Knopf „Weiter“.
    func testAllConsentTextsMentionInstallationIDAndWithdrawal() throws {
        for lang in ["de", "en"] {
            let dict = try strings(lang)
            let button = try XCTUnwrap(dict["PUSH_CONTINUE"], lang)
            for key in ["PUSH_PLACE_CONFIRM_MESSAGE", "REGION_EXPLANATION", "SETUP_ALERT_CONFIRM_MESSAGE"] {
                let text = try XCTUnwrap(dict[key], "\(key) \(lang)")
                XCTAssertTrue(text.contains(lang == "de" ? "zufällige Installationskennung" : "random installation ID"), "\(key) \(lang)")
                XCTAssertTrue(text.contains(lang == "de" ? "widerruft das jederzeit und löscht die Daten auf dem Server" : "withdraws consent at any time and deletes the data on the server"), "\(key) \(lang)")
                XCTAssertTrue(text.contains(lang == "de" ? "„\(button)“ willigst du ein" : "“\(button)” you consent"), "\(key) \(lang)")
                XCTAssertTrue(text.contains(lang == "de" ? "Gerätetoken" : "device token"), "\(key) \(lang)")
            }
            for key in ["PUSH_PLACE_CONFIRM_MESSAGE", "SETUP_ALERT_CONFIRM_MESSAGE"] {
                let text = try XCTUnwrap(dict[key], key)
                XCTAssertTrue(text.contains("0,7 km") || text.contains("0.7 km"), "\(key) \(lang): Rasterzelle")
            }
        }
    }

    func testPendingNoteExistsAndDiffersFromNothingPreselectedNote() throws {
        for lang in ["de", "en"] {
            let dict = try strings(lang)
            let pending = try XCTUnwrap(dict["SETUP_ALERT_PENDING_NOTE"], lang)
            let none = try XCTUnwrap(dict["SETUP_ALERT_PROMPT_NOTE"], lang)
            XCTAssertNotEqual(pending, none, lang)
            XCTAssertTrue(pending.contains(lang == "de" ? "Bestätigung" : "confirm"), lang)
            XCTAssertFalse(pending.contains(lang == "de" ? "vorgewählt" : "preselected"), lang)
            XCTAssertTrue(none.contains(lang == "de" ? "vorgewählt" : "preselected"), lang)
        }
    }

    /// „Regenhinweis“ überall gleich; „Warnung“ bleibt den amtlichen DWD-Warnungen vorbehalten.
    func testRainAlertTitleIsConsistent() throws {
        let titles = ["de": "Regenhinweis", "en": "Rain alert"]
        for (lang, title) in titles {
            let dict = try strings(lang)
            XCTAssertEqual(dict["SETUP_ALERT_TITLE"], title, lang)
            XCTAssertEqual(dict["PUSH_PLACE_CONFIRM_TITLE"], lang == "de" ? "Regenhinweis aktivieren?" : "Enable Rain Alert?", lang)
            for (key, value) in dict where key.hasPrefix("SETUP_") {
                XCTAssertFalse(value.contains("Regenwarnung") || value.localizedCaseInsensitiveContains("rain warning"), "\(key) \(lang)")
            }
        }
    }

    /// Von Lino am 19.11.2026 freigegebener Wortlaut (de) der drei gezeigten Zustände: Regenhinweis ohne Vorauswahl,
    /// Zustimmungsdialog „Regenhinweis aktivieren?“, Ansicht nach Ablehnung (Ablehnungshinweis). Eine Änderung macht den Test
    /// rot und braucht eine neue Freigabe. Nicht eingefroren (nicht freigegeben): englische Texte, SETUP_LOCATION_BODY, REGION_EXPLANATION, PUSH_PLACE_CONFIRM_MESSAGE.
    func testApprovedGermanWordingOfThreeShownStatesIsFrozen() throws {
        let dict = try strings("de")
        let approved: [String: String] = [
            "SETUP_ALERT_TITLE": "Regenhinweis",
            "SETUP_ALERT_BODY": "Wir melden dir, wenn an deinem Ort Regen beginnt. Dafür gehen an den Showers-Server das Gerätetoken, eine zufällige Installationskennung, die Rasterzelle des Radarbildes (etwa 0,7 km Kantenlänge) sowie Schwelle und Vorlaufzeit. Kein genauer Standort, kein Ortsname, kein Konto. Du kannst das jederzeit ausschalten; dann werden die Daten auf dem Server gelöscht.",
            "SETUP_ALERT_GERMANY": "Bisher nur für Orte in Deutschland.",
            "SETUP_ALERT_CHOOSE": "Für welche Orte?",
            "SETUP_ALERT_PROMPT_NOTE": "Nichts ist vorgewählt. Erst nach deiner Zustimmung fragt iOS, ob Showers Mitteilungen senden darf.",
            "SETUP_ALERT_ENABLE": "Regenhinweis einschalten",
            "PUSH_PLACE_CONFIRM_TITLE": "Regenhinweis aktivieren?",
            "SETUP_ALERT_CONFIRM_MESSAGE": "Showers meldet dir per Mitteilung, wenn es bei %@ bald zu regnen beginnt. Dafür gehen an den Showers-Server: das Gerätetoken, eine zufällige Installationskennung, die Rasterzelle des Radarbildes (Kantenlänge etwa 0,7 km, keine Koordinaten), Schwelle und Vorlaufzeit; kein Konto. Mit „Weiter“ willigst du ein. Ausschalten widerruft das jederzeit und löscht die Daten auf dem Server. Danach fragt iOS, ob Mitteilungen erlaubt sind.",
            "PUSH_CONTINUE": "Weiter",
            "PUSH_READ_PRIVACY": "Datenschutzerklärung lesen",
            "COMMON_CANCEL": "Abbrechen",
            "PUSH_MSG_DENIED": "Mitteilungen sind für Showers in den Systemeinstellungen ausgeschaltet.",
        ]
        for (key, text) in approved { XCTAssertEqual(dict[key], text, key) }
    }
}

// MARK: Erststart ohne Systemantwort (notificationSettings antwortet nicht)

/// One-shot gate: `wait()` suspends until `open()` (controlled time instead of real sleeping).
private actor Gate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    func wait() async {
        if isOpen { return }
        await withCheckedContinuation { waiters.append($0) }
    }
    func open() { isOpen = true; waiters.forEach { $0.resume() }; waiters = [] }
}

/// Status answers only when the test says so (or never); a prompt is never allowed.
private final class SilentAuthorizer: PushAuthorizing, @unchecked Sendable {
    let gate = Gate()
    private let lock = NSLock()
    private var answer: PushAuthorization = .unknown
    private(set) var prompts = 0
    func status() async -> PushAuthorization {
        await gate.wait()
        return lock.withLock { answer }
    }
    func requestAuthorization() async -> Bool { lock.withLock { prompts += 1 }; return false }
    func answerLate(_ value: PushAuthorization) async {
        lock.withLock { answer = value }
        await gate.open()
    }
}

@MainActor
final class SetupCoordinatorStartTests: XCTestCase {
    private var suite = ""

    override func setUp() { suite = "setup-start-\(UUID().uuidString)" }
    override func tearDown() { UserDefaults().removePersistentDomain(forName: suite) }

    private func make() -> (SetupCoordinator, WeatherStore, PushManager, SilentAuthorizer, FakeRegistrar, FakeGateway) {
        let defaults = UserDefaults(suiteName: suite)!
        let store = WeatherStore(client: DWDClient(transport: { _ in throw URLError(.notConnectedToInternet) }),
                                 defaults: defaults, reloadWidgets: {})
        let authorizer = SilentAuthorizer(), registrar = FakeRegistrar(), gateway = FakeGateway()
        let push = PushManager(gateway: gateway, secrets: FakeSecrets(), authorizer: authorizer, registrar: registrar,
                               defaults: defaults, environment: .sandbox, locale: "de")
        return (SetupCoordinator(progress: SetupProgress(defaults: defaults)), store, push, authorizer, registrar, gateway)
    }

    private func waitUntil(_ condition: @MainActor () -> Bool, seconds: Double = 5) async -> Bool {
        let end = Date().addingTimeInterval(seconds)
        while Date() < end {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return condition()
    }

    /// Echter Startpfad: `evaluate` wartet auf die Systemabfrage höchstens bis zur Frist; danach erscheint der Assistent
    /// mit Regenhinweis-Schritt, ohne Zustimmung anzunehmen und ohne irgendetwas zu registrieren.
    func testWizardAppearsAtDeadlineWhenNotificationStatusNeverAnswers() async {
        let (coordinator, store, push, authorizer, registrar, gateway) = make()
        let deadline = Gate()
        let run = Task { await coordinator.evaluate(store: store, push: push, deadline: { await deadline.wait() }) }
        try? await Task.sleep(for: .milliseconds(100))
        XCTAssertFalse(coordinator.isPresented, "before the deadline the wizard waits for the system answer")
        await deadline.open()
        let shown = await waitUntil({ coordinator.isPresented })
        XCTAssertTrue(shown, "wizard appears once the deadline passed although the system never answered")
        XCTAssertTrue(coordinator.steps.contains(.rainAlert), "unknown state keeps the rain alert step")
        XCTAssertEqual(push.authorization, .unknown, "no consent assumed")
        XCTAssertEqual(registrar.registered, 0)
        XCTAssertEqual(push.enabledCount, 0)
        XCTAssertEqual(authorizer.prompts, 0)
        XCTAssertTrue(gateway.calls.isEmpty, "nothing registered on the server: \(gateway.calls)")
        run.cancel()
        await authorizer.answerLate(.notDetermined)
    }

    /// Verspätete Systemantwort („erlaubt“) nach der Frist: Zustand wird aktualisiert, aber nichts eingeschaltet oder registriert.
    func testLateSystemAnswerEnablesNothing() async {
        let (coordinator, store, push, authorizer, registrar, gateway) = make()
        await coordinator.evaluate(store: store, push: push, deadline: {})
        XCTAssertTrue(coordinator.isPresented)
        let steps = coordinator.steps
        await authorizer.answerLate(.authorized)
        let updated = await waitUntil({ push.authorization == .authorized })
        XCTAssertTrue(updated, "late answer still lands in the state")
        XCTAssertEqual(coordinator.steps, steps, "late answer does not rebuild the shown wizard")
        XCTAssertEqual(registrar.registered, 0, "late answer registers nothing")
        XCTAssertEqual(push.enabledCount, 0)
        XCTAssertEqual(authorizer.prompts, 0)
        XCTAssertTrue(gateway.calls.isEmpty, "\(gateway.calls)")
    }

    /// Antwortet das System rechtzeitig, gilt seine Antwort (kein Warten bis zur Frist).
    func testTimelyAnswerIsUsedWithoutWaitingForDeadline() async {
        let (coordinator, store, push, authorizer, _, _) = make()
        await authorizer.answerLate(.denied)
        await coordinator.evaluate(store: store, push: push, deadline: { try? await Task.sleep(for: .seconds(3600)) })
        XCTAssertEqual(push.authorization, .denied)
        XCTAssertFalse(coordinator.steps.contains(.rainAlert), "denied closes the rain alert step")
    }
}
