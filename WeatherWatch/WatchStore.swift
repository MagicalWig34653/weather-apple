import Foundation
import Combine
#if canImport(WidgetKit)
import WidgetKit
#endif

/// The watch owns its places and forecasts; the phone sends only full place snapshots.
@MainActor
final class WatchStore: ObservableObject {
    typealias FetchForecast = @Sendable (WeatherCoordinate) async throws -> RainForecast
    enum SyncIssue: Equatable { case invalidPayload, storage, connection }
    enum ForecastIssue: Equatable { case unavailable, unsupportedLocation }

    @Published private(set) var places: [SavedPlace] = []
    @Published private(set) var forecasts: [UUID: RainForecast] = [:]
    @Published private(set) var loading: Set<UUID> = []
    @Published private(set) var forecastIssues: [UUID: ForecastIssue] = [:]
    @Published private(set) var syncIssue: SyncIssue?
    @Published private(set) var hasStorageIssue = false

    private let placeStore: PlaceStore?
    private let cache: ForecastCache?
    private let fetch: FetchForecast
    private var requests: [UUID: UUID] = [:]

    init(placeStore: PlaceStore?, cache: ForecastCache?, fetch: @escaping FetchForecast) {
        self.placeStore = placeStore
        self.cache = cache
        self.fetch = fetch
        hasStorageIssue = placeStore == nil || cache == nil
        do {
            places = try placeStore?.load().places ?? []
            // Finish cleanup after an interrupted prior synchronization, before reading caches.
            try cache?.retain(placeIDs: Set(places.map(\.id)))
            loadCaches()
        } catch {
            hasStorageIssue = true
        }
    }

    static func live() -> WatchStore {
        let client = DWDClient()
        return WatchStore(placeStore: try? PlaceStore(), cache: try? ForecastCache()) {
            try await client.forecast(at: $0)
        }
    }

    func connectionFailed(_ failed: Bool) {
        if failed { syncIssue = .connection }
        else if syncIssue == .connection { syncIssue = nil }
    }

    /// nil means no places key yet, not a deletion. Invalid payloads preserve the last good list.
    func receive(placesData: Data?) {
        guard let placesData else { return }
        let replacement: [SavedPlace]
        do {
            replacement = try JSONDecoder().decode([SavedPlace].self, from: placesData)
            guard Set(replacement.map(\.id)).count == replacement.count,
                  replacement.allSatisfy({
                      $0.coordinate.latitude.isFinite && $0.coordinate.longitude.isFinite
                          && (-90...90).contains($0.coordinate.latitude)
                          && (-180...180).contains($0.coordinate.longitude)
                  }) else { throw PayloadError.invalidPlaces }
        } catch {
            syncIssue = .invalidPayload
            return
        }
        guard let placeStore else { syncIssue = .storage; return }
        do {
            // A reused ID with a new coordinate must never inherit the old point forecast.
            for old in places {
                if let updated = replacement.first(where: { $0.id == old.id }), updated.coordinate != old.coordinate {
                    try cache?.remove(for: old.id)
                }
            }
            try placeStore.save(.init(places: replacement))
        } catch {
            syncIssue = .storage
            return
        }
        let unchanged = Set(replacement.filter { new in
            places.contains { $0.id == new.id && $0.coordinate == new.coordinate }
        }.map(\.id))
        forecasts = forecasts.filter { unchanged.contains($0.key) }
        forecastIssues = forecastIssues.filter { unchanged.contains($0.key) }
        requests = requests.filter { unchanged.contains($0.key) }
        loading.formIntersection(unchanged)
        places = replacement
        syncIssue = nil
        do { try cache?.retain(placeIDs: Set(replacement.map(\.id))) }
        catch { hasStorageIssue = true }
        loadCaches()
        reloadComplications()
    }

    private func reloadComplications() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    func refresh(placeID: UUID) async {
        guard let place = places.first(where: { $0.id == placeID }), !loading.contains(placeID) else { return }
        guard place.coordinate.isSupported else {
            forecastIssues[placeID] = .unsupportedLocation
            return
        }
        let token = UUID()
        requests[placeID] = token
        loading.insert(placeID)
        defer {
            if requests[placeID] == token {
                requests[placeID] = nil
                loading.remove(placeID)
            }
        }
        do {
            let forecast = try await fetch(place.coordinate)
            try Task.checkCancellation()
            // No suspension between this check and persistence: deletion cannot resurrect a cache.
            guard requests[placeID] == token,
                  places.contains(where: { $0.id == placeID && $0.coordinate == place.coordinate }) else { return }
            if let previous = forecasts[placeID], previous.referenceTime > forecast.referenceTime {
                forecastIssues[placeID] = nil
                return
            }
            forecasts[placeID] = forecast
            forecastIssues[placeID] = nil
            do { try cache?.save(forecast, for: placeID) }
            catch { hasStorageIssue = true }
            reloadComplications()
        } catch is CancellationError {
            // Navigation/foreground cancellation is not a weather-service failure.
        } catch {
            guard requests[placeID] == token else { return }
            forecastIssues[placeID] = .unavailable
        }
    }

    private func loadCaches() {
        for place in places where forecasts[place.id] == nil {
            do { forecasts[place.id] = try cache?.load(for: place.id) }
            catch { hasStorageIssue = true }
        }
    }

    private enum PayloadError: Error { case invalidPlaces }
}

/// The watch warns from 20 minutes, including the boundary; time is always the DWD run time.
struct WatchForecastPresentation {
    let outlook: RainOutlook
    let state: RainOutlook.State
    let ageMinutes: Int?

    init(forecast: RainForecast?, now: Date) {
        outlook = RainOutlook.evaluate(forecast, at: now)
        if let forecast {
            ageMinutes = max(0, Int(now.timeIntervalSince(forecast.referenceTime) / 60))
            state = now.timeIntervalSince(forecast.referenceTime) >= RainForecast.maximumAge ? .stale : outlook.state
        } else {
            ageMinutes = nil
            state = .noData
        }
    }
}
