# Datenschutz-Entwurf für das Release (Seitentext und App-Privacy, Variante B)

**Stand 10.11.2026: Teil A (DE) ist final und gekürzt (siehe dort); es gibt keine englische Datenschutzseite, Teil A-EN ist nicht veröffentlicht; Klammern und Hinweise im Text sind entfernt, die Teile C bis G sind Arbeitsnotizen und gehören nicht auf die Seite.** Stand 7. November 2026 (Nutzerentscheidungen eingearbeitet; zweite Runde: Hosting Hetzner, Dashboard-Einsicht, Auskunft über die Installationskennung; danach technisch-redaktionelle Plausibilitätsprüfung gegen den Code, Korrekturen im Text mit `[R1]` bis `[R9]` markiert und in Teil F erklärt, Fragen für die externe Rechtsprüfung in Teil G). **ENTWURF zur Freigabe durch den Nutzer, NICHT live.** Weder `/datenschutz` im Backend noch `docs-site/content/datenschutz.md` noch App Store Connect wurden geändert. Dies ist keine Rechtsberatung; Rechtsgrundlagen, Impressum und Einordnung sind Vorschläge und vor Livegang rechtlich zu prüfen. Aussagen sind aus dem Code und den Repo-Dokumenten belegt; Unbekanntes steht in Teil C als Nutzerfrage und im Seitentext als `[ ... ]`.

Quellen (gelesen am 7.11.2026): Live-Seitenquelle `Sources/RadarCore/SitePages.swift` (Schwesterrepo, Methode `privacy`), Schwesterrepo `migrations/003, 006, 007, 010, 015`, `docs-site/content/api.md` (Push, Testmeldung, Live Activity, Kopplung, Warnungen), `PushService.swift` (Aufbewahrung), `PushMeasure.swift` (Dashboard), `docs/datenschutz-gebiets-live-activity.md`, `docs/decisions.md` beider Repos, `docs/app-store-release-checkliste.md`, `docs/superpowers/specs/2026-11-07-warnungen-design.md`, `docs/research/dwd-warnungen-weitergabe.md`, App-Code `Weather/Push/PushGateway.swift`, `Shared/Data/DWDClient.swift`.

## Entscheidungen des Nutzers (7.11.2026, verbindlich, hier eingearbeitet)

1. **Warnungen** (Unwetter, Frost, Glatteis) stehen **nicht** im Release-Text; der Baustein in Teil E bleibt als vorbereiteter Zusatz für den späteren Livegang. Die Anzeige der Warnungen in der App ruft die Aktivwarnungen ohne Ortsangabe ab (Spec §5), braucht also keinen neuen Abschnitt, nur die Quellenangabe (Abschnitt 14).
2. **Zweisprachig:** vollständige deutsche (Teil A) und englische Fassung (Teil A-EN) mit gleicher Struktur; Name nach außen immer „Showers“.
3. **Reverse Proxy (Zoraxy) protokolliert mit IP-Adresse.** Rotation nach Größe: höchstens 64 MB je Datei, 16 Dateien. Laut Nutzer entsteht im Schnitt alle 2 bis 4 Wochen eine neue Datei (Schätzung, mehrere Dienste auf dem Proxy). Rechnerisch ergibt das ca. 7 bis 14 Monate Aufbewahrung (16 Dateien x 2 bis 4 Wochen), abhängig vom Verkehr; deshalb im Text ehrlich „bis zu rund 14 Monate, größenbasierte Rotation“. Zweck: Betrieb, Fehlersuche, Missbrauchsabwehr; Rechtsgrundlage Art. 6 Abs. 1 lit. f DSGVO (Vorschlag, nicht rechtlich geprüft). **Empfehlung (Nutzeraktion):** die Frist am Proxy auf eine zeitbasierte Löschung nach 14 bis 30 Tagen kürzen; danach Abschnitt 3 (de und en) anpassen.
4. **App Privacy:** Orts-Zelle (~0,7 km) als „Precise Location“, Gebiete (~2 km gerundet) als „Coarse Location“; Gerätekennung wie bisher; verknüpft, kein Tracking, Zweck App-Funktionalität (Teil B).
5. **Speicherfristen unverändert:** 60 Tage Inaktivität, Warteschlange 6 Stunden, Diagnose-Verlauf 48 Stunden, Zähler 30 Tage / 72 Stunden.
6. **Verantwortlicher:** Der Nutzer trägt `OPERATOR_NAME`, `OPERATOR_ADDRESS`, `OPERATOR_EMAIL` selbst im Betrieb ein; der Text enthält nur Platzhalter, keine erfundenen Angaben.
7. **Domains:** showers.linolaske.de und showernow.linolaske.de laufen parallel (keine Weiterleitung); sichtbar nach außen nur showers.linolaske.de.
8. **Hosting:** eigener virtueller Server (vServer) bei Hetzner in Deutschland; Hetzner ist Hosting-Anbieter und Auftragsverarbeiter. Vertrag zur Auftragsverarbeitung (Art. 28 DSGVO) schließt der Nutzer selbst ab. Backup-Rhythmus bleibt offene Nutzerangabe (nicht geraten). Eingearbeitet in neuen Abschnitt 15.
9. **Dashboard-Einsicht** wird offen benannt: Für ein gekoppeltes Gerät sieht der Betreiber die auf etwa 1 km gerundete Position, nur bei Kopplung (Abschnitte 2 und 11).
10. **Auskunft:** Die App soll die Installationskennung in den Einstellungen anzeigen und kopierbar machen; Text in Abschnitt 13 entsprechend. **App-Änderung folgt nach Build 34** (bis dahin ist der Satz in der App nicht erfüllt, also nicht vorher live schalten).

Weiterhin Empfehlung: **Rechtsgrundlage Push** ist Einwilligung, Art. 6 Abs. 1 lit. a DSGVO (Opt-in, jederzeit widerrufbar); Vorschlag, Betreiber entscheidet (Teil C). **App Privacy:** Variante A („Data Not Collected“) entfällt, sobald Push live ist; Variante B in Teil B.

---

## Benennung und Domain (Nutzervorgabe 7.11.2026)

Nach außen heißt die App immer **„Showers“**, nie „ShowerNow“. „ShowerNow“ bleibt intern (Bundle-ID `de.linolaske.showernow`, App-Group, Repo, Code). Sichtbare URLs verwenden **showers.linolaske.de** (zeigt auf dieselbe Instanz wie showernow.linolaske.de). Beide Hosts laufen parallel, ohne Weiterleitung (Entscheidung 7.11.); sichtbar nach außen ist nur showers.linolaske.de. Der Seitentext in Teil A/A-EN und die App-Privacy-Angaben in Teil B nennen daher nur „Showers“; Datenschutz-URL in App Store Connect: `https://showers.linolaske.de/datenschutz`. Im Entwurf kommt ausdrücklich kein „ShowerNow“ vor.

---

## Teil A: Seitentext, deutsch (final, gekürzt; entspricht `/datenschutz` im Backend)

**Textstand final laut Nutzerentscheidung 10.11.2026:** gekürzt auf die Angaben nach Art. 13 DSGVO, Klammern, Platzhalter und Entwurfshinweise entfernt, keine Aussage zu Backups, Aufsichtsbehörde allgemein. Dieselbe Fassung gilt für die Webseite (Backend `SitePages.swift`) und den App-Info-Text. Der Absatz „Amtliche Warnungen“ (Teil E) erscheint auf der Webseite nur mit `PUSH_ENABLED` und `WARN_PUSH_ENABLED`. Die ausführlichere frühere Fassung steht in der Git-Historie dieser Datei (Stand 8.11.2026).

