#if WIDGET_LOGIC_TESTS
@testable import Weather
#endif
import AppIntents
import Foundation

/// Only an ID and a display name enter the configuration; coordinates are resolved from PlaceStore.
struct PlaceEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Gespeicherter Ort")
    static let defaultQuery = PlaceEntityQuery()

    let id: UUID
    let name: String

    init(place: SavedPlace) {
        id = place.id
        name = place.name
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct PlaceEntityQuery: EntityQuery {
    private let loadPlaces: @Sendable () throws -> PlaceStore.Snapshot

    init() { loadPlaces = { try PlaceStore().load() } }

    init(loadPlaces: @escaping @Sendable () throws -> PlaceStore.Snapshot) {
        self.loadPlaces = loadPlaces
    }

    func entities(for identifiers: [UUID]) async throws -> [PlaceEntity] {
        let snapshot = try loadPlaces()
        return identifiers.compactMap { id in
            snapshot.places.first { $0.id == id }.map { PlaceEntity(place: $0) }
        }
    }

    func suggestedEntities() async throws -> [PlaceEntity] {
        try loadPlaces().places.map { PlaceEntity(place: $0) }
    }

    func defaultResult() async -> PlaceEntity? {
        guard let snapshot = try? loadPlaces(),
              let place = WidgetPlaceSelection.resolve(nil, in: snapshot) else { return nil }
        return PlaceEntity(place: place)
    }
}

struct WeatherWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Regenprognose"
    static let description = IntentDescription("Zeigt die Prognose für einen in Showers gespeicherten Ort.")

    @Parameter(title: "Ort")
    var place: PlaceEntity?

    init() {}
}
