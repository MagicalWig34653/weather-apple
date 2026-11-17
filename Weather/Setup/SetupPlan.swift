import CoreLocation
import Foundation

/// Setup wizard logic (pure, no UI). Which steps are open follows from the permission state and the stored `setupVersion`.
enum SetupStep: String, CaseIterable, Sendable {
    case welcome, location, places, rainAlert, done

    /// Setup version in which the step was introduced; a later version only shows newer steps to people who finished earlier.
    var introducedInVersion: Int { 1 }
}

enum SetupLocationState: Equatable, Sendable {
    case notDetermined, allowed, denied

    init(_ status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined: self = .notDetermined
        case .authorizedWhenInUse, .authorizedAlways: self = .allowed
        case .denied, .restricted: self = .denied
        @unknown default: self = .denied
        }
    }
}

struct SetupSnapshot: Equatable, Sendable {
    var location: SetupLocationState
    var notifications: PushAuthorization
    var savedPlaceCount: Int
    var rainAlertCount: Int
}

enum SetupMode: Equatable, Sendable {
    /// Clean install: welcome, all open steps, finish.
    case firstRun
    /// Existing user (TestFlight) without `setupVersion`: only the open steps.
    case migration
    /// `setupVersion` is older than the current one: only open steps introduced later.
    case update(from: Int)
    /// Restarted from the information sheet: framed like the first run.
    case manual
}

enum SetupDecision: Equatable, Sendable {
    case show(mode: SetupMode, steps: [SetupStep])
    case alreadyDone
    /// Existing user, nothing left to ask: mark as completed silently.
    case nothingOpen
}

enum SetupPlan {
    static let currentVersion = 1

    static func isOpen(_ step: SetupStep, snapshot: SetupSnapshot) -> Bool {
        switch step {
        case .welcome, .done: false
        case .location: snapshot.location == .notDetermined
        case .places: snapshot.savedPlaceCount == 0
        case .rainAlert: (snapshot.notifications == .notDetermined || snapshot.notifications == .authorized) && snapshot.rainAlertCount == 0
        }
    }

    /// Anything already decided or in use means the person is not a clean install.
    static func isExistingUser(_ snapshot: SetupSnapshot) -> Bool {
        snapshot.savedPlaceCount > 0 || snapshot.rainAlertCount > 0 || snapshot.location != .notDetermined
            || snapshot.notifications == .denied || snapshot.notifications == .authorized
    }

    static func steps(mode: SetupMode, snapshot: SetupSnapshot, version: Int = currentVersion,
                      introduced: (SetupStep) -> Int = { $0.introducedInVersion }) -> [SetupStep] {
        let open = [SetupStep.location, .places, .rainAlert].filter { isOpen($0, snapshot: snapshot) }
        switch mode {
        case .firstRun, .manual: return [.welcome] + open + [.done]
        case .migration: return open
        case .update(let from): return open.filter { introduced($0) > from && introduced($0) <= version }
        }
    }

    static func decide(completedVersion: Int, snapshot: SetupSnapshot) -> SetupDecision {
        guard completedVersion < currentVersion else { return .alreadyDone }
        let mode: SetupMode = completedVersion > 0 ? .update(from: completedVersion)
            : (isExistingUser(snapshot) ? .migration : .firstRun)
        let list = steps(mode: mode, snapshot: snapshot)
        return list.isEmpty ? .nothingOpen : .show(mode: mode, steps: list)
    }
}

/// Persisted `setupVersion` (0 = never completed). UI tests set it through the launch argument `-setupVersion <n>`.
struct SetupProgress {
    static let key = "setupVersion"
    let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    var completedVersion: Int { defaults.integer(forKey: Self.key) }
    func markCompleted() { defaults.set(SetupPlan.currentVersion, forKey: Self.key) }
    func reset() { defaults.removeObject(forKey: Self.key) }
}
