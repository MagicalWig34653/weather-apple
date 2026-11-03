import Foundation
import XCTest
@testable import Weather

@MainActor
final class WidgetLogicTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let place = SavedPlace(name: "Testort", coordinate: WeatherCoordinate(latitude: 50, longitude: 10))

    private func forecast(reference: Date? = nil, rainIndex: Int? = nil) -> RainForecast {
        let reference = reference ?? now
        return RainForecast(referenceTime: reference, samples: (0...24).map { index in
            RainSample(date: reference.addingTimeInterval(Double(index * 300)),
                       amountMM: rainIndex.map { index >= $0 ? 0.2 : 0 } ?? 0)
        })
    }

    func testTimelineGridReloadAndDeepLinks() throws {
        let value = forecast(rainIndex: 2)
        let result = WidgetForecastResult(place: place, forecast: value, source: .live, issue: nil)
        let plan = WidgetTimelineBuilder.build(for: result, at: now)
        XCTAssertEqual(plan.reloadDate, now.addingTimeInterval(900))
        XCTAssertEqual(plan.entries.first?.date, now)
        XCTAssertEqual(plan.entries.last?.date, now.addingTimeInterval(3600))
        let grid = (0...12).map { now.addingTimeInterval(Double($0 * 300)) }
        XCTAssertTrue(grid.allSatisfy { date in plan.entries.contains { $0.date == date } })
        XCTAssertEqual(plan.entries.count, 14) // 13 grid entries plus exact freshness expiration.
        XCTAssertEqual(plan.entries[0].outlook.minutes, 10)
        XCTAssertEqual(plan.entries[1].outlook.minutes, 5)
        XCTAssertEqual(plan.entries[2].outlook.state, .rainingNow)
        for entry in plan.entries {
            XCTAssertEqual(entry.referenceTime, value.referenceTime)
            XCTAssertEqual(WidgetDeepLink.placeID(from: try XCTUnwrap(entry.deepLinkURL)), place.id)
        }
    }

    func testStaleTransitionDoesNotWaitForNextGridEntry() throws {
        let reference = now.addingTimeInterval(-7 * 60)
        let result = WidgetForecastResult(place: place, forecast: forecast(reference: reference), source: .cache, issue: nil)
        let plan = WidgetTimelineBuilder.build(for: result, at: now)
        let expiration = reference.addingTimeInterval(RainForecast.maximumAge + 0.001)
        let entry = try XCTUnwrap(plan.entries.first { $0.date == expiration })
        XCTAssertEqual(entry.outlook.state, .stale)
        XCTAssertEqual(entry.dataAge ?? 0, 1200.001, accuracy: 0.0001)
        XCTAssertTrue(plan.entries.filter { $0.date >= expiration }.allSatisfy { $0.outlook.state == .stale })
        XCTAssertEqual(WidgetTimelineBuilder.entry(for: result, at: reference.addingTimeInterval(1200)).outlook.state, .dry)
    }

    func testFutureRunAndMissingForecastDoNotClaimDry() {
        let future = WidgetForecastResult(place: place, forecast: forecast(reference: now.addingTimeInterval(61)),
                                          source: .cache, issue: nil)
        XCTAssertEqual(WidgetTimelineBuilder.entry(for: future, at: now).outlook.state, .stale)
        let missing = WidgetForecastResult(place: nil, forecast: forecast(), source: .unavailable, issue: .noSavedPlaces)
        let entry = WidgetTimelineBuilder.entry(for: missing, at: now)
        XCTAssertEqual(entry.outlook.state, .noData)
        XCTAssertNil(entry.forecast)
        XCTAssertNil(entry.referenceTime)
        XCTAssertNil(entry.deepLinkURL)
        XCTAssertEqual(WidgetTimelineBuilder.build(for: missing, at: now).entries.count, 13)
    }

    func testSelectionUsesLastSelectedOnlyWhenNotExplicitlyConfigured() {
        let other = SavedPlace(name: "Anderer Testort", coordinate: place.coordinate)
        let snapshot = PlaceStore.Snapshot(places: [place, other], selectedPlaceID: other.id)
        XCTAssertEqual(WidgetPlaceSelection.resolve(nil, in: snapshot), other)
        XCTAssertEqual(WidgetPlaceSelection.resolve(place.id, in: snapshot), place)
        XCTAssertNil(WidgetPlaceSelection.resolve(UUID(), in: snapshot))
        XCTAssertEqual(WidgetPlaceSelection.resolve(nil, in: .init(places: [place], selectedPlaceID: UUID())), place)
        XCTAssertNil(WidgetPlaceSelection.resolve(nil, in: .init()))
    }

    func testSuccessWritesOnlySelectedPlaceCache() async throws {
        let fixture = try Fixture(place: place)
        defer { fixture.remove() }
        let expected = forecast()
        let expectedCoordinate = place.coordinate
        let loader = fixture.loader { coordinate in
            XCTAssertEqual(coordinate, expectedCoordinate)
            return expected
        }
        let result = await loader.result(for: nil)
        XCTAssertEqual(result.source, .live)
        XCTAssertNil(result.issue)
        XCTAssertEqual(try fixture.cache.load(for: place.id)?.referenceTime, expected.referenceTime)
        XCTAssertNil(try fixture.cache.load(for: UUID()))
    }

    func testOfflineFallsBackToMatchingCacheAndAgesDuringTimeline() async throws {
        let fixture = try Fixture(place: place)
        defer { fixture.remove() }
        try fixture.cache.save(forecast(), for: place.id)
        let result = await fixture.loader { _ in throw URLError(.notConnectedToInternet) }.result(for: place.id)
        XCTAssertEqual(result.source, .cache)
        XCTAssertEqual(result.place?.id, place.id)
        let plan = WidgetTimelineBuilder.build(for: result, at: now)
        XCTAssertEqual(plan.entries.first?.outlook.state, .dry)
        XCTAssertEqual(plan.entries.last?.outlook.state, .stale)
    }

    func testExpiredCacheNeverPromisesDry() async throws {
        let fixture = try Fixture(place: place)
        defer { fixture.remove() }
        try fixture.cache.save(forecast(reference: now.addingTimeInterval(-1201)), for: place.id)
        let result = await fixture.loader { _ in throw URLError(.timedOut) }.result(for: nil)
        XCTAssertEqual(result.source, .cache)
        XCTAssertTrue(WidgetTimelineBuilder.build(for: result, at: now).entries.allSatisfy { $0.outlook.state == .stale })
    }

    func testMissingAndCorruptCachesProduceNoDataWithoutOtherPlaceFallback() async throws {
        let fixture = try Fixture(place: place)
        defer { fixture.remove() }
        try ForecastCache(directory: fixture.cacheDirectory).save(forecast(), for: UUID())
        let loader = fixture.loader { _ in throw URLError(.timedOut) }
        let missing = await loader.result(for: place.id)
        XCTAssertEqual(missing.issue, .forecastUnavailable)
        XCTAssertEqual(missing.source, .unavailable)
        try Data("invalid".utf8).write(to: fixture.cacheDirectory.appendingPathComponent(place.id.uuidString + ".json"))
        let corrupt = await loader.result(for: place.id)
        XCTAssertEqual(WidgetTimelineBuilder.entry(for: corrupt, at: now).outlook.state, .noData)
    }

    func testCacheWriteFailureKeepsSuccessfulForecast() async {
        let snapshot = PlaceStore.Snapshot(places: [place])
        let expected = forecast()
        let loader = WidgetForecastLoader(loadPlaces: { snapshot }, loadCached: { _ in nil },
                                          saveCached: { _, _ in throw CocoaError(.fileWriteNoPermission) },
                                          fetch: { _ in expected })
        let result = await loader.result(for: place.id)
        XCTAssertEqual(result.source, .live)
        XCTAssertEqual(result.forecast?.referenceTime, expected.referenceTime)
    }

    func testEmptyDeletedAndUnreadableSelectionDoNotFetch() async throws {
        let fixture = try Fixture(place: place)
        defer { fixture.remove() }
        let loader = fixture.loader { _ in XCTFail("No fetch for a missing place"); throw URLError(.badURL) }
        let deleted = await loader.result(for: UUID())
        XCTAssertEqual(deleted.issue, .placeUnavailable)
        try fixture.store.save(.init())
        let empty = await loader.result(for: nil)
        XCTAssertEqual(empty.issue, .noSavedPlaces)
        try Data("invalid".utf8).write(to: fixture.root.appendingPathComponent("places.json"))
        let unreadable = await loader.result(for: nil)
        XCTAssertEqual(unreadable.issue, .storageUnavailable)
    }

    func testDeletionDuringFetchDoesNotResurrectCacheOnSuccessOrFailure() async throws {
        for succeeds in [true, false] {
            let fixture = try Fixture(place: place)
            defer { fixture.remove() }
            let expected = forecast()
            let result = await fixture.loader { _ in
                try fixture.store.save(.init())
                if succeeds { return expected }
                throw URLError(.timedOut)
            }.result(for: place.id)
            XCTAssertEqual(result.issue, .placeUnavailable)
            XCTAssertNil(result.place)
            XCTAssertNil(try fixture.cache.load(for: place.id))
        }
    }

    func testDeletionBetweenLoaderValidationAndCacheWriteDoesNotCreateOrphan() async throws {
        let fixture = try Fixture(place: place)
        defer { fixture.remove() }
        let expected = forecast()
        let loader = WidgetForecastLoader(
            loadPlaces: { try fixture.store.load() },
            loadCached: { try fixture.cache.load(for: $0) },
            saveCached: { forecast, id in
                // Exakt die Lücke nach der zweiten Ortsprüfung des Loaders.
                try fixture.store.save(.init())
                try fixture.cache.save(forecast, for: id)
            }, fetch: { _ in expected })
        _ = await loader.result(for: place.id)
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: fixture.cacheDirectory.appendingPathComponent(place.id.uuidString + ".json").path))
    }

    func testCoordinateEditDuringFetchDiscardsOldLocationForecast() async throws {
        let fixture = try Fixture(place: place)
        defer { fixture.remove() }
        var edited = place
        edited.coordinate = WeatherCoordinate(latitude: 51, longitude: 11)
        let snapshot = PlaceStore.Snapshot(places: [edited])
        let expected = forecast()
        let result = await fixture.loader { _ in
            try fixture.store.save(snapshot)
            return expected
        }.result(for: place.id)
        XCTAssertEqual(result.issue, .placeUnavailable)
        XCTAssertNil(try fixture.cache.load(for: place.id))
    }

    func testSnapshotUsesCacheWithoutFetch() throws {
        let fixture = try Fixture(place: place)
        defer { fixture.remove() }
        try fixture.cache.save(forecast(), for: place.id)
        let result = fixture.loader { _ in XCTFail("Snapshot must not fetch"); throw URLError(.badURL) }.cachedResult(for: nil)
        XCTAssertEqual(result.source, .cache)
        XCTAssertEqual(result.place?.id, place.id)
    }
}

private struct Fixture: Sendable {
    let root: URL
    let store: PlaceStore
    let cache: ForecastCache
    var cacheDirectory: URL { root.appendingPathComponent("cache") }

    init(place: SavedPlace) throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("WidgetTests-" + UUID().uuidString)
        store = PlaceStore(directory: root)
        cache = ForecastCache(directory: root.appendingPathComponent("cache"), placeStore: store)
        try store.save(.init(places: [place], selectedPlaceID: place.id))
    }

    func loader(fetch: @escaping @Sendable (WeatherCoordinate) async throws -> RainForecast) -> WidgetForecastLoader {
        WidgetForecastLoader(loadPlaces: { try store.load() }, loadCached: { try cache.load(for: $0) },
                             saveCached: { try cache.save($0, for: $1) }, fetch: fetch)
    }

    func remove() { try? FileManager.default.removeItem(at: root) }
}
