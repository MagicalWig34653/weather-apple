import CoreLocation
import Observation

/// Decides at launch whether the setup wizard is shown and carries its steps. No analytics: nothing about
/// skipped or aborted runs is recorded; only the finished `setupVersion` is stored on the device.
@MainActor @Observable
final class SetupCoordinator {
    private(set) var steps: [SetupStep] = []
    private(set) var mode: SetupMode = .firstRun
    var isPresented = false
    @ObservationIgnored private let progress: SetupProgress
    @ObservationIgnored private var evaluated = false

    init(progress: SetupProgress = SetupProgress()) { self.progress = progress }

    /// UI tests (all pass `-AppleLanguages`) never see the wizard unless they ask for it with `-UITestSetup`.
    static var suppressedForUITests: Bool {
        #if DEBUG
        let args = CommandLine.arguments
        if args.contains("-UITestSetup") { return false }
        return args.contains("-AppleLanguages")
        #else
        return false
        #endif
    }

    /// The status is a local query that normally answers within a fraction of a second; 2 s keeps the first screen quick
    /// while leaving room for a slow cold start. On timeout the state stays unknown (rain alert step shown, nothing assumed).
    static let authorizationDeadline: @Sendable () async -> Void = { try? await Task.sleep(for: .seconds(2)) }

    static func snapshot(store: WeatherStore, push: PushManager) -> SetupSnapshot {
        SetupSnapshot(location: SetupLocationState(CLLocationManager().authorizationStatus), notifications: push.authorization,
                      savedPlaceCount: store.places.count, rainAlertCount: push.enabledCount)
    }

    /// Once per launch, after the notification state is known.
    func evaluate(store: WeatherStore, push: PushManager, deadline: @escaping @Sendable () async -> Void = SetupCoordinator.authorizationDeadline) async {
        guard !evaluated, !Self.suppressedForUITests else { return }
        evaluated = true
        // At most `deadline` (2 s): a missing system answer must not keep the wizard away (unknown is shown, not consent).
        await push.refreshAuthorization(until: deadline)
        #if DEBUG
        PushUITestStub.cleanPlaces(store)
        if CommandLine.arguments.contains("-UITestSetup") {
            // The shared simulator keeps permission and place state; tests get the framed flow regardless.
            progress.reset()
            restart(store: store, push: push)
            return
        }
        #endif
        switch SetupPlan.decide(completedVersion: progress.completedVersion, snapshot: Self.snapshot(store: store, push: push)) {
        case .show(let mode, let steps): present(mode: mode, steps: steps)
        case .nothingOpen: progress.markCompleted()
        case .alreadyDone: break
        }
    }

    /// "Einrichtung erneut starten" in the information sheet.
    func restart(store: WeatherStore, push: PushManager) {
        let steps = SetupPlan.steps(mode: .manual, snapshot: Self.snapshot(store: store, push: push))
        present(mode: .manual, steps: steps)
    }

    func finish() {
        progress.markCompleted()
        isPresented = false
    }

    private func present(mode: SetupMode, steps: [SetupStep]) {
        self.mode = mode
        self.steps = steps
        isPresented = true
    }
}
