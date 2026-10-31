import Foundation
import Observation
import UIKit
import UserNotifications

enum PushAuthorization: Equatable, Sendable { case unknown, notDetermined, denied, authorized }

protocol PushAuthorizing: Sendable {
    func status() async -> PushAuthorization
    /// Shows the system prompt; returns whether notifications are allowed afterwards.
    func requestAuthorization() async -> Bool
}

@MainActor protocol RemoteNotificationRegistering {
    func register()
    func unregister()
}

struct SystemPushAuthorizing: PushAuthorizing {
    func status() async -> PushAuthorization {
        switch await UNUserNotificationCenter.current().notificationSettings().authorizationStatus {
        case .notDetermined: .notDetermined
        case .denied: .denied
        case .authorized, .provisional, .ephemeral: .authorized
        @unknown default: .unknown
        }
    }
    func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }
}

@MainActor struct SystemRemoteRegistrar: RemoteNotificationRegistering {
    func register() { UIApplication.shared.registerForRemoteNotifications() }
    func unregister() { UIApplication.shared.unregisterForRemoteNotifications() }
}

/// Per-place opt-in. Only a ~1 km radar cell is derived from the coordinate; the coordinate itself stays in the place list.
struct PlacePushSettings: Codable, Equatable, Sendable {
    var cell: PushGrid.Cell
    var leadMinutes = PushLead.defaultMinutes
    var sensitivity = PushSensitivity.moderate
    var subscriptionID: String?
    /// Local changes not yet confirmed by the server.
    var needsUpload = true
    /// Default off: time-sensitive delivery breaks through Focus and Notification Summary.
    var timeSensitive = false

    init(cell: PushGrid.Cell, leadMinutes: Int = PushLead.defaultMinutes, sensitivity: PushSensitivity = .moderate,
         subscriptionID: String? = nil, needsUpload: Bool = true, timeSensitive: Bool = false) {
        self.cell = cell; self.leadMinutes = leadMinutes; self.sensitivity = sensitivity
        self.subscriptionID = subscriptionID; self.needsUpload = needsUpload; self.timeSensitive = timeSensitive
    }

    /// State stored by earlier versions has no `timeSensitive` key.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        cell = try c.decode(PushGrid.Cell.self, forKey: .cell)
        leadMinutes = try c.decode(Int.self, forKey: .leadMinutes)
        sensitivity = try c.decode(PushSensitivity.self, forKey: .sensitivity)
        subscriptionID = try c.decodeIfPresent(String.self, forKey: .subscriptionID)
        needsUpload = try c.decode(Bool.self, forKey: .needsUpload)
        timeSensitive = try c.decodeIfPresent(Bool.self, forKey: .timeSensitive) ?? false
    }

    var request: PushSubscriptionRequest {
        PushSubscriptionRequest(cell: cell, threshold: sensitivity.threshold, leadMinutes: leadMinutes, enabled: true,
                                timeSensitive: timeSensitive)
    }
}

/// Persisted push state: no device token, no secret, no coordinates.
struct PushState: Codable, Equatable, Sendable {
    var places: [UUID: PlacePushSettings] = [:]
    var pendingSubscriptionDeletes: [String] = []
    var pendingInstallationDelete = false
}

enum PlacePushStatus: Equatable {
    case off, pending, active
}

@MainActor @Observable
final class PushManager {
    static let stateKey = "push.state.v1"
    static let maxSubscriptions = 10

    private(set) var state: PushState
    private(set) var authorization: PushAuthorization = .unknown
    /// User-facing problem per place (memory only).
    private(set) var messages: [UUID: String] = [:]
    private(set) var isSyncing = false

    @ObservationIgnored private var deviceToken: String?
    @ObservationIgnored private var syncAgain = false
    @ObservationIgnored private let gateway: PushGateway
    @ObservationIgnored private let secrets: PushSecretStore
    @ObservationIgnored private let authorizer: PushAuthorizing
    @ObservationIgnored private let registrar: RemoteNotificationRegistering
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let environment: PushEnvironment
    @ObservationIgnored private let locale: String

