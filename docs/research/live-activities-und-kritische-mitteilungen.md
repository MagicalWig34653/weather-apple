# Live Activities und kritische Mitteilungen (Recherche für Radfahrer-Warnung)

Stand: 31. Oktober 2026. Reine Recherche, kein Produktcode, nichts bei Apple beantragt oder angelegt. Anlass: Radfahrer bemerken normale Meldungen („Regen beginnt in N Minuten“) nicht. Baut auf `push-benachrichtigungen.md` (Server-Push, Variante S) auf.

Kennzeichnung: **[P]** gegen Apple-Primärquelle gelesen am 31. Oktober 2026; **[A]** Annahme/Einschätzung; **[U]** ungeprüft.
Quellen (alle abgerufen 31. Oktober 2026), Basis `https://developer.apple.com/tutorials/data/documentation/`:
Q1 `bundleresources/entitlements/com.apple.developer.usernotifications.critical-alerts`; Q2 `usernotifications/generating-a-remote-notification`; Q3 `usernotifications/unnotificationinterruptionlevel` (+ `/timesensitive`, `/critical`); Q4 `usernotifications/unauthorizationoptions/criticalalert`; Q5 `activitykit/displaying-live-data-with-live-activities`; Q6 `activitykit/starting-and-updating-live-activities-with-activitykit-push-notifications`; Q7 `activitykit/activity/pushtostarttoken`; Q8 `https://developer.apple.com/app-store/review/guidelines/` (HTML).

## 1. Kritische Mitteilungen (Critical Alerts)

- [P, Q1] Entitlement `com.apple.developer.usernotifications.critical-alerts` (Boolean): erlaubt der App, `UNAuthorizationOptions.criticalAlert` anzufragen; Pushs spielen dann Ton auch bei gesperrtem Gerät, Stummschalter und Nicht-stören/Fokus; eigener Ton und eigene Lautstärke möglich. Das Entitlement ist per Antragsformular bei Apple zu beantragen (Q1 verweist auf `developer.apple.com/contact/request/notifications-critical-alerts-entitlement/`; Seite liefert HTTP 302, Inhalt/Kriterien nicht gelesen, vermutlich Anmeldung nötig [U]).
- [P, Q3/Q4] „requires an approved entitlement“; ohne Genehmigung kein critical.
- [P, Q2] Payload: `aps.interruption-level: "critical"` plus `aps.sound` als Dictionary `{ "critical": 1, "name": "default" | Datei, "volume": 0..1 }` (bei normalen Mitteilungen `sound` als String). Systemton wird genommen, wenn kein Ton gesetzt (Q3).
- [A] Nutzerberechtigung: eigener Systemdialog über `requestAuthorization([.alert,.sound,.criticalAlert])`; Nutzer kann in den iOS-Einstellungen je App „Kritische Hinweise“ abschalten. Genaue Dialogtexte [U].
- **Zulässigkeit für Regenhinweise: [A] unrealistisch.** Apples Formular richtet sich laut allgemeiner Kenntnis an Gesundheits-, Sicherheits-, Notfall- und Alarmanwendungen (Richtlinientext selbst nicht gelesen [U]); die Review Guidelines (Q8) nennen critical alerts nicht, 4.5.4 verlangt nur, dass Push nicht für Funktion erforderlich ist und nicht für Werbung ohne Opt-in dient. Ein Wetter-Komfort-Hinweis „Regen in 20 min“ ist kein Notfall; hohe Ablehnungswahrscheinlichkeit, und auch bei Zusage Risiko eines späteren Entzugs bei Missbrauch (Q8 4.5.4: „Abuse … may result in revocation“, [P] für Wortlaut). Nur ein offizieller Warnfall (z. B. Unwetterwarnung der Behörden) wäre denkbar, aber nicht der Produktkern und DWD-Warnungen unterliegen eigenen Lizenzfragen [U].
- Fazit: nicht als Basis planen; Antrag wäre kostenlos aber unsicher und verzögernd. Nutzerfrage „kann das Backend Critical auslösen?“: technisch ja (nur Payload-Felder, kein Backend-Mehraufwand), aber nur mit von Apple genehmigtem Entitlement an der App.

## 2. Time Sensitive

