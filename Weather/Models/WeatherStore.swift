import CoreLocation
import Foundation
import Observation
import SwiftUI

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
    var isLoading = false
    var forecastError: String?
    var radarError: String?
    var locationMessage: String?
    var storageMessage: String?
    var isPlaying = false
    var centerRevision = 0
    var radarReloadRevision = 0
    var lastRefresh: Date?

    @ObservationIgnored private let client = DWDClient()
    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var waitingForLocation = false
    @ObservationIgnored private var forecastPlaceID: UUID?

    override init() {
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
        isLoading = true
        // A retry must also reload missing tiles when the data run is unchanged.
        radarReloadRevision += 1
        defer { if generation == requestID { isLoading = false } }
        forecastError = nil
        radarError = nil
        // Each source can fail independently: a point error must not disable the map.
        async let newTimeline = loadTimeline()
        async let newForecast = loadForecast(at: place.coordinate)
        let (mapResult, pointResult) = await (newTimeline, newForecast)
        guard generation == requestID, selectedPlace.id == place.id, !Task.isCancelled else { return }
        switch mapResult {
        case .success(let value):
            timeline = value
            selectedFrame = value.dates.firstIndex(of: value.referenceTime) ?? 0
        case .failure(let error):
            radarError = error.localizedDescription
        }
        switch pointResult {
        case .success(let value):
            forecast = value
            forecastPlaceID = place.id
        case .failure(let error):
            if forecastPlaceID != place.id { forecast = nil }
            forecastError = error.localizedDescription
        }
        lastRefresh = Date()
    }

    private func loadTimeline() async -> Result<RadarTimeline, Error> {
        do { return .success(try await client.radarTimeline()) }
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
