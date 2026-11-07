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
    var liveActivity = false
    var liveActivityDirty = false

    init(cell: PushGrid.Cell, leadMinutes: Int = PushLead.defaultMinutes, sensitivity: PushSensitivity = .moderate,
         subscriptionID: String? = nil, needsUpload: Bool = true, timeSensitive: Bool = false) {
        self.cell = cell; self.leadMinutes = leadMinutes; self.sensitivity = sensitivity
        self.subscriptionID = subscriptionID; self.needsUpload = needsUpload; self.timeSensitive = timeSensitive
    }

    /// Earlier state has neither timeSensitive nor Live Activity keys; all opt-ins default off.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        cell = try c.decode(PushGrid.Cell.self, forKey: .cell)
        leadMinutes = try c.decode(Int.self, forKey: .leadMinutes)
        sensitivity = try c.decode(PushSensitivity.self, forKey: .sensitivity)
        subscriptionID = try c.decodeIfPresent(String.self, forKey: .subscriptionID)
        needsUpload = try c.decode(Bool.self, forKey: .needsUpload)
        timeSensitive = try c.decodeIfPresent(Bool.self, forKey: .timeSensitive) ?? false
        liveActivity = try c.decodeIfPresent(Bool.self, forKey: .liveActivity) ?? false
        liveActivityDirty = try c.decodeIfPresent(Bool.self, forKey: .liveActivityDirty) ?? false
    }

    var request: PushSubscriptionRequest {
        PushSubscriptionRequest(cell: cell, threshold: sensitivity.threshold, leadMinutes: leadMinutes, enabled: true,
                                timeSensitive: timeSensitive, liveActivity: liveActivity)
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
    /// Live Activity for this region (same trigger share as the alert, no own value). Default off.
    var liveActivity = false
    var liveActivityDirty = false

    /// Cell latitude is only needed to convert km into grid cells. `live_activity` is sent only as `true` (the server
    /// treats a missing field as false), so requests of regions without Live Activity are unchanged.
    var request: PushSubscriptionRequest {
        let latitude = PushGrid.coordinate(of: center).latitude
        return PushSubscriptionRequest(
            cell: center, threshold: sensitivity.threshold, leadMinutes: leadMinutes, enabled: true, timeSensitive: timeSensitive,
            region: PushRegionSpec(radiusCells: PushGrid.radiusCells(km: radiusKm, latitude: latitude), minSharePercent: sharePercent),
            liveActivity: liveActivity ? true : nil)
    }
}

