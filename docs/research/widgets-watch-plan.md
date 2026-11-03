# Widgets, Watch, Live Activity: Umsetzungsplan

Stand: 3. November 2026. Reiner Plan, kein Produktcode, nichts bei Apple angelegt. Setzt `plan.md` Abschnitt 4 und `research/live-activities-und-kritische-mitteilungen.md` (Live Activities) fort. Aufgabe Todolino 54374E79.

Kennzeichnung: **[B]** im Repo gelesen; **[P]** gegen Apple-Doku gelesen am 3.11.2026; **[A]** Annahme/Einschätzung; **[U]** ungeprüft, vor Umsetzung am Gerät/in Doku klären.
Apple-Quellen (Basis `https://developer.apple.com/tutorials/data/documentation/`): Q1 `widgetkit/keeping-a-widget-up-to-date`; Q2 `widgetkit/making-a-configurable-widget`; Q3 `widgetkit/creating-accessory-widgets-and-watch-complications`; Q4 `watchconnectivity/wcsession`; Q5 `activitykit/activity/pushtostarttokenupdates`; dazu Q5-Q7 des Live-Activity-Befunds (`displaying-live-data-with-live-activities`, `starting-and-updating-live-activities-with-activitykit-push-notifications`).

## 0. Ausgangslage [B]

- `project.yml`: nur iOS (Deployment 27.0), Targets `Weather` (Quellen: gesamter Ordner `Weather/`), `WeatherTests`, `WeatherUITests`. Identität in `Configuration/Base.xcconfig` (`WEATHER_BUNDLE_ID = de.linolaske.showernow`, Team `J2DU2P47XW`, Buildnummer 14). Entitlements der App: `aps-environment`, `time-sensitive`. Keine App Group, keine URL-Schemes, kein `onOpenURL`.
- Daten: `DWDClient` (actor, `forecast(at:)`, ephemere URLSession, Punktprognose direkt beim DWD, 5-Minuten-Raster, `RainForecast.maximumAge` 20 min); `RainForecast`/`RainSample`/`WeatherCoordinate` (alle `Codable, Sendable`). `WeatherStore` (MainActor, UI-gebunden) hält Orte als `places.json` in Application Support (`SavedPlace`: id, name, coordinate); Punktprognosen nur im Speicher. Push: `PushManager`/`PushGateway` (Geräte-Token, Abos je Zelle/Region, Backend-API `/v1/push/...`, `env` sandbox/production).
- Folgerung: Die Rechenkerne (`DWDClient`, `DWDRequest`, `DWDResponse`, `RainForecast`) sind UI-frei und teilbar; `WeatherStore` und `PushManager` hängen an UIKit/Observation und bleiben nur in der App.

## 1. Bestätigte Plattformfakten

