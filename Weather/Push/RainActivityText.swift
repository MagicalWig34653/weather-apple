import Foundation

/// Texts of the rain Live Activity settings and messages. German or English follows `locale` (default: app language);
/// the strings live in `Localizable.strings` (`RAIN_ACTIVITY_*`).
enum RainActivityText {
    case title, explanation, unavailable, privacy, limit, notEligible, retry, waitingForToken, full
    case regionExplanation, regionPrivacy

    /// Bundle of the requested language (falls back to the main bundle), so tests can check both languages.
    private static func bundle(for locale: String) -> Bundle {
        let code = locale.lowercased().hasPrefix("de") ? "de" : "en"
        if let path = Bundle.main.path(forResource: code, ofType: "lproj"), let bundle = Bundle(path: path) { return bundle }
        return .main
    }

    func text(locale: String = AppLanguage.code) -> String {
        let b = Self.bundle(for: locale)
        switch self {
        case .title: return NSLocalizedString("RAIN_ACTIVITY_TITLE", bundle: b, value: "Live Activity", comment: "Live Activity")
        case .explanation: return NSLocalizedString("RAIN_ACTIVITY_EXPLANATION", bundle: b, value: "Zeigt bevorstehenden Regen auf dem Sperrbildschirm und in der Dynamic Island. Standardmäßig aus; höchstens eine Live Activity gleichzeitig. Du kannst sie auch in den Systemeinstellungen abschalten.", comment: "Live Activity")
        case .unavailable: return NSLocalizedString("RAIN_ACTIVITY_UNAVAILABLE", bundle: b, value: "Live Activities sind derzeit nicht verfügbar. Der Server muss sie unterstützen und sie müssen im System erlaubt sein.", comment: "Live Activity")
        case .privacy: return NSLocalizedString("RAIN_ACTIVITY_PRIVACY", bundle: b, value: "Bei Aktivierung erhält der Server zusätzliche Gerätekennungen für Start und Aktualisierung, verknüpft mit diesem Ortsabo. Der Ortsname bleibt auf dem Gerät und kann auf dem Sperrbildschirm erscheinen. Kein Standortverlauf. Beim Abschalten werden laufende Activities beendet.", comment: "Live Activity")
        case .regionExplanation: return NSLocalizedString("RAIN_ACTIVITY_REGION_EXPLANATION", bundle: b, value: "Zeigt Regen im Umkreis auf dem Sperrbildschirm und in der Dynamic Island: wie viel Prozent der Fläche nass sind und die stärkste Stufe. Startet beim gleichen Auslöseanteil wie die Mitteilung. Standardmäßig aus; höchstens eine Live Activity gleichzeitig, ein Ort hat dabei Vorrang vor einem Umkreis.", comment: "Live Activity")
        case .regionPrivacy: return NSLocalizedString("RAIN_ACTIVITY_REGION_PRIVACY", bundle: b, value: "Bei Aktivierung erhält der Server zusätzliche Gerätekennungen für Start und Aktualisierung, verknüpft mit diesem Umkreis-Abo. Der Name des Umkreises bleibt auf dem Gerät und kann auf dem Sperrbildschirm erscheinen. Keine zusätzlichen Standortdaten, kein Standortverlauf. Beim Abschalten werden laufende Activities beendet.", comment: "Live Activity")
        case .limit: return NSLocalizedString("RAIN_ACTIVITY_LIMIT", bundle: b, value: "Es kann nur eine Live Activity gleichzeitig laufen.", comment: "Live Activity")
        case .notEligible: return NSLocalizedString("RAIN_ACTIVITY_NOT_ELIGIBLE", bundle: b, value: "Diese Live Activity ist abgelaufen oder für das Abo nicht mehr verfügbar.", comment: "Live Activity")
        case .waitingForToken: return NSLocalizedString("RAIN_ACTIVITY_WAITING", bundle: b, value: "Wird vorbereitet. Bitte warte einen Moment.", comment: "Live Activity")
        case .full: return NSLocalizedString("RAIN_ACTIVITY_FULL", bundle: b, value: "Zurzeit können keine weiteren Live Activities aktiviert werden. Bitte versuche es später erneut.", comment: "Live Activity")
        case .retry: return NSLocalizedString("RAIN_ACTIVITY_RETRY", bundle: b, value: "Die Live Activity konnte nicht synchronisiert werden. Beim nächsten Öffnen wird es erneut versucht.", comment: "Live Activity")
        }
    }
}
