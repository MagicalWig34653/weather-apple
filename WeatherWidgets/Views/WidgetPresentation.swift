import SwiftUI

/// UI-facing interpretation of one timeline entry. Never reports "dry" unless the outlook is fresh and complete.
struct WidgetPresentation {
    enum Tone { case rain, dry, warning, neutral }

    let symbol: String
    let headline: String
    /// Short form for circular/inline families.
    let short: String
    let detail: String?
    let tone: Tone
    let showsChart: Bool
    let minutes: Int?

    private static func rainInMinutes(_ m: Int) -> String {
        String(format: NSLocalizedString("WIDGET_RAIN_IN_MIN", value: "Regen in %lld Min.", comment: "Widget"), m)
    }

    private static func endsInMinutes(_ m: Int) -> String {
        String(format: NSLocalizedString("WIDGET_ENDS_IN_MIN", value: "Endet in %lld Min.", comment: "Widget"), m)
    }

    init(entry: WeatherWidgetEntry) {
        let outlook = entry.outlook
        minutes = outlook.minutes
        showsChart = outlook.state != .stale && outlook.state != .noData && entry.forecast != nil
        let raining = NSLocalizedString("WIDGET_RAINING", value: "Es regnet", comment: "Widget")
        let rainShort = NSLocalizedString("WIDGET_RAIN", value: "Regen", comment: "Widget")
        switch outlook.state {
        case .rainingNow:
            symbol = "cloud.rain.fill"; headline = raining; short = rainShort
            detail = NSLocalizedString("WIDGET_NO_END", value: "Ende nicht absehbar", comment: "Widget"); tone = .rain
        case .endsIn:
            let m = outlook.minutes ?? 0
            symbol = "cloud.rain.fill"; headline = raining; short = rainShort
            detail = Self.endsInMinutes(m); tone = .rain
        case .startsIn:
            let m = outlook.minutes ?? 0
            symbol = "cloud.drizzle.fill"; headline = Self.rainInMinutes(m); short = Self.rainInMinutes(m)
            detail = nil; tone = .rain
        case .dry:
            let dry = NSLocalizedString("WIDGET_DRY", value: "Trocken", comment: "Widget")
            symbol = "sun.max.fill"; headline = dry; short = dry
            detail = NSLocalizedString("WIDGET_NO_RAIN_EXPECTED", value: "Vorerst kein Regen erwartet", comment: "Widget"); tone = .dry
        case .stale:
            symbol = "clock.badge.exclamationmark"
            headline = NSLocalizedString("WIDGET_STALE", value: "Daten veraltet", comment: "Widget")
            short = NSLocalizedString("WIDGET_STALE_SHORT", value: "Veraltet", comment: "Widget")
            detail = NSLocalizedString("WIDGET_NO_RELIABLE", value: "Keine verlässliche Aussage", comment: "Widget"); tone = .warning
        case .noData:
            symbol = "exclamationmark.triangle.fill"
            let noPlace = NSLocalizedString("WIDGET_NO_PLACE", value: "Kein Ort", comment: "Widget")
            switch entry.issue {
            case .noSavedPlaces:
                headline = noPlace; short = noPlace
                detail = NSLocalizedString("WIDGET_ADD_PLACE", value: "Ort in Showers anlegen", comment: "Widget")
            case .placeUnavailable:
                headline = NSLocalizedString("WIDGET_PLACE_MISSING", value: "Ort fehlt", comment: "Widget"); short = noPlace
                detail = NSLocalizedString("WIDGET_RECONFIGURE", value: "Widget neu konfigurieren", comment: "Widget")
            default:
                if outlook.missingDataReason == .possibleRain {
                    headline = NSLocalizedString("WIDGET_RAIN_POSSIBLE", value: "Regen möglich", comment: "Widget")
                    short = NSLocalizedString("WIDGET_RAIN_POSSIBLE_SHORT", value: "Regen?", comment: "Widget")
                    detail = NSLocalizedString("WIDGET_DATA_INCOMPLETE", value: "Daten unvollständig", comment: "Widget")
                } else {
                    let noData = NSLocalizedString("WIDGET_NO_DATA", value: "Keine Daten", comment: "Widget")
                    headline = noData; short = noData
                    detail = NSLocalizedString("WIDGET_NO_CURRENT_FORECAST", value: "Keine aktuelle Prognose", comment: "Widget")
                }
            }
            tone = .warning
        }
    }

    var color: Color {
        switch tone {
        case .rain: .cyan
        case .dry: .green
        case .warning: .orange
        case .neutral: .secondary
        }
    }
}

extension RainOutlook.Intensity {
    var barColor: Color {
        switch self {
        case .none: .secondary.opacity(0.35)
        case .light: .cyan
        case .moderate: .blue
        case .heavy: .indigo
        }
    }
}
