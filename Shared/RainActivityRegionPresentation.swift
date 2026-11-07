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

    init(state: RainActivityAttributes.ContentState, isStale: Bool, localRadiusKm: Int?, locale: String = Locale.preferredLanguages.first ?? "de") {
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

    private var german: Bool { locale.lowercased().hasPrefix("de") }

    /// "Umkreis 10 km"
    var radiusText: String? {
        guard let radiusKm else { return nil }
        return german ? "Umkreis \(radiusKm) km" : "\(radiusKm) km radius"
    }

    /// "34 % der Fläche nass" / "bis zu 34 % der Fläche nass"
    var shareText: String? {
        guard let share else { return nil }
        switch (share.kind, german) {
        case (.now, true): return "\(share.percent) % der Fläche nass"
        case (.peak, true): return "bis zu \(share.percent) % der Fläche nass"
        case (.now, false): return "\(share.percent)% of the area wet"
        case (.peak, false): return "up to \(share.percent)% of the area wet"
        }
    }

    /// "Stärkste Stufe 4 (leicht)", wording like the sensitivity levels (1-2, 3-4, 5-7, 8 and up).
    var intensityText: String? {
        guard let maxClass else { return nil }
        let word: String
        switch maxClass {
        case ..<3: word = german ? "sehr leicht" : "very light"
        case 3...4: word = german ? "leicht" : "light"
        case 5...7: word = german ? "mäßig" : "moderate"
        default: word = german ? "stark" : "heavy"
        }
        return german ? "Stärkste Stufe \(maxClass) (\(word))" : "Strongest level \(maxClass) (\(word))"
    }

    /// Fraction for the share bar (0...1); only for a currently wet share.
    var barFraction: Double? {
        guard let share, share.kind == .now else { return nil }
        return Double(share.percent) / 100
    }

    /// Short text for the compact Dynamic Island when there is no countdown.
    var compactShareText: String? {
        guard let share else { return nil }
        return "\(share.percent) %"
    }

    func headline(phase: RainActivityAttributes.Phase, isStale: Bool, hasCountdown: Bool) -> String {
        if isStale { return german ? "Daten veraltet" : "Data outdated" }
        switch phase {
        case .startsIn:
            if hasCountdown { return german ? "Regen im Umkreis in" : "Rain in the area in" }
            return german ? "Regen im Umkreis gleich" : "Rain in the area imminent"
        case .raining, .endsIn: return german ? "Es regnet im Umkreis" : "Raining in the area"
        case .dry: return german ? "Im Umkreis trocken" : "Dry in the area"
        }
    }

    /// Small caption above the headline: local name and radius.
    func title(name: String?) -> String? {
        let parts = [name, radiusText].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
