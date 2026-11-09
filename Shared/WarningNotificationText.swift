import Foundation

/// Own short text for official-warning pushes. The server sends the DWD headline and description plus "Quelle: DWD".
/// Because the legal research (docs/research/dwd-warnungen-weitergabe.md) is unresolved on whether shortened DWD text counts
/// as a modification, the extension replaces it with a short own notice (type, level, "tap for details"), without a DWD
/// source note and without the title "official warning". The place name goes into the subtitle. The full unchanged DWD
/// warning with source note is shown in the warning view of the app.
enum WarningNotificationText {
    static let kinds = ["severe_weather": "WARN_PUSH_TITLE_SEVERE", "frost": "WARN_PUSH_TITLE_FROST", "ice": "WARN_PUSH_TITLE_ICE"]
    static let bodyKey = "WARN_PUSH_BODY"

    /// Kind and level from the top-level payload fields; nil if either is unusable (the original text then stays).
    static func parse(userInfo: [AnyHashable: Any]) -> (kind: String, severity: Int)? {
        guard (userInfo["type"] as? String) == "warning",
              let kind = userInfo["kind"] as? String, kinds[kind] != nil else { return nil }
        let raw = userInfo["severity"]
        let level = (raw as? Int) ?? (raw as? NSNumber)?.intValue ?? (raw as? String).flatMap(Int.init)
        guard let level, (1...4).contains(level) else { return nil }
        return (kind, level)
    }

    /// Title such as "Frosthinweis, Stufe 1"; nil if the text cannot be resolved.
    /// The format uses `%@` (not `%d`): the server sends the level as a string in `title-loc-args`, so the system
    /// localization (without this extension) and the extension produce the same text.
    static func title(kind: String, severity: Int, localized: (String) -> String?) -> String? {
        guard let key = kinds[kind], let format = localized(key), format != key else { return nil }
        return String(format: format, String(severity))
    }

    static func body(localized: (String) -> String?) -> String? {
        guard let text = localized(bodyKey), text != bodyKey else { return nil }
        return text
    }

    /// Place name for the subtitle; nil/empty -> nil.
    static func subtitle(name: String?) -> String? { NotificationNameStore.clean(name) }
}
