import Foundation

/// Presentation only. State, freshness and deep links come unchanged from the P3 entry.
struct WatchWidgetPresentation {
    let entry: WeatherWidgetEntry

    var statusKey: String {
        switch entry.issue {
        case .noSavedPlaces: return "Save places on iPhone"
        case .placeUnavailable: return "Place removed"
        case .storageUnavailable: return "Storage unavailable"
        default: break
        }
        switch entry.outlook.state {
        case .rainingNow: return "Raining now"
        case .startsIn: return "Rain in %d min"
        case .endsIn: return "Rain ends in %d min"
        case .dry: return "No measurable rain for now"
        case .stale: return "Out of date"
        case .noData:
            switch entry.outlook.missingDataReason {
            case .possibleRain: return "Rain possible · data incomplete"
            case .incomplete: return "No reliable forecast"
            default: return "No forecast"
            }
        }
    }

    var compactKey: String {
        if entry.issue == .noSavedPlaces { return "Set up" }
        if entry.place == nil { return "No data" }
        switch entry.outlook.state {
        case .rainingNow: return "Rain"
        case .startsIn: return "In %dm"
        case .endsIn: return "Ends %dm"
        case .dry: return "Dry for now"
        case .stale: return "Out of date"
        case .noData: return "No data"
        }
    }

    var symbolName: String {
        switch entry.outlook.state {
        case .rainingNow, .endsIn: "cloud.rain.fill"
        case .startsIn: "cloud.drizzle.fill"
        case .dry: "cloud"
        case .stale: "clock.badge.exclamationmark"
        case .noData: "questionmark.circle"
        }
    }

    var status: String { formatted(statusKey) }
    var compactStatus: String { formatted(compactKey) }
    var isCached: Bool { entry.source == .cache }

    var age: String {
        guard let age = entry.dataAge else { return WatchWidgetText.string("No run time") }
        return String(format: WatchWidgetText.string("DWD run · %d min ago"), Int(age / 60))
    }

    private func formatted(_ key: String) -> String {
        String(format: WatchWidgetText.string(key), entry.outlook.minutes ?? 0)
    }
}

enum WatchWidgetText {
    static func string(_ key: String) -> String {
        NSLocalizedString(key, bundle: .main, value: key, comment: "Watch complication")
    }
}
