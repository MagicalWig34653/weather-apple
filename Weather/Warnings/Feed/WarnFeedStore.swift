import Foundation
import Observation

enum WarnFeedBackendConfig {
    /// `https://<host>/v1/warnings/active`, derived from the radar base URL (same host, same debug override).
    static func activeURL(radarBaseURL: URL = RadarBackendConfig.baseURL()) -> URL {
        radarBaseURL.deletingLastPathComponent().appendingPathComponent("warnings/active")
    }
}

/// Loads all active warnings (public, without any location or installation identifier) and keeps the last state.
/// Matching against the device's own districts happens locally in the views.
@MainActor @Observable
final class WarnFeedStore {
    typealias Transport = @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)

    enum State: Equatable { case idle, loading, loaded, failed(cachedAt: Date?) }

    /// Shortest gap between two automatic requests (the server caches for 30 s anyway).
    static let minInterval: TimeInterval = 30

    private(set) var warnings: [ActiveWarning] = []
    /// Last successful feed sync of the server (not the device clock).
    private(set) var fetchedAt: Date?
    private(set) var state: State = .idle
    private(set) var placeCells: [WarnPlaceCells] = []

    @ObservationIgnored private let isEnabled: @MainActor () -> Bool
    @ObservationIgnored var placesProvider: @MainActor () -> [WarnPlaceCells]
    @ObservationIgnored private let transport: Transport
    @ObservationIgnored private let url: URL
    @ObservationIgnored private let cacheURL: URL?
    @ObservationIgnored private let languageCode: () -> String
    @ObservationIgnored private let clock: () -> Date
    @ObservationIgnored private var lastAttempt: Date?

    init(isEnabled: @escaping @MainActor () -> Bool, url: URL = WarnFeedBackendConfig.activeURL(),
         cacheURL: URL? = WarnFeedStore.defaultCacheURL(), transport: Transport? = nil,
         languageCode: @escaping () -> String = { WarnFeedStore.appLanguage() },
         clock: @escaping () -> Date = Date.init,
         placesProvider: @escaping @MainActor () -> [WarnPlaceCells] = { [] }) {
        self.isEnabled = isEnabled; self.url = url; self.cacheURL = cacheURL
        self.languageCode = languageCode; self.clock = clock; self.placesProvider = placesProvider
        self.transport = transport ?? Self.liveTransport()
        loadCache()
    }

    /// "en" when the app runs in English, otherwise "de" (the only languages the server knows).
    nonisolated static func appLanguage() -> String {
        Bundle.main.preferredLocalizations.first == "en" ? "en" : "de"
    }

    nonisolated static func defaultCacheURL() -> URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("warnings-active.json")
    }

    private static func liveTransport() -> Transport {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCredentialStorage = nil
        configuration.timeoutIntervalForRequest = 8
        configuration.timeoutIntervalForResource = 20
        let session = URLSession(configuration: configuration)
        return { request in
            let (data, response) = try await session.data(for: request)
            guard let response = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
            return (data, response)
        }
    }

    /// Recomputes which warning cells the saved places lie in (call when places or regions change).
    func reloadPlaces() {
        guard isEnabled() else { placeCells = []; return }
        placeCells = placesProvider()
    }

    /// `force` skips the minimum interval (pull to refresh). Without the capability no request is made.
    func refresh(force: Bool = false) async {
        guard isEnabled() else { return }
        if state == .loading { return }
        let now = clock()
        if !force, let lastAttempt, now.timeIntervalSince(lastAttempt) < Self.minInterval { return }
        lastAttempt = now
        reloadPlaces()
        state = .loading
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.httpShouldHandleCookies = false
        request.setValue(languageCode(), forHTTPHeaderField: "Accept-Language")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        do {
            let (data, response) = try await transport(request)
            guard response.statusCode == 200 else { throw URLError(.badServerResponse) }
            let decoded = try ActiveWarningsResponse.decode(data)
            warnings = decoded.warnings
            fetchedAt = decoded.fetchedAt
            state = .loaded
            if let cacheURL { try? data.write(to: cacheURL, options: .atomic) }
        } catch is CancellationError {
            state = fetchedAt == nil ? .idle : .failed(cachedAt: fetchedAt)
        } catch {
            state = .failed(cachedAt: fetchedAt)
        }
    }

    private func loadCache() {
        guard let cacheURL, let data = try? Data(contentsOf: cacheURL),
              let decoded = try? ActiveWarningsResponse.decode(data) else { return }
        warnings = decoded.warnings
        fetchedAt = decoded.fetchedAt
    }

    // MARK: Derived

    /// Warnings of the saved places (non-expired, sorted).
    func relevantWarnings(now: Date) -> [ActiveWarning] {
        WarnFilter.relevant(warnings, cells: Set(placeCells.flatMap(\.cells)), now: now)
    }

    func allWarnings(now: Date) -> [ActiveWarning] { WarnFilter.active(warnings, now: now) }

    /// Names of the saved places a warning applies to (device only, for display).
    func placeNames(for warning: ActiveWarning) -> [String] {
        placeCells.filter { !$0.cells.isDisjoint(with: warning.warncellIDs) }.compactMap { NotificationNameStore.clean($0.name) }
    }

    var hasPlaces: Bool { !placeCells.isEmpty }
    var hasAnyCells: Bool { placeCells.contains { !$0.cells.isEmpty } }

    func staleness(now: Date) -> Staleness? { fetchedAt.map { WarnFilter.staleness(fetchedAt: $0, now: now) } }
}

extension WarnFeedStore {
    /// Production wiring: no request without the server capability `warnings`; places come from the `WarnManager`.
    static func live(warn: WarnManager) -> WarnFeedStore {
        var transport: Transport?
        var cacheURL = defaultCacheURL()
        var provider: @MainActor () -> [WarnPlaceCells] = { [warn] in warn.placeCells() }
        #if DEBUG
        if let mode = uiTestMode {
            transport = uiTestTransport(mode: mode)
            cacheURL = nil
            if mode == "fixture" { provider = { [WarnPlaceCells(name: "Berlin", cells: ["111000000"])] } }
        }
        #endif
        return WarnFeedStore(isEnabled: { [warn] in warn.capabilityWarnings }, cacheURL: cacheURL, transport: transport,
                             placesProvider: provider)
    }
}