    init(gateway: PushGateway, secrets: PushSecretStore, authorizer: PushAuthorizing, registrar: RemoteNotificationRegistering,
         defaults: UserDefaults = .standard, environment: PushEnvironment = .current,
         locale: String = PushManager.currentLocale()) {
        self.gateway = gateway; self.secrets = secrets; self.authorizer = authorizer; self.registrar = registrar
        self.defaults = defaults; self.environment = environment; self.locale = locale
        if let data = defaults.data(forKey: Self.stateKey), let decoded = try? JSONDecoder().decode(PushState.self, from: data) {
            state = decoded
        } else { state = PushState() }
    }

    static func live() -> PushManager {
        PushManager(gateway: HTTPPushGateway(), secrets: KeychainPushSecretStore(),
                    authorizer: SystemPushAuthorizing(), registrar: SystemRemoteRegistrar())
    }

    static func currentLocale() -> String {
        (Locale.preferredLanguages.first ?? "de").lowercased().hasPrefix("de") ? "de" : "en"
    }

    // MARK: Queries

    var enabledCount: Int { state.places.count }
    var isAnyEnabled: Bool { enabledCount > 0 }
    var canAddSubscription: Bool { enabledCount < Self.maxSubscriptions }

    func settings(for placeID: UUID) -> PlacePushSettings? { state.places[placeID] }

    func status(for placeID: UUID) -> PlacePushStatus {
        guard let settings = state.places[placeID] else { return .off }
        return settings.subscriptionID != nil && !settings.needsUpload ? .active : .pending
    }

    /// "Mitteilungen: aus/an" for the info sheet.
    var summary: String {
        guard isAnyEnabled else { return "Mitteilungen: aus" }
        return authorization == .denied ? "Mitteilungen: an (im System ausgeschaltet)" : "Mitteilungen: an"
    }

    // MARK: Lifecycle

    /// Call at launch and when the app becomes active: refresh authorization, register for a fresh token, retry open work.
    func start() async {
        await refreshAuthorization()
        if isAnyEnabled, authorization == .authorized { registrar.register() }
        await sync()
    }

    func refreshAuthorization() async { authorization = await authorizer.status() }

    /// Token delivery from `UIApplicationDelegate`. Kept in memory only.
    func didRegister(deviceToken data: Data) async {
        deviceToken = data.map { String(format: "%02x", $0) }.joined()
        await sync()
    }

    func didFailToRegister() {
        for id in state.places.keys { messages[id] = "Das Gerät konnte keinen Mitteilungs-Token abrufen. Es wird später erneut versucht." }
    }

    // MARK: Changes

    /// Opt-in. The explanation text has already been shown by the caller. Returns whether the opt-in is active.
    @discardableResult
    func enable(placeID: UUID, latitude: Double, longitude: Double) async -> Bool {
        messages[placeID] = nil
        guard let cell = PushGrid.cell(latitude: latitude, longitude: longitude) else {
            messages[placeID] = "Dieser Ort liegt außerhalb des Radargebiets; Regenhinweise sind hier nicht möglich."
            return false
        }
        guard state.places[placeID] != nil || canAddSubscription else {
            messages[placeID] = "Höchstens \(Self.maxSubscriptions) Orte können Hinweise senden."
            return false
        }
        var current = await authorizer.status()
        if current == .notDetermined {
            _ = await authorizer.requestAuthorization()
            current = await authorizer.status()
        }
        authorization = current
        guard current == .authorized else {
            messages[placeID] = "Mitteilungen sind für ShowerNow in den Systemeinstellungen ausgeschaltet."
            return false
        }
        if state.places[placeID] == nil { state.places[placeID] = PlacePushSettings(cell: cell) }
        state.pendingInstallationDelete = false
        persist()
        registrar.register()
        await sync()
        return true
    }

    func update(placeID: UUID, leadMinutes: Int? = nil, sensitivity: PushSensitivity? = nil, timeSensitive: Bool? = nil) async {
        guard var settings = state.places[placeID] else { return }
        if let leadMinutes, PushLead.options.contains(leadMinutes) { settings.leadMinutes = leadMinutes }
        if let sensitivity { settings.sensitivity = sensitivity }
        if let timeSensitive { settings.timeSensitive = timeSensitive }
        settings.needsUpload = true
        state.places[placeID] = settings
        persist()
        await sync()
    }

