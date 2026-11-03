#if DEBUG
import SwiftUI
import WidgetKit

enum PreviewData {
    static let now = Date()
    static let place = SavedPlace(name: "Berlin", coordinate: WeatherCoordinate(latitude: 52.52, longitude: 13.4))

    static func forecast(rates: [Double?], runAge: TimeInterval = 120) -> RainForecast {
        let ref = now.addingTimeInterval(-runAge)
        let samples = rates.enumerated().map { i, r in
            RainSample(date: now.addingTimeInterval(Double(i) * 300), amountMM: r.map { $0 / 12 })
        }
        return RainForecast(referenceTime: ref, samples: samples)
    }

    static func entry(_ forecast: RainForecast?, place: SavedPlace? = place,
                      issue: WidgetForecastResult.Issue? = nil) -> WeatherWidgetEntry {
        WidgetTimelineBuilder.entry(for: WidgetForecastResult(place: place, forecast: forecast,
                                                              source: forecast == nil ? .unavailable : .live,
                                                              issue: issue), at: now)
    }

    static let dry = entry(forecast(rates: Array(repeating: 0, count: 24)))
    static let startsIn = entry(forecast(rates: (0..<24).map { $0 < 3 ? 0 : [0.5, 2, 5, 9, 3, 1, 0.2][$0 % 7] }))
    static let raining = entry(forecast(rates: (0..<24).map { $0 < 5 ? 3 : 0 }))
    static let stale = entry(forecast(rates: Array(repeating: 0, count: 24), runAge: 40 * 60))
    static let none = entry(nil, place: nil, issue: .noSavedPlaces)
}


#Preview("Small", as: .systemSmall) {
    WeatherWidget()
} timeline: { PreviewData.startsIn; PreviewData.raining; PreviewData.dry; PreviewData.stale; PreviewData.none }

#Preview("Medium", as: .systemMedium) {
    WeatherWidget()
} timeline: { PreviewData.startsIn; PreviewData.raining; PreviewData.dry; PreviewData.stale; PreviewData.none }

#Preview("Circular", as: .accessoryCircular) {
    WeatherWidget()
} timeline: { PreviewData.startsIn; PreviewData.dry; PreviewData.stale }

#Preview("Rectangular", as: .accessoryRectangular) {
    WeatherWidget()
} timeline: { PreviewData.startsIn; PreviewData.dry; PreviewData.stale }

#Preview("Inline", as: .accessoryInline) {
    WeatherWidget()
} timeline: { PreviewData.startsIn; PreviewData.stale }
#endif