- [P, Q3] `interruption-level: "time-sensitive"` ist ein regulärer Wert (`passive`, `active`, `time-sensitive`, `critical`); durchbricht Benachrichtigungszusammenfassung und Fokus; Nutzer kann Zeitkritisch je App abschalten. Zeigt sofort an, aktiviert Display, kann Ton spielen (Q3). Umgeht den Stummschalter **nicht** (das tut nur critical).
- [P, Q2] `relevance-score` (0..1) steuert die Sortierung in der Zusammenfassung; hilft nur nachrangig.
- Entitlement/Capability: [U] Die Entitlement-Seite war unter dem vermuteten Pfad nicht abrufbar (404). [A] Üblich ist die Xcode-Capability „Time Sensitive Notifications“ (Entitlement `com.apple.developer.usernotifications.time-sensitive`), ohne Apple-Genehmigung; vor Umsetzung gegen Doku prüfen.
- Bewertung [A]: Pflicht-Baustein, billig (ein Payload-Feld, ein Schalter in Einstellungen „Zeitkritisch“), aber löst das Kernproblem (Radfahrer fühlt/hört nichts) nur teilweise: bei laufender Fahrt hilft Fokus-Durchbruch wenig, wenn Gerät in Tasche stumm ist.

## 3. Live Activities

- [P, Q5] ActivityKit, Darstellung auf Sperrbildschirm, Dynamic Island, CarPlay sowie gekoppeltem Mac und Apple Watch; Umsetzung im Widget-Extension-Target (neu oder bestehend), UI per SwiftUI/WidgetKit; Nutzer kann Live Activities je App abschalten (`ActivityAuthorizationInfo`). Updatedaten max. 4 KB (Q5).
- [P, Q5] Laufzeit: höchstens 8 Stunden aktiv, danach automatisch beendet und aus der Dynamic Island entfernt; auf dem Sperrbildschirm bleibt sie bis zu 4 weitere Stunden (oder bis Nutzer sie entfernt, bzw. `dismissalDate` in diesem Fenster).
- [P, Q5] Alert-Konfiguration: bei Update kann ein Alert auf iPhone, iPad und gekoppelter Apple Watch erzeugt werden (auf Watch werden `title`/`body` genutzt) – das ist der Hebel, der Radfahrer-Handgelenk-Haptik auslösen kann [A].
- [P, Q6] Remote-Update per APNs: Header `apns-push-type: liveactivity`, `apns-topic: <bundleID>.push-type.liveactivity`, `apns-priority` 5 oder 10; `aps` mit `timestamp`, `event` (update/end), `content-state`, optional `stale-date`, `dismissal-date`, `relevance-score`, `alert`. Priorität 10 zählt gegen ein vom System gesetztes Budget und kann gedrosselt werden; Priorität 5 zählt nicht und ist die empfohlene Grundeinstellung, Mischung 5/10 empfohlen. Budgethöhe nicht dokumentiert [U].
- [P, Q6/Q7] Tokens: pro Activity ein Push-Token (Update/Ende), vom Gerät an den Server zu melden und bei Änderung zu ersetzen; zusätzlich ein Push-to-Start-Token (`Activity.pushToStartToken` und Update-Sequenz), mit dem der Server eine neue Live Activity **starten** kann, ohne dass die App läuft. Er kommt unabhängig von einer laufenden Activity. Mindestversion „iOS 17.2“ stammt aus Erinnerung, in den gelesenen Texten nicht belegt [U]. Channels/Broadcast ab iOS 18 [P, Q6] sind für Einzelorte nicht nötig.
- Verfügbarkeit: iPhone/iPad [P] (Sperrbildschirm, iPhone mit Dynamic Island, sonst als Banner); Mac und Apple Watch als Spiegelung [P, Q5]; „Smart Stack“ als Wortlaut in Q5 nicht gefunden [U]; Apple-Watch-nativ (watchOS-App nötig?) [U]. Eigene Live Activity auf der Uhr ohne watchOS-App ist laut Q5 über Spiegelung möglich; Details [U].
- Review: Q8 enthält keine eigene Live-Activity-Regel; [A] allgemein 4.5.4 (Push nicht funktionsnotwendig) und 2.5.4 (Hintergrunddienste nur bestimmungsgemäß). Live Activity nur für laufende, zeitlich begrenzte Ereignisse vorgesehen; „Regen in den nächsten 60 Minuten am Ort“ ist als ereignisbezogenes Fenster vertretbar, Dauer-Anzeige über Tage nicht [A].
- **Wann könnten Live Activities kommen?** Nicht vor einer Entscheidung über Server-Push (P0–P10 aus dem Push-Entwurf), denn Push-to-Start und Updates brauchen APNs-Key, Token-Tabellen und Datenschutzanpassung. App-seitig (lokal gestartet, aktualisiert beim Öffnen) wäre eine Live Activity früher möglich, wäre aber ohne Push nach der App-Sperre veraltet [A].

## 4. Weitere Hebel für Radfahrer

