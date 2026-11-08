import Foundation

/// Which warnings the list shows.
enum WarnScope: Equatable, Sendable {
    case mine, all

    /// Standard is "my places"; without saved places everything is shown.
    static func defaultScope(hasPlaces: Bool) -> WarnScope { hasPlaces ? .mine : .all }
}

/// Pure presentation of the warnings view. Texts of the DWD (headline, text, instruction) are never touched here.
enum WarningPresentation {
    private typealias S = WarnSettingsPresentation

    private static func text(_ key: String, _ bundle: Bundle) -> String {
        bundle.localizedString(forKey: key, value: key, table: nil)
    }

    static func levelWord(_ level: Int, bundle: Bundle = .main) -> String { S.levelWord(level, bundle: bundle) }
    static func levelTitle(_ level: Int, bundle: Bundle = .main) -> String { S.levelTitle(level, bundle: bundle) }
    static func kindTitle(_ kind: WarnKind, bundle: Bundle = .main) -> String { S.kindTitle(kind, bundle: bundle) }
    static func disclaimer(bundle: Bundle = .main) -> String { S.disclaimer(bundle: bundle) }

    /// Level is never conveyed by color alone: the symbol differs per level as well.
    static func levelSymbol(_ level: Int) -> String {
        switch min(max(level, 1), 4) {
        case 1: "exclamationmark.circle"
        case 2: "exclamationmark.triangle"
        case 3: "exclamationmark.triangle.fill"
        default: "exclamationmark.octagon.fill"
        }
    }

    /// Type symbol of the card (the type is also named in the VoiceOver label).
    static func kindSymbol(_ kind: WarnKind) -> String {
        switch kind {
        case .severeWeather: "cloud.bolt.rain.fill"
        case .frost: "thermometer.snowflake"
        case .ice: "snowflake"
        }
    }

    // MARK: Grouping

    /// A section of the list: one saved place ("my places") or the whole list without a title ("all").
    struct Group: Identifiable, Equatable {
        let title: String?
        let warnings: [ActiveWarning]
        var id: String { title ?? "-" }
    }

    /// "My places": one group per saved place (a warning appears under every place it affects), groups by highest level, then name.
    /// Warnings without a matching place name go to a trailing untitled group. "All": one untitled group in the given order.
    static func groups(_ warnings: [ActiveWarning], scope: WarnScope, placeNames: (ActiveWarning) -> [String]) -> [Group] {
        guard !warnings.isEmpty else { return [] }
        guard scope == .mine else { return [Group(title: nil, warnings: warnings)] }
        var byPlace: [String: [ActiveWarning]] = [:]
        var unnamed: [ActiveWarning] = []
        for warning in warnings {
            let names = Set(placeNames(warning))
            if names.isEmpty { unnamed.append(warning) }
            for name in names { byPlace[name, default: []].append(warning) }
        }
        var result = byPlace.map { Group(title: $0.key, warnings: $0.value) }.sorted {
            let (a, b) = ($0.warnings.map(\.severity).max() ?? 0, $1.warnings.map(\.severity).max() ?? 0)
            return a != b ? a > b : $0.title!.localizedStandardCompare($1.title!) == .orderedAscending
        }
        if !unnamed.isEmpty { result.append(Group(title: nil, warnings: unnamed)) }
        return result
    }

    // MARK: Times

