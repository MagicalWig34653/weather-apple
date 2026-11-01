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

/// Circle region opt-in. Stores only the coarse center cell (3 x 3 cells, about 2 km), never a coordinate.
/// The optional name stays on the device and is never sent.
struct RegionPushSettings: Codable, Equatable, Sendable {
    var name: String?
    var center: PushGrid.Cell
    var radiusKm = 10
    var sharePercent = PushGrid.defaultRegionSharePercent
    var leadMinutes = PushLead.defaultMinutes
    var sensitivity = PushSensitivity.moderate
    var timeSensitive = false
    var subscriptionID: String?
    var needsUpload = true

    /// Cell latitude is only needed to convert km into grid cells.
    var request: PushSubscriptionRequest {
        let latitude = PushGrid.coordinate(of: center).latitude
        return PushSubscriptionRequest(
            cell: center, threshold: sensitivity.threshold, leadMinutes: leadMinutes, enabled: true, timeSensitive: timeSensitive,
            region: PushRegionSpec(radiusCells: PushGrid.radiusCells(km: radiusKm, latitude: latitude), minSharePercent: sharePercent))
    }
}

/// Persisted push state: no device token, no secret, no coordinates.
struct PushState: Codable, Equatable, Sendable {
    var places: [UUID: PlacePushSettings] = [:]
    var regions: [UUID: RegionPushSettings] = [:]
    var pendingSubscriptionDeletes: [String] = []
    var pendingInstallationDelete = false

    init() {}

    /// State stored by earlier versions has no `regions` key (existing place subscriptions stay untouched).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        places = try c.decodeIfPresent([UUID: PlacePushSettings].self, forKey: .places) ?? [:]
        regions = try c.decodeIfPresent([UUID: RegionPushSettings].self, forKey: .regions) ?? [:]
        pendingSubscriptionDeletes = try c.decodeIfPresent([String].self, forKey: .pendingSubscriptionDeletes) ?? []
        pendingInstallationDelete = try c.decodeIfPresent(Bool.self, forKey: .pendingInstallationDelete) ?? false
    }
}

