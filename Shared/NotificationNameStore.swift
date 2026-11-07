import Foundation

/// Names of push subscriptions for the Notification Service Extension. The app writes them into the App Group
/// (subscription ID to name); they stay on the device and are never sent to the server.
enum NotificationNameStore {
    static let defaultsKey = "notification.names.v1"
    static let separator = " \u{00B7} "
    static let maxNameLength = 40

    static func write(_ names: [String: String], to defaults: UserDefaults?) {
        defaults?.set(names, forKey: defaultsKey)
    }

    static func name(for subscriptionID: String, in defaults: UserDefaults?) -> String? {
        guard let value = defaults?.dictionary(forKey: defaultsKey)?[subscriptionID] as? String else { return nil }
        return clean(value)
    }

    /// Trimmed, single-line, shortened name; nil if empty.
    static func clean(_ name: String?) -> String? {
        guard let name else { return nil }
        let single = name.components(separatedBy: .newlines).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !single.isEmpty else { return nil }
        return single.count > maxNameLength ? String(single.prefix(maxNameLength - 1)) + "\u{2026}" : single
    }

    /// Name per subscription ID. Places (by place ID) and regions (own name, may be missing).
    static func mapping(placeSubscriptions: [UUID: String], placeNames: [UUID: String],
                        regionSubscriptions: [String: String?]) -> [String: String] {
        var map: [String: String] = [:]
        for (placeID, sub) in placeSubscriptions { if let name = clean(placeNames[placeID]) { map[sub] = name } }
        for (sub, name) in regionSubscriptions { if let name = clean(name) { map[sub] = name } }
        return map
    }

    /// New body text: the original text with " · Name" appended. Without a name or text it stays unchanged.
    /// If the system did not localize the alert (empty body), `localized` resolves the loc-key text.
    static func body(original: String, locKey: String?, locArgs: [String], name: String?,
                     localized: (String) -> String?) -> String {
        guard let name = clean(name) else { return original }
        var text = original
        if text.isEmpty, let locKey, let format = localized(locKey), format != locKey {
            text = locArgs.reduce(format) { current, arg in
                guard let range = current.range(of: "%@") else { return current }
                return current.replacingCharacters(in: range, with: arg)
            }
        }
        guard !text.isEmpty else { return original }
        return text + separator + name
    }
}
