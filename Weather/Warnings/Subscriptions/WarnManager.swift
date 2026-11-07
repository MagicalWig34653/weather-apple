import Foundation
import Observation

/// What the manager needs from the push installation (implemented by `PushManager`, faked in tests).
@MainActor protocol WarnInstallationHost: AnyObject {
    /// Identity of the server-acknowledged installation; nil until then.
    func warningIdentity() -> PushIdentity?
    /// System permission and token registration (the caller has shown the explanation first).
    func prepareInstallationForWarnings() async -> Bool
    func syncInstallation() async
}

extension PushManager: WarnInstallationHost {
    func syncInstallation() async { await sync() }
}

/// A place or region as seen by the matcher. Coordinates and names stay in this process; only cell IDs reach the server.
struct WarnTarget: Equatable, Sendable {
    let key: String
    let name: String?
    let latitude: Double
    let longitude: Double
    /// nil = place (one cell), otherwise region radius in km.
    let radiusKm: Double?
}

enum WarnNotice: Equatable, Sendable {
    case limitReached, geometryOutdated, offline, rateLimited, notificationsDenied, failed
}

@MainActor @Observable
final class WarnManager {
    static let settingsKey = "warn.settings.v1"
    static let stateKey = "warn.state.v1"
    static let capability = "warnings", pushCapability = "warnings_push"
    /// Places on the coast or in harbours may lie just outside the outlines.
    static let placeMaxDistanceKm = 5.0

    struct SubRecord: Codable, Equatable { var id: String; var fingerprint: String }
    struct State: Codable, Equatable { var subs: [String: SubRecord] = [:] }

    private(set) var capabilityWarnings = false
    private(set) var capabilityWarningsPush = false
    private(set) var settings: WarnUserSettings
    private(set) var notice: WarnNotice?
    private(set) var isReconciling = false

    @ObservationIgnored private var state: State
    @ObservationIgnored private var again = false
    @ObservationIgnored private let gateway: WarnGateway
    @ObservationIgnored private let host: WarnInstallationHost
    @ObservationIgnored private let capabilities: () async throws -> Set<String>
    @ObservationIgnored private let matcherProvider: () -> WarnCellMatcher?
    @ObservationIgnored private var cachedMatcher: WarnCellMatcher?
    @ObservationIgnored var targets: () -> [WarnTarget]
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let nameDefaults: UserDefaults?

    init(gateway: WarnGateway, host: WarnInstallationHost, capabilities: @escaping () async throws -> Set<String>,
         matcher: @escaping () -> WarnCellMatcher?, targets: @escaping () -> [WarnTarget] = { [] },
         defaults: UserDefaults = .standard, nameDefaults: UserDefaults? = nil) {
        self.gateway = gateway; self.host = host; self.capabilities = capabilities; self.matcherProvider = matcher
        self.targets = targets; self.defaults = defaults; self.nameDefaults = nameDefaults
        settings = defaults.data(forKey: Self.settingsKey).flatMap { try? JSONDecoder().decode(WarnUserSettings.self, from: $0) } ?? WarnUserSettings()
        state = defaults.data(forKey: Self.stateKey).flatMap { try? JSONDecoder().decode(State.self, from: $0) } ?? State()
    }

    /// The installation must stay while warnings are on.
    var isActive: Bool { settings.enabled }
    var subscriptionCount: Int { state.subs.count }

    // MARK: Capabilities

    /// `GET /v1/status`; on failure the previous value stays (UI keeps its state, no request is made without the flag).
    func refreshCapabilities() async {
        do {
            let set = try await capabilities()
            capabilityWarnings = set.contains(Self.capability)
            capabilityWarningsPush = set.contains(Self.pushCapability)
        } catch is CancellationError {}
        catch {}
    }

    // MARK: Settings

    /// Opt-in or opt-out. The explanation (including "no replacement for official channels") was shown before.
    func setEnabled(_ on: Bool) async {
        notice = nil
        if on {
            if !capabilityWarningsPush { await refreshCapabilities() }
            guard capabilityWarningsPush else { return }
            guard await host.prepareInstallationForWarnings() else { notice = .notificationsDenied; return }
        }
        settings.enabled = on
        persistSettings()
        await reconcile()
        if !on { await host.syncInstallation() }
    }

