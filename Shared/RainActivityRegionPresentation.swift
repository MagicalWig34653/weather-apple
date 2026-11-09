import Foundation

/// Display content of a region Live Activity (pure, no UI frameworks, shared by widget and tests).
/// Texts follow the `locale` argument like `RainActivityText`; the percentage is a lower bound (unknown cells never count as wet).
struct RainActivityRegionPresentation: Equatable, Sendable {
    enum ShareKind: Equatable, Sendable { case now, peak }

    /// Radius of the area in km (from the payload, otherwise the locally stored one).
    let radiusKm: Int?
    /// Share to show; nil when stale, dry, or the payload carries no useful share.
    let share: (percent: Int, kind: ShareKind)?
    /// Strongest class in the area (1...15); nil when dry or stale.
    let maxClass: Int?
    let locale: String

    init(state: RainActivityAttributes.ContentState, isStale: Bool, localRadiusKm: Int?, locale: String = AppLanguage.code) {
        self.locale = locale
        radiusKm = Self.valid(radius: state.regionRadiusKm) ?? Self.valid(radius: localRadiusKm)
        if isStale || state.phase == .dry {
            share = nil; maxClass = nil
        } else {
            let wet = state.wetSharePercent.map(Self.clamp), peak = state.peakSharePercent.map(Self.clamp)
            switch state.phase {
            case .raining, .endsIn:
                if let wet, wet > 0 { share = (wet, .now) }
                else if let peak, peak > 0 { share = (peak, .peak) }
                else { share = nil }
            case .startsIn:
                if let peak, peak > 0 { share = (peak, .peak) }
                else if let wet, wet > 0 { share = (wet, .now) }
                else { share = nil }
            case .dry:
                share = nil
            }
            maxClass = state.intensityClass >= 1 ? min(state.intensityClass, 15) : nil
        }
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.radiusKm == rhs.radiusKm && lhs.share?.percent == rhs.share?.percent && lhs.share?.kind == rhs.share?.kind
            && lhs.maxClass == rhs.maxClass && lhs.locale == rhs.locale
    }

    private static func clamp(_ value: Int) -> Int { min(100, max(0, value)) }
    private static func valid(radius: Int?) -> Int? { radius.flatMap { $0 >= 1 ? $0 : nil } }

    /// Bundle of the requested language (falls back to the main bundle), so tests can check both languages.
    private var bundle: Bundle {
        let code = locale.lowercased().hasPrefix("de") ? "de" : "en"
        if let path = Bundle.main.path(forResource: code, ofType: "lproj"), let bundle = Bundle(path: path) { return bundle }
        return .main
    }

    /// Text from the shared table `SharedTexts` (Shared/Resources), German default as `value`.
    private func text(_ key: String, value german: String) -> String {
        NSLocalizedString(key, tableName: "SharedTexts", bundle: bundle, value: german, comment: "Area Live Activity")
    }

    /// "Umkreis 10 km"
    var radiusText: String? {
        guard let radiusKm else { return nil }
        return String(format: text("REGION_ACTIVITY_RADIUS", value: "Umkreis %d km"), radiusKm)
    }

    /// "34 % der Fläche nass" / "bis zu 34 % der Fläche nass"
    var shareText: String? {
        guard let share else { return nil }
        switch share.kind {
        case .now: return String(format: text("REGION_ACTIVITY_SHARE_NOW", value: "%d %% der Fläche nass"), share.percent)
        case .peak: return String(format: text("REGION_ACTIVITY_SHARE_PEAK", value: "bis zu %d %% der Fläche nass"), share.percent)
        }
    }

    /// "Stärkste Stufe 4 (leicht)", wording like the sensitivity levels (1-2, 3-4, 5-7, 8 and up).
    var intensityText: String? {
        guard let maxClass else { return nil }
        let word: String
        switch maxClass {
        case ..<3: word = text("REGION_ACTIVITY_WORD_VERY_LIGHT", value: "sehr leicht")
        case 3...4: word = text("REGION_ACTIVITY_WORD_LIGHT", value: "leicht")
        case 5...7: word = text("REGION_ACTIVITY_WORD_MODERATE", value: "mäßig")
        default: word = text("REGION_ACTIVITY_WORD_HEAVY", value: "stark")
        }
        return String(format: text("REGION_ACTIVITY_INTENSITY", value: "Stärkste Stufe %1$d (%2$@)"), maxClass, word)
    }

    /// Fraction for the share bar (0...1); only for a currently wet share.
    var barFraction: Double? {
        guard let share, share.kind == .now else { return nil }
        return Double(share.percent) / 100
    }

    /// Short text for the compact Dynamic Island when there is no countdown.
    var compactShareText: String? {
        guard let share else { return nil }
        return String(format: text("REGION_ACTIVITY_SHARE_COMPACT", value: "%d %%"), share.percent)
    }

    func headline(phase: RainActivityAttributes.Phase, isStale: Bool, hasCountdown: Bool) -> String {
        if isStale { return text("REGION_ACTIVITY_HEADLINE_STALE", value: "Daten veraltet") }
        switch phase {
        case .startsIn:
            if hasCountdown { return text("REGION_ACTIVITY_HEADLINE_STARTS_IN", value: "Regen im Umkreis in") }
            return text("REGION_ACTIVITY_HEADLINE_IMMINENT", value: "Regen im Umkreis gleich")
        case .raining, .endsIn: return text("REGION_ACTIVITY_HEADLINE_RAINING", value: "Es regnet im Umkreis")
        case .dry: return text("REGION_ACTIVITY_HEADLINE_DRY", value: "Im Umkreis trocken")
        }
    }

    /// Small caption above the headline: local name and radius.
    func title(name: String?) -> String? {
        let parts = [name, radiusText].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
