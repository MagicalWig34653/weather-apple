import Foundation

/// Time-dependent interpretation of one forecast; no fetching, storage or clock access.
struct RainOutlook: Equatable, Sendable {
    enum State: String, Codable, Sendable {
        case rainingNow, startsIn, endsIn, dry, stale, noData
    }

    enum Intensity: Int, Codable, Sendable {
        case none = 0, light, moderate, heavy

        init(rateMMPerHour rate: Double) {
            if rate < RainForecast.rainThresholdMMPerHour { self = .none }
            else if rate < 2 { self = .light }
            else if rate < 7.5 { self = .moderate }
            else { self = .heavy }
        }
    }

    enum MissingDataReason: Equatable, Sendable {
        case unavailable, incomplete, possibleRain
    }

    let state: State
    /// Whole minutes until the transition (rounded down, matching the app summary).
    let minutes: Int?
    let intensity: Intensity
    let missingDataReason: MissingDataReason?

    private init(_ state: State, minutes: Int? = nil, intensity: Intensity = .none,
                 missingDataReason: MissingDataReason? = nil) {
        self.state = state
        self.minutes = minutes
        self.intensity = intensity
        self.missingDataReason = missingDataReason
    }

    static func evaluate(_ forecast: RainForecast?, at now: Date) -> RainOutlook {
        guard let forecast else { return RainOutlook(.noData, missingDataReason: .unavailable) }
        guard !forecast.isStale(at: now) else { return RainOutlook(.stale) }
        let remaining = forecast.samples.filter { $0.date >= now }
        guard !remaining.isEmpty else { return RainOutlook(.noData, missingDataReason: .unavailable) }
        if let firstRain = remaining.first(where: { ($0.rateMMPerHour ?? -1) >= RainForecast.rainThresholdMMPerHour }) {
            if remaining.contains(where: { $0.date <= firstRain.date && $0.amountMM == nil }) {
                return RainOutlook(.noData, missingDataReason: .possibleRain)
            }
            let minutes = Int(max(0, firstRain.date.timeIntervalSince(now) / 60))
            let intensity = Intensity(rateMMPerHour: firstRain.rateMMPerHour!)
            guard minutes < 5 else { return RainOutlook(.startsIn, minutes: minutes, intensity: intensity) }
            // Do not infer a rain end across missing values or a gap in the five-minute grid.
            var previous = firstRain.date
            for sample in remaining where sample.date > firstRain.date {
                guard sample.date.timeIntervalSince(previous) <= 300,
                      let rate = sample.rateMMPerHour else { break }
                if rate < RainForecast.rainThresholdMMPerHour {
                    return RainOutlook(.endsIn, minutes: Int(max(0, sample.date.timeIntervalSince(now) / 60)),
                                       intensity: intensity)
                }
                previous = sample.date
            }
            return RainOutlook(.rainingNow, intensity: intensity)
        }
        guard remaining.allSatisfy({ $0.amountMM != nil }) else {
            return RainOutlook(.noData, missingDataReason: .incomplete)
        }
        return RainOutlook(.dry)
    }

    /// Existing app wording is retained, including its cautious handling of unknown values.
    var summary: String { summary(bundle: .main) }

    func summary(bundle: Bundle) -> String {
        switch state {
        case .stale: return NSLocalizedString("OUTLOOK_STALE", bundle: bundle, value: "Prognosedaten sind veraltet", comment: "Rain outlook summary")
        case .rainingNow, .endsIn: return NSLocalizedString("OUTLOOK_RAIN_AT_PLACE", bundle: bundle, value: "Regen am ausgewählten Ort", comment: "Rain outlook summary")
        case .startsIn:
            return String(format: NSLocalizedString("OUTLOOK_RAIN_IN_MINUTES", bundle: bundle, value: "Regen voraussichtlich in etwa %d Min.", comment: "Rain outlook summary"),
                          minutes ?? 0)
        case .dry: return NSLocalizedString("OUTLOOK_DRY", bundle: bundle, value: "Vorerst kein messbarer Regen erwartet", comment: "Rain outlook summary")
        case .noData:
            switch missingDataReason {
            case .possibleRain: return NSLocalizedString("OUTLOOK_POSSIBLE_RAIN", bundle: bundle, value: "Regen möglich · Daten teilweise unvollständig", comment: "Rain outlook summary")
            case .incomplete: return NSLocalizedString("OUTLOOK_UNRELIABLE", bundle: bundle, value: "Keine verlässliche Regenaussage verfügbar", comment: "Rain outlook summary")
            default: return NSLocalizedString("OUTLOOK_NO_FORECAST", bundle: bundle, value: "Keine aktuelle Prognose verfügbar", comment: "Rain outlook summary")
            }
        }
    }
}
