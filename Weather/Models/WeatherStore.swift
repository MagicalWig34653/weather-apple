import CoreLocation
import Foundation
import Observation
import SwiftUI
import WidgetKit

enum RadarSource: Equatable, Sendable {
    case cache, direct
    var label: String {
        self == .cache ? NSLocalizedString("RADAR_SOURCE_CACHE", value: "über Showers", comment: "Radar source")
            : NSLocalizedString("RADAR_SOURCE_DIRECT", value: "direkt vom DWD", comment: "Radar source")
    }
}

struct RadarAttribution: Equatable, Sendable {
    let attribution: String
    let modificationNotice: String
    static let `default` = RadarAttribution(
        attribution: NSLocalizedString("STORE_ATTRIBUTION", value: "Quelle: Deutscher Wetterdienst", comment: "Weather store message"),
        modificationNotice: NSLocalizedString("STORE_MODIFICATION_NOTICE", value: "Datenbasis: Deutscher Wetterdienst, Rasterdaten bildlich wiedergegeben", comment: "Weather store message"))
    init(attribution: String, modificationNotice: String) {
        self.attribution = attribution; self.modificationNotice = modificationNotice
    }
    init(_ manifest: RadarManifest) {
        self.init(attribution: manifest.attribution, modificationNotice: manifest.modificationNotice)
    }
}

@MainActor @Observable
final class WeatherStore: NSObject, @MainActor CLLocationManagerDelegate {
    var places: [SavedPlace] = []
    var selectedPlace = SavedPlace(name: "Berlin", coordinate: WeatherCoordinate(latitude: 52.52, longitude: 13.405))
    var forecast: RainForecast?
    var timeline: RadarTimeline?
    var selectedFrame = 0
    var isRadarLoading = false
    var isForecastLoading = false {
        didSet { if isForecastLoading, !oldValue { startProgressPolling() } }
    }
    /// Last reading of the running forecast load. Polled: the transport reports from background threads, which must not write observable state.
    private(set) var forecastReading = LoadProgress.Reading.indeterminate
    @ObservationIgnored private var progressPoll: Task<Void, Never>?
    var isLoading: Bool { isRadarLoading || isForecastLoading }
    var radarNotice: String?
    var forecastError: String?
    var radarError: String?
    var locationMessage: String?
    var storageMessage: String?
    var isPlaying = false
    var centerRevision = 0
    var radarReloadRevision = 0
    var lastRefresh: Date?
    /// Consecutive failed point-forecast loads (0 after a success or a place change).
    private(set) var forecastFailures = 0
    /// Last successful point-forecast load; tells "service has nothing newer" from "not asked yet".
    private(set) var forecastCheckedAt: Date?
    /// Where the currently shown radar images come from (honest source display).
    var radarSource: RadarSource = .cache
    var radarAttribution = RadarAttribution.default
    /// Effective maximum past of the radar timeline (hours): the user's choice, else the backend's window; only the cache
    /// backend can deliver more than one hour.
    private(set) var pastHours = RadarPastWindow.defaultHours
    /// The user's explicit choice; `nil` = never chosen (each map's own server window applies).
    private(set) var pastChoice: Int?
    /// The step shown as selected: the choice, else the active map's window (largest step not above it).
    var shownPastHours: Int {
        if let pastChoice { return pastChoice }
        guard layers.active != .radar, let offered = layers.offeredHistoryHours(layers.active) else { return pastHours }
        return RadarPastWindow.options.filter { $0 <= max(offered, RadarPastWindow.directHours) }.max() ?? RadarPastWindow.defaultHours
    }
    /// Past used for the play window: the choice, else the fixed default (the window never grows with the backend's 72 h).
    var playbackPastHours: Int { pastChoice ?? RadarPastWindow.defaultHours }
    private(set) var historyStatus = RadarHistoryStatus.notNeeded
    /// Longest past the server currently offers (`history_hours`), if known.
    var serverHistoryHours: Int? { if case .loaded(let hours) = historyStatus { hours } else { nil } }
    /// Longest past the ACTIVE map offers: the radar's `history.json`, else the layer's own manifest.
    /// What the server offers for the map in view: the radar's `history.json`, else the layer's own manifest.
    var activeServerHistoryHours: Int? { layers.active == .radar ? serverHistoryHours : layers.offeredHistoryHours(layers.active) }

