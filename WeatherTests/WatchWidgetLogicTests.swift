#if WATCH_WIDGET_LOGIC_TESTS
import Foundation
import XCTest
@testable import WeatherWatchWidgets

@MainActor
final class WatchWidgetLogicTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let place = SavedPlace(name: "Testort", coordinate: WeatherCoordinate(latitude: 50, longitude: 10))

    private func forecast(reference: Date, rainFrom: Int? = nil, rainUntil: Int? = nil,
                          missing: Bool = false) -> RainForecast {
        RainForecast(referenceTime: reference, samples: (0...24).map { index in
            let rains = rainFrom.map { index >= $0 && index < (rainUntil ?? 25) } ?? false
            return RainSample(date: reference.addingTimeInterval(Double(index * 300)),
                              amountMM: missing ? nil : rains ? 0.2 : 0)
        })
    }

    private func entry(_ forecast: RainForecast?, at date: Date? = nil,
                       source: WidgetForecastResult.Source = .live) -> WeatherWidgetEntry {
        WidgetTimelineBuilder.entry(for: .init(place: place, forecast: forecast, source: source,
                                               issue: forecast == nil ? .forecastUnavailable : nil), at: date ?? now)
    }

    func testCountdownThenStalePresentationUsesSharedTimeline() throws {
        let value = forecast(reference: now, rainFrom: 2)
        let plan = WidgetTimelineBuilder.build(for: .init(place: place, forecast: value, source: .cache, issue: nil), at: now)
        XCTAssertEqual(WatchWidgetPresentation(entry: plan.entries[0]).statusKey, "Rain in %d min")
        XCTAssertEqual(plan.entries[0].outlook.minutes, 10)
        XCTAssertEqual(WatchWidgetPresentation(entry: plan.entries[1]).compactKey, "In %dm")
        XCTAssertEqual(plan.entries[1].outlook.minutes, 5)
        let stale = try XCTUnwrap(plan.entries.first { $0.outlook.state == .stale })
        let presentation = WatchWidgetPresentation(entry: stale)
        XCTAssertEqual(presentation.statusKey, "Out of date")
        XCTAssertEqual(presentation.compactKey, "Out of date")
        XCTAssertTrue(presentation.isCached)
        XCTAssertEqual(stale.referenceTime, now)
        XCTAssertEqual(WidgetDeepLink.placeID(from: try XCTUnwrap(stale.deepLinkURL)), place.id)
    }

    func testDryExpiresAtSharedBoundaryAndFutureRunIsStale() {
        let value = forecast(reference: now)
        XCTAssertEqual(WatchWidgetPresentation(entry: entry(value, at: now.addingTimeInterval(1200))).compactKey, "Dry for now")
        XCTAssertEqual(WatchWidgetPresentation(entry: entry(value, at: now.addingTimeInterval(1200.001))).compactKey, "Out of date")
        let future = forecast(reference: now.addingTimeInterval(61))
        XCTAssertEqual(WatchWidgetPresentation(entry: entry(future)).statusKey, "Out of date")
    }

    func testRainEndAndIncompleteForecastNeverBecomeDry() {
        let ending = WatchWidgetPresentation(entry: entry(forecast(reference: now, rainFrom: 0, rainUntil: 2)))
        XCTAssertEqual(ending.statusKey, "Rain ends in %d min")
        XCTAssertEqual(ending.entry.outlook.minutes, 10)
        let incomplete = WatchWidgetPresentation(entry: entry(forecast(reference: now, missing: true)))
        XCTAssertEqual(incomplete.statusKey, "No reliable forecast")
        XCTAssertEqual(incomplete.compactKey, "No data")
        var samples = forecast(reference: now, rainFrom: 2).samples
        samples[0] = RainSample(date: now, amountMM: nil)
        let possible = WatchWidgetPresentation(entry: entry(RainForecast(referenceTime: now, samples: samples)))
        XCTAssertEqual(possible.statusKey, "Rain possible · data incomplete")
        XCTAssertEqual(possible.compactKey, "No data")
    }

    func testSetupRemovedAndStorageIssuesCarryNoForecastOrLink() {
        for (issue, key) in [(WidgetForecastResult.Issue.noSavedPlaces, "Save places on iPhone"),
                             (.placeUnavailable, "Place removed"), (.storageUnavailable, "Storage unavailable")] {
            let value = WidgetTimelineBuilder.entry(for: .init(place: nil, forecast: forecast(reference: now),
                                                               source: .unavailable, issue: issue), at: now)
            XCTAssertEqual(WatchWidgetPresentation(entry: value).statusKey, key)
            XCTAssertNil(value.forecast)
            XCTAssertNil(value.deepLinkURL)
            XCTAssertNil(value.referenceTime)
        }
    }

    func testWatchRecommendationsUseOnlyLocalStoreWithoutNetworkOrCacheIO() {
        let places = [place, SavedPlace(name: "Zweiter Testort", coordinate: place.coordinate)]
        let snapshot = PlaceStore.Snapshot(places: places)
        let provider = WatchWidgetProvider(loader: loader(snapshot: snapshot))
        XCTAssertEqual(provider.recommendations().count, 2)
        // A setup recommendation remains available before iPhone sync; no location is invented.
        XCTAssertEqual(WatchWidgetProvider(loader: loader(snapshot: .init())).recommendations().count, 1)
    }

    func testWatchRecommendationsSurviveUnavailableStorage() {
        let loader = WidgetForecastLoader(loadPlaces: { throw CocoaError(.fileReadNoPermission) },
                                          loadCached: { _ in XCTFail("Recommendations must not read forecasts"); return nil },
                                          saveCached: { _, _ in XCTFail("Recommendations must not write") },
                                          fetch: { _ in XCTFail("Recommendations must not fetch"); throw URLError(.badURL) })
        XCTAssertEqual(WatchWidgetProvider(loader: loader).recommendations().count, 1)
    }

    private func loader(snapshot: PlaceStore.Snapshot) -> WidgetForecastLoader {
        WidgetForecastLoader(loadPlaces: { snapshot },
                             loadCached: { _ in XCTFail("Recommendations must not read forecasts"); return nil },
                             saveCached: { _, _ in XCTFail("Recommendations must not write") },
                             fetch: { _ in XCTFail("Recommendations must not fetch"); throw URLError(.badURL) })
    }
}
#endif
