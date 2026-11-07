import Foundation

/// Kept within P8's writable scope; German/English chosen like the existing push payload locale.
enum RainActivityText {
    case title, explanation, unavailable, privacy, limit, notEligible, retry, waitingForToken, full
    case regionExplanation, regionPrivacy

    func text(locale: String = Locale.preferredLanguages.first ?? "de") -> String {
        let german = locale.lowercased().hasPrefix("de")
        switch self {
        case .title: return german ? "Live Activity" : "Live Activity"
        case .explanation: return german
            ? "Zeigt bevorstehenden Regen auf dem Sperrbildschirm und in der Dynamic Island. Standardmäßig aus; höchstens eine Live Activity gleichzeitig. Du kannst sie auch in den Systemeinstellungen abschalten."
            : "Shows upcoming rain on the Lock Screen and in the Dynamic Island. Off by default; at most one Live Activity at a time. You can also disable it in system settings."
        case .unavailable: return german
            ? "Live Activities sind derzeit nicht verfügbar. Der Server muss sie unterstützen und sie müssen im System erlaubt sein."
            : "Live Activities are currently unavailable. The server must support them and they must be allowed in system settings."
        case .privacy: return german
            ? "Bei Aktivierung erhält der Server zusätzliche Gerätekennungen für Start und Aktualisierung, verknüpft mit diesem Ortsabo. Der Ortsname bleibt auf dem Gerät und kann auf dem Sperrbildschirm erscheinen. Kein Standortverlauf. Beim Abschalten werden laufende Activities beendet."
            : "When enabled, the server receives additional device identifiers for starting and updating activities, linked to this place subscription. The place name stays on the device and may appear on the Lock Screen. No location history. Turning this off ends running activities."
        case .regionExplanation: return german
            ? "Zeigt Regen im Umkreis auf dem Sperrbildschirm und in der Dynamic Island: wie viel Prozent der Fläche nass sind und die stärkste Stufe. Startet beim gleichen Auslöseanteil wie die Mitteilung. Standardmäßig aus; höchstens eine Live Activity gleichzeitig, ein Ort hat dabei Vorrang vor einem Umkreis."
            : "Shows rain in the area on the Lock Screen and in the Dynamic Island: the percentage of the area that is wet and the strongest level. Starts at the same trigger share as the notification. Off by default; at most one Live Activity at a time, and a place takes priority over an area."
        case .regionPrivacy: return german
            ? "Bei Aktivierung erhält der Server zusätzliche Gerätekennungen für Start und Aktualisierung, verknüpft mit diesem Umkreis-Abo. Der Name des Umkreises bleibt auf dem Gerät und kann auf dem Sperrbildschirm erscheinen. Keine zusätzlichen Standortdaten, kein Standortverlauf. Beim Abschalten werden laufende Activities beendet."
            : "When enabled, the server receives additional device identifiers for starting and updating activities, linked to this area subscription. The area name stays on the device and may appear on the Lock Screen. No additional location data, no location history. Turning this off ends running activities."
        case .limit: return german ? "Es kann nur eine Live Activity gleichzeitig laufen." : "Only one Live Activity can run at a time."
        case .notEligible: return german ? "Diese Live Activity ist abgelaufen oder für das Abo nicht mehr verfügbar." : "This Live Activity has expired or is no longer available for this subscription."
        case .waitingForToken: return german ? "Wird vorbereitet. Bitte warte einen Moment." : "Getting ready. Please wait a moment."
        case .full: return german ? "Zurzeit können keine weiteren Live Activities aktiviert werden. Bitte versuche es später erneut." : "Live Activities are temporarily unavailable. Please try turning this on again later."
        case .retry: return german ? "Die Live Activity konnte nicht synchronisiert werden. Beim nächsten Öffnen wird es erneut versucht." : "The Live Activity could not be synced. It will be retried when you next open the app."
        }
    }
}