    // MARK: Test notification

    enum TestState: Equatable { case idle, sending, sent, failed(String) }
    private(set) var testState: TestState = .idle

    /// Test button visible only when notifications are allowed and at least one place is active.
    var canSendTest: Bool { isAnyEnabled && authorization == .authorized && deviceToken != nil }

    func sendTest() async {
        guard testState != .sending else { return }
        guard canSendTest, let identity = secrets.load() else {
            testState = .failed("Mitteilungen sind noch nicht eingerichtet. Bitte kurz warten oder die App neu öffnen.")
            return
        }
        testState = .sending
        do {
            _ = try await gateway.sendTestNotification(identity)
            testState = .sent
        } catch {
            testState = .failed(Self.testMessage(for: error))
            if case PushGatewayError.test(.tokenUnregistered) = error {
                // The server dropped the installation: register again and recreate the subscriptions.
                for id in state.places.keys { state.places[id]?.subscriptionID = nil; state.places[id]?.needsUpload = true }
                persist()
                await sync()
            }
        }
    }

    static func testMessage(for error: Error) -> String {
        guard let error = error as? PushGatewayError else { return "Die Testmeldung konnte nicht gesendet werden." }
        switch error {
        case .offline: return "Keine Internetverbindung."
        case .transport, .server: return "Der Mitteilungsdienst ist gerade nicht erreichbar. Bitte später erneut versuchen."
        case .unauthorized: return "Dieses Gerät ist beim Server nicht (mehr) registriert. Beim nächsten Start wird es neu eingerichtet."
        case .notFound: return "Der Mitteilungsdienst ist auf dem Server derzeit nicht aktiv."
        case .test(let failure):
            switch failure {
            case .environmentNotAllowed: return "Der Server nimmt diese App-Variante (Entwicklung oder Store) nicht an."
            case .apnsUnavailable503: return "Der Server kann Mitteilungen derzeit nicht senden (Apple-Zugang nicht eingerichtet)."
            case .badDeviceToken: return "Apple lehnt das Gerätetoken ab. Es passt nicht zur Umgebung dieser App-Variante."
            case .keyRejected: return "Apple lehnt den Zugangsschlüssel des Servers ab. Das muss der Betreiber beheben."
            case .apnsUnavailable: return "Apples Mitteilungsdienst ist gerade nicht erreichbar. Bitte später erneut versuchen."
            case .apnsRejected: return "Apple hat die Testmeldung abgelehnt."
            case .tokenUnregistered: return "Das Gerätetoken ist nicht mehr gültig. Das Gerät wird neu registriert; danach erneut versuchen."
            case .rateLimited(let after):
                if let after, after > 0 {
                    let minutes = max(1, Int((Double(after) / 60).rounded(.up)))
                    return "Zu viele Testmeldungen (höchstens 3 pro Stunde). Bitte in etwa \(minutes) Minuten erneut versuchen."
                }
                return "Zu viele Testmeldungen (höchstens 3 pro Stunde). Bitte später erneut versuchen."
            case .other: return "Die Testmeldung konnte nicht gesendet werden."
            }
        default: return "Die Testmeldung konnte nicht gesendet werden."
        }
    }

    /// Opt-out or place removal: delete the subscription (and the installation with the last one).
    func disable(placeID: UUID) async { await remove([placeID]) }
    func placesRemoved(_ ids: [UUID]) async { await remove(ids) }

    private func remove(_ ids: [UUID]) async {
        var changed = false
        for id in ids {
            guard let settings = state.places.removeValue(forKey: id) else { continue }
            if let sub = settings.subscriptionID { state.pendingSubscriptionDeletes.append(sub) }
            messages[id] = nil
            changed = true
        }
        guard changed else { return }
        persist()
        await sync()
    }

    /// App reset / "alle Mitteilungen aus": DELETE of the whole installation (server removes subscriptions and outbox).
    func resetAll() async {
        state.places = [:]
        state.pendingSubscriptionDeletes = []
        state.pendingInstallationDelete = true
        messages = [:]
        persist()
        await sync()
    }

    // MARK: Sync

