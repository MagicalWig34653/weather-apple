import Foundation
import XCTest
@testable import Weather

@MainActor
final class WidgetIntentTests: XCTestCase {
    func testEntityQueryUsesOnlyStoredIDsAndCurrentNames() async throws {
        let first = SavedPlace(name: "Umbenannter Testort", coordinate: WeatherCoordinate(latitude: 50, longitude: 10))
        let second = SavedPlace(name: "Zweiter Testort", coordinate: first.coordinate)
        let snapshot = PlaceStore.Snapshot(places: [first, second], selectedPlaceID: second.id)
        let query = PlaceEntityQuery(loadPlaces: { snapshot })
        let entities = try await query.entities(for: [second.id, UUID(), first.id])
        XCTAssertEqual(entities.map(\.id), [second.id, first.id])
        XCTAssertEqual(entities.last?.name, first.name)
        let suggestions = try await query.suggestedEntities()
        XCTAssertEqual(suggestions.map(\.id), [first.id, second.id])
        let selected = await query.defaultResult()
        XCTAssertEqual(selected?.id, second.id)
    }

    func testEmptyStoreOffersNoLocationOption() async throws {
        let query = PlaceEntityQuery(loadPlaces: { .init() })
        let suggestions = try await query.suggestedEntities()
        let resolved = try await query.entities(for: [UUID()])
        let selected = await query.defaultResult()
        XCTAssertTrue(suggestions.isEmpty)
        XCTAssertTrue(resolved.isEmpty)
        XCTAssertNil(selected)
        XCTAssertNil(WeatherWidgetIntent().place)
    }

    func testStoreFailureDoesNotInventDefaultOrOptions() async {
        let query = PlaceEntityQuery(loadPlaces: { throw CocoaError(.fileReadNoPermission) })
        let selected = await query.defaultResult()
        XCTAssertNil(selected)
        do {
            _ = try await query.suggestedEntities()
            XCTFail("An unreadable store must not produce options")
        } catch { /* Query surfaces the storage failure to the configuration UI. */ }
    }
}