- [P, Q1] Widgets rendern in eigenem Prozess; WidgetKit verteilt Reloads über ein dynamisches Tagesbudget je Widget-Instanz (24 h). Für oft angesehene Widgets typisch 40 bis 70 Reloads/Tag (grob alle 15 bis 60 min). Nicht gezählt: Host-App im Vordergrund, App-Intent-Ausführung, Systemsprach-/Dynamic-Type-Wechsel, StandBy-Darstellung. Selten besuchte Homescreen-Seiten werden seltener geladen. WidgetKit-Push als zusätzlicher Weg existiert, ersetzt keine Timelines. **Folge:** Zeitgenaue Aktualität im 5-min-Takt ist nicht garantierbar; Datenalter muss immer sichtbar/prüfbar sein (deckt sich mit `plan.md`: keine Garantie für Hintergrundaktualisierung).
- [P, Q2] Ortsauswahl per `AppIntentConfiguration` + `AppIntentTimelineProvider`; Optionen aus App Intents (`AppEntity`/`EntityQuery`), dynamisch lieferbar.
- [P, Q3] Accessory-Widgets (Sperrbildschirm iPhone/iPad, Smart Stack und Komplikationen watchOS) nutzen dieselben WidgetKit-/SwiftUI-Typen; Apple empfiehlt dafür eigene watchOS-Widget-Extension neben der iOS-Extension, Code teilbar.
- [P, Q4] `WCSession` in beiden Apps nötig; bei nur einer aktiven Seite laufen Übertragungen opportunistisch im Hintergrund; Mehrfach-Uhr-Unterstützung verlangt Delegate-Methoden für asynchrone Aktivierung.
- [P, Q5 und früherer Befund] Push-to-Start-Token (`Activity.pushToStartToken(Updates)`) startet Live Activities per APNs ohne laufende App; Updates per Activity-Token; `apns-push-type: liveactivity`, Topic `<bundleID>.push-type.liveactivity`, Priorität 5 zählt nicht gegen ein Budget, 10 schon; max. 8 h aktiv; UI im Widget-Extension-Target; Spiegelung auf Apple Watch/Mac laut Q5 vorgesehen.
- [A] Extension-Bundle-IDs müssen mit der ID der einbettenden App beginnen; eine Watch-App und iOS-Widgets/Watch-Widgets brauchen je eigene App-ID im Portal; App Groups sind plattformübergreifend teilbar (iOS, watchOS), nicht zwischen Phone und Watch als gemeinsamer Speicher (die Uhr hat eigenen Container, daher WatchConnectivity oder Direktabruf).
- [U] Mindestversionen, Speichergrenze des Widget-Prozesses (grob 30 MB [A], Messung nötig), `XcodeGen` 2.46: genaue Typ-/Embedding-Konfiguration für watchOS (siehe 2), watchOS-eigenständige Live-Activity-Darstellung (ohne Spiegelung).

## 2. Target-Struktur in `project.yml` (Vorschlag)

| Target | Typ / Plattform | Bundle-ID | Zweck |
|---|---|---|---|
| `Weather` (besteht) | application, iOS | `de.linolaske.showernow` | bettet Extension und Watch-App ein |
| `WeatherWidgets` | app-extension (WidgetKit), iOS | `de.linolaske.showernow.widgets` | Home-/Sperrbildschirm-Widgets, Live-Activity-UI |
| `WeatherWatch` | application, watchOS (Companion) | `de.linolaske.showernow.watchkitapp` | Watch-App |
| `WeatherWatchWidgets` | app-extension (WidgetKit), watchOS | `de.linolaske.showernow.watchkitapp.widgets` | Komplikationen/Smart Stack |
| `WeatherTests` (besteht) | unit-test | unverändert | zusätzlich Tests der geteilten Logik |

- App Group: `group.de.linolaske.showernow` für `Weather` und `WeatherWidgets` (iOS). Die Watch-Targets teilen untereinander `group.de.linolaske.showernow` (eigener Container auf der Uhr). Entitlement-Dateien je Target unter `Configuration/` (`WeatherWidgets.entitlements`, `WeatherWatch.entitlements`, `WeatherWatchWidgets.entitlements`, nur `com.apple.security.application-groups`); `aps-environment` bleibt nur an der App (Live-Activity-Pushs laufen über Token der App; Extension braucht kein Push-Entitlement [A]).
- Info.plist: App erhält `NSSupportsLiveActivities = YES` und `CFBundleURLTypes` (Schema `showernow`); `WeatherWatch` erhält `WKApplication`/`WKCompanionAppBundleIdentifier = de.linolaske.showernow` (Einzel-Target-Watch-App; XcodeGen-Konfiguration [U], der Build-Agent prüft Embedding und Plist-Schlüssel real). `ITSAppUsesNonExemptEncryption = false` an jedem App-Target. Identitätswerte weiter über `Base.xcconfig` (`WEATHER_BUNDLE_ID` als Präfix); Watch-Deployment 27.0 ergänzen (`WATCHOS_DEPLOYMENT_TARGET`).
- Embedding: iOS-App hängt per `dependencies` (embed) von `WeatherWidgets` und `WeatherWatch` ab; die Watch-App von `WeatherWatchWidgets`. Marketing-/Build-Nummer kommen aus `Base.xcconfig` und sind damit für alle Targets gleich (Apple verlangt Übereinstimmung).
- Quellen über Verzeichnis-Globs, damit spätere Pakete keine `project.yml` anfassen müssen: `Weather/` (App), `Shared/` (in mehreren Targets), `WeatherWidgets/`, `WeatherWatch/`, `WeatherWatchWidgets/`. Es entsteht **keine** Package-Struktur und kein Framework: ein Quellordner `Shared/` im Repo-Wurzelverzeichnis, dessen Dateien in mehrere Targets aufgenommen werden (Dateizugehörigkeit). Für Mac/iPad entsteht dadurch noch nichts; iPad zeigt iPhone-Widgets ohnehin [A].
- Signing/TestFlight (kein Auftrag zum Anlegen erteilt): Neue App-IDs (`.widgets`, `.watchkitapp`, `.watchkitapp.widgets`) und die App Group müssen im Developer-Portal existieren; bei Automatic Signing legt Xcode sie mit angemeldetem Team an (Nutzer/Build-Verantwortlicher muss in Xcode angemeldet sein, `docs/signing.md` fortschreiben). Archiv enthält dann Watch-App; Upload nur mit Xcode 27.1 (27.2 wurde abgelehnt, siehe `status.md`). Externe TestFlight-Prüfung: neue Binäre, Datenschutzangaben und Testtext erweitern; Build 13 ist noch in der Prüfung, die erste Widget-/Watch-Fassung deshalb als eigener Build 15+ planen. Watch-Test braucht Gerät (Watch Ultra); Simulator deckt Layout, nicht Budget/Konnektivität ab.