    @ObservationIgnored private let reloadWidgets: () -> Void
    @ObservationIgnored private let client: DWDClient
    @ObservationIgnored private let backend: RadarBackendClient
    /// Optional map layers (pressure, lightning, clouds) with their own manifests; the radar logic above is independent of it.
    let layers: RadarLayerStore
    @ObservationIgnored private var backendBlockedUntil = Date.distantPast
    @ObservationIgnored private lazy var pathGate = RadarPathGate()
    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private var generation = UUID()
    /// Token of the running point-forecast load (a forecast-only reload does not touch the radar generation).
    @ObservationIgnored private var forecastToken = UUID()
    /// Shared by polls, manual reloads and timeline composition across suspension points.
    @ObservationIgnored private var radarGeneration = UUID()
    /// Refresh started by the last `select`; tests await it to order requests deterministically.
    @ObservationIgnored private(set) var selectionRefresh: Task<Void, Never>?
    @ObservationIgnored private var waitingForLocation = false
    /// Flüchtige Auswahlen bleiben nur im RAM; gespeicherte Orte nutzen zusätzlich den App-Group-Cache.
    @ObservationIgnored private var lastValidForecasts: [(placeID: UUID, forecast: RainForecast)] = []
    static let lastForecastLimit = 10
    @ObservationIgnored private var attemptedRadarFallback = false
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var placeStore: PlaceStore?
    @ObservationIgnored private var forecastCache: ForecastCache?
    @ObservationIgnored private var latestManifest: RadarManifest?
    @ObservationIgnored private var history: RadarHistory?
    @ObservationIgnored private var historyCheckedRun: String?
    @ObservationIgnored private var composedHours = RadarPastWindow.defaultHours

    override convenience init() {
        #if DEBUG
        if let mode = ForecastUITestStub.mode {
            self.init(client: ForecastUITestStub.client(mode: mode), backend: RadarUITestStub.isActive ? RadarUITestStub.backend : ForecastUITestStub.backend)
            clock = { ForecastUITestStub.now }
            return
        }
        #endif
        self.init(client: DWDClient())
    }

    init(client: DWDClient, backend: RadarBackendClient = RadarBackendClient(),
         defaults: UserDefaults = .standard, layers: RadarLayerStore? = nil,
         placeStore: PlaceStore? = nil, forecastCache: ForecastCache? = nil,
         reloadWidgets: @escaping () -> Void = { WidgetCenter.shared.reloadAllTimelines() }) {
        self.reloadWidgets = reloadWidgets
        self.client = client
        self.backend = backend
        #if DEBUG
        if layers == nil, let mode = RadarLayerStore.uiTestMode {
            self.layers = RadarLayerStore(radarBaseURL: backend.baseURL,
                                          client: RadarLayerStore.uiTestClient(mode: mode, radarBaseURL: backend.baseURL),
                                          clock: { RadarLayerStore.frozenNow ?? Date() })
        } else {
            self.layers = layers ?? RadarLayerStore(radarBaseURL: backend.baseURL)
        }
#else
        self.layers = layers ?? RadarLayerStore(radarBaseURL: backend.baseURL)
#endif
        self.defaults = defaults
        super.init()
        #if DEBUG
        if CommandLine.arguments.contains("-UITestResetPastChoice") { RadarPastWindow.clear(defaults) }   // UI tests: a fresh install
        #endif
        pastChoice = RadarPastWindow.choice(defaults)
        pastHours = pastChoice ?? RadarPastWindow.defaultHours
        composedHours = pastHours
        self.layers.setPastHours(pastChoice)
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        do {
            let store = try placeStore ?? PlaceStore()
            self.placeStore = store
            self.forecastCache = try forecastCache ?? ForecastCache()
            #if DEBUG
            // UI tests: start without a stored forecast (an earlier test's newer run would end every load before it starts).
            if CommandLine.arguments.contains("-UITestResetForecast") { try? self.forecastCache?.retain(placeIDs: []) }
            #endif
            let snapshot = try store.load()
            places = snapshot.places
            if let selected = places.first(where: { $0.id == snapshot.selectedPlaceID }) ?? places.first {
                selectedPlace = selected
                forecast = try self.forecastCache?.load(for: selected.id)
            }
            try self.forecastCache?.retain(placeIDs: Set(places.map(\.id)))
        } catch { storageMessage = NSLocalizedString("STORE_ERR_LOAD_PLACES", value: "Gespeicherte Orte oder Prognosen konnten nicht geladen werden.", comment: "Weather store message") }
    }

