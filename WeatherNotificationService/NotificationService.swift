import UserNotifications

/// Appends the locally stored place or area name to the rain alert. The server sends no name; if there is no entry,
/// an error or a timeout, the text stays unchanged. Warning pushes (type=warning) get an own short text, see WarningNotificationText.
final class NotificationService: UNNotificationServiceExtension {
    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttempt: UNMutableNotificationContent?

    override func didReceive(_ request: UNNotificationRequest,
                             withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        bestAttempt = request.content.mutableCopy() as? UNMutableNotificationContent
        guard let content = bestAttempt else { return contentHandler(request.content) }
        let defaults = UserDefaults(suiteName: "group.de.linolaske.showernow")
        let hostBundle = Bundle(url: Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent())
        if let warning = WarningNotificationText.parse(userInfo: content.userInfo) {
            applyWarning(warning, to: content, defaults: defaults, hostBundle: hostBundle)
            return deliver(content)
        }
        if let name = NotificationNameStore.name(for: content.threadIdentifier, in: defaults) {
            let alert = (content.userInfo["aps"] as? [String: Any])?["alert"] as? [String: Any]
            let key = alert?["loc-key"] as? String
            let args = (alert?["loc-args"] as? [Any])?.map { "\($0)" } ?? []
            content.body = NotificationNameStore.body(original: content.body, locKey: key, locArgs: args, name: name) { key in
                hostBundle?.localizedString(forKey: key, value: nil, table: nil)
            }
        }
        deliver(content)
    }

    /// Warning push: own short text and the place name as subtitle. Interruption level and sound stay as the payload sent them.
    /// If the strings are unavailable, title and body stay as sent.
    private func applyWarning(_ warning: (kind: String, severity: Int), to content: UNMutableNotificationContent,
                              defaults: UserDefaults?, hostBundle: Bundle?) {
        let localized: (String) -> String? = { hostBundle?.localizedString(forKey: $0, value: nil, table: nil) }
        guard let title = WarningNotificationText.title(kind: warning.kind, severity: warning.severity, localized: localized),
              let body = WarningNotificationText.body(localized: localized) else { return }
        content.title = title
        content.body = body
        if let subtitle = WarningNotificationText.subtitle(name: NotificationNameStore.name(for: content.threadIdentifier, in: defaults)) {
            content.subtitle = subtitle
        }
    }

    override func serviceExtensionTimeWillExpire() {
        if let bestAttempt { deliver(bestAttempt) }
    }

    private func deliver(_ content: UNNotificationContent) {
        guard let handler = contentHandler else { return }
        contentHandler = nil
        handler(content)
    }
}
