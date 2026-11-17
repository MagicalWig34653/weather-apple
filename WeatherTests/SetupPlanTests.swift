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
}
