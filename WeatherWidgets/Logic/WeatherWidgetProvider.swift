#if WIDGET_LOGIC_TESTS
@testable import Weather
#endif
import Foundation
import WidgetKit

extension WeatherWidgetEntry: TimelineEntry {}

struct WeatherWidgetProvider: AppIntentTimelineProvider {
    typealias Intent = WeatherWidgetIntent
    typealias Entry = WeatherWidgetEntry

    private let loader: WidgetForecastLoader
    private let clock: @Sendable () -> Date

    init(loader: WidgetForecastLoader = .live(), clock: @escaping @Sendable () -> Date = { Date() }) {
        self.loader = loader
        self.clock = clock
    }

    func placeholder(in context: Context) -> Entry {
        WidgetTimelineBuilder.entry(for: WidgetForecastResult(place: nil, forecast: nil,
                                                              source: .unavailable, issue: .noSavedPlaces), at: clock())
    }

    func snapshot(for configuration: Intent, in context: Context) async -> Entry {
        WidgetTimelineBuilder.entry(for: loader.cachedResult(for: configuration.place?.id), at: clock())
    }

    func timeline(for configuration: Intent, in context: Context) async -> Timeline<Entry> {
        let result = await loader.result(for: configuration.place?.id)
        // Start after IO completes, not at the potentially much earlier request time.
        let plan = WidgetTimelineBuilder.build(for: result, at: clock())
        return Timeline(entries: plan.entries, policy: .after(plan.reloadDate))
    }
}
