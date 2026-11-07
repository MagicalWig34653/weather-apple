import Foundation

/// Pure presentation logic of the warnings settings (texts de/en via `Localizable.strings`, rows by state).
enum WarnSettingsPresentation {
    enum Row: Equatable {
        /// "No replacement for official channels": stands before the main switch (and in the confirmation before the system prompt).
        case disclaimer
        case mainToggle
        case typeToggle(WarnKind)
        case minLevel(WarnKind)
        case timeSensitive
        case timeSensitiveHint
    }

    /// Nothing at all without the server capability `warnings_push`.
    static func rows(capability: Bool, settings: WarnUserSettings) -> [Row] {
        guard capability else { return [] }
        var rows: [Row] = [.disclaimer, .mainToggle]
        guard settings.enabled else { return rows }
        for kind in WarnKind.allCases {
            rows.append(.typeToggle(kind))
            if settings.types.contains(kind) { rows.append(.minLevel(kind)) }
        }
        rows += [.timeSensitive, .timeSensitiveHint]
        return rows
    }

    private static func text(_ key: String, _ bundle: Bundle) -> String {
        bundle.localizedString(forKey: key, value: key, table: nil)
    }

    /// "Stufe 3: Unwetterwarnung" / "Level 3: Severe weather warning": level always with its digit.
    static func levelTitle(_ level: Int, bundle: Bundle = .main) -> String {
        let clamped = min(max(level, 1), 4)
        return String(format: text("WARN_LEVEL_FORMAT", bundle), clamped, text("WARN_LEVEL_WORD_\(clamped)", bundle))
    }

    static func levelWord(_ level: Int, bundle: Bundle = .main) -> String {
        text("WARN_LEVEL_WORD_\(min(max(level, 1), 4))", bundle)
    }

    static func kindTitle(_ kind: WarnKind, bundle: Bundle = .main) -> String {
        switch kind {
        case .severeWeather: text("WARN_TYPE_SEVERE", bundle)
        case .frost: text("WARN_TYPE_FROST", bundle)
        case .ice: text("WARN_TYPE_ICE", bundle)
        }
    }

    static func disclaimer(bundle: Bundle = .main) -> String { text("WARN_DISCLAIMER", bundle) }
    static func timeSensitiveHint(bundle: Bundle = .main) -> String { text("WARN_TIME_SENSITIVE_HINT", bundle) }

    static func noticeText(_ notice: WarnNotice, bundle: Bundle = .main) -> String {
        switch notice {
        case .limitReached: text("WARN_NOTICE_LIMIT", bundle)
        case .geometryOutdated: text("WARN_NOTICE_GEOMETRY", bundle)
        case .offline: text("WARN_NOTICE_OFFLINE", bundle)
        case .rateLimited: text("WARN_NOTICE_RATE", bundle)
        case .notificationsDenied: text("WARN_NOTICE_DENIED", bundle)
        case .failed: text("WARN_NOTICE_FAILED", bundle)
        }
    }

    /// One sentence per row for VoiceOver.
    static func accessibilityLabel(_ row: Row, settings: WarnUserSettings, bundle: Bundle = .main) -> String {
        switch row {
        case .disclaimer: disclaimer(bundle: bundle)
        case .mainToggle: text("WARN_TOGGLE", bundle)
        case .typeToggle(let kind): kindTitle(kind, bundle: bundle)
        case .minLevel(let kind):
            String(format: text("WARN_MIN_LEVEL_SENTENCE", bundle), kindTitle(kind, bundle: bundle),
                   levelTitle(settings.level(for: kind), bundle: bundle))
        case .timeSensitive: text("WARN_TIME_SENSITIVE", bundle)
        case .timeSensitiveHint: timeSensitiveHint(bundle: bundle)
        }
    }
}
