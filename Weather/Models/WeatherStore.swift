import CoreLocation
import Foundation
import Observation
import SwiftUI

enum RadarSource: Equatable, Sendable {
    case cache, direct
    var label: String { self == .cache ? "ShowerNow-Cache" : "direkt vom DWD" }
}

struct RadarAttribution: Equatable, Sendable {
    let attribution: String
    let modificationNotice: String
    static let `default` = RadarAttribution(
        attribution: "Quelle: Deutscher Wetterdienst",
        modificationNotice: "Datenbasis: Deutscher Wetterdienst, Rasterdaten bildlich wiedergegeben")
    init(attribution: String, modificationNotice: String) {
        self.attribution = attribution; self.modificationNotice = modificationNotice
    }
    init(_ manifest: RadarManifest) {
        self.init(attribution: manifest.attribution, modificationNotice: manifest.modificationNotice)
    }
}

struct SavedPlace: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var coordinate: WeatherCoordinate
}

@MainActor @Observable
final class WeatherStore: NSObject, @MainActor CLLocationManagerDelegate {
    var places: [SavedPlace] = []
    var selectedPlace = SavedPlace(name: "Berlin", coordinate: WeatherCoordinate(latitude: 52.52, longitude: 13.405))
    var forecast: RainForecast?
    var timeline: RadarTimeline?
    var selectedFrame = 0
    var isRadarLoading = false
    var isForecastLoading = false
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
    /// Where the currently shown radar images come from (honest source display).
    var radarSource: RadarSource = .cache
    var radarAttribution = RadarAttribution.default

    @ObservationIgnored private let client: DWDClient
    @ObservationIgnored private let backend: RadarBackendClient
    @ObservationIgnored private var backendBlockedUntil = Date.distantPast
    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var waitingForLocation = false
    @ObservationIgnored private var forecastPlaceID: UUID?
    @ObservationIgnored private var attemptedRadarFallback = false

    override convenience init() {
        self.init(client: DWDClient())
    }

    init(client: DWDClient, backend: RadarBackendClient = RadarBackendClient()) {
        self.client = client
        self.backend = backend
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        do {
            let url = try Self.storageURL()
            if FileManager.default.fileExists(atPath: url.path) {
                places = try JSONDecoder().decode([SavedPlace].self, from: Data(contentsOf: url))
                if let first = places.first { selectedPlace = first }
            }
        } catch { storageMessage = "Gespeicherte Orte konnten nicht geladen werden." }
    }

