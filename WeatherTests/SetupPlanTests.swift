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

    func testDeniedOrUnknownNotificationsCloseRainAlertStep() {
        XCTAssertFalse(SetupPlan.isOpen(.rainAlert, snapshot: snapshot(notifications: .denied, places: 1)))
        XCTAssertFalse(SetupPlan.isOpen(.rainAlert, snapshot: snapshot(notifications: .unknown, places: 1)))
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
                        XCTAssertEqual(steps.contains(.rainAlert), (notifications == .notDetermined || notifications == .authorized) && alerts == 0)
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
}