## 3. Geteilter Code (Zielzugehörigkeit statt Package)

Neuer Ordner `Shared/` (per `git mv`, Verhalten unverändert):

| Datei(en) | App | Widgets iOS | Watch + Watch-Widgets |
|---|---|---|---|
| `Data/RainForecast.swift` (inkl. `WeatherCoordinate`, `DWDDataError`), `DWDClient`, `DWDRequest`, `DWDResponse` | ja | ja | ja |
| neu `PlaceStore.swift` (Orte lesen/schreiben im App-Group-Container, Migration aus Application Support) | ja | ja (lesen) | ja (eigener Container) |
| neu `ForecastCache.swift` (letzte gültige Prognose je Ort, App Group, Datei) | ja | ja | ja |
| neu `RainOutlook.swift` (reine Funktion: Prognose + `now` → Zustand `rainingNow/startsIn/endsIn/dry/stale/noData`, Minuten, Intensitätsklasse; ersetzt die String-Logik in `summary(at:)` ohne deren Verhalten zu ändern) | ja | ja | ja |
| neu `WidgetDeepLink.swift` (`showernow://place/<uuid>`) | ja | ja | ja |
| `SavedPlace` (aus `WeatherStore.swift` herausgelöst) | ja | ja | ja |
| `LiveActivity/RainActivityAttributes.swift` | ja | ja | optional |

Nicht geteilt: `WeatherStore`, `PushManager`, Karte, `RadarBackend`/`RadarLayer`/`SunMask` (Widgets und Watch brauchen kein Radarbild; Backend-Abhängigkeit entfällt, Widgets laufen unabhängig vom eigenen Backend wie die Karte-Fallback-Regel). Abhängigkeitsprüfung `DWDClient`: falls er unerwartet `RadarBackend`-Typen braucht [U], diese Typen minimal mit herauslösen statt Ketten zu ziehen.

## 4. Datenfluss