> # Datenschutzerklärung
> Für die App Showers (iPhone, iPad, Apple Watch) und den zugehörigen Radar-Dienst. Stand: 10. November 2026.
>
> ## 1. Verantwortlicher
> Name, Anschrift und E-Mail des Verantwortlichen (auf der Webseite aus der Betreiberkonfiguration `OPERATOR_NAME`, `OPERATOR_ADDRESS`, `OPERATOR_EMAIL`; im App-Info-Text dieselben Angaben).
>
> ## 2. Überblick
> Kein Benutzerkonto, kein Tracking, keine Werbung, keine Analyse-Dienste. Gespeicherte Orte, ihre Namen und deine Einstellungen bleiben auf deinem Gerät. Die Nutzung ist freiwillig: Du musst keine Daten bereitstellen; ohne Regenhinweise registriert sich die App nicht auf dem Server. Eine automatisierte Entscheidungsfindung im Sinne von Art. 22 DSGVO findet nicht statt.
>
> ## 3. Radar-Abruf und Server-Protokolle
> Die App lädt Radarbilder und weitere Karten (Luftdruck, Blitze, Wolken, Sonne, Temperatur, Feuchte) für ganz Deutschland vom Showers-Radar-Dienst. Die Anfragen enthalten keinen Ort, keine Cookies und keine Kennung. Der Radar-Dienst selbst führt keine Zugriffsprotokolle und speichert keine IP-Adressen; er zählt nur aggregierte, personenlose Werte für den Betrieb (Anfragen je Routengruppe, Fehlerzähler, 30 Tage beziehungsweise 72 Stunden).
> Dem Radar-Dienst ist ein Reverse Proxy vorgeschaltet. Technisch bedingt sieht er die IP-Adresse jedes Abrufs und protokolliert sie befristet. Zweck sind Betrieb, Fehlersuche und Abwehr von Missbrauch; Rechtsgrundlage ist unser berechtigtes Interesse (Art. 6 Abs. 1 lit. f DSGVO).
>
> ## 4. Orte, Standort, Prognose und Karten
> Der Standortzugriff ist optional und wird erst angefragt, wenn du ihn nutzen willst; es gibt keine Hintergrundortung und keine Standortverläufe. Gespeicherte Orte und ihre Namen liegen nur lokal auf deinem Gerät (auch für Widgets und Apple Watch). Die kurze Einordnung der Regenlage erstellt Apple Foundation Models auf dem Gerät.
> Die Punktprognose für einen Ort, auch für Widgets und Apple Watch, ruft die App direkt beim Deutschen Wetterdienst (DWD) ab. Der Radar-Dienst erhält diese Orte nicht. Antwortet der Radar-Dienst nicht oder sind seine Daten älter als 20 Minuten, lädt die App die Radarbilder ebenfalls direkt beim DWD; die Legendenbilder einiger Karten lädt sie direkt beim DWD beziehungsweise bei EUMETSAT. Diese Stellen sehen dabei den angefragten Punkt oder Kartenausschnitt und, wie bei jeder Internetverbindung, deine IP-Adresse; es gelten ihre eigenen Datenschutzhinweise.
> Karte und Ortssuche nutzen Apple MapKit: Dein Gerät ruft Kartendaten von Apple ab, bei der Suche gehen Suchtext und ein fester Suchbereich (Deutschland, nicht dein Standort) an Apple, auf der Apple Watch für den Kartenhintergrund die Koordinate des Ortes. Apple sieht dabei deine IP-Adresse; es gelten die Datenschutzbestimmungen von Apple. Suchtext und Karte gehen nicht an den Radar-Dienst.
>
> ## 5. Regenhinweise und Live Activities (optional)
> Wenn du Regenhinweise für einen Ort oder ein Gebiet einschaltest, kann dich der Radar-Dienst auch bei geschlossener App benachrichtigen. Zweck ist die Zustellung dieser Hinweise; Rechtsgrundlage ist deine Einwilligung (Art. 6 Abs. 1 lit. a DSGVO), die du mit dem Einschalten erteilst und durch Ausschalten oder Löschen jederzeit mit Wirkung für die Zukunft widerrufen kannst. Ohne diese Funktion wird nichts davon gespeichert.
> **Gespeichert werden** auf dem Server: eine zufällige Installationskennung und der Hash eines Geheimnisses (das Geheimnis selbst liegt nur im Schlüsselbund deines Geräts); das Gerätetoken für Apple Push-Mitteilungen, die Umgebung (Entwicklung oder Produktion) und die Sprache; je Regenhinweis bei einem Ort die Rasterzelle des Radarbildes (Kantenlänge etwa 0,7 km, keine Koordinate, kein Ortsname), bei einem Gebiet der auf etwa 2 km gerundete Mittelpunkt und der Radius, dazu Schwelle, Vorlauf, Einstellungen, Zustand der Auswertung und Zeitpunkte; bei Live Activities Start- und Activity-Token; kurzzeitig der zu sendende Mitteilungstext in einer Warteschlange. Es sind bis zu 10 Regenhinweise je Installation möglich, davon bis zu 3 Gebiete. Die Rasterzelle kann zusammen mit der Installationskennung einem Gerät zugeordnet und damit personenbezogen sein; ein Standortverlauf entsteht nicht. Ortsnamen kennt der Server nicht: Eine Erweiterung der App ergänzt sie auf dem Gerät.
> **Testmeldung.** In den Einstellungen kannst du eine Testmeldung mit festem Text auslösen (höchstens 3 je Stunde); sie wird nicht gespeichert.
> **Apple.** Mitteilungen und Live Activities werden über den Apple Push Notification Service zugestellt. Apple erhält dafür vom Server das Gerätetoken, den Inhalt der Mitteilung und technische Kennungen zum Zusammenfassen von Mitteilungen. Dabei können Daten an Server von Apple außerhalb der EU, insbesondere in den USA, übermittelt werden. Es gelten die Datenschutzbestimmungen von Apple.
> **Speicherdauer.** Löschst du einen Regenhinweis oder schaltest die Funktion aus, löscht die App die Registrierung auf dem Server; damit werden Installation, Regenhinweise, Activity-Daten und wartende Mitteilungen gelöscht. Meldet Apple ein Gerätetoken als ungültig (zum Beispiel nach Löschen der App), löscht der Server die Registrierung sofort. Registrierungen, die 60 Tage lang nicht mehr von der App gemeldet wurden, werden automatisch gelöscht. Mitteilungen in der Warteschlange werden nach etwa 6 Stunden entfernt.
>
> ## 6. Betreiber-Diagnose (freiwillig)
> Der Betreiber kann ein Gerät zur Fehlersuche bei Regenhinweisen und Live Activities koppeln. Das ist standardmäßig aus, nur in den Einstellungen der App einschaltbar und nur möglich, solange der Betreiber im Dashboard kurzzeitig ein Kopplungsfenster geöffnet hat. Dabei zeigt die App einen kurzen Koppelcode (10 Minuten gültig, einmal verwendbar), den der Betreiber nach Anmeldung mit seinem Passkey im Dashboard eingibt. Gespeichert werden die Zuordnung zur Push-Registrierung, eine vom Betreiber vergebene Bezeichnung, Zeitpunkte und ein Verlauf technischer Versandergebnisse der letzten 48 Stunden. Nur für ein gekoppeltes Gerät sieht der Betreiber dessen Regenhinweise mit der auf etwa 1 km gerundeten Position und der aktuellen Auswertung; er kann diesem Gerät Test-Mitteilungen und eine Test-Live-Activity senden. Höchstens drei Geräte können gleichzeitig gekoppelt sein. Im Betreiberprotokoll werden Kopplung, Entkopplung und Aktionen ohne Installationskennung, Token oder Ort mit einem kurzen Prüfwert 365 Tage aufbewahrt. Die Kopplung gilt bis zum Widerruf, längstens bis die Push-Registrierung gelöscht wird; du kannst sie jederzeit in der App ausschalten, dabei wird sie auf dem Server gelöscht. Rechtsgrundlage ist deine Einwilligung (Art. 6 Abs. 1 lit. a DSGVO).
>
> ## 7. Empfänger, Hosting und Drittländer
> Der Radar-Dienst und seine Datenbank laufen auf einem eigenen virtuellen Server bei der Hetzner Online GmbH in einem Rechenzentrum in Deutschland. Hetzner verarbeitet die dort gespeicherten Daten als Auftragsverarbeiter nach Art. 28 DSGVO nur nach unseren Weisungen. Empfänger der Push-Daten ist Apple (Abschnitt 5). Direkt von deinem Gerät, ohne Beteiligung des Betreibers, gehen Anfragen an den DWD, an EUMETSAT und an Apple (Abschnitt 4); diese Stellen verarbeiten die Daten in eigener Verantwortung. Darüber hinaus geben wir keine Daten weiter und verkaufen keine Daten. Eine Übermittlung in Drittländer kann nur über Apple erfolgen (Abschnitt 5).
>
> ## 8. Deine Rechte
> Dir stehen nach der Datenschutz-Grundverordnung (DSGVO) die Rechte auf Auskunft, Berichtigung, Löschung, Einschränkung der Verarbeitung, Datenübertragbarkeit und Widerspruch zu (Art. 15 bis 21 DSGVO) sowie das Recht, eine erteilte Einwilligung jederzeit mit Wirkung für die Zukunft zu widerrufen. Soweit wir Daten auf Grundlage berechtigter Interessen verarbeiten (Protokolle des Reverse Proxys, Abschnitt 3), kannst du aus Gründen, die sich aus deiner besonderen Situation ergeben, jederzeit widersprechen (Art. 21 DSGVO). Zudem kannst du dich bei einer Datenschutz-Aufsichtsbehörde beschweren, insbesondere in dem Mitgliedstaat deines Aufenthaltsorts.
> Am einfachsten löschst du deine Daten auf dem Server selbst: Schalte alle Regenhinweise in der App aus oder lösche sie. Da die Installationskennung nur auf deinem Gerät liegt, kann der Betreiber Daten auf Anfrage nur zuordnen, wenn du die Installationskennung nennst; du findest sie in der App in den Einstellungen und kannst sie dort kopieren. Wende dich für Anfragen an die in Abschnitt 1 genannte Stelle.
>
> ## 9. Quellen
> Quelle: Deutscher Wetterdienst. Die Radarbilder sind aus Rasterdaten des DWD bildlich wiedergegeben und aufbereitet. Wolken- und Sonnenkarten: Contains modified EUMETSAT Meteosat data 2026. Kartenhintergrund: Apple Karten.