    func sync() async {
        guard !isSyncing else { syncAgain = true; return }
        isSyncing = true
        defer { isSyncing = false }
        repeat {
            syncAgain = false
            await runSync()
        } while syncAgain
    }

    private func runSync() async {
        let orphan = state.places.isEmpty && secrets.load() != nil
        if state.pendingInstallationDelete || orphan {
            await deleteInstallation()
            return
        }
        guard !state.places.isEmpty, let token = deviceToken, authorization != .denied else { return }
        guard var identity = secrets.load() ?? createIdentity() else { return fail("Die Kennung konnte nicht sicher gespeichert werden.") }

        do { try await gateway.putInstallation(identity, token: token, environment: environment, locale: locale) }
        catch PushGatewayError.unauthorized {
            // Installation ID taken with an unknown secret (e.g. restored keychain): start over with a new identity.
            guard let fresh = createIdentity() else { return fail("Die Kennung konnte nicht sicher gespeichert werden.") }
            identity = fresh
            for id in state.places.keys { state.places[id]?.subscriptionID = nil; state.places[id]?.needsUpload = true }
            state.pendingSubscriptionDeletes = []
            persist()
            do { try await gateway.putInstallation(identity, token: token, environment: environment, locale: locale) }
            catch { return fail(Self.message(for: error)) }
        } catch { return fail(Self.message(for: error)) }

        var remaining: [String] = []
        for sub in state.pendingSubscriptionDeletes {
            do { try await gateway.deleteSubscription(identity, id: sub) }
            catch PushGatewayError.notFound {}
            catch { remaining.append(sub) }
        }
        state.pendingSubscriptionDeletes = remaining
        persist()

        for (placeID, settings) in state.places.sorted(by: { $0.key.uuidString < $1.key.uuidString }) where settings.needsUpload {
            do {
                var id = settings.subscriptionID
                if let existing = id {
                    do { try await gateway.updateSubscription(identity, id: existing, settings.request) }
                    catch PushGatewayError.notFound { id = nil }
                }
                if id == nil { id = try await gateway.createSubscription(identity, settings.request) }
                state.places[placeID]?.subscriptionID = id
                state.places[placeID]?.needsUpload = false
                messages[placeID] = nil
            } catch PushGatewayError.subscriptionLimit {
                state.places[placeID] = nil
                messages[placeID] = "Der Server nimmt höchstens \(Self.maxSubscriptions) Orte an."
            } catch {
                messages[placeID] = Self.message(for: error)
            }
            persist()
        }
    }

    private func deleteInstallation() async {
        if let identity = secrets.load() {
            do { try await gateway.deleteInstallation(identity) }
            catch PushGatewayError.unauthorized {}
            catch PushGatewayError.notFound {}
            catch {
                state.pendingInstallationDelete = true
                persist()
                return
            }
        }
        secrets.delete()
        state.pendingInstallationDelete = false
        state.pendingSubscriptionDeletes = []
        persist()
        deviceToken = nil
        registrar.unregister()
    }

    private func createIdentity() -> PushIdentity? {
        let identity = PushIdentity.make()
        return secrets.save(identity) ? identity : nil
    }

    private func fail(_ message: String) {
        for id in state.places.keys { messages[id] = message }
    }

    static func message(for error: Error) -> String {
        switch error as? PushGatewayError {
        case .offline: "Keine Internetverbindung. Der Hinweis wird beim nächsten Start oder Öffnen der App eingerichtet."
        case .rateLimited: "Der Server ist gerade ausgelastet. Bitte später erneut versuchen."
        case .notFound: "Der Mitteilungsdienst ist auf dem Server derzeit nicht aktiv."
        case .server, .transport: "Der Mitteilungsdienst ist gerade nicht erreichbar. Es wird später erneut versucht."
        case .some, .none: "Der Hinweis konnte nicht eingerichtet werden."
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(state) { defaults.set(data, forKey: Self.stateKey) }
    }
}

/// Bridges the system callbacks (device token) into `PushManager`.
final class PushAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    @MainActor static weak var manager: PushManager?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { @MainActor in await Self.manager?.didRegister(deviceToken: deviceToken) }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Task { @MainActor in Self.manager?.didFailToRegister() }
    }

    /// Rain hints are also useful while the app is open.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
