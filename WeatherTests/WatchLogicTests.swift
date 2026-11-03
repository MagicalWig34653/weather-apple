// Portable tests for WatchStore.swift. The current iOS test target does not include WeatherWatch/.
// Run with the isolated macOS harness documented in WeatherWatch/P5-Handoff.md.
#if WATCH_LOGIC_TESTS
import XCTest
@testable import WeatherWatchLogic

@MainActor
final class WatchLogicTests: XCTestCase {
    private var directory: URL!
    private var places: PlaceStore!
    private var cache: ForecastCache!
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    override func setUp() async throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        places = PlaceStore(directory: directory.appendingPathComponent("places"))
        cache = ForecastCache(directory: directory.appendingPathComponent("cache"))
    }

    override func tearDown() async throws {
        if FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
    }

    private func place(_ name: String = "Test", id: UUID = UUID(), latitude: Double = 50) -> SavedPlace {
        SavedPlace(id: id, name: name, coordinate: .init(latitude: latitude, longitude: 10))
    }

    private func forecast(age: TimeInterval = 0) -> RainForecast {
        RainForecast(referenceTime: now.addingTimeInterval(-age), samples: [
            RainSample(date: now, amountMM: 0),
            RainSample(date: now.addingTimeInterval(300), amountMM: 0)
        ])
    }

    private func data(_ places: [SavedPlace]) throws -> Data { try JSONEncoder().encode(places) }

    private func store(fetch: WatchStore.FetchForecast? = nil) -> WatchStore {
        let result = forecast()
        return WatchStore(placeStore: places, cache: cache, fetch: fetch ?? { _ in result })
    }

    func testPhonePayloadRoundTripFullReplacementAndRestart() async throws {
        let model = store()
        let old = place("Alt")
        let new = place("Neu")
        model.receive(placesData: try data([old]))
        model.receive(placesData: try data([new]))
        XCTAssertEqual(model.places, [new])
        XCTAssertEqual(try places.load().places, [new])
        XCTAssertEqual(store().places, [new])
        model.receive(placesData: try data([]))
        XCTAssertTrue(model.places.isEmpty)
        XCTAssertTrue(store().places.isEmpty)
    }

    func testAbsentCorruptAndDuplicatePayloadPreserveLastGoodSnapshot() async throws {
        let model = store()
        let saved = place()
        model.receive(placesData: try data([saved]))
        model.receive(placesData: nil)
        XCTAssertNil(model.syncIssue)
        model.receive(placesData: Data("{bad}".utf8))
        XCTAssertEqual(model.syncIssue, .invalidPayload)
        XCTAssertEqual(model.places, [saved])
        model.receive(placesData: try data([saved, saved]))
        XCTAssertEqual(model.syncIssue, .invalidPayload)
        XCTAssertEqual(try places.load().places, [saved])
        model.receive(placesData: try data([place(latitude: 100)]))
        XCTAssertEqual(model.places, [saved])
        model.receive(placesData: try data([]))
        XCTAssertNil(model.syncIssue)
    }

    func testFetchPersistsAndRestartUsesCacheOffline() async throws {
        let saved = place()
        let model = store()
        model.receive(placesData: try data([saved]))
        await model.refresh(placeID: saved.id)
        XCTAssertEqual(model.forecasts[saved.id]?.referenceTime, now)
        XCTAssertEqual(try cache.load(for: saved.id)?.referenceTime, now)
        XCTAssertTrue(model.loading.isEmpty)
        let offline = store(fetch: { _ in throw URLError(.notConnectedToInternet) })
        await offline.refresh(placeID: saved.id)
        XCTAssertEqual(offline.forecasts[saved.id]?.referenceTime, now)
        XCTAssertEqual(offline.forecastIssues[saved.id], .unavailable)
    }

    func testRenamePreservesCacheButCoordinateChangeInvalidatesIt() async throws {
        let saved = place()
        let model = store()
        model.receive(placesData: try data([saved]))
        await model.refresh(placeID: saved.id)
        model.receive(placesData: try data([place("Umbenannt", id: saved.id)]))
        XCTAssertNotNil(model.forecasts[saved.id])
        model.receive(placesData: try data([place(id: saved.id, latitude: 51)]))
        XCTAssertNil(model.forecasts[saved.id])
        XCTAssertNil(try cache.load(for: saved.id))
    }

    func testDeletionCleansCaches() async throws {
        let saved = place()
        let model = store()
        model.receive(placesData: try data([saved]))
        await model.refresh(placeID: saved.id)
        model.receive(placesData: try data([]))
        XCTAssertTrue(model.forecasts.isEmpty)
        XCTAssertNil(try cache.load(for: saved.id))
    }

    func testLateResponseCannotResurrectDeletedPlace() async throws {
        let gate = ForecastGate()
        let model = store(fetch: { _ in try await gate.wait() })
        let saved = place()
        model.receive(placesData: try data([saved]))
        let task = Task { await model.refresh(placeID: saved.id) }
        await gate.started()
        model.receive(placesData: try data([]))
        await gate.finish(forecast())
        await task.value
        XCTAssertTrue(model.forecasts.isEmpty)
        XCTAssertTrue(model.loading.isEmpty)
        XCTAssertNil(try cache.load(for: saved.id))
    }

    func testLateResponseCannotReplaceChangedCoordinate() async throws {
        let gate = ForecastGate()
        let model = store(fetch: { _ in try await gate.wait() })
        let saved = place()
        model.receive(placesData: try data([saved]))
        let task = Task { await model.refresh(placeID: saved.id) }
        await gate.started()
        model.receive(placesData: try data([place(id: saved.id, latitude: 51)]))
        await gate.finish(forecast())
        await task.value
        XCTAssertNil(model.forecasts[saved.id])
        XCTAssertNil(try cache.load(for: saved.id))
    }

    func testRepeatedRefreshWhileLoadingDoesNotStartSecondRequest() async throws {
        let gate = ForecastGate()
        let model = store(fetch: { _ in try await gate.wait() })
        let saved = place()
        model.receive(placesData: try data([saved]))
        let first = Task { await model.refresh(placeID: saved.id) }
        await gate.started()
        await model.refresh(placeID: saved.id)
        XCTAssertEqual(model.loading, [saved.id])
        await gate.finish(forecast())
        await first.value
        XCTAssertTrue(model.loading.isEmpty)
    }

    func testFailedOtherPlaceNeverShowsFirstPlacesForecast() async throws {
        let first = place()
        let second = place(latitude: 51)
        let result = forecast()
        let model = store(fetch: { coordinate in
            if coordinate.latitude == 51 { throw URLError(.notConnectedToInternet) }
            return result
        })
        model.receive(placesData: try data([first, second]))
        await model.refresh(placeID: first.id)
        await model.refresh(placeID: second.id)
        XCTAssertNotNil(model.forecasts[first.id])
        XCTAssertNil(model.forecasts[second.id])
        XCTAssertEqual(model.forecastIssues[second.id], .unavailable)
    }

    func testOlderResponseDoesNotReplaceNewerCacheLoadedAtStartup() async throws {
        let saved = place()
        try places.save(.init(places: [saved]))
        try cache.save(forecast(), for: saved.id)
        let older = forecast(age: 300)
        let model = store(fetch: { _ in older })
        await model.refresh(placeID: saved.id)
        XCTAssertEqual(model.forecasts[saved.id]?.referenceTime, now)
        XCTAssertEqual(try cache.load(for: saved.id)?.referenceTime, now)
    }

    func testUnsupportedPlaceDoesNotFetch() async throws {
        let model = store(fetch: { _ in XCTFail("Unsupported point fetched"); throw URLError(.badURL) })
        let saved = place(latitude: 40)
        model.receive(placesData: try data([saved]))
        await model.refresh(placeID: saved.id)
        XCTAssertEqual(model.forecastIssues[saved.id], .unsupportedLocation)
        XCTAssertTrue(model.loading.isEmpty)
    }

    func testStaleAtTwentyMinutesAndFutureDatedRunNeverSaysDry() async throws {
        XCTAssertEqual(WatchForecastPresentation(forecast: forecast(age: 1199), now: now).state, .dry)
        for age: TimeInterval in [1200, 1201, 3600, -61] {
            XCTAssertEqual(WatchForecastPresentation(forecast: forecast(age: age), now: now).state, .stale)
        }
        XCTAssertEqual(WatchForecastPresentation(forecast: nil, now: now).state, .noData)
        XCTAssertEqual(WatchForecastPresentation(forecast: forecast(age: 1200), now: now).ageMinutes, 20)
    }

    func testPersistenceFailureKeepsLastGoodPlaces() async throws {
        let model = store()
        let saved = place()
        model.receive(placesData: try data([saved]))
        try FileManager.default.removeItem(at: directory.appendingPathComponent("places"))
        try Data().write(to: directory.appendingPathComponent("places"))
        model.receive(placesData: try data([]))
        XCTAssertEqual(model.syncIssue, .storage)
        XCTAssertEqual(model.places, [saved])
    }

    func testCancelledRequestDoesNotReportServiceFailure() async throws {
        let model = store(fetch: { _ in throw CancellationError() })
        let saved = place()
        model.receive(placesData: try data([saved]))
        await model.refresh(placeID: saved.id)
        XCTAssertNil(model.forecastIssues[saved.id])
        XCTAssertTrue(model.loading.isEmpty)
    }
}

private actor ForecastGate {
    private var continuation: CheckedContinuation<RainForecast, any Error>?
    private var observers: [CheckedContinuation<Void, Never>] = []
    func wait() async throws -> RainForecast {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            observers.forEach { $0.resume() }
            observers.removeAll()
        }
    }
    func started() async {
        if continuation != nil { return }
        await withCheckedContinuation { observers.append($0) }
    }
    func finish(_ forecast: RainForecast) { continuation?.resume(returning: forecast); continuation = nil }
}
#endif