extension RegionPushSettings {
    /// State stored by earlier builds has no Live Activity keys (default off).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decodeIfPresent(String.self, forKey: .name)
        center = try c.decode(PushGrid.Cell.self, forKey: .center)
        radiusKm = try c.decodeIfPresent(Int.self, forKey: .radiusKm) ?? 10
        sharePercent = try c.decodeIfPresent(Int.self, forKey: .sharePercent) ?? PushGrid.defaultRegionSharePercent
        leadMinutes = try c.decodeIfPresent(Int.self, forKey: .leadMinutes) ?? PushLead.defaultMinutes
        sensitivity = try c.decodeIfPresent(PushSensitivity.self, forKey: .sensitivity) ?? .moderate
        timeSensitive = try c.decodeIfPresent(Bool.self, forKey: .timeSensitive) ?? false
        subscriptionID = try c.decodeIfPresent(String.self, forKey: .subscriptionID)
        needsUpload = try c.decodeIfPresent(Bool.self, forKey: .needsUpload) ?? true
        liveActivity = try c.decodeIfPresent(Bool.self, forKey: .liveActivity) ?? false
        liveActivityDirty = try c.decodeIfPresent(Bool.self, forKey: .liveActivityDirty) ?? false
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
    private(set) var liveActivityMessages: [UUID: String] = [:]
    private(set) var liveActivitySupport: PushRegionSupport = .unknown
    /// Capability `live_activity_regions`: without it a region never gets `live_activity` (old servers would answer 400).
    private(set) var liveActivityRegionSupport: PushRegionSupport = .unknown
    @ObservationIgnored private var displacementTried: Set<String> = []
    @ObservationIgnored private let activityManager: RainActivityManaging?
    @ObservationIgnored private let activityDefaults: UserDefaults?
    @ObservationIgnored private var liveActivityStartToken: String?
    @ObservationIgnored private var activityTokens: [String: String] = [:]
    @ObservationIgnored private var pendingReservationDeletes: Set<String> = []
    @ObservationIgnored private var pendingActivityDeletes: [String: Set<String>] = [:]
    @ObservationIgnored private var deviceToken: String?
    @ObservationIgnored private var placeNames: [UUID: String] = [:]
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
         locale: String = PushManager.currentLocale(), activityManager: RainActivityManaging? = nil,
         activityDefaults: UserDefaults? = nil) {
        self.gateway = gateway; self.secrets = secrets; self.authorizer = authorizer; self.registrar = registrar
        self.defaults = defaults; self.environment = environment; self.locale = locale
        self.activityManager = activityManager; self.activityDefaults = activityDefaults
        if let data = defaults.data(forKey: Self.stateKey), let decoded = try? JSONDecoder().decode(PushState.self, from: data) {
            state = decoded
        } else { state = PushState() }
    }

    static func live() -> PushManager {
        let manager = PushManager(gateway: HTTPPushGateway(), secrets: KeychainPushSecretStore(),
                                  authorizer: SystemPushAuthorizing(), registrar: SystemRemoteRegistrar(),
                                  activityManager: SystemRainActivityManager(), activityDefaults: UserDefaults(suiteName: SharedConfig.appGroup))
        // Install observers before an asynchronous status request or any foreground scene is needed.
        manager.observeActivities()
        return manager
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
        if state.places.values.contains(where: { $0.liveActivity || $0.liveActivityDirty })
            || state.regions.values.contains(where: { $0.liveActivity || $0.liveActivityDirty }) { await refreshLiveActivitySupport() }
        observeActivities()
        if !liveActivitiesEnabled { await activityManager?.end(subscriptionID: nil) }
        if isAnyEnabled, authorization == .authorized { registrar.register() }
        await sync()
    }

    /// `GET /v1/status`; on failure the support stays `.unknown` (no region upload, no 400).
    func refreshRegionSupport() async {
        do {
            let capabilities = try await gateway.capabilities()
            regionSupport = capabilities.contains(PushRegionWire.capability) ? .supported : .unsupported
            liveActivitySupport = capabilities.contains(PushActivityWire.capability) ? .supported : .unsupported
            liveActivityRegionSupport = capabilities.contains(PushActivityWire.regionCapability) ? .supported : .unsupported
        }
        catch is CancellationError {}
        catch { regionSupport = .unknown; liveActivitySupport = .unknown; liveActivityRegionSupport = .unknown }
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
            messages[placeID] = "Mitteilungen sind für Showers in den Systemeinstellungen ausgeschaltet."
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
            return .failed("Mitteilungen sind für Showers in den Systemeinstellungen ausgeschaltet.")
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
        if let sub = settings.subscriptionID {
            state.pendingSubscriptionDeletes.append(sub)
            if settings.liveActivity { queueActivityDelete(subscriptionID: sub) }
        }
        messages[id] = nil
        liveActivityMessages[id] = nil
        persist()
        if settings.liveActivity { await endUnsubscribedActivities() }
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
                await resetSubscriptionIDs()
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
            if let sub = settings.subscriptionID {
                state.pendingSubscriptionDeletes.append(sub)
                queueActivityDelete(subscriptionID: sub)
            }
            messages[id] = nil
            liveActivityMessages[id] = nil
            changed = true
        }
        guard changed else { return }
        persist()
        await endUnsubscribedActivities()
        await sync()
    }

    /// App reset / "alle Mitteilungen aus": DELETE of the whole installation (server removes subscriptions and outbox).
    func resetAll() async {
        state.places = [:]
        state.regions = [:]
        state.pendingSubscriptionDeletes = []
        state.pendingInstallationDelete = true
        messages = [:]
        liveActivityMessages = [:]
        regionNotice = nil
        persist()
        await activityManager?.end(subscriptionID: nil)
        activityTokens = [:]
        pendingActivityDeletes = [:]
        pendingReservationDeletes = []
        await sync()
    }

    // MARK: Live Activities

    var liveActivitiesEnabled: Bool { activityManager?.activitiesEnabled ?? false }

    func refreshLiveActivitySupport() async {
        await refreshRegionSupport() // One status response provides both capabilities.
    }

    /// Whether a region may offer the Live Activity switch (both capabilities announced).
    var regionLiveActivityAvailable: Bool { liveActivitySupport == .supported && liveActivityRegionSupport == .supported }

    private func activityKind(_ subscriptionID: String) -> RainActivityKind? {
        if state.places.values.contains(where: { $0.subscriptionID == subscriptionID && $0.liveActivity }) { return .point }
        if state.regions.values.contains(where: { $0.subscriptionID == subscriptionID && $0.liveActivity }) { return .region }
        return nil
    }

    private func activityEligible(_ subscriptionID: String) -> Bool { activityKind(subscriptionID) != nil }

    private func observeActivities() {
        activityManager?.start(eligible: { [weak self] sub in self?.activityKind(sub) },
                               startToken: { [weak self] data in await self?.receivedStartToken(data) },
                               activityToken: { [weak self] sub, data in await self?.receivedActivityToken(subscriptionID: sub, data: data) },
                               ended: { [weak self] sub, data in await self?.activityEnded(subscriptionID: sub, data: data) })
    }

    func setLiveActivity(placeID: UUID, enabled: Bool) async {
        guard state.places[placeID] != nil else { return }
        if enabled {
            await refreshLiveActivitySupport()
            guard liveActivitySupport == .supported, liveActivitiesEnabled else {
                messages[placeID] = RainActivityText.unavailable.text(locale: locale)
                return
            }
        }
        guard state.places[placeID] != nil else { return }
        liveActivityMessages[placeID] = nil
        state.places[placeID]?.liveActivity = enabled
        state.places[placeID]?.liveActivityDirty = true
        state.places[placeID]?.needsUpload = true
        persist()
        observeActivities()
        if !enabled, let sub = state.places[placeID]?.subscriptionID {
            queueActivityDelete(subscriptionID: sub)
            await activityManager?.end(subscriptionID: sub)
        }
        await sync()
    }

    /// Live Activity switch of a region. Only with both capabilities; the start token is awaited like for places.
    func setRegionLiveActivity(regionID: UUID, enabled: Bool) async {
        guard state.regions[regionID] != nil else { return }
        if enabled {
            await refreshLiveActivitySupport()
            guard regionLiveActivityAvailable, liveActivitiesEnabled else {
                liveActivityMessages[regionID] = RainActivityText.unavailable.text(locale: locale)
                return
            }
        }
        guard state.regions[regionID] != nil else { return }
        liveActivityMessages[regionID] = nil
        state.regions[regionID]?.liveActivity = enabled
        state.regions[regionID]?.liveActivityDirty = true
        state.regions[regionID]?.needsUpload = true
        persist()
        observeActivities()
        if !enabled, let sub = state.regions[regionID]?.subscriptionID {
            queueActivityDelete(subscriptionID: sub)
            await activityManager?.end(subscriptionID: sub)
        }
        await sync()
    }

    /// Explicit fallback entry point for a future “Observe” action; never called automatically.
    func startLiveActivityFallback(placeID: UUID, displayName: String, content: RainActivityAttributes.ContentState) throws {
        guard liveActivitySupport == .supported, let settings = state.places[placeID], settings.liveActivity,
              !settings.needsUpload, let sub = settings.subscriptionID, let activityManager else {
            throw PushGatewayError.activityNotEligible
        }
        observeActivities()
        try activityManager.startFallback(attributes: .init(displayName: displayName, subscriptionID: sub), state: content)
    }

    func receivedStartToken(_ data: Data) async {
        let token = PushActivityWire.hex(data)
        guard PushActivityWire.isValidToken(token) else { return }
        liveActivityStartToken = token
        await sync()
    }

    func receivedActivityToken(subscriptionID: String, data: Data) async {
        let token = PushActivityWire.hex(data)
        guard PushActivityWire.isValidToken(token) else { return }
        guard activityEligible(subscriptionID) else {
            pendingActivityDeletes[subscriptionID, default: []].insert(token)
            await activityManager?.end(subscriptionID: subscriptionID)
            await sync()
            return
        }
        activityTokens[subscriptionID] = token
        await sync()
    }

    func activityEnded(subscriptionID: String, data: Data?) async {
        if let data {
            let token = PushActivityWire.hex(data)
            pendingActivityDeletes[subscriptionID, default: []].insert(token)
            if activityTokens[subscriptionID] == token { activityTokens[subscriptionID] = nil }
        } else {
            // A tokenless end may release a reservation, but never a known replacement activity.
            guard activityTokens[subscriptionID] == nil else { return }
            pendingReservationDeletes.insert(subscriptionID)
        }
        await sync()
    }

    private func queueActivityDelete(subscriptionID: String) {
        if let token = activityTokens.removeValue(forKey: subscriptionID) {
            pendingActivityDeletes[subscriptionID, default: []].insert(token)
        } else {
            pendingReservationDeletes.insert(subscriptionID)
        }
    }

    private func endUnsubscribedActivities() async {
        for sub in state.pendingSubscriptionDeletes { await activityManager?.end(subscriptionID: sub) }
    }

    private func syncActivities(_ identity: PushIdentity, deviceToken: String) async {
        guard liveActivitySupport == .supported else { return }
        for sub in pendingReservationDeletes {
            // Token arrival supersedes an unidentified end; token-specific deletion remains safe.
            if activityTokens[sub] != nil { pendingReservationDeletes.remove(sub); continue }
            do { try await gateway.deleteActivityToken(identity, subscriptionID: sub, token: nil) }
            catch PushGatewayError.notFound {}
            catch { activityMessage(error); continue }
            pendingReservationDeletes.remove(sub)
        }
        for (sub, tokens) in pendingActivityDeletes {
            for token in tokens {
                do { try await gateway.deleteActivityToken(identity, subscriptionID: sub, token: token) }
                catch PushGatewayError.notFound {} // Subscription deletion already cascaded.
                catch { activityMessage(error); continue }
                pendingActivityDeletes[sub]?.remove(token)
                if pendingActivityDeletes[sub]?.isEmpty == true { pendingActivityDeletes[sub] = nil }
            }
        }
        for (sub, token) in activityTokens where activityEligible(sub) && liveActivitiesEnabled {
            guard activityTokens[sub] == token else { continue } // dropped meanwhile (e.g. a displaced region)
            do {
                try await gateway.putActivityToken(identity, subscriptionID: sub, token: token)
                displacementTried.remove(sub)
            }
            catch PushGatewayError.activityNotEligible {
                activityMessage(PushGatewayError.activityNotEligible)
                queueActivityDelete(subscriptionID: sub)
                syncAgain = true
                await activityManager?.end(subscriptionID: sub)
            }
            catch PushGatewayError.activityFull {
                for (id, settings) in state.places where settings.subscriptionID == sub && settings.liveActivity {
                    state.places[id]?.liveActivity = false
                    state.places[id]?.liveActivityDirty = true
                    state.places[id]?.needsUpload = true
                    liveActivityMessages[id] = RainActivityText.full.text(locale: locale)
                }
                for (id, settings) in state.regions where settings.subscriptionID == sub && settings.liveActivity {
                    state.regions[id]?.liveActivity = false
                    state.regions[id]?.liveActivityDirty = true
                    state.regions[id]?.needsUpload = true
                    liveActivityMessages[id] = RainActivityText.full.text(locale: locale)
                }
                persist()
                queueActivityDelete(subscriptionID: sub)
                syncAgain = true
                await activityManager?.end(subscriptionID: sub)
            }
            catch PushGatewayError.activityLimit {
                // Place before region: the server does not displace on `PUT .../activity`, so the app ends a running
                // region activity itself, unregisters its token and then registers the place (once per place).
                if activityKind(sub) == .point, await displaceRegionActivities(for: sub) { continue }
                activityMessage(PushGatewayError.activityLimit)
                queueActivityDelete(subscriptionID: sub)
                syncAgain = true
                await activityManager?.end(subscriptionID: sub)
            }
            catch { activityMessage(error) } // Retry current token on the next sync/foreground.
        }
    }

    /// Ends all region activities (local end, token unregistered by the next delete pass) so a place can take the one slot.
    /// Returns false when there is nothing to displace or this place already tried, so a 409 cannot loop.
    private func displaceRegionActivities(for pointSub: String) async -> Bool {
        let regionSubs = state.regions.values.compactMap { $0.liveActivity ? $0.subscriptionID : nil }
        guard !regionSubs.isEmpty, !displacementTried.contains(pointSub) else { return false }
        displacementTried.insert(pointSub)
        for sub in regionSubs {
            queueActivityDelete(subscriptionID: sub)
            await activityManager?.end(subscriptionID: sub)
        }
        syncAgain = true
        return true
    }

    private func activityMessage(_ error: Error) {
        let text: String
        switch error as? PushGatewayError {
        case .activityLimit: text = RainActivityText.limit.text(locale: locale)
        case .activityNotEligible: text = RainActivityText.notEligible.text(locale: locale)
        default: text = RainActivityText.retry.text(locale: locale)
        }
        for (id, settings) in state.places where settings.liveActivity { messages[id] = text }
        for (id, settings) in state.regions where settings.liveActivity { liveActivityMessages[id] = text }
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
            await resetSubscriptionIDs()
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

        // A live opt-in is sent only after this installation's current start token is acknowledged.
        var reportedStartToken: String?
        if liveActivitySupport == .supported {
            let wantsActivities = liveActivitiesEnabled
                && (state.places.values.contains { $0.liveActivity } || state.regions.values.contains { $0.liveActivity })
            if !wantsActivities || liveActivityStartToken != nil {
                do {
                    try await reportStartToken(identity, deviceToken: token, enabled: wantsActivities)
                    reportedStartToken = wantsActivities ? liveActivityStartToken : nil
                } catch { activityMessage(error) }
            }
        }

        for (placeID, settings) in state.places.sorted(by: { $0.key.uuidString < $1.key.uuidString }) where settings.needsUpload {
            // Keep the change pending when a previous opt-in cannot yet be reconciled with the server.
            if (settings.liveActivity || settings.liveActivityDirty), liveActivitySupport != .supported { continue }
            var request = settings.request
            if liveActivitySupport != .supported { request.liveActivity = nil }
            if request.liveActivity == true, reportedStartToken == nil || reportedStartToken != liveActivityStartToken {
                liveActivityMessages[placeID] = RainActivityText.waitingForToken.text(locale: locale)
                continue
            }
            do {
                let id = try await uploadRecovering(identity, deviceToken: token, existing: settings.subscriptionID, request)
                if state.places[placeID] == nil { discardLate(subscription: id) }
                else {
                    state.places[placeID]?.subscriptionID = id
                    // Confirm only what was uploaded; a change made meanwhile stays open (sync runs again).
                    if state.places[placeID]?.request == settings.request {
                        state.places[placeID]?.needsUpload = false
                        state.places[placeID]?.liveActivityDirty = false
                    }
                    messages[placeID] = nil
                    if request.liveActivity == true { liveActivityMessages[placeID] = nil }
                }
            } catch PushGatewayError.startTokenRequired {
                liveActivityMessages[placeID] = RainActivityText.waitingForToken.text(locale: locale)
            } catch PushGatewayError.activityFull {
                if state.places[placeID]?.request == settings.request {
                    state.places[placeID]?.liveActivity = false
                    state.places[placeID]?.liveActivityDirty = true
                    state.places[placeID]?.needsUpload = true
                    liveActivityMessages[placeID] = RainActivityText.full.text(locale: locale)
                    if let sub = settings.subscriptionID {
                        queueActivityDelete(subscriptionID: sub)
                        await activityManager?.end(subscriptionID: sub)
                    }
                    syncAgain = true // Reconcile ordinary rain notifications with live_activity:false.
                }
            } catch PushGatewayError.subscriptionLimit {
                state.places[placeID] = nil
                messages[placeID] = "Der Server nimmt höchstens \(Self.maxSubscriptions) Orte an."
            } catch {
                messages[placeID] = Self.message(for: error)
            }
            persist()
        }

        await uploadRegions(identity, deviceToken: token, reportedStartToken: reportedStartToken)
        await syncActivities(identity, deviceToken: token)
    }

    /// Upload; a `start_token_required` for a live opt-in gets exactly one recovery attempt (report the token again, upload again).
    private func uploadRecovering(_ identity: PushIdentity, deviceToken: String, existing: String?,
                                  _ request: PushSubscriptionRequest) async throws -> String {
        do { return try await upload(identity, existing: existing, request) }
        catch PushGatewayError.startTokenRequired where request.liveActivity == true {
            do { try await reportStartToken(identity, deviceToken: deviceToken, enabled: true) }
            catch { throw PushGatewayError.startTokenRequired }
            do { return try await upload(identity, existing: existing, request) }
            catch PushGatewayError.activityFull { throw PushGatewayError.activityFull }
            catch PushGatewayError.subscriptionLimit { throw PushGatewayError.subscriptionLimit }
            catch { throw PushGatewayError.startTokenRequired }
        }
    }

    private func reportStartToken(_ identity: PushIdentity, deviceToken: String, enabled: Bool) async throws {
        let token = enabled ? liveActivityStartToken : nil
        if enabled, token == nil { throw PushGatewayError.startTokenRequired }
        try await gateway.putLiveActivityStartToken(identity, deviceToken: deviceToken, environment: environment,
                                                    locale: locale, startToken: token)
        // A rotation during the request must be acknowledged before any opt-in is uploaded.
        if enabled, token != liveActivityStartToken { throw PushGatewayError.startTokenRequired }
    }

    /// The entry was removed while its request was in flight: the server may now hold a subscription nobody references.
    /// Queue it for deletion (a repeated delete answers 404, which is ignored).
    private func discardLate(subscription id: String) {
        if !state.pendingSubscriptionDeletes.contains(id) { state.pendingSubscriptionDeletes.append(id) }
        syncAgain = true
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

    private func uploadRegions(_ identity: PushIdentity, deviceToken: String, reportedStartToken: String?) async {
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
            // Never send `live_activity` without both capabilities; a pending opt-in/out stays open until they are known.
            if (settings.liveActivity || settings.liveActivityDirty), !regionLiveActivityAvailable { continue }
            var request = settings.request
            if !regionLiveActivityAvailable { request.liveActivity = nil }
            if request.liveActivity == true, reportedStartToken == nil || reportedStartToken != liveActivityStartToken {
                liveActivityMessages[regionID] = RainActivityText.waitingForToken.text(locale: locale)
                continue
            }
            do {
                let id = try await uploadRecovering(identity, deviceToken: deviceToken, existing: settings.subscriptionID, request)
                if state.regions[regionID] == nil { discardLate(subscription: id) }
                else {
                    state.regions[regionID]?.subscriptionID = id
                    if state.regions[regionID]?.request == settings.request {
                        state.regions[regionID]?.needsUpload = false
                        state.regions[regionID]?.liveActivityDirty = false
                    }
                    messages[regionID] = nil
                    if request.liveActivity == true { liveActivityMessages[regionID] = nil }
                }
            } catch PushGatewayError.startTokenRequired {
                liveActivityMessages[regionID] = RainActivityText.waitingForToken.text(locale: locale)
            } catch PushGatewayError.activityFull {
                if state.regions[regionID]?.request == settings.request {
                    state.regions[regionID]?.liveActivity = false
                    state.regions[regionID]?.liveActivityDirty = true
                    state.regions[regionID]?.needsUpload = true
                    liveActivityMessages[regionID] = RainActivityText.full.text(locale: locale)
                    if let sub = settings.subscriptionID {
                        queueActivityDelete(subscriptionID: sub)
                        await activityManager?.end(subscriptionID: sub)
                    }
                    syncAgain = true // Reconcile ordinary region alerts with live_activity omitted.
                }
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

    private func resetSubscriptionIDs() async {
        // Tokens belong to the old server subscriptions, never attach them to replacement IDs.
        activityTokens = [:]
        pendingActivityDeletes = [:]
        pendingReservationDeletes = []
        for id in state.places.keys { state.places[id]?.subscriptionID = nil; state.places[id]?.needsUpload = true }
        for id in state.regions.keys { state.regions[id]?.subscriptionID = nil; state.regions[id]?.needsUpload = true }
        await activityManager?.end(subscriptionID: nil)
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
        activityTokens = [:]
        pendingActivityDeletes = [:]
        pendingReservationDeletes = []
        await activityManager?.end(subscriptionID: nil)
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
        // Only IDs, no names/coordinates/tokens. Widget extension resolves names through PlaceStore.
        let mapping = state.places.reduce(into: [String: String]()) { map, entry in
            if entry.value.liveActivity, let sub = entry.value.subscriptionID { map[sub] = entry.key.uuidString }
        }
        activityDefaults?.set(mapping, forKey: RainActivityAttributes.placeMappingDefaultsKey)
        // Region name and radius for the widget; they stay in the App Group on this device and are never sent.
        let regionMapping = state.regions.reduce(into: [String: [String: Any]]()) { map, entry in
            guard entry.value.liveActivity, let sub = entry.value.subscriptionID else { return }
            var info: [String: Any] = ["radiusKm": entry.value.radiusKm]
            if let name = entry.value.name, !name.isEmpty { info["name"] = name }
            map[sub] = info
        }
        activityDefaults?.set(regionMapping, forKey: RainActivityAttributes.regionMappingDefaultsKey)
        writeNotificationNames()
    }

    /// Place names for the Notification Service Extension (App Group, device only). Call whenever the place list changes.
    func updatePlaceNames(_ places: [SavedPlace]) {
        placeNames = Dictionary(places.map { ($0.id, $0.name) }, uniquingKeysWith: { _, last in last })
        writeNotificationNames()
    }

    private func writeNotificationNames() {
        let placeSubs = state.places.reduce(into: [UUID: String]()) { map, entry in
            if let sub = entry.value.subscriptionID { map[entry.key] = sub }
        }
        let regionSubs = state.regions.reduce(into: [String: String?]()) { map, entry in
            if let sub = entry.value.subscriptionID { map[sub] = entry.value.name }
        }
        NotificationNameStore.write(NotificationNameStore.mapping(placeSubscriptions: placeSubs, placeNames: placeNames,
                                                                  regionSubscriptions: regionSubs), to: activityDefaults)
    }
}

/// Bridges the system callbacks (device token) into `PushManager`.
final class PushAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    @MainActor static weak var manager: PushManager?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        // Push-to-start may launch the process without an active SwiftUI scene.
        Task { @MainActor in await Self.manager?.start() }
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