    /// Load now when nothing was loaded yet, no forecast is shown, or a newer run is expected than the shown one
    /// (independent of how long ago the last load was).
    func needsRefresh(now: Date? = nil) -> Bool {
        let now = now ?? clock()
        return !isForecastLoading && (forecast == nil
                       || ForecastRefreshPolicy.newRunExpected(shown: forecast?.referenceTime, now: now))
    }

    /// Time source for the forecast logic; injectable for tests.
    @ObservationIgnored var clock: () -> Date = { Date() }

    /// What the forecast header says about freshness; `nil` for a current forecast.
    enum ForecastStatus: Equatable { case refreshing, failed, serverBehind }

    /// A failure is shown only after a repeat also failed.
    var forecastFailureConfirmed: Bool { forecastError != nil && forecastFailures >= ForecastRefreshPolicy.confirmedFailures }

    func forecastStatus(now: Date? = nil) -> ForecastStatus? {
        let now = now ?? clock()
        guard let forecast else { return nil }
        // "Refreshing" only while a request really runs: not while waiting for a repeat after a first failure,
        // not for a stale forecast whose load ended or was cancelled (Build 49 kept spinning in those states).
        if isForecastLoading { return .refreshing }
        if forecastFailureConfirmed { return .failed }
        if ForecastRefreshPolicy.serverBehind(shown: forecast.referenceTime, checkedAt: forecastCheckedAt, now: now) { return .serverBehind }
        return nil
    }

    /// Loading circle at the right edge of the forecast pill: exactly while a forecast request runs, also the first one.
    var showsForecastSpinner: Bool { isForecastLoading }

    /// Bar on the bottom edge of the forecast header: with a measured fill only where every request reports a total.
    var updateProgressDisplay: UpdateProgressDisplay {
        UpdateProgressDisplay.make(isForecastLoading: isForecastLoading, isRadarLoading: isRadarLoading, reading: forecastReading)
    }

