import Foundation
import Darwin
import XCTest
@testable import Weather

final class SharedStorageTests: XCTestCase {
    private var root: URL!
    private var group: URL { root.appendingPathComponent("group", isDirectory: true) }
    private var cache: ForecastCache { ForecastCache(directory: group.appendingPathComponent("ForecastCache")) }
    private let time = Date(timeIntervalSince1970: 1_800_000_000)

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws { try FileManager.default.removeItem(at: root) }

    private func place(_ name: String = "Testort") -> SavedPlace {
        SavedPlace(name: name, coordinate: WeatherCoordinate(latitude: 50, longitude: 10))
    }

    private func forecast(offset: TimeInterval = 0, amount: Double? = 0.2) -> RainForecast {
        let reference = time.addingTimeInterval(offset)
        return RainForecast(referenceTime: reference, samples: [RainSample(date: reference, amountMM: amount)])
    }

    func testMigrationPreservesPlacesRemovesSourceAndRunsOnlyOnce() throws {
        let legacy = root.appendingPathComponent("legacy.json")
        let old = [place("Eins"), place("Zwei")]
        let bytes = try JSONEncoder().encode(old)
        try bytes.write(to: legacy)
        let store = PlaceStore(directory: group, legacyPlacesURL: legacy)
        XCTAssertEqual(try store.load(), .init(places: old, selectedPlaceID: old[0].id))
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacy.path))
        try store.save(.init(places: [old[1]], selectedPlaceID: old[1].id))
        XCTAssertEqual(try store.load().places, [old[1]])
    }

    func testMigrationRetriesFailedCleanupOnNextStartWithoutRestoringDeletedPlaces() throws {
        let legacy = root.appendingPathComponent("legacy.json")
        let old = [place("Gelöschter Testort")]
        try JSONEncoder().encode(old).write(to: legacy)
        let failingCleanup = PlaceStore(directory: group, legacyPlacesURL: legacy,
                                       removeLegacy: { _ in throw CocoaError(.fileWriteNoPermission) })
        XCTAssertEqual(try failingCleanup.load().places, old)
        XCTAssertTrue(FileManager.default.fileExists(atPath: legacy.path))
        try failingCleanup.save(.init())
        let reopened = PlaceStore(directory: group, legacyPlacesURL: legacy)
        XCTAssertTrue(try reopened.load().places.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacy.path))
        try FileManager.default.removeItem(at: group.appendingPathComponent("places.json"))
        XCTAssertTrue(try reopened.load().places.isEmpty)
    }

    func testMigrationMarkerPreventsReimportWhenDestinationIsMissingAndCleanupStillFails() throws {
        let legacy = root.appendingPathComponent("legacy.json")
        try JSONEncoder().encode([place()]).write(to: legacy)
        let store = PlaceStore(directory: group, legacyPlacesURL: legacy,
                               removeLegacy: { _ in throw CocoaError(.fileWriteNoPermission) })
        _ = try store.load()
        try store.save(.init())
        try FileManager.default.removeItem(at: group.appendingPathComponent("places.json"))
        XCTAssertTrue(try store.load().places.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: legacy.path))
        XCTAssertTrue(try PlaceStore(directory: group, legacyPlacesURL: legacy).load().places.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacy.path))
    }

    func testExistingDestinationWinsOverLegacyAndRetriesCleanup() throws {
        let legacy = root.appendingPathComponent("legacy.json")
        try JSONEncoder().encode([place("Alt")]).write(to: legacy)
        let current = [place("Aktuell")]
        try PlaceStore(directory: group).save(.init(places: current))
        XCTAssertEqual(try PlaceStore(directory: group, legacyPlacesURL: legacy).load().places, current)
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacy.path))
    }

    func testCorruptMigrationSourceDoesNotCreateDestination() throws {
        let legacy = root.appendingPathComponent("legacy.json")
        try Data("broken".utf8).write(to: legacy)
        XCTAssertThrowsError(try PlaceStore(directory: group, legacyPlacesURL: legacy).load())
        XCTAssertFalse(FileManager.default.fileExists(atPath: group.appendingPathComponent("places.json").path))
        XCTAssertEqual(try String(contentsOf: legacy, encoding: .utf8), "broken")
    }

    func testMigrationWriteFailureKeepsLegacySource() throws {
        let legacy = root.appendingPathComponent("legacy.json")
        let original = [place()]
        try JSONEncoder().encode(original).write(to: legacy)
        try Data().write(to: group) // Ein Dateipfad kann kein Containerverzeichnis werden.
        XCTAssertThrowsError(try PlaceStore(directory: group, legacyPlacesURL: legacy).load())
        XCTAssertEqual(try JSONDecoder().decode([SavedPlace].self, from: Data(contentsOf: legacy)), original)
    }

    func testSelectionPersistsAndDeletedSelectionFallsBack() throws {
        let places = [place("Eins"), place("Zwei")]
        let store = PlaceStore(directory: group)
        try store.save(.init(places: places, selectedPlaceID: places[1].id))
        XCTAssertEqual(try PlaceStore(directory: group).load().selectedPlaceID, places[1].id)
        try store.save(.init(places: [places[0]], selectedPlaceID: places[1].id))
        XCTAssertEqual(try store.load().selectedPlaceID, places[0].id)
        try store.save(.init())
        XCTAssertEqual(try store.load(), .init())
    }

    func testStoreDirectoriesAreIsolated() throws {
        let store = PlaceStore(directory: group)
        try store.save(.init(places: [place()]))
        XCTAssertTrue(try PlaceStore(directory: root.appendingPathComponent("other")).load().places.isEmpty)
    }

    func testCacheReplacesOneForecastWithoutHistoryAndSurvivesReopening() throws {
        let id = UUID()
        try cache.save(forecast(), for: id)
        try cache.save(forecast(offset: 300), for: id)
        XCTAssertEqual(try cache.load(for: id)?.referenceTime, time.addingTimeInterval(300))
        let files = try FileManager.default.contentsOfDirectory(atPath: group.appendingPathComponent("ForecastCache").path).filter { $0.hasSuffix(".json") }
        XCTAssertEqual(files, [id.uuidString + ".json"])
        let data = try Data(contentsOf: group.appendingPathComponent("ForecastCache/" + files[0]))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(Set(json.keys), ["referenceTime", "samples"])
    }

    func testOlderForecastDoesNotReplaceNewerRun() throws {
        let id = UUID()
        try cache.save(forecast(offset: 300), for: id)
        try cache.save(forecast(), for: id)
        XCTAssertEqual(try cache.load(for: id)?.referenceTime, time.addingTimeInterval(300))
    }

    func testCacheWaitsForSharedLockAndRechecksNewerRun() throws {
        let id = UUID()
        let cacheDirectory = group.appendingPathComponent("ForecastCache")
        try cache.save(forecast(), for: id)
        let descriptor = Darwin.open(cacheDirectory.appendingPathComponent(".lock").path, O_RDWR)
        XCTAssertGreaterThanOrEqual(descriptor, 0)
        guard descriptor >= 0 else { return }
        defer { Darwin.close(descriptor) }
        XCTAssertEqual(flock(descriptor, LOCK_EX), 0)
        let started = DispatchSemaphore(value: 0)
        let finished = DispatchSemaphore(value: 0)
        let other = ForecastCache(directory: cacheDirectory)
        let older = forecast()
        let failure = expectation(description: "Speichern nach Freigabe")
        DispatchQueue.global().async {
            started.signal()
            do { try other.save(older, for: id) }
            catch { XCTFail("Cache-Schreibfehler: \(error)") }
            finished.signal()
            failure.fulfill()
        }
        XCTAssertEqual(started.wait(timeout: .now() + 2), .success)
        XCTAssertEqual(finished.wait(timeout: .now() + 0.1), .timedOut)
        // Ein anderer Prozess kann während seiner Sperre einen neueren Lauf publizieren.
        try JSONEncoder().encode(forecast(offset: 300)).write(
            to: cacheDirectory.appendingPathComponent(id.uuidString + ".json"), options: .atomic)
        XCTAssertEqual(flock(descriptor, LOCK_UN), 0)
        wait(for: [failure], timeout: 2)
        XCTAssertEqual(try cache.load(for: id)?.referenceTime, time.addingTimeInterval(300))
    }

    func testInvalidForecastDoesNotReplaceValidForecast() throws {
        let id = UUID()
        try cache.save(forecast(), for: id)
        XCTAssertThrowsError(try cache.save(RainForecast(referenceTime: time, samples: []), for: id))
        XCTAssertThrowsError(try cache.save(forecast(amount: -1), for: id))
        XCTAssertThrowsError(try cache.save(forecast(amount: nil), for: id))
        XCTAssertEqual(try cache.load(for: id)?.samples.first?.amountMM, 0.2)
    }

    func testCachePrunesDeletedPlacesAndNeverReturnsOtherPlaces() throws {
        let first = UUID(), second = UUID()
        try cache.save(forecast(), for: first)
        try cache.save(forecast(offset: 300), for: second)
        XCTAssertNil(try cache.load(for: UUID()))
        try cache.retain(placeIDs: [second])
        XCTAssertNil(try cache.load(for: first))
        XCTAssertNotNil(try cache.load(for: second))
        try cache.remove(for: second)
        try cache.remove(for: second)
        XCTAssertNil(try cache.load(for: second))
    }

    func testManagedCacheRechecksMembershipAfterWaitingForWriteLock() throws {
        let saved = place()
        let store = PlaceStore(directory: group)
        try store.save(.init(places: [saved]))
        let cacheDirectory = group.appendingPathComponent("ForecastCache")
        let managed = ForecastCache(directory: cacheDirectory, placeStore: store)
        try managed.save(forecast(), for: saved.id)
        let descriptor = Darwin.open(cacheDirectory.appendingPathComponent(".lock").path, O_RDWR)
        XCTAssertGreaterThanOrEqual(descriptor, 0)
        guard descriptor >= 0 else { return }
        defer { Darwin.close(descriptor) }
        XCTAssertEqual(flock(descriptor, LOCK_EX), 0)
        let started = DispatchSemaphore(value: 0)
        let finished = DispatchSemaphore(value: 0)
        let completed = expectation(description: "Ortsprüfung nach Cache-Sperre")
        let value = forecast(offset: 300)
        DispatchQueue.global().async {
            started.signal()
            do { try managed.save(value, for: saved.id) }
            catch { XCTFail("Cache-Schreibfehler: \(error)") }
            finished.signal()
            completed.fulfill()
        }
        XCTAssertEqual(started.wait(timeout: .now() + 2), .success)
        XCTAssertEqual(finished.wait(timeout: .now() + 0.1), .timedOut)
        try store.save(.init())
        XCTAssertEqual(flock(descriptor, LOCK_UN), 0)
        wait(for: [completed], timeout: 2)
        // Direkt die Datei prüfen: Ein bereinigendes load() könnte einen fehlerhaften Write verstecken.
        XCTAssertFalse(FileManager.default.fileExists(atPath: cacheDirectory.appendingPathComponent(saved.id.uuidString + ".json").path))
    }

    func testManagedCacheLoadAndPruneRemoveOrphansUsingCurrentStore() throws {
        let saved = place()
        let orphan = UUID()
        let store = PlaceStore(directory: group)
        try store.save(.init(places: [saved]))
        let managed = ForecastCache(directory: group.appendingPathComponent("ForecastCache"), placeStore: store)
        try cache.save(forecast(), for: saved.id)
        try cache.save(forecast(), for: orphan) // Vorhandene verwaiste Datei aus älterer App-Version.
        XCTAssertNotNil(try managed.load(for: saved.id))
        XCTAssertNil(try cache.load(for: orphan))
        try cache.save(forecast(), for: orphan)
        XCTAssertNil(try managed.load(for: orphan))
        try store.save(.init())
        try managed.retain(placeIDs: [saved.id]) // Veralteter Snapshot des Aufrufers.
        XCTAssertNil(try cache.load(for: saved.id))
    }

    func testPlaceSnapshotLockSerializesMembershipCheckWithDeletion() throws {
        let saved = place()
        let store = PlaceStore(directory: group)
        try store.save(.init(places: [saved]))
        let started = DispatchSemaphore(value: 0)
        let finished = DispatchSemaphore(value: 0)
        let completed = expectation(description: "Ortslöschung nach Snapshot-Freigabe")
        try store.withSnapshot { snapshot in
            DispatchQueue.global().async {
                started.signal()
                do { try store.save(.init()) }
                catch { XCTFail("Orts-Schreibfehler: \(error)") }
                finished.signal()
                completed.fulfill()
            }
            XCTAssertEqual(started.wait(timeout: .now() + 2), .success)
            XCTAssertEqual(finished.wait(timeout: .now() + 0.1), .timedOut)
            XCTAssertEqual(snapshot.places, [saved])
        }
        wait(for: [completed], timeout: 2)
        XCTAssertTrue(try store.load().places.isEmpty)
    }

    func testCorruptCacheReportsReadErrorAndNextValidSaveRepairsIt() throws {
        let id = UUID()
        try cache.save(forecast(), for: id)
        try Data("broken".utf8).write(to: group.appendingPathComponent("ForecastCache/" + id.uuidString + ".json"))
        XCTAssertThrowsError(try cache.load(for: id))
        try cache.save(forecast(offset: 300), for: id)
        XCTAssertEqual(try cache.load(for: id)?.referenceTime, time.addingTimeInterval(300))
    }

    @MainActor
    func testWeatherStoreRestoresSelectedSavedForecastAndDeletesCache() throws {
        let places = [place("Eins"), place("Zwei")]
        let store = PlaceStore(directory: group)
        try store.save(.init(places: places, selectedPlaceID: places[1].id))
        try cache.save(forecast(), for: places[1].id)
        let weather = WeatherStore(client: DWDClient(), placeStore: store, forecastCache: cache)
        XCTAssertEqual(weather.selectedPlace.id, places[1].id)
        XCTAssertEqual(weather.forecast?.referenceTime, time)
        weather.deletePlaces(at: IndexSet(integer: 1))
        XCTAssertNil(try cache.load(for: places[1].id))
        XCTAssertEqual(try store.load().places, [places[0]])
        XCTAssertEqual(try store.load().selectedPlaceID, places[0].id)
    }

    @MainActor
    func testWeatherStoreKeepsUnsavedForecastOffDisk() throws {
        let weather = WeatherStore(client: DWDClient(), placeStore: PlaceStore(directory: group), forecastCache: cache)
        let transientID = UUID()
        weather.rememberForecast(forecast(), for: transientID)
        XCTAssertNotNil(weather.lastValidForecast(for: transientID))
        XCTAssertNil(try cache.load(for: transientID))
    }

}