- Apple-Watch-Haptik: [A] Mitteilungen werden auf die Uhr gespiegelt, wenn iPhone gesperrt ist; die Uhr gibt Haptik. Haptik ist nicht per Payload steuerbar; Nutzer muss Watch-Spiegelung und „Haptische Stärke“ setzen [U]. Das ist für Radfahrer der wirksamste Kanal und kostet keinen Code, nur Hinweis in der App („Mitteilungen auf Apple Watch aktivieren“).
- Ton: [P, Q2] eigener Tonname (nicht critical) möglich, in der App gebündelt, Länge maximal ~30 s [U]; lauter/auffälliger Ton hilft nur bei nicht stumm geschaltetem Gerät.
- Zeitpunkt: größere Vorlaufzeit (20–30 min statt 10) und zweite Erinnerung kurz vor Beginn [A]; Radfahrer sehen/hören unterwegs seltener, Warnung deshalb vor dem Losfahren (Pendelzeiten) sinnvoller als unterwegs; konfigurierbare Zeitfenster in der Regel (`quiet_from/quiet_to` im Entwurf, umgekehrt als „Pendelfenster“ nutzbar) [A].
- Fokusfilter: [A] Nutzer kann die App im Fokus „Radfahren“/„Fahren“ als erlaubte App eintragen, dann kommen Mitteilungen ohne Time-Sensitive durch; Hinweis in der App-Hilfe statt Code. Fokusfilter-API (App Intents) ist optional [U].
- CarPlay/Navigation: Live Activities erscheinen laut Q5 in CarPlay, für Fahrrad nicht relevant [A].

## 5. Auswirkungen und Aufwand

Backend: Time Sensitive/Critical: nur Payload-Feld, gleiches Gerätetoken (kein neues Schema); Opt-in-Level je Sub ein Feld `urgency` (Enum). Live Activity: zusätzliche Spalten/Tabelle `push_activity(install_id, push_to_start_token, activity_token, activity_id, started_at, ends_at)`, zweiter Sendeweg (Topic `.push-type.liveactivity`, Priorität 5/10, `event`/`content-state`), Zustandsautomat „Aktivität starten/aktualisieren/beenden“, hartes Ende ≤ 8 h, Löschung bei 410. Datenschutz: zusätzliche Token sind Gerätekennungen mit Ortsbezug (wie Push-Token), in Datenschutztext und App-Privacy (Device ID, Zweck App-Funktionalität, nicht für Tracking) ergänzen [A]; keine neuen Standortdaten, wenn nur gespeicherte Zelle genutzt wird.
App: Time Sensitive: Capability, Berechtigungsfluss, Einstellungs-Schalter. Critical: Entitlement-Antrag bei Apple, danach Capability, `.criticalAlert` in der Berechtigungsanfrage. Live Activity: Widget-Extension-Target, `NSSupportsLiveActivities` in Info.plist [U, aus Erinnerung], `ActivityAttributes`/`ContentState`, UI für Lock Screen, Dynamic Island (kompakt/minimal/erweitert) und ggf. Watch-Darstellung, Token-Übermittlung. Signing nur beschreiben: Extension braucht eigene App-ID und Profil, App-Group optional; nichts angelegt.

| Paket | Inhalt | Aufwand [A] |
|---|---|---|
| L0 | Hinweistexte in der App: Watch-Spiegelung, Fokus „Radfahren“, Ton | klein |
| L1 | Time Sensitive (Payload, Schalter, Capability) | klein, nach Push-Grundlage P8 |
| L2 | Pendelfenster-/Vorlaufoptionen, zweite Erinnerung | klein bis mittel, Backend-Regeln |
| L3 | Live Activity lokal starten/aktualisieren (ohne Push) | mittel, Extension, nur begrenzt nützlich |
| L4 | Live Activity per Push-to-Start und Update (Tokens, Sender, Automat) | groß, setzt P1–P6 voraus |
| L5 | Critical-Alerts-Antrag | gering im Aufwand, hohes Ablehnungsrisiko; nur mit Nutzerentscheidung |

## 6. Empfehlung

1. Zuerst Server-Push wie im Push-Entwurf (Voraussetzung für alles Weitere).
2. L0 + L1 sofort danach: Time Sensitive ab Werk, optional abschaltbar, plus Hilfe zu Apple-Watch-Haptik und Fokus.
3. L2 (Vorlauf 20–30 min, Pendelfenster).
4. L4 nur, wenn Radfahrer-Feedback zeigt, dass L1 nicht reicht; L3 überspringen.
5. L5 nicht beantragen, solange Regenhinweise Komfortfunktion sind.

## 7. Nicht geprüft

Antragskriterien/-seite der Critical-Alerts-Entitlement (302, nicht gelesen); Time-Sensitive-Entitlement-Seite (404); Mindestversionen (iOS 17.2/18); Budgethöhe für Priorität 10; Smart-Stack-Verhalten und watchOS-native Live Activities; Nutzerdialogtexte; Watch-Haptik-Einstellungen; Fokusfilter-API; keine Gerätetests.
