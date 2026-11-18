#if DEBUG
import CoreLocation
import Foundation
import MapKit

/// UI tests only (Debug builds): `-UITestPush fake|fakedeny|system` replaces the push backend with an in-memory fake so a
/// test can walk the whole opt-in without ever contacting the Showers server (no installation, no subscription, no token upload).
/// - `fake`: the iOS permission prompt is replaced by an automatic "allowed".
/// - `fakedeny`: the permission prompt is replaced by an automatic "not allowed".
/// - `system`: the real iOS permission prompt is shown (answered by the test); everything else stays fake.
/// `-UITestSetupClean` deletes all saved places before the wizard starts (so the places step is open); typing "Teststadt" into
/// the wizard's search then offers one fixed result (Berlin) without MapKit or network.
enum PushUITestStub {
    static var mode: String? {
        guard let index = CommandLine.arguments.firstIndex(of: "-UITestPush"),
              CommandLine.arguments.indices.contains(index + 1) else { return nil }
        return CommandLine.arguments[index + 1]
    }
    static var isActive: Bool { mode != nil }

    @MainActor static func manager() -> PushManager? {
        guard let mode else { return nil }
        let suite = "de.linolaske.showernow.uitest.push"
        UserDefaults().removePersistentDomain(forName: suite)
        let registrar = FakeRegistrar()
        let authorizer: PushAuthorizing = mode == "system" ? SystemPushAuthorizing() : FakeAuthorizer(allow: mode != "fakedeny")
        let manager = PushManager(gateway: FakeGateway(), secrets: FakeSecrets(), authorizer: authorizer, registrar: registrar,
                                  defaults: UserDefaults(suiteName: suite) ?? .standard)
        registrar.manager = manager
        return manager
    }

    @MainActor static func cleanPlaces(_ store: WeatherStore) {
        guard CommandLine.arguments.contains("-UITestSetupClean"), !store.places.isEmpty else { return }
        store.deletePlaces(at: IndexSet(store.places.indices))
    }

    /// Fixed search result for the term "Teststadt" (nil for every other term).
    static func searchResult(for term: String) -> MKMapItem? {
        guard isActive, term == "Teststadt" else { return nil }
        let item = MKMapItem(location: CLLocation(latitude: 52.52, longitude: 13.405), address: nil)
        item.name = "Teststadt"
        return item
    }
}

/// Counters the test reads through the invisible `setup-debug` element of the wizard.
final class PushStubLog: @unchecked Sendable {
    static let shared = PushStubLog()
    private let lock = NSLock()
    private var counts: [String: Int] = [:]
    func bump(_ key: String) { lock.lock(); counts[key, default: 0] += 1; lock.unlock() }
    func count(_ key: String) -> Int { lock.lock(); defer { lock.unlock() }; return counts[key, default: 0] }
    var summary: String {
        "enable=\(count("enable")) installs=\(count("installation")) subs=\(count("subscription")) authRequests=\(count("authRequest"))"
    }
}

private final class FakeAuthorizer: PushAuthorizing, @unchecked Sendable {
    private let lock = NSLock()
    private var state: PushAuthorization = .notDetermined
    private let allow: Bool
    init(allow: Bool) { self.allow = allow }
    private func current() -> PushAuthorization { lock.lock(); defer { lock.unlock() }; return state }
    private func decide() { lock.lock(); state = allow ? .authorized : .denied; lock.unlock() }
    func status() async -> PushAuthorization { current() }
    func requestAuthorization() async -> Bool {
        PushStubLog.shared.bump("authRequest")
        decide()
        return allow
    }
}

@MainActor private final class FakeRegistrar: RemoteNotificationRegistering {
    weak var manager: PushManager?
    func register() { Task { await manager?.didRegister(deviceToken: Data(repeating: 0xAB, count: 32)) } }
    func unregister() {}
}

private final class FakeSecrets: PushSecretStore, @unchecked Sendable {
    private let lock = NSLock()
    private var identity: PushIdentity?
    func load() -> PushIdentity? { lock.lock(); defer { lock.unlock() }; return identity }
    func save(_ identity: PushIdentity) -> Bool { lock.lock(); self.identity = identity; lock.unlock(); return true }
    func delete() { lock.lock(); identity = nil; lock.unlock() }
}

private struct FakeGateway: PushGateway {
    func putInstallation(_ identity: PushIdentity, token: String, environment: PushEnvironment, locale: String) async throws { PushStubLog.shared.bump("installation") }
    func deleteInstallation(_ identity: PushIdentity) async throws {}
    func createSubscription(_ identity: PushIdentity, _ request: PushSubscriptionRequest) async throws -> String {
        PushStubLog.shared.bump("subscription"); return "stub-subscription"
    }
    func updateSubscription(_ identity: PushIdentity, id: String, _ request: PushSubscriptionRequest) async throws {}
    func deleteSubscription(_ identity: PushIdentity, id: String) async throws {}
    func sendTestNotification(_ identity: PushIdentity) async throws -> String { "sandbox" }
    func capabilities() async throws -> Set<String> { [] }
}
#endif