**Widget (iOS).** `AppIntentTimelineProvider` mit Intent `PlaceEntity` (Auswahl aus `PlaceStore`, Standard: zuletzt in der App gewählter Ort; kein „Aktueller Standort“, siehe E3). Ablauf je `timeline(for:in:)`:
1. Ort laden; `DWDClient.forecast(at:)` direkt (ephemere URLSession; zwei Requests: Lauf-Ermittlung und Punktdaten [B]); Erfolg → `ForecastCache` schreiben.
2. Fehler/offline → `ForecastCache` lesen; Alter anzeigen; ist `isStale` (>20 min), Zustand `stale`, nie „trocken“ [B-Regel aus `plan.md`/`RainForecast.summary`].
3. Einträge: je 5 min über die nächsten ~60 min aus derselben Prognose (`RainOutlook` je Entrypunkt, ohne weiteren Abruf), `policy: .after(<jetzt + 15 min>)`. Damit wenige Reloads (innerhalb des Budgets, [P Q1]) und sich selbst fortschreibende Anzeige „in N Min.“.
4. App ruft nach jedem erfolgreichen Abruf `WidgetCenter.shared.reloadTimelines(ofKind:)` (zählt im Vordergrund nicht gegen das Budget [P Q1]); beim Hintergrundwechsel keine zusätzliche Last.
Darstellung: klein (Status, Minuten, Mini-Balken), mittel (Verlauf 2 h als Balken/Chart), Zubehör Sperrbildschirm rund/rechteckig/Zeile; Datenalter als „Stand HH:mm“ bzw. „veraltet“; `widgetURL` = Deep Link auf den Ort. Datenquelle-Hinweis (DWD) im mittleren Widget klein (Attribution wie in der App [A]).

**Deep Link.** App registriert `showernow://place/<uuid>`; `onOpenURL` in `WeatherApp` → `WeatherStore.select(place)`. Unbekannte ID → App öffnet normal. Universal Links nicht nötig (kein Domain-Eintrag, kein Backend-Aufwand) [A].

**Watch.** Orte kommen vom iPhone per `WCSession.updateApplicationContext` (kleines JSON, nur „zuletzt gewinnt“, [P Q4] opportunistisch im Hintergrund); die Uhr speichert sie in `PlaceStore`. Prognose holt die Uhr **direkt** beim DWD mit `DWDClient` (öffentliche Daten, keine Geheimnisse; Watch Ultra kann WLAN/Mobilfunk, sonst reicht das System-Proxying über das iPhone [A]). Vorteil: kein Aufwand, keine Abhängigkeit von erreichbarem iPhone, gleiche Logik wie Widget. Nachteil: eigener Funkverbrauch; Mitigation: Cache 5 min wie `DWDClient`, Komplikation nutzt dieselbe Timeline-Logik wie Widget (Budget [A] ähnlich). `WCSession`-`transferUserInfo` nicht nötig. Übertragen wird nie ein Standortverlauf, nur die gespeicherten Orte.

**Live Activity** siehe 6.

## 5. Datenschutz

- Keine neue Standorterhebung: Widgets/Watch nutzen nur gespeicherte Orte aus `PlaceStore`; keine Hintergrundortung, kein „Aktueller Standort“-Widget. Das ist auch ohne WidgetKit-Standortneuladung [P Q1] einfacher zu prüfen.
- Kein Standortverlauf: `ForecastCache` hält je Ort nur die letzte Prognose (überschrieben, keine Zeitreihe, keine Zeitstempel der Abrufe außer `referenceTime`); Datei mit `completeFileProtectionUntilFirstUserAuthentication` wie `places.json` [B]. Keine Debuglogs mit Koordinaten/Ortsnamen.
- Widget- und Watch-Abrufe senden Koordinaten wie die App direkt an den DWD (öffentliche Punktabfrage); Datenschutztext ergänzt: „Auch Widgets und Apple Watch rufen die Prognose für gespeicherte Orte direkt beim DWD ab.“ Backend sieht davon nichts.
- Live Activity: Token (Push-to-Start/Activity) sind Gerätekennungen mit Ortsbezug wie die bestehenden Push-Token (`push-benachrichtigungen.md`); App-Privacy-Angaben „Device ID, App-Funktionalität, nicht verknüpft zum Tracking“ prüfen/ergänzen; Löschung mit `DELETE installation` und 410 wie bisher. `ActivityAttributes` enthalten nur Anzeigename (lokal, vom Nutzer vergeben) und Abo-ID, keine Koordinaten [A]. Attributwerte erscheinen auf Sperrbildschirm: Nutzer sollte Ortsnamen so wählen können [A].

## 6. Live Activity „Regen beginnt/endet bald“