    private static func calendar(_ timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    private static func timeOnly(_ date: Date, locale: Locale, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale; formatter.timeZone = timeZone
        formatter.dateStyle = .none; formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    /// "heute 22:00", "morgen 09:00", "gestern 23:10" or "Sa., 8. Nov. 09:00".
    static func dayTime(_ date: Date, now: Date, locale: Locale, timeZone: TimeZone, bundle: Bundle = .main) -> String {
        let cal = calendar(timeZone)
        let offset = cal.dateComponents([.day], from: cal.startOfDay(for: now), to: cal.startOfDay(for: date)).day ?? 99
        let time = timeOnly(date, locale: locale, timeZone: timeZone)
        switch offset {
        case 0: return "\(text("WARN_TODAY", bundle)) \(time)"
        case 1: return "\(text("WARN_TOMORROW", bundle)) \(time)"
        case -1: return "\(text("WARN_YESTERDAY", bundle)) \(time)"
        default:
            let formatter = DateFormatter()
            formatter.locale = locale; formatter.timeZone = timeZone
            formatter.setLocalizedDateFormatFromTemplate("EEEdMMM")
            return "\(formatter.string(from: date)) \(time)"
        }
    }

    /// "heute 22:00 bis morgen 09:00"; the end shows only the time when it falls on the start's day.
    static func timeRange(onset: Date, expires: Date, now: Date = Date(), locale: Locale = .current,
                          timeZone: TimeZone = .current, bundle: Bundle = .main) -> String {
        let start = dayTime(onset, now: now, locale: locale, timeZone: timeZone, bundle: bundle)
        let end = calendar(timeZone).isDate(onset, inSameDayAs: expires)
            ? timeOnly(expires, locale: locale, timeZone: timeZone)
            : dayTime(expires, now: now, locale: locale, timeZone: timeZone, bundle: bundle)
        return String(format: text("WARN_RANGE", bundle), start, end)
    }

    /// "Quelle: Deutscher Wetterdienst, ausgegeben 12:31" (with the day if not today).
    static func sourceLine(sent: Date, now: Date = Date(), locale: Locale = .current,
                           timeZone: TimeZone = .current, bundle: Bundle = .main) -> String {
        let cal = calendar(timeZone)
        let when = cal.isDate(sent, inSameDayAs: now)
            ? timeOnly(sent, locale: locale, timeZone: timeZone)
            : dayTime(sent, now: now, locale: locale, timeZone: timeZone, bundle: bundle)
        return String(format: text("WARN_SOURCE_ISSUED", bundle), when)
    }

    // MARK: Data state

    /// nil while fresh.
    static func staleNotice(_ staleness: Staleness, bundle: Bundle = .main) -> String? {
        staleness == .stale ? text("WARN_STALE", bundle) : nil
    }

    static func standLine(fetchedAt: Date, now: Date = Date(), locale: Locale = .current,
                          timeZone: TimeZone = .current, bundle: Bundle = .main) -> String {
        let cal = calendar(timeZone)
        let when = cal.isDate(fetchedAt, inSameDayAs: now)
            ? timeOnly(fetchedAt, locale: locale, timeZone: timeZone)
            : dayTime(fetchedAt, now: now, locale: locale, timeZone: timeZone, bundle: bundle)
        return String(format: text("WARN_STAND", bundle), when)
    }

    /// Hint when the DWD text is not in the app language (the server falls back to the other language).
    static func languageHint(warningLang: String, appLang: String, bundle: Bundle = .main) -> String? {
        guard warningLang != appLang else { return nil }
        return text(warningLang == "en" ? "WARN_LANG_ONLY_EN" : "WARN_LANG_ONLY_DE", bundle)
    }

    // MARK: Empty and error states

    enum Content: Equatable {
        case loading
        case unavailable
        case noPlaces
        case noCells
        case empty
        case list
    }

    /// Honest content state: no data is never shown as "no warnings".
    static func content(scope: WarnScope, hasData: Bool, isLoading: Bool, hasPlaces: Bool, hasAnyCells: Bool, count: Int) -> Content {
        if !hasData { return isLoading ? .loading : .unavailable }
        if scope == .mine {
            if !hasPlaces { return .noPlaces }
            if !hasAnyCells { return .noCells }
        }
        return count == 0 ? .empty : .list
    }

    static func contentText(_ content: Content, scope: WarnScope, bundle: Bundle = .main) -> String? {
        switch content {
        case .loading: text("WARN_LOADING", bundle)
        case .unavailable: text("WARN_FAILED_NONE", bundle)
        case .noPlaces: text("WARN_NO_PLACES", bundle)
        case .noCells: text("WARN_NO_CELLS", bundle)
        case .empty: text(scope == .mine ? "WARN_EMPTY_MINE" : "WARN_EMPTY_ALL", bundle)
        case .list: nil
        }
    }

    /// Calm symbol of the centered state (never a "shield" for missing data).
    static func contentSymbol(_ content: Content) -> String {
        switch content {
        case .loading: "clock"
        case .unavailable: "wifi.exclamationmark"
        case .noPlaces, .noCells: "mappin.slash"
        case .empty, .list: "checkmark.circle"
        }
    }

    /// Short second line, only where the feed itself is healthy and empty.
    static func contentDetail(_ content: Content, bundle: Bundle = .main) -> String? {
        content == .empty ? text("WARN_EMPTY_TYPES", bundle) : nil
    }

    static func levelShort(_ level: Int, bundle: Bundle = .main) -> String {
        String(format: text("WARN_LEVEL_SHORT", bundle), min(max(level, 1), 4))
    }

    static func failedNotice(bundle: Bundle = .main) -> String { text("WARN_FAILED_CACHED", bundle) }

    static func affects(_ names: [String], bundle: Bundle = .main) -> String? {
        names.isEmpty ? nil : String(format: text("WARN_AFFECTS", bundle), names.joined(separator: ", "))
    }

    // MARK: Accessibility

    /// One sentence per warning: type, level with digit, period, headline, source.
    static func accessibilityLabel(for warning: ActiveWarning, now: Date = Date(), locale: Locale = .current,
                                   timeZone: TimeZone = .current, bundle: Bundle = .main) -> String {
        [kindTitle(warning.kind, bundle: bundle), levelTitle(warning.severity, bundle: bundle),
         timeRange(onset: warning.onset, expires: warning.expires, now: now, locale: locale, timeZone: timeZone, bundle: bundle),
         warning.headline,
         sourceLine(sent: warning.sent, now: now, locale: locale, timeZone: timeZone, bundle: bundle)].joined(separator: ". ")
    }

    // MARK: Entry point (badge at the radar)

    struct Summary: Equatable { let count: Int; let maxLevel: Int }

    static func summary(of relevant: [ActiveWarning]) -> Summary {
        Summary(count: relevant.count, maxLevel: relevant.map(\.severity).max() ?? 0)
    }

    static func buttonLabel(bundle: Bundle = .main) -> String { text("WARN_BUTTON", bundle) }

    static func buttonValue(_ summary: Summary, stale: Bool, bundle: Bundle = .main) -> String {
        var parts: [String] = []
        switch summary.count {
        case 0: parts.append(text("WARN_BADGE_NONE", bundle))
        case 1: parts.append(String(format: text("WARN_BADGE_ONE", bundle), summary.maxLevel))
        default: parts.append(String(format: text("WARN_BADGE_MANY", bundle), summary.count, summary.maxLevel))
        }
        if stale { parts.append(text("WARN_STALE", bundle)) }
        return parts.joined(separator: ". ")
    }
}
