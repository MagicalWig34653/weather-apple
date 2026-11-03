import XCTest
@testable import Weather

@MainActor
final class AppWidgetIntegrationTests: XCTestCase {
    private func makeStore(client: DWDClient? = nil, reload: @escaping () -> Void) throws -> (WeatherStore, PlaceStore, ForecastCache) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let places = PlaceStore(directory: root)
        let cache = ForecastCache(directory: root.appendingPathComponent("ForecastCache"))
        let offline = DWDClient(transport: { _ in throw URLError(.notConnectedToInternet) })
        return (WeatherStore(client: client ?? offline, backend: DWDDataTests.unreachableBackend,
                             placeStore: places, forecastCache: cache, reloadWidgets: reload), places, cache)
    }

    func testSavedPlaceChangesReloadWidgetsAfterPersistence() async throws {
        var reloads = 0
        let (store, places, _) = try makeStore { reloads += 1 }
        store.saveSelection(name: "Testort")
        XCTAssertEqual(reloads, 1)
        let id = store.selectedPlace.id
        XCTAssertEqual(try places.load().places.first?.id, id)
        store.rename(store.selectedPlace, name: "Neuer Name")
        XCTAssertEqual(reloads, 2)
        XCTAssertEqual(try places.load().places.first?.name, "Neuer Name")
        store.deletePlaces(at: IndexSet(integer: 0))
        XCTAssertEqual(reloads, 3)
        XCTAssertTrue(try places.load().places.isEmpty)
    }

    func testDeepLinkSelectsSavedPlaceAndPersistsSelection() async throws {
        var reloads = 0
        let (store, places, _) = try makeStore { reloads += 1 }
        let target = SavedPlace(name: "Ziel", coordinate: WeatherCoordinate(latitude: 50, longitude: 10))
        store.places = [target]
        XCTAssertTrue(store.openWidgetURL(WidgetDeepLink.url(for: target.id)))
        XCTAssertEqual(store.selectedPlace, target)
        XCTAssertEqual(try places.load().selectedPlaceID, target.id)
        XCTAssertEqual(store.centerRevision, 1)
        XCTAssertEqual(reloads, 1)
    }

    func testUnknownAndMalformedDeepLinksKeepSelectionAndDoNotReload() async throws {
        var reloads = 0
        let (store, _, _) = try makeStore { reloads += 1 }
        let original = store.selectedPlace
        for url in [WidgetDeepLink.url(for: UUID()), URL(string: "https://place/\(original.id)")!,
                    URL(string: "showernow://place/not-a-uuid")!] {
            XCTAssertFalse(store.openWidgetURL(url))
        }
        XCTAssertEqual(store.selectedPlace, original)
        XCTAssertEqual(store.centerRevision, 0)
        XCTAssertEqual(reloads, 0)
    }

    func testTransientMapSelectionReloadsButDoesNotSavePlace() async throws {
        var reloads = 0
        let (store, places, _) = try makeStore { reloads += 1 }
        store.selectMapPoint(latitude: 50, longitude: 10)
        XCTAssertEqual(reloads, 1)
        XCTAssertTrue(store.places.isEmpty)
        XCTAssertTrue(try places.load().places.isEmpty)
    }

    func testSuccessfulForecastReloadsAfterSharedCacheIsWritten() async throws {
        let bundle = Bundle(for: AppWidgetIntegrationTests.self)
        let url = bundle.url(forResource: "wms-wet-point-response", withExtension: "json", subdirectory: "Fixtures")
            ?? bundle.url(forResource: "wms-wet-point-response", withExtension: "json")
        let fixture = try Data(contentsOf: XCTUnwrap(url))
        let reference = DWDRequest.date("2026-10-28T15:15:00Z")!
        let client = DWDClient(transport: { request in
            let data = request.url?.host == "opendata.dwd.de"
                ? Data("composite_rv_20261028_1515.tar".utf8) : fixture
            return (data, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }, clock: { reference })
        var reloads = 0
        var cachedReferenceAtReload: Date?
        var cacheToRead: ForecastCache?
        var placeID: UUID?
        let (store, _, cache) = try makeStore(client: client) {
            reloads += 1
            if let cacheToRead, let placeID {
                cachedReferenceAtReload = try? cacheToRead.load(for: placeID)?.referenceTime
            }
        }
        store.saveSelection(name: "Testort")
        cacheToRead = cache
        placeID = store.selectedPlace.id
        reloads = 0
        await store.refresh()
        XCTAssertNil(store.forecastError)
        XCTAssertEqual(reloads, 1)
        XCTAssertEqual(cachedReferenceAtReload, reference)
    }

    func testFailedForecastDoesNotReloadWidgets() async throws {
        var reloads = 0
        let (store, _, _) = try makeStore { reloads += 1 }
        await store.refresh()
        XCTAssertNotNil(store.forecastError)
        XCTAssertEqual(reloads, 0)
    }
}
