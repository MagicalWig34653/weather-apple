import Foundation

/// Native localized resources, with English fallbacks when a key is missing.
enum WatchText {
    static func string(_ key: String) -> String {
        NSLocalizedString(key, bundle: .main, value: key, comment: "Watch app")
    }

    static func status(_ presentation: WatchForecastPresentation) -> String {
        switch presentation.state {
        case .stale: string("Forecast is out of date")
        case .dry: string("No measurable rain expected for now")
        case .rainingNow: string("Raining now")
        case .startsIn: String(format: string("Rain in about %d min"), presentation.outlook.minutes ?? 0)
        case .endsIn: String(format: string("Rain ends in about %d min"), presentation.outlook.minutes ?? 0)
        case .noData:
            switch presentation.outlook.missingDataReason {
            case .possibleRain: string("Rain possible · incomplete data")
            case .incomplete: string("No reliable rain forecast")
            default: string("No current forecast")
            }
        }
    }

    static func age(_ minutes: Int) -> String {
        String(format: string("DWD run · %d min ago"), minutes)
    }
}