/// Whether the server announces region support in `GET /v1/status`.
enum PushRegionSupport: Equatable, Sendable { case unknown, unsupported, supported }

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

    /// Memory only; checked via `/v1/status` so that no region request ever hits an old server (no 400).
    private(set) var regionSupport: PushRegionSupport = .unknown
    /// Region-level notice for the list (e.g. limit reached); memory only.
    private(set) var regionNotice: String?
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

    var enabledCount: Int { state.places.count + state.regions.count }
    var regionCount: Int { state.regions.count }
    var canAddRegion: Bool { regionCount < PushGrid.maxRegions && enabledCount < Self.maxSubscriptions }
    var regionsSorted: [(id: UUID, settings: RegionPushSettings)] {
        state.regions.map { ($0.key, $0.value) }.sorted {
            ($0.1.name ?? "", $0.0.uuidString) < ($1.1.name ?? "", $1.0.uuidString)
        }
    }
    func region(for id: UUID) -> RegionPushSettings? { state.regions[id] }
    func regionStatus(for id: UUID) -> PlacePushStatus {
        guard let settings = state.regions[id] else { return .off }
        return settings.subscriptionID != nil && !settings.needsUpload ? .active : .pending
    }
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
        if !state.regions.isEmpty { await refreshRegionSupport() }
        if isAnyEnabled, authorization == .authorized { registrar.register() }
        await sync()
    }

    /// `GET /v1/status`; on failure the support stays `.unknown` (no region upload, no 400).
    func refreshRegionSupport() async {
        do { regionSupport = try await gateway.capabilities().contains(PushRegionWire.capability) ? .supported : .unsupported }
        catch is CancellationError {}
        catch { regionSupport = .unknown }
    }

    func refreshAuthorization() async { authorization = await authorizer.status() }

    /// Token delivery from `UIApplicationDelegate`. Kept in memory only.
    func didRegister(deviceToken data: Data) async {
        deviceToken = data.map { String(format: "%02x", $0) }.joined()
        await sync()
    }

    func didFailToRegister() {
        for id in Array(state.places.keys) + Array(state.regions.keys) { messages[id] = "Das Gerät konnte keinen Mitteilungs-Token abrufen. Es wird später erneut versucht." }
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
        guard await ensureAuthorized() else {
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

    private func ensureAuthorized() async -> Bool {
        var current = await authorizer.status()
        if current == .notDetermined {
            _ = await authorizer.requestAuthorization()
            current = await authorizer.status()
        }
        authorization = current
        return current == .authorized
    }

    // MARK: Regions

    enum RegionAddResult: Equatable { case added(UUID), failed(String) }

    /// Opt-in for a circle region. The explanation text has already been shown by the caller. `latitude`/`longitude` are
    /// reduced to the coarse center cell immediately and are not stored.
    func addRegion(latitude: Double, longitude: Double, radiusKm: Int, sharePercent: Int, name: String?) async -> RegionAddResult {
        regionNotice = nil
        if regionSupport != .supported { await refreshRegionSupport() }
        guard regionSupport == .supported else {
            return .failed(regionSupport == .unsupported ? "Der Server unterstützt noch keine Regionen."
                           : "Ob der Server Regionen unterstützt, konnte nicht geprüft werden. Bitte später erneut versuchen.")
        }
        guard let cell = PushGrid.cell(latitude: latitude, longitude: longitude) else {
            return .failed("Dieser Mittelpunkt liegt außerhalb des Radargebiets.")
        }
        guard regionCount < PushGrid.maxRegions else { return .failed("Höchstens \(PushGrid.maxRegions) Regionen sind möglich.") }
        guard enabledCount < Self.maxSubscriptions else { return .failed("Höchstens \(Self.maxSubscriptions) Hinweise (Orte und Regionen) sind möglich.") }
        guard PushGrid.regionRadiusPresetsKm.contains(radiusKm), PushGrid.regionSharePercents.contains(sharePercent) else {
            return .failed("Ungültiger Radius oder Auslöseanteil.")
        }
        guard await ensureAuthorized() else {
            return .failed("Mitteilungen sind für ShowerNow in den Systemeinstellungen ausgeschaltet.")
        }
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let id = UUID()
        state.regions[id] = RegionPushSettings(name: (trimmed?.isEmpty ?? true) ? nil : trimmed, center: PushGrid.coarseCenter(of: cell),
                                               radiusKm: radiusKm, sharePercent: sharePercent)
        state.pendingInstallationDelete = false
        persist()
        registrar.register()
        await sync()
        // The server may refuse right away (limit): then the region is gone and the notice explains why.
        if state.regions[id] == nil { return .failed(regionNotice ?? "Die Region konnte nicht eingerichtet werden.") }
        return .added(id)
    }

    func updateRegion(id: UUID, name: String?? = nil, radiusKm: Int? = nil, sharePercent: Int? = nil, leadMinutes: Int? = nil,
                      sensitivity: PushSensitivity? = nil, timeSensitive: Bool? = nil) async {
        guard var settings = state.regions[id] else { return }
        if let name {
            let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines)
            settings.name = (trimmed?.isEmpty ?? true) ? nil : trimmed
        }
        if let radiusKm, PushGrid.regionRadiusPresetsKm.contains(radiusKm) { settings.radiusKm = radiusKm }
        if let sharePercent, PushGrid.regionSharePercents.contains(sharePercent) { settings.sharePercent = sharePercent }
        if let leadMinutes, PushLead.options.contains(leadMinutes) { settings.leadMinutes = leadMinutes }
        if let sensitivity { settings.sensitivity = sensitivity }
        if let timeSensitive { settings.timeSensitive = timeSensitive }
        // A pure rename is local only.
        let nameOnly = settings.request == state.regions[id]?.request
        if !nameOnly { settings.needsUpload = true }
        state.regions[id] = settings
        persist()
        if !nameOnly { await sync() }
    }

    /// Opt-out / delete: removes the server subscription (and the installation with the last one).
    func removeRegion(id: UUID) async {
        guard let settings = state.regions.removeValue(forKey: id) else { return }
        if let sub = settings.subscriptionID { state.pendingSubscriptionDeletes.append(sub) }
        messages[id] = nil
        persist()
        await sync()
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
                resetSubscriptionIDs()
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
        state.regions = [:]
        state.pendingSubscriptionDeletes = []
        state.pendingInstallationDelete = true
        messages = [:]
        regionNotice = nil
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
        let orphan = state.places.isEmpty && state.regions.isEmpty && secrets.load() != nil
        if state.pendingInstallationDelete || orphan {
            await deleteInstallation()
            return
        }
        guard !(state.places.isEmpty && state.regions.isEmpty), let token = deviceToken, authorization != .denied else { return }
        guard var identity = secrets.load() ?? createIdentity() else { return fail("Die Kennung konnte nicht sicher gespeichert werden.") }

        do { try await gateway.putInstallation(identity, token: token, environment: environment, locale: locale) }
        catch PushGatewayError.unauthorized {
            // Installation ID taken with an unknown secret (e.g. restored keychain): start over with a new identity.
            guard let fresh = createIdentity() else { return fail("Die Kennung konnte nicht sicher gespeichert werden.") }
            identity = fresh
            resetSubscriptionIDs()
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
                let id = try await upload(identity, existing: settings.subscriptionID, settings.request)
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

        await uploadRegions(identity)
    }

    private func upload(_ identity: PushIdentity, existing: String?, _ request: PushSubscriptionRequest) async throws -> String {
        var id = existing
        if let existing {
            do { try await gateway.updateSubscription(identity, id: existing, request) }
            catch PushGatewayError.notFound { id = nil }
        }
        if id == nil { id = try await gateway.createSubscription(identity, request) }
        return id ?? ""
    }

    private func uploadRegions(_ identity: PushIdentity) async {
        let open = state.regions.sorted(by: { $0.key.uuidString < $1.key.uuidString }).filter { $0.value.needsUpload }
        guard !open.isEmpty else { return }
        if regionSupport != .supported { await refreshRegionSupport() }
        guard regionSupport == .supported else {
            // Never send region fields to a server without the capability (it could answer 400).
            let text = regionSupport == .unsupported ? "Der Server unterstützt noch keine Regionen." : "Ob der Server Regionen unterstützt, konnte nicht geprüft werden. Es wird später erneut versucht."
            for (id, _) in open { messages[id] = text }
            return
        }
        for (regionID, settings) in open {
            do {
                let id = try await upload(identity, existing: settings.subscriptionID, settings.request)
                state.regions[regionID]?.subscriptionID = id
                state.regions[regionID]?.needsUpload = false
                messages[regionID] = nil
            } catch PushGatewayError.regionCapacity {
                if settings.subscriptionID == nil {
                    state.regions[regionID] = nil
                    messages[regionID] = nil
                    regionNotice = Self.regionCapacityMessage
                } else { messages[regionID] = Self.regionCapacityMessage }
            } catch PushGatewayError.regionLimit {
                // 409 region_limit also covers the cell budget (8000 per installation), not only the 3 regions.
                if settings.subscriptionID == nil {
                    state.regions[regionID] = nil
                    messages[regionID] = nil
                    regionNotice = Self.regionLimitMessage
                } else { messages[regionID] = Self.regionLimitMessage }
            } catch PushGatewayError.subscriptionLimit {
                state.regions[regionID] = nil
                regionNotice = "Der Server nimmt höchstens \(Self.maxSubscriptions) Hinweise an."
            } catch {
                messages[regionID] = Self.message(for: error)
            }
            persist()
        }
    }

    static let regionLimitMessage = "Der Server nimmt höchstens \(PushGrid.maxRegions) Regionen je Gerät an, deren Gesamtfläche begrenzt ist. Wähle einen kleineren Radius oder lösche eine Region."
    static let regionCapacityMessage = "Der Server hat gerade keine Kapazität für weitere Regionen. Wähle einen kleineren Radius oder versuche es später erneut."

    private func resetSubscriptionIDs() {
        for id in state.places.keys { state.places[id]?.subscriptionID = nil; state.places[id]?.needsUpload = true }
        for id in state.regions.keys { state.regions[id]?.subscriptionID = nil; state.regions[id]?.needsUpload = true }
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
        for id in Array(state.places.keys) + Array(state.regions.keys) { messages[id] = message }
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
