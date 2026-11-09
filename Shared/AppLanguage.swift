import Foundation

/// The single place that decides which language the app speaks.
///
/// Source of truth is `Bundle.main.preferredLocalizations.first`: the system language (or the per-app language
/// from iOS Settings) resolved against the bundle's `de`/`en` localizations. Anything that is not German falls back
/// to English (E2, `CFBundleDevelopmentRegion = en`). The same code is reported to the server (`PushManager`,
/// `Accept-Language` of the warning feed) and used for texts that are chosen in code, so what the user reads and
/// what the server is told cannot diverge. The server accepts only `de` and `en`.
enum AppLanguage {
    static let supported = ["de", "en"]

    /// `"de"` or `"en"` for the running bundle.
    static var code: String { code(preferredLocalizations: Bundle.main.preferredLocalizations) }

    static func code(preferredLocalizations: [String]) -> String {
        guard let first = preferredLocalizations.first?.lowercased() else { return "en" }
        return first.hasPrefix("de") ? "de" : "en"
    }

    /// Locale matching `code`, for formatters that must follow the app language (not the region format).
    static var locale: Locale { Locale(identifier: code) }

    static var isGerman: Bool { code == "de" }
}