**Modell.** `RainActivityAttributes` (statisch: Anzeigename, Abo-/Ort-ID) und `ContentState` (`phase`: `startsIn`/`raining`/`endsIn`/`dry`, `eventDate: Date?`, `intensityClass: Int`, `referenceTime`, optional `staleDate`). Zustand ≤ 4 KB [P Q5-Befund]. UI in `WeatherWidgets` (Sperrbildschirm, Dynamic Island kompakt/minimal/erweitert; Mirror auf Watch Smart Stack automatisch [P Q5 Befund], watch-eigene Darstellung [U]). Countdown per `Text(timerInterval:)`/`Text(date, style: .timer)`, damit ohne Updates minutengenau.

**Start lokal.** App-Vordergrund oder Aktion „Beobachten“ (Button im Ort), `Activity.request` mit `pushType: .token`; Ende bei Trockenheit, spätestens 8 h [P]. Ohne Push wird sie nach App-Sperre veraltet (`staleDate` setzen, Anzeige „veraltet“); lokale Variante deshalb nur als Übergang/Fallback und für Tests, wie schon im Befund (L3) bewertet.

**Start per Push (Ziel).** App beobachtet `Activity.pushToStartTokenUpdates` ([P Q5]) und meldet den Token dem Backend; bei jedem neuen Activity-Token (`pushTokenUpdates`) ebenso. Auslöser serverseitig: dieselbe Auswertung wie die bestehende Mitteilung (`PushEvaluator.step` meldet „Regen in N min“; zusätzlich ein Übergang „Regen endet in N min“ [A], bisher nicht vorhanden). Statt/neben dem Alert sendet das Backend `event: "start"` (mit `attributes-type`, `attributes`, `content-state`, `alert`), danach `update` je neuem Lauf (Priorität 5) und `end` bei Trockenheit/8 h (`dismissal-date`).

**Backend-Änderungen (additiv, Schwesterrepo, Konzept).**
- Migration `007_push_activity.sql`: Spalte `push_installation.la_start_token` (nullable) und Tabelle `push_activity(subscription_id, activity_token, started_at, ends_at)`; Löschkaskade wie Abos; Token-Rotation ersetzt.
- API (alles optional, alte Apps unverändert): `PUT /v1/push/installations/<id>` bekommt optional `live_activity_start_token`; `PUT/DELETE /v1/push/subscriptions/<sub>/activity` mit `activity_token`; Abo-Feld `live_activity: bool` (Standard false). Fähigkeit über `capabilities` in `GET /v1/status` (`live_activity`) wie bei `regions` [B], App bietet die Option nur bei Meldung an.
- Sender: zweiter Pfad im APNs-Sender (`apns-push-type: liveactivity`, Topic `<bundleID>.push-type.liveactivity`, Priorität 5 als Standard, 10 nur für Start/Ende [P Q6-Befund]); 410 → Token löschen. Environment `sandbox`/`production` je Installation wie bisher [B].
- Zusammenspiel mit Push-Regionen: Region-Abos (Kreis) liefern dieselben `aps`-Zustände; Live Activity für Region ist möglich, aber **nicht in v1** (Region ist kein „mein Ort“ mit Zeitpunkt); nur Ortsabos [A]. Pro Installation höchstens 1 aktive Live Activity (Systemlimit je App existiert, Höhe [U]); Wiederholsperre 60 min gilt weiter.
- Tests: Zustandsmaschine (Start/Update/Ende, 8-h-Ende, Token-Rotation, 410), Vapor-Tests Felder/Rückwärtskompatibilität, `FakeApnsSender`; echte Zustellung nur am Gerät.

**Grenzen.** Live Activities können Nutzer je App abschalten (`ActivityAuthorizationInfo`); Push-to-Start-Token kommt erst nach erstem Start der App mit gesetzter Fähigkeit [U]; kein Dauerbetrieb über Tage (Review-Risiko, siehe Befund).

## 7. Tests

