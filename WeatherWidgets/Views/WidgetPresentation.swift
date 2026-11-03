import SwiftUI

/// UI-facing interpretation of one timeline entry. Never reports "dry" unless the outlook is fresh and complete.
struct WidgetPresentation {
    enum Tone { case rain, dry, warning, neutral }

    let symbol: String
    let headline: LocalizedStringKey
    /// Short form for circular/inline families.
    let short: LocalizedStringKey
    let detail: LocalizedStringKey?
    let tone: Tone
    let showsChart: Bool
    let minutes: Int?

    init(entry: WeatherWidgetEntry) {
        let outlook = entry.outlook
        minutes = outlook.minutes
        showsChart = outlook.state != .stale && outlook.state != .noData && entry.forecast != nil
        switch outlook.state {
        case .rainingNow:
            symbol = "cloud.rain.fill"; headline = "Es regnet"; short = "Regen"
            detail = "Ende nicht absehbar"; tone = .rain
        case .endsIn:
            let m = outlook.minutes ?? 0
            symbol = "cloud.rain.fill"; headline = "Es regnet"; short = "Regen"
            detail = "Endet in \(m) Min."; tone = .rain
        case .startsIn:
            let m = outlook.minutes ?? 0
            symbol = "cloud.drizzle.fill"; headline = "Regen in \(m) Min."; short = "Regen in \(m) Min."
            detail = nil; tone = .rain
        case .dry:
            symbol = "sun.max.fill"; headline = "Trocken"; short = "Trocken"
            detail = "Vorerst kein Regen erwartet"; tone = .dry
        case .stale:
            symbol = "clock.badge.exclamationmark"; headline = "Daten veraltet"; short = "Veraltet"
            detail = "Keine verlässliche Aussage"; tone = .warning
        case .noData:
            symbol = "exclamationmark.triangle.fill"
            switch entry.issue {
            case .noSavedPlaces:
                headline = "Kein Ort"; short = "Kein Ort"; detail = "Ort in ShowerNow anlegen"
            case .placeUnavailable:
                headline = "Ort fehlt"; short = "Kein Ort"; detail = "Widget neu konfigurieren"
            default:
                if outlook.missingDataReason == .possibleRain {
                    headline = "Regen möglich"; short = "Regen?"; detail = "Daten unvollständig"
                } else {
                    headline = "Keine Daten"; short = "Keine Daten"; detail = "Keine aktuelle Prognose"
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
