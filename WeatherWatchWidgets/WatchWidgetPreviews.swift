#if DEBUG
import SwiftUI
import WidgetKit

struct WatchWidgetPreviews: PreviewProvider {
    private static let now = Date(timeIntervalSince1970: 1_800_000_000)
    private static let place = SavedPlace(name: "Beispielort", coordinate: .init(latitude: 50, longitude: 10))
    private static var fresh: WeatherWidgetEntry {
        let forecast = RainForecast(referenceTime: now, samples: (0...24).map { index in
            RainSample(date: now.addingTimeInterval(Double(index * 300)), amountMM: index >= 2 ? 0.2 : 0)
        })
        return WidgetTimelineBuilder.entry(for: .init(place: place, forecast: forecast, source: .live, issue: nil), at: now)
    }

    static var previews: some View {
        Group {
            WatchRainWidgetView(entry: fresh)
                .previewContext(WidgetPreviewContext(family: .accessoryCircular))
            WatchRainWidgetView(entry: fresh)
                .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
            WatchRainWidgetView(entry: fresh)
                .previewContext(WidgetPreviewContext(family: .accessoryInline))
            WatchRainWidgetView(entry: fresh)
                .previewContext(WidgetPreviewContext(family: .accessoryCorner))
            WatchRainWidgetView(entry: WidgetTimelineBuilder.entry(
                for: .init(place: place, forecast: fresh.forecast, source: .cache, issue: nil),
                at: now.addingTimeInterval(1201)))
                .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
            WatchRainWidgetView(entry: WidgetTimelineBuilder.entry(
                for: .init(place: nil, forecast: nil, source: .unavailable, issue: .noSavedPlaces), at: now))
                .previewContext(WidgetPreviewContext(family: .accessoryCircular))
        }
    }
}
#endif