    func setType(_ kind: WarnKind, on: Bool) async {
        if on { settings.types.insert(kind) } else { settings.types.remove(kind) }
        persistSettings(); await reconcile()
    }

    func setMinSeverity(_ kind: WarnKind, level: Int) async {
        guard (1...4).contains(level) else { return }
        settings.minSeverity[kind] = level
        persistSettings(); await reconcile()
    }

    func setTimeSensitive(_ on: Bool) async {
        settings.timeSensitive = on
        persistSettings(); await reconcile()
    }

    /// "Alle Mitteilungen ausschalten": the installation delete removes the server subscriptions.
    func resetLocally() {
        settings.enabled = false
        state = State()
        notice = nil
        persistSettings(); persistState(); writeNames([:])
    }

    // MARK: Reconcile

    /// Matches server subscriptions to the stored places and regions: creates missing ones, updates changed ones, deletes
    /// orphans. Only with capability `warnings_push`; without it no gateway call is made. Concurrent calls coalesce.
    func reconcile() async {
        guard !isReconciling else { again = true; return }
        isReconciling = true
        defer { isReconciling = false }
        repeat {
            again = false
            await run()
        } while again
    }

    private struct Wanted { var cells: [WarnCellID]; var names: [String] }

    private func matcher() -> WarnCellMatcher? {
        if cachedMatcher == nil { cachedMatcher = matcherProvider() }
        return cachedMatcher
    }

    private func cells(for target: WarnTarget, matcher: WarnCellMatcher) -> [WarnCellID] {
        if let radius = target.radiusKm {
            return matcher.cells(intersectingCircleLat: target.latitude, lon: target.longitude, radiusKm: radius, limit: 64)
        }
        return matcher.nearestCell(lat: target.latitude, lon: target.longitude, maxDistanceKm: Self.placeMaxDistanceKm).map { [$0] } ?? []
    }

    /// Display only (warnings view, independent of the push switch): warning cells per saved place and region.
    func placeCells() -> [WarnPlaceCells] {
        guard let matcher = matcher() else { return [] }
        return targets().map { WarnPlaceCells(name: $0.name, cells: Set(cells(for: $0, matcher: matcher))) }
    }

    /// Targets with identical cells share one subscription (no duplicate pushes for two places in one district).
    private func desired() -> [String: Wanted] {
        guard settings.enabled, !settings.types.isEmpty, let matcher = matcher() else { return [:] }
        var result: [String: Wanted] = [:]
        for target in targets() {
            let cells = cells(for: target, matcher: matcher)
            guard !cells.isEmpty else { continue }
            let key = cells.joined(separator: ",")
            var entry = result[key] ?? Wanted(cells: cells, names: [])
            if let name = NotificationNameStore.clean(target.name), !entry.names.contains(name) { entry.names.append(name) }
            result[key] = entry
        }
        return result
    }

    private func wire(_ cells: [WarnCellID]) -> WarnSubscriptionSettings {
        WarnSubscriptionSettings(warncellIDs: cells, types: settings.types,
                                 minSeverity: Dictionary(uniqueKeysWithValues: settings.types.map { ($0, settings.level(for: $0)) }),
                                 enabled: true, timeSensitive: settings.timeSensitive)
    }

    private func fingerprint(_ s: WarnSubscriptionSettings) -> String {
        let types = s.types.map(\.rawValue).sorted().map { "\($0):\(s.minSeverity[WarnKind(rawValue: $0)!] ?? 0)" }
        return s.warncellIDs.joined(separator: ",") + "|" + types.joined(separator: ",") + "|\(s.timeSensitive)"
    }

