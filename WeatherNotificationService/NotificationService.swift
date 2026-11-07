import UserNotifications

/// Appends the locally stored place or area name to the rain alert. The server sends no name; if there is no entry,
/// an error or a timeout, the text stays unchanged.
final class NotificationService: UNNotificationServiceExtension {
    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttempt: UNMutableNotificationContent?

    override func didReceive(_ request: UNNotificationRequest,
                             withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        bestAttempt = request.content.mutableCopy() as? UNMutableNotificationContent
        guard let content = bestAttempt else { return contentHandler(request.content) }
        let defaults = UserDefaults(suiteName: "group.de.linolaske.showernow")
        if let name = NotificationNameStore.name(for: content.threadIdentifier, in: defaults) {
            let alert = (content.userInfo["aps"] as? [String: Any])?["alert"] as? [String: Any]
            let key = alert?["loc-key"] as? String
            let args = (alert?["loc-args"] as? [Any])?.map { "\($0)" } ?? []
            let hostBundle = Bundle(url: Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent())
            content.body = NotificationNameStore.body(original: content.body, locKey: key, locArgs: args, name: name) { key in
                hostBundle?.localizedString(forKey: key, value: nil, table: nil)
            }
        }
        deliver(content)
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