    private func startProgressPolling() {
        progressPoll?.cancel()
        forecastReading = .indeterminate
        progressPoll = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, self.isForecastLoading else { break }
                let reading = self.client.progress.reading
                if reading != self.forecastReading { self.forecastReading = reading }
                try? await Task.sleep(for: .milliseconds(100))
            }
            if !Task.isCancelled { self?.forecastReading = .indeterminate }
        }
    }

    /// Visible-app loop: load when due (also right after returning), then wait as `ForecastRefreshSchedule` says.
    func runForecastRefresh(schedule: ForecastRefreshSchedule = ForecastRefreshSchedule(),
                            restricted: (() -> Bool)? = nil,
                            sleep: (TimeInterval) async throws -> Void = { try await Task.sleep(for: .seconds($0)) }) async {
        var schedule = schedule
        while !Task.isCancelled {
            if needsRefresh() { await reloadForecast() }
            var limited = restricted?() ?? (ProcessInfo.processInfo.isLowPowerModeEnabled || pathGate.isConstrained)
            #if DEBUG
            // Only with -UITestForecast (DEBUG): the simulator's network path state can push the cadence to 300 s.
            // The cause of the one-off test-runner restart in ForecastRefreshUITests is not proven (Backlog card).
            if ForecastUITestStub.mode != nil { limited = false }
            #endif
            let delay = schedule.nextDelay(now: clock(),shown: forecast?.referenceTime, failures: forecastFailures, restricted: limited)
            do { try await sleep(delay) } catch { return }
        }
    }

    var frameDate: Date? {
        guard let timeline, timeline.dates.indices.contains(selectedFrame) else { return nil }
        return timeline.dates[selectedFrame]
    }

    var frameReference: Date? {
        guard let timeline, let frameDate else { return nil }
        return min(frameDate, timeline.referenceTime)
    }

    var isForecastFrame: Bool {
        guard let frameDate, let timeline else { return false }
        return frameDate > timeline.referenceTime
    }

    /// Unknown or malformed links leave the current selection untouched.
    @discardableResult
    func openWidgetURL(_ url: URL) -> Bool {
        guard let id = WidgetDeepLink.placeID(from: url),
              let place = places.first(where: { $0.id == id }) else { return false }
        select(place)
        return true
    }

    func select(_ place: SavedPlace) {
        // Invalidate the old request before the replacement refresh task can start.
        generation = UUID()
        forecastToken = UUID()
        radarGeneration = UUID()
        selectedPlace = place
        if places.contains(where: { $0.id == place.id }) { persistPlaces() }
        forecast = lastValidForecast(for: place.id)
        forecastError = nil
        forecastFailures = 0
        forecastCheckedAt = nil
        isPlaying = false
        centerRevision += 1
        reloadWidgets()
        selectionRefresh = Task { await refresh() }
    }

    func selectMapPoint(latitude: Double, longitude: Double) {
        select(SavedPlace(name: "Kartenpunkt", coordinate: WeatherCoordinate(latitude: latitude, longitude: longitude)))
    }

    func saveSelection(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        selectedPlace.name = trimmed
        if let index = places.firstIndex(where: { $0.id == selectedPlace.id }) {
            places[index] = selectedPlace
        } else { places.append(selectedPlace) }
        persistPlaces()
        if let forecast { rememberForecast(forecast, for: selectedPlace.id) }
        reloadWidgets()
    }

    func rename(_ place: SavedPlace, name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = places.firstIndex(where: { $0.id == place.id }) else { return }
        places[index].name = trimmed
        if selectedPlace.id == place.id { selectedPlace.name = trimmed }
        persistPlaces()
        reloadWidgets()
    }

    /// Called with the IDs of deleted places (push subscriptions are removed there).
    @ObservationIgnored var onPlacesRemoved: (([UUID]) -> Void)?

    func deletePlaces(at offsets: IndexSet) {
        let removed = offsets.compactMap { places.indices.contains($0) ? places[$0].id : nil }
        places.remove(atOffsets: offsets)
        if !removed.isEmpty { onPlacesRemoved?(removed) }
        lastValidForecasts.removeAll { removed.contains($0.placeID) }
        persistPlaces()
        do { try forecastCache?.retain(placeIDs: Set(places.map(\.id))) }
        catch { storageMessage = NSLocalizedString("STORE_ERR_REMOVE_FORECASTS", value: "Gespeicherte Prognosen konnten nicht entfernt werden.", comment: "Weather store message") }
        reloadWidgets()
    }

    func refresh() async {
        let requestID = UUID()
        generation = requestID
        forecastToken = requestID
        radarGeneration = requestID
        let place = selectedPlace
        isRadarLoading = true
        isForecastLoading = true
        radarNotice = nil
        attemptedRadarFallback = false
        // A retry must also reload missing tiles when the data run is unchanged.
        radarReloadRevision += 1
        defer {
            if generation == requestID {
                isRadarLoading = false
                isForecastLoading = false
            }
        }
        forecastError = nil
        radarError = nil
        // Each source can fail independently: a point error must not disable the map.
        async let mapUpdate: Void = refreshTimeline(requestID: requestID, placeID: place.id)
        async let pointUpdate: Void = refreshForecast(requestID: requestID, place: place)
        _ = await (mapUpdate, pointUpdate)
        guard generation == requestID, selectedPlace.id == place.id, !Task.isCancelled else { return }
        lastRefresh = Date()
    }

    private func refreshTimeline(requestID: UUID, placeID: UUID) async {
        let result = await loadTimeline(requestID: requestID)
        guard generation == requestID, radarGeneration == requestID, selectedPlace.id == placeID, !Task.isCancelled else { return }
        isRadarLoading = false
        switch result {
        case .success(let value):
            apply(value.timeline, source: value.source, attribution: value.attribution, keepSelection: false)
            // The setting changed while loading: compose again for the new choice (selection kept).
            if value.source == .cache, composedHours != pastHours { await recomposeTimeline() }
        case .failure(let error):
            radarError = error.localizedDescription
        }
    }

    private func apply(_ value: RadarTimeline, source: RadarSource, attribution: RadarAttribution?, keepSelection: Bool) {
        let previous = frameDate, previousReference = timeline?.referenceTime
        timeline = value
        radarSource = source
        radarAttribution = attribution ?? .default
        radarError = nil
        selectedFrame = keepSelection
            ? RadarTimelineSelection.index(previous: previous, previousReference: previousReference,
                                           dates: value.dates, reference: value.referenceTime)
            : value.dates.firstIndex(of: value.referenceTime) ?? 0
    }

    /// Visible-app poll of the cache manifest (ETag, 304 is cheap). A new run replaces the
    /// slots and keeps the selected instant; a returning backend ends a direct-DWD fallback.
    @discardableResult
    func pollRadar() async -> RadarPollOutcome {
        guard !isRadarLoading, Date() >= backendBlockedUntil else { return .skipped }
        let requestID = UUID()
        radarGeneration = requestID
        let outcome = await backend.latest()
        guard radarGeneration == requestID, !isRadarLoading, !Task.isCancelled, Date() >= backendBlockedUntil else { return .skipped }
        switch outcome {
        case .fresh(let manifest, _):
            if radarSource == .cache, latestManifest == manifest { return .succeeded }
            guard let merged = await resolveBackendTimeline(manifest, retryHistory: false, requestID: requestID) else { return .skipped }
            guard radarGeneration == requestID, !isRadarLoading, !Task.isCancelled else { return .skipped }
            apply(merged.timeline, source: .cache, attribution: RadarAttribution(manifest), keepSelection: true)
            radarNotice = nil
            return .succeeded
        case .fallback:
            if radarSource == .cache, let timeline,
               Date().timeIntervalSince(timeline.referenceTime) > RadarBackendConfig.maximumDataAge {
                await switchToDirectRadar(notice: nil, requestID: requestID)
            }
            return .failed
        }
    }

    /// Adaptive loop for the visible app: poll, then wait as `RadarPollSchedule` says. Ends on cancellation.
    func runRadarPolling(schedule: RadarPollSchedule = RadarPollSchedule(),
                         now: @escaping () -> Date = { Date() },
                         restricted: (() -> Bool)? = nil,
                         sleep: (TimeInterval) async throws -> Void = { try await Task.sleep(for: .seconds($0)) }) async {
        var schedule = schedule
        while !Task.isCancelled {
            let outcome = await pollRadar()
            let limited = restricted?() ?? (ProcessInfo.processInfo.isLowPowerModeEnabled || pathGate.isConstrained)
            let delay = schedule.nextDelay(now: now(), latestReference: latestManifest?.referenceTime,
                                           failed: outcome == .failed, restricted: limited)
            do { try await sleep(delay) } catch { return }
        }
    }

    /// Called by the map when cache images cannot be loaded at all: use the direct DWD path
    /// and do not return to the cache for a few minutes.
    func backendImagesUnavailable() {
        guard radarSource == .cache, timeline?.backend != nil, !isRadarLoading else { return }
        backendBlockedUntil = Date().addingTimeInterval(RadarBackendConfig.imageFailureBlockInterval)
        let requestID = UUID()
        radarGeneration = requestID
        Task { await switchToDirectRadar(notice: NSLocalizedString("STORE_RADAR_CACHE_DOWN", value: "Der Showers-Radar-Dienst ist gerade nicht erreichbar. Die Radarbilder kommen direkt vom DWD.", comment: "Weather store message"), requestID: requestID) }
    }

    private func switchToDirectRadar(notice: String?, requestID: UUID) async {
        guard radarGeneration == requestID, !Task.isCancelled else { return }
        do {
            let direct = try await client.radarTimeline()
            guard radarGeneration == requestID, !isRadarLoading, !Task.isCancelled else { return }
            apply(direct, source: .direct, attribution: nil, keepSelection: true)
            radarNotice = notice
        } catch { /* keep the current images; the next refresh reports the error */ }
    }

    /// Point forecast only (timed refresh and retries): leaves the radar and its tiles alone.
    func reloadForecast() async {
        guard !isForecastLoading else { return }
        let token = UUID()
        forecastToken = token
        let place = selectedPlace
        isForecastLoading = true
        forecastError = nil
        defer { if forecastToken == token { isForecastLoading = false } }
        await refreshForecast(requestID: token, place: place)
        if forecastToken == token, selectedPlace.id == place.id, !Task.isCancelled { lastRefresh = clock() }
    }

    private func refreshForecast(requestID: UUID, place: SavedPlace) async {
        let result = await loadForecast(at: place.coordinate)
        guard forecastToken == requestID, selectedPlace.id == place.id, !Task.isCancelled else { return }
        isForecastLoading = false
        switch result {
        case .success(let value):
            forecast = value
            forecastFailures = 0
            forecastCheckedAt = clock()
            rememberForecast(value, for: place.id)
            reloadWidgets()
        case .failure(let error) where isRunNotReady(error):
            // The index lists a new run, but the service still answers "not available" for it (measured 10 to 30 s,
            // 20.11.2026): the shown forecast is valid and nothing failed. The loop asks again within seconds.
            forecastCheckedAt = clock()
        case .failure(let error):
            forecastFailures += 1
            // Keep (or restore) this place's last valid forecast; the view marks it as not confirmed.
            forecast = lastValidForecast(for: place.id)
            forecastError = error.localizedDescription
        }
    }

    private func isRunNotReady(_ error: Error) -> Bool {
        guard (error as? DWDDataError) == .runUnavailable, let forecast else { return false }
        return !forecast.isStale(at: clock())
    }

    func lastValidForecast(for placeID: UUID) -> RainForecast? {
        if let value = lastValidForecasts.first(where: { $0.placeID == placeID })?.forecast { return value }
        guard places.contains(where: { $0.id == placeID }) else { return nil }
        do { return try forecastCache?.load(for: placeID) }
        catch {
            storageMessage = NSLocalizedString("STORE_ERR_LOAD_FORECAST", value: "Gespeicherte Prognose konnte nicht geladen werden.", comment: "Weather store message")
            return nil
        }
    }

    func rememberForecast(_ forecast: RainForecast, for placeID: UUID) {
        if places.contains(where: { $0.id == placeID }) {
            do { try forecastCache?.save(forecast, for: placeID) }
            catch { storageMessage = NSLocalizedString("STORE_ERR_SAVE_FORECAST", value: "Prognose konnte nicht auf dem Gerät gespeichert werden.", comment: "Weather store message") }
        }
        lastValidForecasts.removeAll { $0.placeID == placeID }
        lastValidForecasts.append((placeID, forecast))
        if lastValidForecasts.count > Self.lastForecastLimit {
            lastValidForecasts.removeFirst(lastValidForecasts.count - Self.lastForecastLimit)
        }
    }

    /// Only a concrete unavailable-run response may select one previous, still-fresh
    /// radar run. The timeline's real reference changes; old images are never relabelled.
    func acceptRadarLoadState(_ state: RadarLoadState) {
        guard state.reloadRevision == radarReloadRevision,
              state.frameDate == frameDate, state.referenceTime == frameReference,
              state.referenceTime == timeline?.referenceTime,
              state.isSettled, state.succeeded == 0, state.runUnavailable > 0,
              !attemptedRadarFallback, !isRadarLoading else { return }
        attemptedRadarFallback = true
        let requestID = generation
        let radarRequestID = UUID()
        radarGeneration = radarRequestID
        let unavailableReference = state.referenceTime
        let currentFrame = frameDate
        isRadarLoading = true
        Task {
            defer { if generation == requestID, radarGeneration == radarRequestID { isRadarLoading = false } }
            do {
                let fallback = try await client.radarTimeline(before: unavailableReference)
                guard generation == requestID, radarGeneration == radarRequestID, frameDate == currentFrame,
                      timeline?.referenceTime == unavailableReference, !Task.isCancelled else { return }
                timeline = fallback
                selectedFrame = fallback.dates.firstIndex(of: fallback.referenceTime) ?? 0
                radarNotice = String(format: NSLocalizedString("STORE_RADAR_FALLBACK_RUN", value: "Neuster Radarlauf noch nicht verfügbar. Radar zeigt den vorherigen Lauf von %@ Uhr.", comment: "Weather store message"),
                                         LocaleFormat.time(fallback.referenceTime))
            } catch {
                guard generation == requestID, radarGeneration == radarRequestID else { return }
                radarNotice = NSLocalizedString("STORE_RADAR_RUN_UNAVAILABLE", value: "Radarlauf derzeit nicht verfügbar. Bitte erneut laden.", comment: "Weather store message")
            }
        }
    }

    private struct LoadedTimeline {
        let timeline: RadarTimeline
        let source: RadarSource
        let attribution: RadarAttribution?
    }

    /// Cache backend first; direct DWD tiles on any error, 404, timeout, invalid or stale data.
    private func loadTimeline(requestID: UUID) async -> Result<LoadedTimeline, Error> {
        guard radarGeneration == requestID, !Task.isCancelled else { return .failure(CancellationError()) }
        if Date() >= backendBlockedUntil, case .fresh(let manifest, _) = await backend.latest() {
            guard let merged = await resolveBackendTimeline(manifest, retryHistory: true, requestID: requestID) else { return .failure(CancellationError()) }
            return .success(LoadedTimeline(timeline: merged.timeline, source: .cache,
                                           attribution: RadarAttribution(manifest)))
        }
        guard radarGeneration == requestID, !Task.isCancelled else { return .failure(CancellationError()) }
        do { return .success(LoadedTimeline(timeline: try await client.radarTimeline(), source: .direct, attribution: nil)) }
        catch { return .failure(error) }
    }

    /// Combines `latest.json` with `history.json` for the chosen past. History is requested only if the
    /// choice exceeds what latest covers, and only for a new run (or when a manual refresh retries a miss).
    private func resolveBackendTimeline(_ latest: RadarManifest, retryHistory: Bool, requestID: UUID) async -> RadarManifest? {
        guard radarGeneration == requestID, !Task.isCancelled else { return nil }
        var hours = pastChoice ?? RadarPastWindow.defaultHours
        // Without a choice the backend's window decides, so `history.json` is read once per run to learn it.
        if pastChoice == nil || RadarTimelineComposer.needsHistory(latest: latest, hours: hours) {
            if latest.run != historyCheckedRun || (retryHistory && history == nil) {
                let result = await backend.history()
                guard radarGeneration == requestID, !Task.isCancelled else { return nil }
                switch result {
                case .loaded(let value, _):
                    history = value
                    historyCheckedRun = latest.run
                case .unavailable(let error):
                    // A transient network error keeps the last valid history; 404/invalid drops it.
                    if error != .unreachable { history = nil }
                    historyCheckedRun = latest.run
                }
            }
        }
        if pastChoice == nil {
            hours = RadarPastWindow.standardHours(history: history.flatMap { RadarTimelineComposer.isCompatible($0, with: latest) ? $0 : nil })
        }
        if RadarTimelineComposer.needsHistory(latest: latest, hours: hours) {
            if let history, RadarTimelineComposer.isCompatible(history, with: latest) {
                historyStatus = .loaded(hours: history.historyHours)
            } else { historyStatus = .unavailable }
        } else {
            historyStatus = .notNeeded
        }
        latestManifest = latest
        pastHours = hours
        composedHours = hours
        return RadarTimelineComposer.compose(latest: latest, history: history, hours: hours)
    }

    /// Changes the maximum past and persists it. The current instant stays selected where possible.
    func setPastHours(_ hours: Int) {
        guard RadarPastWindow.options.contains(hours), hours != pastChoice else { return }
        pastChoice = hours
        pastHours = hours
        layers.setPastHours(hours)
        RadarPastWindow.save(hours, to: defaults)
        guard radarSource == .cache, latestManifest != nil, !isRadarLoading else { return }
        Task { await recomposeTimeline() }
    }

    /// Forgets the choice: every map shows its own server window again (nothing stored).
    func usePastDefault() {
        guard pastChoice != nil else { return }
        pastChoice = nil
        RadarPastWindow.clear(defaults)
        layers.setPastHours(nil)
        guard radarSource == .cache, latestManifest != nil, !isRadarLoading else { return }
        Task { await recomposeTimeline() }
    }

    private func recomposeTimeline() async {
        guard radarSource == .cache, !isRadarLoading, let latest = latestManifest else { return }
        let choice = pastChoice
        let requestID = UUID()
        radarGeneration = requestID
        guard let merged = await resolveBackendTimeline(latest, retryHistory: true, requestID: requestID) else { return }
        guard radarGeneration == requestID, choice == pastChoice, !isRadarLoading, !Task.isCancelled, radarSource == .cache else { return }
        apply(merged.timeline, source: .cache, attribution: RadarAttribution(latest), keepSelection: true)
    }

    private func loadForecast(at coordinate: WeatherCoordinate) async -> Result<RainForecast, Error> {
        // Caches are skipped only while a newer run than the shown one is expected.
        let now = clock()
        let expected = ForecastRefreshPolicy.newRunExpected(shown: forecast?.referenceTime, now: now)
            ? ForecastRefreshPolicy.expectedRun(at: now) : nil
        do { return .success(try await client.forecast(at: coordinate, expectedNewest: expected)) }
        catch { return .failure(error) }
    }

    func requestLocation() {
        waitingForLocation = true
        locationMessage = nil
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways: manager.requestLocation()
        case .denied, .restricted:
            waitingForLocation = false
            locationMessage = NSLocalizedString("STORE_LOCATION_DENIED", value: "Standortzugriff ist deaktiviert. Du kannst einen Ort suchen oder den Zugriff in den iOS-Einstellungen erlauben.", comment: "Weather store message")
        @unknown default:
            waitingForLocation = false
            locationMessage = NSLocalizedString("STORE_LOCATION_UNAVAILABLE", value: "Der Standort ist derzeit nicht verfügbar.", comment: "Weather store message")
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard waitingForLocation else { return }
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        } else if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted {
            waitingForLocation = false
            locationMessage = NSLocalizedString("STORE_LOCATION_DENIED_SEARCH", value: "Ohne Standortzugriff kannst du Orte weiterhin suchen und auf der Karte auswählen.", comment: "Weather store message")
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        waitingForLocation = false
        guard let location = locations.last, abs(location.timestamp.timeIntervalSinceNow) < 120 else {
            locationMessage = NSLocalizedString("STORE_LOCATION_NO_FIX", value: "Es konnte kein aktueller Standort bestimmt werden.", comment: "Weather store message")
            return
        }
        select(SavedPlace(name: NSLocalizedString("STORE_CURRENT_LOCATION", value: "Aktueller Standort", comment: "Weather store message"), coordinate: WeatherCoordinate(
            latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)))
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        waitingForLocation = false
        locationMessage = NSLocalizedString("STORE_LOCATION_FAILED", value: "Der Standort konnte nicht bestimmt werden. Bitte erneut versuchen oder einen Ort suchen.", comment: "Weather store message")
    }

    private func persistPlaces() {
        do {
            guard let placeStore else { throw PlaceStore.StorageError.appGroupUnavailable }
            let previousSelection = try placeStore.load().selectedPlaceID
            let selectedID = places.contains(where: { $0.id == selectedPlace.id }) ? selectedPlace.id : previousSelection
            try placeStore.save(.init(places: places, selectedPlaceID: selectedID))
            storageMessage = nil
        } catch { storageMessage = NSLocalizedString("STORE_ERR_SAVE_CHANGE", value: "Die Änderung konnte nicht auf dem Gerät gespeichert werden.", comment: "Weather store message") }
    }
}

enum RadarPollOutcome: Equatable, Sendable { case succeeded, failed, skipped }
