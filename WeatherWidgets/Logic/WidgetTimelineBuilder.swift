#if WIDGET_LOGIC_TESTS
@testable import Weather
#endif
import Foundation

/// Stable kind shared by the P6 configuration and the P4 foreground reload hook.
enum WeatherWidgetKind {
    static let forecast = "ShowerNowForecast"
}

struct WidgetForecastResult: Sendable {
    enum Source: Sendable { case live, cache, unavailable }
    enum Issue: Sendable {
        case noSavedPlaces, placeUnavailable, storageUnavailable, forecastUnavailable
    }

    let place: SavedPlace?
    let forecast: RainForecast?
    let source: Source
    let issue: Issue?
}

/// UI-independent entry; the WidgetKit conformance lives in the provider adapter.
struct WeatherWidgetEntry: Sendable {
    let date: Date
    let place: SavedPlace?
    let forecast: RainForecast?
    let outlook: RainOutlook
    let source: WidgetForecastResult.Source
    let issue: WidgetForecastResult.Issue?

    var referenceTime: Date? { forecast?.referenceTime }
    var dataAge: TimeInterval? { referenceTime.map { max(0, date.timeIntervalSince($0)) } }
    var deepLinkURL: URL? { place.map { WidgetDeepLink.url(for: $0.id) } }
}

enum WidgetTimelineBuilder {
    static let entryInterval: TimeInterval = 5 * 60
    static let horizon: TimeInterval = 60 * 60
    /// Reload request after a successful live fetch. The DWD run is already a few minutes old on arrival and
    /// counts as stale after 20 minutes, so a fresh fetch stays fresh only for roughly 10 to 15 minutes.
    static let reloadInterval: TimeInterval = 10 * 60
    /// Reload request when the data is only cached/stale or the fetch failed (offline, DWD error).
    static let retryInterval: TimeInterval = 5 * 60

    struct Plan: Sendable {
        let entries: [WeatherWidgetEntry]
        /// A request to WidgetKit, not a guarantee of an actual background refresh.
        let reloadDate: Date
    }

    static func entry(for result: WidgetForecastResult, at date: Date) -> WeatherWidgetEntry {
        // Never display an unassociated forecast (for example after deletion of the configured place).
        let forecast = result.place == nil ? nil : result.forecast
        return WeatherWidgetEntry(date: date, place: result.place, forecast: forecast,
                                  outlook: RainOutlook.evaluate(forecast, at: date),
                                  source: result.source, issue: result.issue)
    }

    static func build(for result: WidgetForecastResult, at now: Date) -> Plan {
        var dates = (0...12).map { now.addingTimeInterval(Double($0) * entryInterval) }
        if result.place != nil, let forecast = result.forecast {
            // Shared defines stale as >20 min. Expire just after that boundary even when
            // the five-minute grid is offset; otherwise a dry assertion could linger ~5 min.
            let expiration = forecast.referenceTime.addingTimeInterval(RainForecast.maximumAge + 0.001)
            if expiration > now, expiration < now.addingTimeInterval(horizon), !dates.contains(expiration) {
                dates.append(expiration)
            }
        }
        return Plan(entries: dates.sorted().map { entry(for: result, at: $0) },
                    reloadDate: now.addingTimeInterval(result.source == .live ? reloadInterval : retryInterval))
    }
}