---

## Teil A-EN: Full page text, English (NICHT VERÖFFENTLICHT, App nur in DE angeboten; veraltete, ausführlichere Fassung, nicht auf Stand Teil A)

Same structure and numbering as Part A. Placeholders in square brackets. Not legal advice; the German text is the reference if they diverge.

> # Privacy Policy
>
> For the Showers app (iPhone, iPad, Apple Watch) and the associated radar service. As of: [date of go-live].
>
> ## 1. Controller
>
> [OPERATOR_NAME, OPERATOR_ADDRESS, OPERATOR_EMAIL: to be entered by the operator]
>
> ## 2. Overview
>
> - No user account, no advertising, no tracking, no analytics SDKs.
> - If you only use the app to view radar and forecasts, the radar service creates no personal identifier: radar requests contain no location, no cookies and no identifier. Technically, the reverse proxy in front of the service sees the IP address and logs it for a limited time (section 3).
> - Only if you turn on rain alerts does the app register your device with the radar service, using a random installation ID, the device token for notifications and the chosen location or area, rounded to a coarser grid (section 5). This is voluntary and can be revoked in the app at any time.
> - Saved places with their names and your settings stay on your device. The place name in a notification is added on the device (section 5).
> - Operational statistics only as aggregated counters that contain no personal data; device diagnostics only voluntarily and only after approval by the operator (sections 10 and 11). Only for a device paired in this way does the operator see its rain alerts with the position rounded to about 1 km; without pairing, the operator sees no individual devices or places.
> - The server is hosted by Hetzner in Germany (section 15).
>
> ## 3. Radar map and radar service
>
> The app loads the radar images for all of Germany from the Showers radar service. Requests contain no location: there are fixed paths per radar run and time step (full image for Germany), no cookies and no identifier.
>
> The radar service itself keeps no access logs and stores no IP addresses or request details. Its technical logs contain only run identifiers and error classes. This also applies to the push interface of the service. Rate limiting works without an IP address as well (per installation ID or overall).
>
> A reverse proxy (TLS, forwarding) sits in front of the radar service. It technically sees the IP address of every request and logs accesses including the IP address. The purposes are operation, troubleshooting and abuse prevention; the legal basis is our legitimate interest (Art. 6(1)(f) GDPR). Log files rotate by size (at most 64 MB per file, 16 files) and are overwritten afterwards. Depending on traffic, entries are therefore kept for up to roughly 14 months. [Draft note: shortening the period at the proxy to 14 to 30 days is recommended; then adjust this paragraph and the German version.]
>
> The app also shows maps for air pressure, lightning, and clouds or sun. These images also come from the radar service, without a location. They are based on data from the German Weather Service (DWD) and, for clouds and sun, on satellite data from EUMETSAT (section 14). The radar service fetches this data from the sources; no user data is transmitted in doing so. Only the small legend image of these maps is loaded by the app directly from the DWD or from EUMETSAT (EUMETView), without a location; as with any internet connection, the respective body sees your IP address. [R1]
>
> ## 4. Direct retrieval from the German Weather Service
>
> If the radar service does not respond or its data is older than 20 minutes, the app retrieves the radar images directly from the German Weather Service (DWD). The DWD then sees the requested map section and, as with any internet connection, your IP address. The DWD's privacy notices apply.
>
> The app queries the point forecast for a place directly from the DWD, as do the widgets and the Apple Watch for your saved places. The requested point and the IP address are visible to the DWD. The radar service does not receive these places.
>
> ## 5. Rain alerts, areas and Live Activities (optional)
>
> If you turn on rain alerts for a place or an area (radius) in the app, the radar service can notify you even when the app is closed ("Rain starts in N minutes", "Rain reaches your area"). Without this function, none of this is stored.
>
> **What data is stored.** The server stores:
>
> - a random installation ID and the hash of a secret with which the app identifies itself to the server (the secret itself is kept only in your device's keychain);
> - the device token for Apple Push Notifications (APNs), the environment (development or production) and the language (German or English);
> - for each rain alert: for a place, the grid cell of the radar image it lies in (edge length about 0.7 km, no coordinate, no place name); for an area, the center point, rounded to a block of about 2 km (the app transmits the grid cell of the center, the server rounds it before storing), and the radius (5, 10 or 25 km); also the threshold, lead time (10, 20 or 30 minutes), for areas the minimum share, whether the alert should be delivered as time-sensitive, whether a Live Activity is wanted, the state of the rule evaluation and timestamps (created, last changed, last sent; "last seen" applies to the installation); [R2]
> - if Live Activities are on, the start token of your device and one activity token per rain alert. The Live Activity shows only times, rain class and, for areas, the share of wet area, no place name and no coordinates. At most one Live Activity runs per device at a time; an activity token is removed after eight hours at the latest, when you turn it off or when you delete the rain alert;
> - briefly, the notification text to be sent, in a queue (see retention).
>
> You can create up to 10 rain alerts per installation, of which up to 3 can be areas. Depending on location, the grid cell can be personal data because it is associated with a device through the installation ID. No location history is created: only the current value is stored per rain alert.
>
> **Place names stay on the device.** The server does not know the name of your place or area. The notification contains an identifier of the rain alert (which the server sends as the thread identifier) and the minutes; a small app extension (Notification Service Extension) adds the name from a local table on your device to the text.
>
> **Test notification.** In the settings you can trigger a test notification. It goes to the device token of your installation, contains a fixed text without a place and is not stored (at most 3 per hour).
>
> **Recipient Apple.** Notifications and Live Activities are delivered through the Apple Push Notification service. For this, Apple receives from the server the device token, the content of the notification or Live Activity and technical identifiers for grouping notifications (the identifier of the rain alert, for the test notification the installation ID). Apple's privacy terms apply. Data may be transferred to Apple servers outside the EU, in particular in the USA. [R3] [Legal review: basis of the third-country transfer and Apple's role, Part G.]
>
> **Retention and deletion.** If you delete a rain alert or turn the function off, the app deletes the registration on the server; this deletes the installation, rain alerts, activity data and waiting notifications. If Apple reports a device token as invalid (for example after the app is deleted), the server deletes the registration immediately. Registrations that the app has not reported for 60 days are deleted automatically. Waiting or sent notifications in the queue are removed after about 6 hours. For backups, see section 15.
>
> **Legal basis.** Your consent (Art. 6(1)(a) GDPR), which you give by turning the function on and can withdraw at any time with effect for the future by turning it off or deleting it. [Legal review, Part C.]
>
> ## 6. Location and saved places
>
> Location access is optional and is requested only when you want to use your location. There is no background location and there are no location histories. Your location stays on the device; only the point for the forecast is sent to the DWD (section 4). Saved places and their names are stored locally on your device (including for widgets and Apple Watch via the device's app group). Only if you turn on rain alerts for a place does its grid cell go to the radar service (section 5).
>
> ## 7. Map view and place search (Apple)
>
> The map and place search of the app use Apple MapKit. For the base map, your device retrieves the map data of the displayed section from Apple. When you search for a place, the app sends your search text and a fixed search region (Germany, not your location) to Apple. Apple technically sees your IP address in the process. The search text goes neither to the radar service nor to the DWD. The map background of the radar map on Apple Watch is loaded through Apple Maps; the coordinate of the place goes to Apple in the process. Apple's processing is governed by Apple's privacy terms.
>
> A point that you choose by search, by long press on the map or via the location function is stored only locally on the device. Only this point goes to the DWD for the forecast. The radar service receives a place only in the case of section 5.
>
> ## 8. On-device summary
>
> The short summary of the rain situation is produced by Apple Foundation Models on the device. No coordinates or place names are sent to third parties in the process.
>
> ## 9. Apple Watch, widgets and Live Activities
>
> Widgets, Apple Watch and Live Activities use the saved places and settings on your device. The forecast for widgets and watch is retrieved directly from the DWD as described in section 4. The radar map on Apple Watch loads the radar images from the radar service like the app, without a location (section 3). The server does not learn your places in the process unless you have turned on rain alerts or Live Activities (section 5). [R4]
>
> ## 10. Operational statistics of the radar service
>
> For operations, the radar service counts aggregated values that contain no personal data: for example requests per route group and status class, response times in coarse classes, retrieval and error counters of the data sources and results of push delivery. Neither IP addresses nor places, device or installation identifiers are counted. The counters are kept per day (30 days) and as hourly counters (72 hours) in the database and are deleted afterwards. Only the operator can access them, through a protected dashboard.
>
> ## 11. Operator diagnostics (only on approval by the operator, voluntary)
>
> The operator can pair a device for troubleshooting rain alerts and Live Activities. This is off by default, can only be turned on in the app's settings, and is only possible while the operator has briefly opened a pairing window in the dashboard (5 minutes by default); outside the window the app does not show the function.
>
> - When you turn it on, the app shows a short pairing code (valid for 10 minutes, usable once), which the operator enters in the dashboard, giving the device a label of their own.
> - The code is issued only during the pairing window and can only be used if the operator is signed in to the dashboard with their passkey. No receipt from Apple (StoreKit) is transmitted or stored.
> - Stored are the link to the push registration of the device, the label, timestamps (pairing, last seen) and a history of technical delivery results for the last 48 hours (for example test notification delivered or rejected by Apple).
> - Only for a paired device and only while it is paired does the operator see in the dashboard its rain alerts including the position (center of the grid cell or of the area, as a coordinate rounded to about 1 km) and the current evaluation. Other devices and their places are not individually visible in the dashboard.
> - Pairing applies until revoked, at most until the push registration is deleted (section 5). You can revoke it at any time by turning it off in the app; it is then deleted on the server. The operator can also remove it. At most three devices can be paired at the same time. [R5]
> - The operator can send test notifications and a test Live Activity to the paired device.
> - The dashboard's operator log keeps pairing, unpairing and actions for 365 days, without installation ID, token or place, with a short check value of the pairing; after unpairing, this check value can no longer be matched to any device. [R5]
> - The legal basis is your consent (Art. 6(1)(a) GDPR), which you give by turning the function on and showing the code, and which you can withdraw at any time by turning it off. [R5] [Legal review, Part G.]
>
> ## 12. No debug logs containing personal data
>
> The app does not log URLs, locations or raw error data. Caches are held in memory or locally on the device. The radar service observes push operation only through fixed, aggregated counters without tokens, places or identifiers.
>
> ## 13. Your rights
>
> Under the General Data Protection Regulation (GDPR) you have in particular the rights of access, rectification, erasure, restriction of processing, data portability and objection (Art. 15 to 21 GDPR), as well as the right to withdraw consent given at any time with effect for the future. You can also lodge a complaint with a data protection supervisory authority, in particular in the member state of your habitual residence [competent supervisory authority of the operator: to be entered by the operator, Part G]. [R6]
>
> **Right to object.** Where we process data on the basis of legitimate interests (Art. 6(1)(f) GDPR, reverse proxy logs in section 3), you can object at any time on grounds relating to your particular situation (Art. 21 GDPR). [R6]
>
> The simplest way to delete your data on the server is to turn off or delete all rain alerts in the app. Because the installation ID is stored only on your device, the operator can match data on request only if you provide the installation ID. You can find it in the app's settings and copy it there. [Draft note: the app change follows after build 34; publish this sentence only once the display is released in the app.] For requests, contact the address given above.
>
> **Obligation and voluntariness.** You are not obliged by law or contract to provide data. Without an IP address the app cannot technically load radar images; without registration there are no rain alerts or Live Activities from the server, without pairing no operator diagnostics. There is no automated decision-making within the meaning of Art. 22 GDPR; rain alerts are computed solely from the radar data for the place you chose. [R6]
>
> ## 14. Sources
>
> Source: Deutscher Wetterdienst (German Weather Service). The radar images are graphical renderings prepared from DWD raster data. Cloud and sun maps: Contains modified EUMETSAT Meteosat data 2026 (EUMETSAT, year of data publication; adjust the year). Map background: Apple Maps.
>
> ## 15. Hosting and recipients
>
> The radar service and its database run on a dedicated virtual server operated by Hetzner Online GmbH in a data center in Germany. [Operator to confirm: the reverse proxy from section 3 runs on the same server or likewise at Hetzner in Germany.] Hetzner provides the server and network and processes the data stored there as a processor under Art. 28 GDPR, only on our instructions and not for its own purposes. [User action before go-live: conclude a data processing agreement with Hetzner.]
>
> Backups: [operator information pending: whether backups or snapshots of the server or database exist, how often and how long they are kept. Do not state anything here until then.]
>
> Other recipients: Apple for delivering notifications and Live Activities (section 5). Directly from your device, without involvement of the operator, requests go to the DWD (sections 3 and 4), to EUMETSAT (legend images, section 3) and to Apple (maps and place search, section 7); these bodies process the data under their own responsibility. Beyond that, we do not pass on or sell any data. The server is located in Germany; a transfer to third countries can only take place via Apple (section 5). [R7]

---

## Teil B: App-Privacy-Angaben in App Store Connect (Variante B)

Beantwortung des Fragebogens „App-Datenschutz“ für den Fall, dass Push, Gebiete und Live Activities live sind. **Kategorienamen und Definitionen sind aus Apple-Wissen, in Connect nicht gesehen und nicht gegen die aktuelle Apple-Seite geprüft.** Kein Rechtsrat.

Frage „Erfasst ihr oder Drittpartner Daten aus dieser App?“: **Ja** (Variante A „Keine Daten erfasst“ entfällt, da Gerätetoken und Zelle serverseitig gespeichert werden; Daten, die nur auf dem Gerät bleiben oder nur kurz im Speicher verarbeitet werden, zählen nicht).

| # | Datentyp (Kategorie) | Erfasst? | Mit der Identität verknüpft? | Tracking? | Zweck | Grundlage im Code |
|---|---|---|---|---|---|---|
| 1 | Kennungen > **Geräte-ID** | Ja: Gerätetoken (APNs), Installations-UUID, Start-/Activity-Token | Ja (Kennung identifiziert die Installation; konservativ „verknüpft“) | Nein | App-Funktionalität | `push_install`, `push_activity`, `la_start_token` |
| 2a | Standort > **Genauer Standort** (Precise Location) | Ja: Rasterzelle eines Ortes (Kante ~0,7 km) | Ja (zusammen mit Installations-UUID gespeichert) | Nein | App-Funktionalität | `push_sub.cell_x/y` (Punkt-Abo) |
| 2b | Standort > **Grober Standort** (Coarse Location) | Ja: auf ~2 km gerundeter Mittelpunkt und Radius eines Gebiets | Ja (zusammen mit Installations-UUID gespeichert) | Nein | App-Funktionalität | `push_sub.cell_x/y`, `radius_cells` (Gebiets-Abo) |
| 3 | alle übrigen Kategorien | Nein (Proxy-IP-Logs: siehe Punkt 10, ungeprüft) | - | - | - | siehe unten |

Hinweise zu den einzelnen Punkten:

1. **Geräte-ID:** Der Server speichert kein IDFA/IDFV, sondern eine selbst erzeugte Installations-UUID plus das APNs-Token. Apple fasst auch solche geräte-/installationsbezogenen Kennungen unter „Device ID“; Vorschlag: so deklarieren.
2. **Genauer vs. grober Standort (Nutzerentscheidung 7.11.):** Die Zelle eines Ortes (Kante ≈ 0,7 km) wird als „Genauer Standort“ deklariert, das Gebiet (3x3-Block ≈ 2 km gerundet) als „Grober Standort“. Begründung knapp: Die Ortszelle ist kleiner als die Größenordnung, die Apple nach meiner Erinnerung für „Coarse“ nennt (Fläche von mindestens ~3 km² beziehungsweise weniger als drei Dezimalstellen bei Breite/Länge), daher die vorsichtigere Einstufung; das gerundete Gebiet liegt darüber. **Nicht geprüft:** die aktuelle Apple-Definition und der Wortlaut der Kategorien in App Store Connect; vor dem Ausfüllen dort abgleichen. **Nachtrag 12.11.2026 (Apple-Seite geprüft):** Apple definiert „Precise Location“ als Auflösung von mindestens drei Dezimalstellen bei Breite/Länge (ca. 110 m); gröber ist „Coarse“. Danach wären Ortszelle und Gebiet beide „Coarse“; die Einstufung bleibt Nutzerentscheidung, siehe [research/rechtspruefung-ergebnis.md](research/rechtspruefung-ergebnis.md) Frage 11 und E4. Hinweis: Das Gebiet-Abo wird vom Server ebenfalls mit Installations-UUID gespeichert; falls Connect je Datentyp nur einen Eintrag zulässt, ist „Genauer Standort“ die abdeckende Angabe.
3. **Verknüpfung:** Die Daten hängen an der Installations-UUID, es gibt aber kein Konto und keine Verbindung zu Name, E-Mail oder Apple-ID. Ob „mit Identität verknüpft“ angekreuzt wird, ist Auslegungssache; wegen der dauerhaft gespeicherten Kennung (bis zu 60 Tage Inaktivität) ist „Ja, verknüpft“ die vorsichtige Angabe.
4. **Tracking:** Nein. Keine Verknüpfung mit Daten Dritter, keine Weitergabe an Datenhändler, keine Werbung, kein Tracking-Domain-Eintrag nötig.
5. **Zweck:** nur „App-Funktionalität“ (Regenhinweise, Live Activities). Nicht: Analyse, Werbung, Personalisierung, Produktentwicklung.
6. **Nicht erfasst:** Kontaktdaten, Gesundheit, Finanzen, Nutzerinhalte, Browserverlauf, Suchverlauf (der Suchtext geht an Apple MapKit, nicht an den Betreiber), Käufe, Nutzungsdaten (nur aggregierte Zähler ohne Kennung), Diagnosedaten (kein Crash-SDK; Apples eigene TestFlight-/App-Store-Berichte zählen nicht zur App), Sensible Daten, Sonstige Daten.
7. **Betreiber-Diagnose (Kopplung):** Zusätzliche Datensätze (Bezeichnung des Geräts, Zeitpunkte, 48-h-Versandverlauf) hängen an derselben Installation. Die Bezeichnung ist eine vom Betreiber vergebene Gerätebezeichnung; sie ist in den Kategorien oben mit abgedeckt (Geräte-ID, kein neuer Datentyp). Nutzerprüfung, falls die Bezeichnung personenbezogen vergeben wird.
8. **Warnungen (später):** Warngebiets-IDs (Gemeinde) sind dem Standort (grob) zuzuordnen, Kategorien voraussichtlich unverändert (Spec §5). Bei Push-Livegang erneut prüfen.
9. **Zusätzlich im Projekt (Agent-Aufgabe, nicht Teil dieses Entwurfs):** `PrivacyInfo.xcprivacy` je Target mit UserDefaults-Gründen (CA92.1, 1C8F.1), erstmals `b29be64` (Build 33: Device ID und Coarse Location, *nicht* verknüpft). Seit `8eb9715` (Build 34) deklariert `Weather/PrivacyInfo.xcprivacy` Device ID, Coarse **und** Precise Location, jeweils verknüpft, kein Tracking, Zweck App Functionality; das stimmt mit dieser Tabelle überein (am 7.11. gegen die Datei geprüft). Build 33 und Teil B widersprechen sich bei „verknüpft“; maßgeblich für den Release ist Build 34 oder neuer. [R8]

10. **Proxy-IP-Logs und App Privacy (neu, ungeprüft):** Der Proxy protokolliert IP-Adressen aller Abrufe (nur Betrieb/Sicherheit, nicht mit Installations-ID verknüpft). Ob Apple dafür eine Angabe verlangt (z. B. unter Nutzungs- oder Diagnosedaten, Zweck Sicherheit/Betrieb), ist nicht geprüft; vor Abgabe in Connect gegen die aktuelle Apple-Definition prüfen. Teil B führt dazu bewusst noch nichts auf.

---

## Teil C: Beantwortete und offene Fragen

### Beantwortet (Nutzer, 7.11.2026; in Teil A/A-EN/B eingearbeitet)

| # | Frage | Antwort / Umsetzung |
|---|---|---|
| 1 | Reverse Proxy: Protokollierung? | **Beantwortet:** Zoraxy protokolliert mit IP. Rotation nach Größe (64 MB x 16 Dateien), neue Datei laut Nutzer alle 2 bis 4 Wochen (Schätzung) ⇒ ca. 7 bis 14 Monate. Text: „bis zu rund 14 Monate“, Zweck Betrieb/Fehlersuche/Missbrauchsabwehr, Art. 6 Abs. 1 lit. f (Vorschlag). **Empfehlung/Nutzeraktion:** am Proxy auf zeitbasierte 14 bis 30 Tage kürzen, danach Abschnitt 3 anpassen. |
| 2 | Verantwortlicher | **Beantwortet:** Nutzer trägt `OPERATOR_NAME/ADDRESS/EMAIL` selbst im Betrieb ein; Text nutzt Platzhalter. Impressum: Korrektur [R9] – die Seite `/impressum` (§ 5 DDG, aus denselben Betreiberangaben) ist im Backend-Code vorhanden (Commit `91bed98`, Navigation und Footer verlinkt); die frühere Angabe „liefert 404“ war veraltet. Ob die Live-Instanz sie ausliefert, nicht geprüft. |
| 4a | Hosting-Ort | **Beantwortet (7.11.):** eigener vServer bei Hetzner in Deutschland; Abschnitt 15 (de/en). Nutzeraktion: Vertrag zur Auftragsverarbeitung mit Hetzner. |
| 5 | Auskunft / Installationskennung | **Beantwortet (7.11.):** App zeigt die Kennung in den Einstellungen an und macht sie kopierbar; Abschnitt 13 (de/en). App-Änderung folgt nach Build 34. |
| 10 | Dashboard-Einsicht | **Beantwortet (7.11.):** offen benennen; Abschnitte 2 und 11 (de/en): Position auf etwa 1 km gerundet, nur bei Kopplung. |
| 6 | Speicherdauer | **Beantwortet:** unverändert (60 Tage Inaktivität, Warteschlange 6 h, Diagnose-Verlauf 48 h, Zähler 30 Tage/72 h, Kopplung bis Widerruf). |
| 7 | App Privacy Standort | **Beantwortet:** Ortszelle = Precise, Gebiete = Coarse; verknüpft, kein Tracking (Teil B). Definition in Connect weiterhin zu prüfen. |
| 8 | Englische Fassung | **Beantwortet:** ja, vollständig (Teil A-EN). Umsetzung auf der Seite (Sprachumschaltung/URL) ist eine spätere Aufgabe. |
| 9 | Warnungen | **Beantwortet:** im Release-Text weglassen; Teil E bleibt vorbereitet. |
| 11 | Domain | **Beantwortet:** beide Hosts parallel ohne Weiterleitung; nach außen nur showers.linolaske.de. Zertifikat/Erreichbarkeit von `/datenschutz`, `/support`, `/marketing` auf showers.linolaske.de weiterhin nicht von mir geprüft. |

### Noch offen (nur der Nutzer kann beantworten)

| # | Frage | Warum / Stand |
|---|---|---|
| 4b | **Datensicherungen:** Gibt es Backups/Snapshots (Hetzner-Backup, Datenbank-Dump)? Rhythmus, Aufbewahrung? | Offene Nutzerangabe, Platzhalter in Abschnitt 15; nicht geraten. Beeinflusst die tatsächliche Löschfrist aller Angaben in Abschnitt 5. |
| 4c | **Vertrag zur Auftragsverarbeitung mit Hetzner** abschließen (Art. 28 DSGVO) | Nutzeraktion vor Livegang. |
| 4d | **Läuft der Reverse Proxy (Zoraxy) auf demselben Hetzner-Server?** | Platzhalter in Abschnitt 15; sonst weiterer Auftragsverarbeiter zu nennen. |
| 5b | **App: Installationskennung in den Einstellungen anzeigen und kopierbar machen** | App-Änderung nach Build 34 (eigene Aufgabe); Satz in Abschnitt 13 erst danach live. |
| 12 | **EUMETSAT-Jahr und Wortlaut** der Attribution | Policy-Text gelesen, Wortlaut „Contains modified EUMETSAT Meteosat data [Jahr]“; Jahr beim Livegang anpassen (Entwurf: 2026). |
| 3 | **Rechtsprüfung** | Alle Rechtsgrundlagen und Einordnungen sind Vorschläge; Fragenliste in Teil G. |
| 13 | **Proxy-Frist kürzen** (zeitbasiert, Empfehlung nach Prüfung eher 7 bis 14 Tage, höchstens 30) und anschließend Text anpassen | Nutzeraktion am Zoraxy; siehe Teil G Frage 1. |
| 14 | **Proxy-IP-Logs in App Privacy** (siehe Teil B, Punkt 10) | ungeprüft. |
| 15 | **Zuständige Aufsichtsbehörde** des Betreibers (Bundesland) eintragen | Platzhalter in Abschnitt 13. |

---

## Teil D: Abweichungen zum jetzigen Live-Text (Stand `SitePages.swift`, 7.11.2026)

| Live | Entwurf | Grund |
|---|---|---|
| „Für die App Showers (iPhone, iPad)“ | + Apple Watch | Watch-App vorhanden |
| Überblick: „Der Radar-Dienst setzt keine Cookies und vergibt keine Kennung.“ | eingeschränkt auf „nur ansehen“; Push mit Installationskennung | Push vergibt UUID, Token, Zelle |
| Überblick: „Gespeicherte Orte und Einstellungen bleiben auf deinem Gerät.“ | zusätzlich Ausnahme Rasterzelle bei Regenhinweisen | Datenänderung durch Push |
| Abschnitt 3 | zusätzlich Push-Schnittstelle (kein Zugriffsprotokoll im Dienst), Ebenen Luftdruck/Blitze/Wolken/Sonne, EUMETSAT | Push-API im selben Dienst; Zusatzebenen live |
| Abschnitt 4 | + Widgets und Watch rufen Prognose beim DWD ab | `Shared/Data/DWDClient.swift` |
| Abschnitt 5 „Standort und gespeicherte Orte“ (alt) | neuer Abschnitt 5 „Regenhinweise, Gebiete, Live Activities“ (alle Daten, Empfänger Apple, Speicherdauer, Rechtsgrundlage); alter Abschnitt wird 6 | Hauptänderung |
| Abschnitt 6 Apple-Karte | + Apple Watch Kartenhintergrund (Koordinate an Apple); Satz „Radar-Dienst erhält keinen Ort“ mit Ausnahme Abschnitt 5 | App-Build 16; Status 4.11. |
| - | neu: Abschnitt 9 Watch/Widgets/Live Activities | Funktionen vorhanden |
| Abschnitt 9 alt (Betreiber-Diagnose) = 11 neu | + Dashboard sieht gerundete Zelle des gekoppelten Geräts; Test-Live-Activity | `PushMeasure.swift`, `api.md` |
| Abschnitt 10 alt = 12 neu | + Push nur über feste Zähler | Beobachtungsdesign (`PushObserver`) |
| Abschnitt 11 alt = 13 neu | + Widerruf der Einwilligung, Löschung durch Ausschalten, Hinweis zur Zuordnung | Art. 7 Abs. 3 DSGVO, kein Konto |
| Abschnitt 12 alt = 14 neu | + EUMETSAT-Attribution, Apple Karten | EUMETSAT-Klärung 31.10. |
| Name/Domain: Live-Seite nennt bereits „Showers“; die App verlinkt Datenschutz/Support/Über noch auf `showernow.linolaske.de` (`RadarBackendConfig`, bewusst nicht umgestellt, `decisions.md` 3.11.) | Entwurf nennt nur „Showers“ und `showers.linolaske.de`; keine sichtbare „ShowerNow“-Nennung | Nutzervorgabe 7.11. Folgeaufgaben (nicht in diesem Entwurf): App-URL-Konstanten, Connect-URLs, Seiten-Links und `docs-site` auf showers.linolaske.de umstellen; Domain-Redirect/Zertifikat prüfen; Texte `docs/apple-externe-tests.md` mit altem Namen |
| Warnungen | nicht enthalten | Nutzerentscheidung 7.11., Teil E |
| Abschnitt 3: Proxy "noch nicht angegeben" | Proxy protokolliert mit IP, Rotation nach Größe, bis zu rund 14 Monate, lit. f | Nutzerangabe 7.11.; Kürzung auf 14 bis 30 Tage empfohlen |
| Nur deutsch | zusätzlich vollständige englische Fassung (Teil A-EN) | Nutzerentscheidung 7.11. |
| Verantwortlicher: "wie bisher aus Betreiberkonfiguration" | Platzhalter `OPERATOR_NAME/ADDRESS/EMAIL`, vom Betreiber einzutragen | Nutzerentscheidung 7.11. |
| App Privacy: eine Standort-Zeile (grob) | Ortszelle Precise, Gebiete Coarse (Teil B 2a/2b) | Nutzerentscheidung 7.11. |
| Betreiber-Diagnose: „Es werden keine Standortdaten gespeichert.“ | gestrichen; stattdessen offen: Betreiber sieht für gekoppeltes Gerät die Position auf etwa 1 km gerundet (auch im Überblick) | Nutzerentscheidung 7.11.; `PushMeasure.swift` (`place`, Koordinate auf 2 Dezimalstellen) |
| kein Hosting-Abschnitt | neu Abschnitt 15 „Hosting und Empfänger“: Hetzner vServer Deutschland, Auftragsverarbeiter, Empfängerübersicht, Drittland nur über Apple; Backups Platzhalter | Nutzerangabe 7.11.; Art. 13 Abs. 1 lit. e/f |
| Rechte ohne Auskunftsweg | Installationskennung in den Einstellungen anzeigen/kopieren (App-Änderung nach Build 34), Widerspruchsrecht Art. 21, Pflicht/Freiwilligkeit, keine automatisierte Entscheidung | Nutzerentscheidung 7.11.; Review [R6] |
| Legendenbilder nicht erwähnt | Direktabruf beim DWD und bei EUMETSAT (IP sichtbar) | Review [R1] |
| Empfänger Apple: Token und Text | + Kennung des Regenhinweises bzw. Installationskennung (Testmeldung) als Collapse-/Thread-Kennung, Drittland USA | Review [R3] |

Nicht in den Entwurf übernommen, weil nicht belegt: Backups (Platzhalter in Abschnitt 15).

---

## Teil E: Baustein „Warnungen“ (Webseite: nur mit `PUSH_ENABLED` und `WARN_PUSH_ENABLED`; Wortlaut im Backend `SitePages.swift`, Warngebiete = Kreise; nur Deutsch)

Bereit zum Einfügen, sobald `warnings_push` aktiviert wird (nach DWD-Antwort und Freigabe):

> **Amtliche Warnungen (optional).** Wenn du Warnungen vor Unwetter, Frost oder Glatteis einschaltest, speichert der Server zusätzlich die Warngebiets-Kennungen (Gemeinden) deiner Orte und Gebiete, die gewünschten Warnarten und die Mindeststufe, jeweils mit deiner Installationskennung. Koordinaten und Ortsnamen speichert der Server dafür nicht; die Zuordnung deines Ortes zu einer Gemeinde geschieht auf deinem Gerät. Die aktuellen Warnungen ruft die App ohne Ortsangabe ab. Löschung wie bei Regenhinweisen (Abmeldung, ungültiges Token, 60 Tage Inaktivität). Quelle der Warnungen: Deutscher Wetterdienst. Die App ersetzt keine offiziellen Warnkanäle; im Notfall wähle 112.

Hinweis: Die Kombination aus Regenhinweis-Zelle und Warngemeinde derselben Installation ist ein etwas genaueres Merkmal (Spec §5); die Kategorien in App Privacy bleiben voraussichtlich Geräte-ID und grober Standort.

---

## Teil F: Technisch-redaktionelle Plausibilitätsprüfung (7.11.2026)

**Art der Prüfung:** technisch-redaktioneller Abgleich des Entwurfs mit dem Code durch einen KI-Agenten, **keine Rechtsberatung und keine rechtliche Prüfung.** Geprüft wurde, ob die Aussagen den Datenflüssen im Code entsprechen und ob die in Art. 13 DSGVO genannten Angaben vorkommen; ob sie rechtlich ausreichen, entscheidet die externe Rechtsprüfung (Teil G).

Gelesen (Stand 7.11.): Backend `migrations/003, 006, 007, 009, 010, 012, 013, 015`, `PushService.swift` (Löschfristen: 60 Tage, Warteschlange 6 h, stündlicher Purge), `MariaRepo+Push.swift`, `PushApi.swift` (Testmeldung, Begrenzung je Installation ohne IP), `PushActivity.swift`, `PushMeasure.swift`/`PushModels.swift` (Dashboard-Position: Zellmitte auf 2 Dezimalstellen), `DeviceLinkRepo+Maria.swift`, `DeviceCommandRepo*.swift` (48 h), `DashboardRepo*.swift` (Statistik 30 Tage, Audit 365 Tage), `Config.swift` (`DASH_DEVICE_TTL_DAYS` Standard 0), `Layers.swift` (Legenden-URLs), `SitePages.swift` (Impressum), `Sources/radar/Radar.swift` (Middleware ohne Zugriffslog); App: Hosts in allen Targets, `Weather/Data/RadarLayer.swift` (Legenden-Hosts), `Shared/Data/DWDRequest.swift`, `Shared/Data/RainForecast.swift` (20 Minuten), `WeatherWatch/Radar/WatchRadarStore.swift`, `WatchMapBackdrop.swift`, `Weather/PrivacyInfo.xcprivacy`.

**Bestätigt:** keine Zugriffsprotokolle im Dienst (eigene Middleware-Liste ohne Request-Logging, Logs nur mit Lauf-IDs und Zählern); Begrenzungen je Installation/global ohne IP; Löschfristen 60 Tage/6 h/48 h/30 Tage/72 h; Kaskadenlöschung (Install → Abos, Activities, Warteschlange, Kopplung, Codes); ungültiges Token löscht sofort; Testmeldung wird nicht gespeichert; Ortsnamen nie an den Server; App-Hosts nur eigener Dienst, `maps.dwd.de`, `opendata.dwd.de` (nur Link), `view.eumetsat.int`, Apple MapKit; Dashboard zeigt Push-Daten sonst nur aggregiert; Privacy Manifest (Build 34) = Teil B; kein Tracking, keine Analyse-SDKs.

**Korrigiert (im Text markiert):**

| Marke | Fehler / Lücke | Beleg | Korrektur |
|---|---|---|---|
| R1 | „Diese Bilder kommen vom Radar-Dienst“ unvollständig: Legendenbilder lädt die App direkt bei `maps.dwd.de` und `view.eumetsat.int`; EUMETSAT war als Empfänger der IP nicht genannt | Backend `Layers.swift` (Legend-URLs), App `RadarLayer.swift` `allowedHosts` | Satz in Abschnitt 3 de/en |
| R2 | Zeitpunkte je Regenhinweis: „zuletzt gesehen“ liegt an der Installation, nicht am Abo; „zuletzt geändert“ (`changed_at`) fehlte. Gebiet: App überträgt die ungerundete Zelle, Server rundet erst | `015_push_eval_trace.sql`, `api.md` Regionen | Abschnitt 5 de/en |
| R3 | Empfänger Apple: Apple erhält neben Token und Text auch `apns-collapse-id` (Abo-Kennung; Testmeldung `test-<Installationskennung>`); Drittlandbezug fehlte | `PushService.swift` (`collapseID: sub.id`), `PushApi.swift` `sendTest` | Abschnitt 5 de/en |
| R4 | „Der Server erfährt davon nichts“ (Watch) falsch: Die Watch lädt Radarbilder vom Radar-Dienst (ohne Ort, Proxy sieht IP) | `WatchRadarStore.swift` | Abschnitt 9 de/en |
| R5 | Betreiber-Diagnose: keine Rechtsgrundlage genannt (Art. 13 Abs. 1 lit. c); Kopplung endet auch mit Löschung der Registrierung (Kaskade); Audit-Protokoll 365 Tage mit 8-stelligem Prüfwert (`sha256(device_id)`) nicht erwähnt | `010_device_link.sql` (FK Cascade), `DashboardRepo.swift` (`auditDays = 365`, `deviceRef`) | Abschnitt 11 de/en |
| R6 | Art. 13 Abs. 2: Hinweis auf Widerspruchsrecht bei lit. f (Art. 21 Abs. 4 verlangt gesonderten Hinweis), Pflicht/Freiwilligkeit (lit. e), automatisierte Entscheidung (lit. f) fehlten; Aufsichtsbehörde ohne Nennung | DSGVO-Text | Abschnitt 13 de/en, Platzhalter Behörde |
| R7 | Empfänger/Drittland fehlten als Übersicht (Art. 13 Abs. 1 lit. e/f) | – | Abschnitt 15 de/en |
| R8 | Teil B Punkt 9 verwies auf Build-33-Manifest (nicht verknüpft) | `Weather/PrivacyInfo.xcprivacy` (Stand `8eb9715`) | Teil B Punkt 9 |
| R9 | Teil C: „`/impressum` liefert 404“ veraltet | Backend `SitePages.swift` `imprint`, Commit `91bed98` | Teil C Zeile 2 |

**Geprüft, ohne Widerspruch:** DE und EN sind nach den Änderungen inhaltlich gleich (Abschnitt für Abschnitt verglichen; die Redaktionsvermerke „unverändert gegenüber …“ in DE-Abschnitten 7, 10 und 11 fehlen in EN bewusst und sind vor Livegang auch im DE-Text zu entfernen). Tracking-Aussagen („kein Tracking“, Teil B „Tracking: Nein“, Manifest `NSPrivacyTracking=false`, keine Tracking-Domains) widerspruchsfrei. Apple 5.1.1(i) (Datenschutzerklärung in App und Connect, welche Daten, wie erhoben, Verwendung, Dritte, Aufbewahrung/Löschung, Widerruf) inhaltlich abgedeckt; 5.1.1(v) Kontolöschung entfällt (kein Konto); 5.1.2 keine Weitergabe für Werbung/Tracking. Datenschutz-URL und Erreichbarkeit in der App nicht geprüft.

**Hinweise ohne Textänderung:** Die Rasterzelle eines Ortes (~0,7 km) ist Precise; Abschnitt 5 nennt sie korrekt „keine Koordinate“, technisch ist sie aber in eine Koordinate rückrechenbar (das Dashboard tut das). Der Push-Registrierungsaufruf selbst geht über den Proxy und ist damit mit der IP im Proxy-Log verbunden (Pfad enthält die Installationskennung, falls Zoraxy Pfade protokolliert); dann wären Proxy-Logs entgegen Teil B Punkt 10 doch mit der Installationskennung verknüpfbar. Nicht geprüft, Teil G Frage 2.

---

## Teil G: Fragen für die externe Rechtsprüfung

1. **Proxy-Logs 14 Monate (Art. 5 Abs. 1 lit. c/e, Art. 6 Abs. 1 lit. f):** Eine größenbasierte Rotation mit bis zu rund 14 Monaten ist für Betrieb und Missbrauchsabwehr nach unserer Einschätzung schwer als erforderlich zu begründen; üblich sind Tage bis wenige Wochen (oft 7 Tage). Ist der Text bei aktueller Konfiguration überhaupt vertretbar, oder muss die Frist vor Livegang gekürzt werden? Reicht eine IP-Kürzung statt Löschung?
2. **Proxy-Logs und Pfade:** Falls Zoraxy die Request-URL protokolliert, stehen dort für Push-Aufrufe die Installationskennung und (bei Abo-Aufrufen) Abo-Kennungen neben der IP. Muss Abschnitt 3 das nennen, und ändert das die App-Privacy-Angabe (Teil B Punkt 10)? (Technisch erst in der Zoraxy-Konfiguration zu prüfen.)
3. **Rechtsgrundlage Push/Live Activity:** Einwilligung (lit. a) oder Vertragserfüllung/Nutzungsverhältnis (lit. b)? Genügt das Einschalten des Schalters als Einwilligungshandlung, und braucht die App vor dem ersten Einschalten einen Hinweistext mit Link?
4. **§ 25 TDDDG:** Speicherung von Installationskennung/Geheimnis im Schlüsselbund, Abruf des APNs-Tokens, UserDefaults: unbedingt erforderlich (Abs. 2 Nr. 2) oder einwilligungspflichtig? Muss die Erklärung das gesondert nennen?
5. **Apple APNs:** Rolle von Apple (eigener Verantwortlicher oder Auftragsverarbeiter des Betreibers?), Grundlage der Drittlandübermittlung (z. B. Angemessenheitsbeschluss EU-US Data Privacy Framework, falls Apple zertifiziert ist; nicht geprüft) und ob der Text das konkreter benennen muss.
6. **Betreiber-Diagnose:** Ist Einwilligung (lit. a) passend, wenn praktisch nur Geräte des Betreibers selbst gekoppelt werden? Ist die Einsicht in die auf etwa 1 km gerundete Position so ausreichend transparent?
7. **Hetzner:** Genügt der Standard-AVV von Hetzner; muss der Firmensitz/die Anschrift genannt werden; Unterauftragsverarbeiter?
8. **Impressum (§ 5 DDG) und Verantwortlicher:** Ist bei einer kostenlosen App eines Einzelnen die Impressumspflicht gegeben (geschäftsmäßig)? Reicht die Verlinkung aus der Datenschutzerklärung? Ist eine ladungsfähige Anschrift nötig?
9. **Datenschutzbeauftragter:** Bestätigen, dass keine Benennungspflicht besteht (Art. 37 DSGVO, § 38 BDSG) und deshalb keine Kontaktangabe nötig ist.
10. **Direktabrufe (DWD, EUMETSAT, Apple MapKit):** Reicht der Hinweis „eigene Verantwortung“, oder ist der Betreiber für die Auslösung der Abrufe mitverantwortlich (gemeinsame Verantwortung, vgl. Fanpage-/Like-Button-Rechtsprechung)?
11. **Englische Fassung:** Klausel „the German text is the reference“ (Teil A-EN Vorspann) gewollt und wirksam?
12. **Rasterzelle als personenbezogenes Datum:** Ist die Formulierung „kann je nach Lage personenbezogen sein“ zu weich (Zelle + Installationskennung + Token sind einem Gerät zugeordnet)?

## Nicht geprüft

Live-Instanz (`/datenschutz`, `/impressum` auf showers.linolaske.de) nicht abgerufen; tatsächliche Zoraxy-Konfiguration (welche Felder, Pfade, Rotation) und Hetzner-Vertrag/Backups; App-Store-Connect-Formular; aktuelle Apple-Definitionen (Precise/Coarse, linked, Pflichtangabe für Server-Logs) und aktueller Wortlaut der Richtlinien 5.1.1/5.1.2 (nur aus Wissensstand); DPF-Zertifizierung von Apple; rechtliche Würdigung jeder Art; Laufzeitverhalten (keine Builds, keine Tests, keine Netzmitschnitte; Aussagen beruhen auf Code-Lesen); Notification Service Extension und Widgets nur über Host-Suche, nicht vollständig gelesen; Foundation Models nur als Import belegt (Abschnitt 8 on-device nicht im Detail geprüft); Backend-Warnungscode (Migration 016 ff.) nicht geprüft, da nicht im Release-Text.

### Nicht geprüft (erste Runde)

Ob die Live-Seite exakt dem Quellcode entspricht (nur Quellcode gelesen, Seite nicht abgerufen); App Store Connect; aktuelle Apple-Definitionen zu Coarse/Precise Location und „linked to identity“; rechtliche Würdigung; ob Widgets Apple-Karten nutzen (nur Watch belegt); tatsächliche Zoraxy-Konfiguration (Rotation, Dateigröße, Protokollinhalt, Intervall 2 bis 4 Wochen nur Nutzerschätzung; 7 bis 14 Monate ist Rechenwert); Sprachliche Passung und juristische Qualität der englischen Fassung (eigene Übersetzung); Apple-Pflichtangabe für Proxy-IP-Logs.