    private func run() async {
        if !settings.enabled, host.warningIdentity() == nil {
            // No acknowledged installation: nothing to delete remotely (an installation delete cascades).
            state = State(); persistState(); writeNames([:])
            return
        }
        guard capabilityWarningsPush else { return }
        guard let identity = host.warningIdentity() else { return }
        notice = nil
        let wanted = desired()
        if settings.enabled, !settings.types.isEmpty, matcher() == nil { notice = .failed; return }

        // Delete obsolete.
        for (key, record) in state.subs.sorted(by: { $0.key < $1.key }) where wanted[key] == nil {
            do { try await gateway.delete(identity, id: record.id); state.subs[key] = nil }
            catch WarnGatewayError.notFound { state.subs[key] = nil }
            catch { if stop(error) { break } }
        }
        persistState()

        // Create / update.
        loop: for (key, entry) in wanted.sorted(by: { $0.key < $1.key }) {
            let request = wire(entry.cells)
            let print = fingerprint(request)
            let existing = state.subs[key]
            if existing?.fingerprint == print { continue }
            do {
                if let existing {
                    do { try await gateway.update(identity, id: existing.id, request); state.subs[key] = SubRecord(id: existing.id, fingerprint: print) }
                    catch WarnGatewayError.notFound {
                        state.subs[key] = SubRecord(id: try await gateway.create(identity, request), fingerprint: print)
                    }
                } else {
                    state.subs[key] = SubRecord(id: try await gateway.create(identity, request), fingerprint: print)
                }
            } catch WarnGatewayError.limit { notice = .limitReached }
            catch WarnGatewayError.cellUnknown { notice = .geometryOutdated }
            catch { if stop(error) { break loop } }
            persistState()
        }

        var names: [String: String] = [:]
        for (key, record) in state.subs {
            if let entry = wanted[key], !entry.names.isEmpty { names[record.id] = entry.names.joined(separator: ", ") }
        }
        writeNames(names)
        persistState()
    }

    /// Sets the notice for connection-level failures; true = stop this run.
    private func stop(_ error: Error) -> Bool {
        switch error as? WarnGatewayError {
        case .rateLimited: notice = .rateLimited
        case .unavailable: notice = .offline
        case .limit: notice = .limitReached
        case .cellUnknown: notice = .geometryOutdated; return false
        default: notice = .failed
        }
        return true
    }

    private func writeNames(_ names: [String: String]) {
        let cleaned = names.compactMapValues { NotificationNameStore.clean($0) }
        NotificationNameStore.writeWarn(cleaned, to: nameDefaults)
    }

    private func persistSettings() {
        if let data = try? JSONEncoder().encode(settings) { defaults.set(data, forKey: Self.settingsKey) }
    }
    private func persistState() {
        if let data = try? JSONEncoder().encode(state) { defaults.set(data, forKey: Self.stateKey) }
    }

    // MARK: Production wiring

    static func live(push: PushManager) -> WarnManager {
        let pushGateway = HTTPPushGateway()
        var capabilities: () async throws -> Set<String> = { try await pushGateway.serverStatus().capabilities }
        #if DEBUG
        // UI tests only: `-UITestWarnCapabilities none|push` simulates the status without network.
        if let index = CommandLine.arguments.firstIndex(of: "-UITestWarnCapabilities"),
           CommandLine.arguments.indices.contains(index + 1) {
            let value = CommandLine.arguments[index + 1]
            capabilities = { value == "push" ? [Self.capability, Self.pushCapability] : value == "display" ? [Self.capability] : [] }
        } else if CommandLine.arguments.contains("-UITestWarnings") {
            capabilities = { [Self.capability] }
        }
        #endif
        let manager = WarnManager(
            gateway: HTTPWarnGateway(push: pushGateway), host: push, capabilities: capabilities,
            matcher: { (try? WarnGeometry.bundled()).map(WarnCellMatcher.init(geometry:)) },
            nameDefaults: UserDefaults(suiteName: SharedConfig.appGroup))
        push.externalSubscriptionsActive = { [weak manager] in manager?.isActive ?? false }
        push.onInstallationReady = { [weak manager] in await manager?.reconcile() }
        push.onResetAll = { [weak manager] in manager?.resetLocally() }
        return manager
    }

    /// Regions come from the rain-hint state (coarse center cell and radius).
    static func targets(places: [SavedPlace], push: PushManager) -> [WarnTarget] {
        var result = places.map {
            WarnTarget(key: "place:\($0.id.uuidString)", name: $0.name, latitude: $0.coordinate.latitude,
                       longitude: $0.coordinate.longitude, radiusKm: nil)
        }
        for entry in push.regionsSorted {
            let center = PushGrid.coordinate(of: entry.settings.center)
            result.append(WarnTarget(key: "region:\(entry.id.uuidString)", name: entry.settings.name, latitude: center.latitude,
                                     longitude: center.longitude, radiusKm: Double(entry.settings.radiusKm)))
        }
        return result
    }
}
