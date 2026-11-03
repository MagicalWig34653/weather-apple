#if WIDGET_LOGIC_TESTS
@testable import Weather
#endif
import Foundation

enum WidgetPlaceSelection {
    /// An explicitly configured, deleted ID must not silently select another place.
    static func resolve(_ id: UUID?, in snapshot: PlaceStore.Snapshot) -> SavedPlace? {
        if let id { return snapshot.places.first { $0.id == id } }
        return snapshot.places.first { $0.id == snapshot.selectedPlaceID } ?? snapshot.places.first
    }
}

/// Injectable IO boundary. Neither the builder nor the views fetch, persist or access the clock.
struct WidgetForecastLoader: Sendable {
    let loadPlaces: @Sendable () throws -> PlaceStore.Snapshot
    let loadCached: @Sendable (UUID) throws -> RainForecast?
    let saveCached: @Sendable (RainForecast, UUID) throws -> Void
    let fetch: @Sendable (WeatherCoordinate) async throws -> RainForecast

    static func live(client: DWDClient = DWDClient()) -> Self {
        Self(loadPlaces: { try PlaceStore().load() },
             loadCached: { try ForecastCache().load(for: $0) },
             saveCached: { try ForecastCache().save($0, for: $1) },
             fetch: { try await client.forecast(at: $0) })
    }

    /// Snapshots/previews use disk only, so opening the widget gallery causes no DWD traffic.
    func cachedResult(for placeID: UUID?) -> WidgetForecastResult {
        switch selection(for: placeID) {
        case .failure(let issue): return unavailable(issue)
        case .success(let place): return cachedResult(for: place)
        }
    }

    func result(for placeID: UUID?) async -> WidgetForecastResult {
        let place: SavedPlace
        switch selection(for: placeID) {
        case .failure(let issue): return unavailable(issue)
        case .success(let selected): place = selected
        }
        do {
            let forecast = try await fetch(place.coordinate)
            // Revalidate after the suspension: deletion or coordinate edits must not
            // resurrect cached data for an old selection. Names may change safely.
            guard let current = try loadPlaces().places.first(where: { $0.id == place.id }),
                  current.coordinate == place.coordinate else { return unavailable(.placeUnavailable) }
            // ForecastCache rechecks membership under its cache and PlaceStore locks.
            // A cache write failure must not discard a successful network response.
            try? saveCached(forecast, place.id)
            return WidgetForecastResult(place: current, forecast: forecast, source: .live, issue: nil)
        } catch {
            // Also revalidate on failure before displaying any cached location data.
            do {
                guard let current = try loadPlaces().places.first(where: { $0.id == place.id }),
                      current.coordinate == place.coordinate else { return unavailable(.placeUnavailable) }
                return cachedResult(for: current)
            } catch { return unavailable(.storageUnavailable) }
        }
    }

    private enum Selection {
        case success(SavedPlace), failure(WidgetForecastResult.Issue)
    }

    private func selection(for id: UUID?) -> Selection {
        do {
            let snapshot = try loadPlaces()
            guard let place = WidgetPlaceSelection.resolve(id, in: snapshot) else {
                return .failure(id == nil && snapshot.places.isEmpty ? .noSavedPlaces : .placeUnavailable)
            }
            return .success(place)
        } catch { return .failure(.storageUnavailable) }
    }

    private func cachedResult(for place: SavedPlace) -> WidgetForecastResult {
        let forecast = try? loadCached(place.id)
        return WidgetForecastResult(place: place, forecast: forecast,
                                    source: forecast == nil ? .unavailable : .cache,
                                    issue: forecast == nil ? .forecastUnavailable : nil)
    }

    private func unavailable(_ issue: WidgetForecastResult.Issue) -> WidgetForecastResult {
        WidgetForecastResult(place: nil, forecast: nil, source: .unavailable, issue: issue)
    }
}
