import Foundation
import WidgetKit

/// Distinct from the iOS kind: this extension reads the Watch's own App Group container.
enum WatchWidgetKind {
    static let forecast = "ShowerNowWatchForecast"
}

extension WeatherWidgetEntry: TimelineEntry {}

/// P3 owns all IO, place resolution and timeline rules; this adapter adds Watch recommendations.
struct WatchWidgetProvider: AppIntentTimelineProvider {
    typealias Intent = WeatherWidgetIntent
    typealias Entry = WeatherWidgetEntry

    private let loader: WidgetForecastLoader
    private let clock: @Sendable () -> Date

    init(loader: WidgetForecastLoader = .live(), clock: @escaping @Sendable () -> Date = { Date() }) {
        self.loader = loader
        self.clock = clock
    }

    func recommendations() -> [AppIntentRecommendation<Intent>] {
        let places = (try? loader.loadPlaces().places) ?? []
        guard !places.isEmpty else {
            return [AppIntentRecommendation(intent: Intent(), description: WatchWidgetText.string("Save places on iPhone"))]
        }
        return places.map { place in
            let intent = Intent()
            intent.place = PlaceEntity(place: place)
            return AppIntentRecommendation(intent: intent, description: place.name)
        }
    }

    func placeholder(in context: Context) -> Entry {
        WidgetTimelineBuilder.entry(for: .init(place: nil, forecast: nil, source: .unavailable,
                                               issue: .noSavedPlaces), at: clock())
    }

    func snapshot(for configuration: Intent, in context: Context) async -> Entry {
        WidgetTimelineBuilder.entry(for: loader.cachedResult(for: configuration.place?.id), at: clock())
    }

    func timeline(for configuration: Intent, in context: Context) async -> Timeline<Entry> {
        let result = await loader.result(for: configuration.place?.id)
        let plan = WidgetTimelineBuilder.build(for: result, at: clock())
        return Timeline(entries: plan.entries, policy: .after(plan.reloadDate))
    }
}