- Unit (`WeatherTests`, Zielzugehörigkeit von `Shared/`): `RainOutlook` Tabellentests (Beginn/Ende/stale/Lücken/keine Daten, identisch zum bisherigen `summary`-Verhalten), `PlaceStore` Migration und Round-Trip mit temporärem Verzeichnis (App Group per Parameter), `ForecastCache` (Überschreiben, kein Verlauf, Alter), Timeline-Builder (Einträge, Reload-Zeit, Fallback aus Cache, `.after`), Deep-Link-Parser (gültig/ungültig/fremder Host), `WCSession`-Payload (Codable, Fake-Session), `ContentState`-Codable und Payload-Fixtures gegen das Backend-JSON.
- Backend: siehe 6.
- UI/Simulator: Widget-Previews/Snapshots aller Größen, Lock-Screen-Familien, Light/Dark, Dynamic Type; Watch-Simulator Layout; Live-Activity-Previews (Sperrbildschirm, Island). Pro Ergebnis klar „Simulator“ vs. „Gerät“ benennen.
- Nur am Gerät prüfbar (bleibt offen, nicht als erledigt melden): echtes Reload-Budget, Reaktion auf Datenalter über Stunden, Smart-Stack-Relevanz, Watch-Direktabruf unterwegs, Push-to-Start, Spiegelung, Speicherverbrauch des Widget-Prozesses.

## 8. Arbeitspakete (exklusiver Dateibesitz)

Regel: `project.yml` und Entitlements besitzt nur P0; spätere Pakete legen Dateien in ihren Verzeichnissen ab (Globs). Ein Build-/Simulator-Verantwortlicher je Welle. Höchstens 3 gleichzeitige Worker.

| Nr. | Paket | Besitz (schreibend) | Wer | nach |
|---|---|---|---|---|
| P0 | Projektgerüst: Targets, Bundle-IDs, Entitlements, leere Widget-/Watch-Stubs, URL-Scheme, Embedding, `Base.xcconfig`-Watch-Werte; Build aller Targets, `signing.md` fortschreiben; kein Anlegen von Portal-Ressourcen ohne Nutzer-Freigabe (E2) | `project.yml`, `Configuration/*`, `docs/signing.md`, Stub-Dateien | Claude (Build/Signing-Verantwortung) | E2 |
| P1 | Shared-Schicht: `git mv` nach `Shared/`, `PlaceStore`/`ForecastCache`/`RainOutlook`/`WidgetDeepLink`, `WeatherStore` auf `PlaceStore` umstellen (Migration), Tests | `Shared/**`, `Weather/Models/WeatherStore.swift`, `Weather/Data/*` (verschobene), `WeatherTests/Shared*` | Codex | P0 |
| P2 | Backend Live-Activity-Push (Schwesterrepo): Migration, API, Sender, Fähigkeit, Tests, `api.md` | Schwesterrepo `Push*`, Migrationen, Docs | Codex | Vertrag aus 6 (unabhängig von P0/P1, kann sofort starten) |
| P3 | Widget-Logik: `PlaceEntity`/Intent, Timeline-Provider, Budget-Strategie, Tests | `WeatherWidgets/Logic/**`, `WeatherTests/Widget*` | Codex | P1 |
| P4 | App-Seite: `onOpenURL`, Reload-Hooks (`WidgetCenter`), WCSession-Sender (Orte), Einstellungstexte, Datenschutztext-Entwurf | `Weather/App/WeatherApp.swift`, `Weather/Views/*` (nur Widget-Hinweise), neu `Weather/Watch/PhoneSession.swift` | Codex | P1 |
| P5 | Watch-App: Ortsliste, Prognoseansicht (kompakt), `WCSession`-Empfang, Direktabruf, Tests | `WeatherWatch/**` | Codex | P1 |
| P6 | Widget-UI: Home klein/mittel, Zubehör Sperrbildschirm, Gestaltung, Previews/Screenshots, Zustände (stale/keine Daten) | `WeatherWidgets/Views/**` | Claude (Gestaltung, Sichtprüfung) | P3 |
| P7 | Komplikationen/Smart Stack (watchOS-Widgets) auf Basis `RainOutlook` und Timeline-Builder | `WeatherWatchWidgets/**` | Codex | P3, P5 |
| P8 | Live Activity App-Seite: Attributes, UI (Sperrbildschirm/Island), `ActivityManager` (lokal + Token-Meldung), `PushGateway`-Felder, Tests | `Shared/LiveActivity/**`, `WeatherWidgets/LiveActivity/**`, `Weather/Push/ActivityManager.swift`, `Weather/Push/PushGateway.swift` | Codex | P2-Vertrag, P3 |
| P9 | Integration/Build/Signing/TestFlight: Archiv mit Watch-App, Export-Prüfung (Entitlements, Embedding), Gerätetests mit Nutzer, Buildnummer, `status.md` | Build, `docs/status.md`, `docs/testflight-upload.md` | Claude (Build-Verantwortung) | P0 bis P8 |
| P10 | Unabhängiges Review (Datenschutz, Speicher, Budget, Push-Zustand) | nur Befunddatei unter `docs/reviews/` | Codex | vor P9 |