    var needsRefresh: Bool {
        !isLoading && (lastRefresh.map { Date().timeIntervalSince($0) >= 300 } ?? true)
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

    func select(_ place: SavedPlace) {
        // Invalidate the old request before the replacement refresh task can start.
        generation = UUID()
        selectedPlace = place
        forecast = nil
        forecastError = nil
        isPlaying = false
        centerRevision += 1
        Task { await refresh() }
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
    }

    func rename(_ place: SavedPlace, name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = places.firstIndex(where: { $0.id == place.id }) else { return }
        places[index].name = trimmed
        if selectedPlace.id == place.id { selectedPlace.name = trimmed }
        persistPlaces()
    }

    func deletePlaces(at offsets: IndexSet) {
        places.remove(atOffsets: offsets)
        persistPlaces()
    }

    func refresh() async {
        let requestID = UUID()
        generation = requestID
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
        let result = await loadTimeline()
        guard generation == requestID, selectedPlace.id == placeID, !Task.isCancelled else { return }
        isRadarLoading = false
        switch result {
        case .success(let value):
            apply(value.timeline, source: value.source, attribution: value.attribution, keepSelection: false)
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
    func pollRadar() async {
        guard !isRadarLoading, Date() >= backendBlockedUntil else { return }
        let outcome = await backend.latest()
        guard !isRadarLoading, !Task.isCancelled, Date() >= backendBlockedUntil else { return }
        switch outcome {
        case .fresh(let manifest, _):
            if radarSource == .cache, timeline?.backend == manifest { return }
            apply(manifest.timeline, source: .cache, attribution: RadarAttribution(manifest), keepSelection: true)
            radarNotice = nil
        case .fallback:
            guard radarSource == .cache, let timeline,
                  Date().timeIntervalSince(timeline.referenceTime) > RadarBackendConfig.maximumDataAge else { return }
            await switchToDirectRadar(notice: nil)
        }
    }

    /// Called by the map when cache images cannot be loaded at all: use the direct DWD path
    /// and do not return to the cache for a few minutes.
    func backendImagesUnavailable() {
        guard radarSource == .cache, timeline?.backend != nil, !isRadarLoading else { return }
        backendBlockedUntil = Date().addingTimeInterval(RadarBackendConfig.imageFailureBlockInterval)
        Task { await switchToDirectRadar(notice: "Radar-Cache nicht erreichbar. Radar kommt direkt vom DWD.") }
    }

    private func switchToDirectRadar(notice: String?) async {
        do {
            let direct = try await client.radarTimeline()
            guard !isRadarLoading, !Task.isCancelled else { return }
            apply(direct, source: .direct, attribution: nil, keepSelection: true)
            radarNotice = notice
        } catch { /* keep the current images; the next refresh reports the error */ }
    }

    private func refreshForecast(requestID: UUID, place: SavedPlace) async {
        let result = await loadForecast(at: place.coordinate)
        guard generation == requestID, selectedPlace.id == place.id, !Task.isCancelled else { return }
        isForecastLoading = false
        switch result {
        case .success(let value):
            forecast = value
            forecastPlaceID = place.id
        case .failure(let error):
            if forecastPlaceID != place.id { forecast = nil }
            forecastError = error.localizedDescription
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
        let unavailableReference = state.referenceTime
        let currentFrame = frameDate
        isRadarLoading = true
        Task {
            defer { if generation == requestID { isRadarLoading = false } }
            do {
                let fallback = try await client.radarTimeline(before: unavailableReference)
                guard generation == requestID, frameDate == currentFrame,
                      timeline?.referenceTime == unavailableReference, !Task.isCancelled else { return }
                timeline = fallback
                selectedFrame = fallback.dates.firstIndex(of: fallback.referenceTime) ?? 0
                radarNotice = "Neuster Radarlauf noch nicht verfügbar. Radar zeigt den vorherigen Lauf von "
                    + fallback.referenceTime.formatted(date: .omitted, time: .shortened) + " Uhr."
            } catch {
                guard generation == requestID else { return }
                radarNotice = "Radarlauf derzeit nicht verfügbar. Bitte erneut laden."
            }
        }
    }

    private struct LoadedTimeline {
        let timeline: RadarTimeline
        let source: RadarSource
        let attribution: RadarAttribution?
    }

    /// Cache backend first; direct DWD tiles on any error, 404, timeout, invalid or stale data.
    private func loadTimeline() async -> Result<LoadedTimeline, Error> {
        if Date() >= backendBlockedUntil, case .fresh(let manifest, _) = await backend.latest() {
            return .success(LoadedTimeline(timeline: manifest.timeline, source: .cache,
                                           attribution: RadarAttribution(manifest)))
        }
        do { return .success(LoadedTimeline(timeline: try await client.radarTimeline(), source: .direct, attribution: nil)) }
        catch { return .failure(error) }
    }

    private func loadForecast(at coordinate: WeatherCoordinate) async -> Result<RainForecast, Error> {
        do { return .success(try await client.forecast(at: coordinate)) }
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
            locationMessage = "Standortzugriff ist deaktiviert. Du kannst einen Ort suchen oder den Zugriff in den iOS-Einstellungen erlauben."
        @unknown default:
            waitingForLocation = false
            locationMessage = "Der Standort ist derzeit nicht verfügbar."
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard waitingForLocation else { return }
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        } else if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted {
            waitingForLocation = false
            locationMessage = "Ohne Standortzugriff kannst du Orte weiterhin suchen und auf der Karte auswählen."
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        waitingForLocation = false
        guard let location = locations.last, abs(location.timestamp.timeIntervalSinceNow) < 120 else {
            locationMessage = "Es konnte kein aktueller Standort bestimmt werden."
            return
        }
        select(SavedPlace(name: "Aktueller Standort", coordinate: WeatherCoordinate(
            latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)))
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        waitingForLocation = false
        locationMessage = "Der Standort konnte nicht bestimmt werden. Bitte erneut versuchen oder einen Ort suchen."
    }

    private static func storageURL() throws -> URL {
        let folder = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                 appropriateFor: nil, create: true)
        return folder.appendingPathComponent("places.json")
    }

    private func persistPlaces() {
        do {
            try JSONEncoder().encode(places).write(to: Self.storageURL(), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            storageMessage = nil
        } catch { storageMessage = "Die Änderung konnte nicht auf dem Gerät gespeichert werden." }
    }
}
