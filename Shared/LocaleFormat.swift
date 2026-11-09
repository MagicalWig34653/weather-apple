import Foundation

/// Locale-safe formatting helpers. Basis for the English localization: no string replacement of separators,
/// no fixed `de_DE`, no fixed 24-hour patterns. Every helper takes the locale explicitly so unit tests can
/// check `de_DE`, `en_US` and `en_GB` without changing the system language.
enum LocaleFormat {
    static let minusSign = "\u{2212}"

    /// Decimal number with the locale's separator. `useTypographicMinus` replaces the hyphen-minus with U+2212.
    static func decimal(_ value: Double, minFractionDigits: Int = 0, maxFractionDigits: Int = 1,
                        useTypographicMinus: Bool = false, locale: Locale = .current) -> String {
        let style = FloatingPointFormatStyle<Double>(locale: locale)
            .precision(.fractionLength(minFractionDigits...max(minFractionDigits, maxFractionDigits)))
            .grouping(.never)
        let text = value.formatted(style)
        guard useTypographicMinus else { return text }
        return text.replacingOccurrences(of: "-", with: minusSign)
    }

    /// Whole number in the locale's digits.
    static func integer(_ value: Int, locale: Locale = .current) -> String {
        value.formatted(IntegerFormatStyle<Int>(locale: locale).grouping(.never))
    }

    /// Short clock time following the locale (24 h in `de_DE`, 12 h with am/pm in `en_US`).
    /// `timeZone` defaults to the device zone, like the rest of the UI.
    static func time(_ date: Date, timeZone: TimeZone = .current, locale: Locale = .current) -> String {
        var style = Date.FormatStyle(date: .omitted, time: .shortened, locale: locale, timeZone: timeZone)
        style.calendar = locale.calendar
        return date.formatted(style)
    }

    /// Short date and time, locale-ordered.
    static func dateTime(_ date: Date, timeZone: TimeZone = .current, locale: Locale = .current) -> String {
        var style = Date.FormatStyle(date: .abbreviated, time: .shortened, locale: locale, timeZone: timeZone)
        style.calendar = locale.calendar
        return date.formatted(style)
    }

    /// Number followed by a unit symbol, separated by a no-break space ("5 °C", "7.5 mm/h").
    /// Whether English should drop the space before °C is an open wording decision (research, formatting).
    static func quantity(_ value: Double, unit: String, maxFractionDigits: Int = 1,
                         useTypographicMinus: Bool = false, locale: Locale = .current) -> String {
        decimal(value, maxFractionDigits: maxFractionDigits, useTypographicMinus: useTypographicMinus, locale: locale)
            + "\u{00A0}" + unit
    }
}