Anteil Codex: 8 von 11 Paketen (P1, P2, P3, P4, P5, P7, P8, P10 = 73 %); Claude: P0, P6, P9.

Wellen: **W0** P0 (allein, belegt Build/Simulator); parallel dazu darf P2 beginnen (anderes Repo). **W1** P1 (plus P2 weiter). **W2** P3 + P4 + P5 (drei Worker, getrennte Verzeichnisse; P2 sollte vorher fertig sein oder die Kapazität bleibt bei drei). **W3** P6 + P7 + P8. **W4** P10 dann P9. Eine erste Auslieferung (nur Home-/Sperrbildschirm-Widgets: P0, P1, P3, P4, P6) ist ohne Watch und Live Activity möglich; Watch (P5, P7) und Live Activity (P2, P8) können danach folgen. Widget-Prozess-Speicher und `DWDClient`-Abhängigkeiten zuerst in P1/P3 am Simulator/Gerät messen.

## 9. Nutzerentscheidungen (max. 4)

- **E1 Reihenfolge der Auslieferung.** (a) Zuerst Widgets (P0, P1, P3, P4, P6) als Build 15, Watch danach, Live Activity zuletzt; (b) alles in einem Build. **Empfehlung (a)**: kleinere Prüfung, Gerätetests der Widgets zuerst, Live Activity braucht ohnehin Backend-Betrieb (APNs-Key, noch offen) und eine Entscheidung nach Radfahrer-Feedback.
- **E2 Neue Signing-Ressourcen.** Darf der Build-Agent per Xcode (Automatic Signing, Team `J2DU2P47XW`) die App-IDs `.widgets`, `.watchkitapp`, `.watchkitapp.widgets` und die App Group `group.de.linolaske.showernow` im Developer-Portal anlegen lassen? **Empfehlung: ja**, freigegeben für genau diese vier Ressourcen; sonst bleibt P0 bei lokalem Build ohne Signing.
- **E3 Widget-Ortsauswahl.** Nur gespeicherte Orte (Empfehlung) oder zusätzlich „Aktueller Standort“ (braucht Standortfreigabe „Immer“/WidgetKit-Standort, mehr Datenschutz-Aufwand). **Empfehlung: nur gespeicherte Orte**, passt zu „keine Hintergrundortung“.
- **E4 Live-Activity-Umfang.** Nur per Push-to-Start (Empfehlung, entspricht Befund L4, lokale Variante nur als Fallback) oder auch schon rein lokal (L3) vorab. **Empfehlung: erst nach Widgets/Watch, mit Push**; lokal allein bringt wenig Nutzen und riskiert veraltete Anzeigen.

## 10. Nicht geprüft

Keine Builds, keine Portal-Prüfung der App-IDs/Groups, `XcodeGen`-Typen für watchOS und Embedding, Speicherlimit und Reload-Verhalten am Gerät, tatsächliche Watch-Direktabrufe, Aufnahmefähigkeit der DWD-Last durch zusätzliche Abrufe (je Widget-Reload ca. 2 Requests; bei 70 Reloads/Tag und mehreren Widgets gering [A], nicht gemessen), Live-Activity-Mindestversionen und Limits, Review-Verhalten von Apple. Apple-Doku nur in den oben genannten Seiten gelesen (Auszüge, keine vollständige Prüfung).
