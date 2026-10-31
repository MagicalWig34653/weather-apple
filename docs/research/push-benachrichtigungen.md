# Push-Benachrichtigungen für gespeicherte Orte (Architekturentwurf)

Stand: 31. Oktober 2026. Reiner Entwurf, kein Produktcode, nichts bei Apple angelegt, kein Backend geändert. Auslöser: Wunsch nach Meldungen wie „in 20 Minuten Regen am Ort X“. Grundlage: `concept-v2.md` §4.6, §5, §6, `decisions.md` (Server-Cache, Datenschutz), `research/backend-radar-cache.md`, `research/dwd-validation.md`, Backend-Code `Sources/RadarCore` (Stand lokal gelesen, nur lesen).

Kennzeichnung: **[B]** bestätigt (Repo-Dokument oder Code gelesen), **[A]** Annahme, **[U]** ungeprüft. Apple-Aussagen (APNs, UserNotifications, App Privacy) stammen aus meinem Wissensstand zu den Apple-Entwicklerdokumenten und wurden in dieser Sitzung **nicht** neu von developer.apple.com abgerufen: durchgehend **[U]**, vor Umsetzung gegen die aktuelle Doku zu prüfen (Links in Abschnitt 8). DSGVO-Aussagen sind keine Rechtsberatung.

## 1. Befund zur Ausgangslage

- [B] Das Backend (Swift/Vapor, MariaDB, Swarm) holt pro 5-Minuten-Lauf 25 Vorhersage-Slots als **WMS-PNG** (`image/png`, 1024 px Breite, EPSG:3857, Bbox fest) und speichert sie als verlustfreies WebP (`Ingestor`, `ImagePipeline`). Es gibt **keinen HDF5-Parser**; die RV-Tars werden nicht verwendet.
- [B] Leader/Lease existiert: `Repo.acquireLeader(name:owner:leaseSeconds:)`/`releaseLeader` (Backfiller nutzt Name `backfill`, Lease 180 s); Läufe werden per `tryClaim`/`renew`/`publish` atomar und owner-geprüft beansprucht. Es gibt `MemoryRepo` (Test) und `MariaRepo`.
- [B] Der Radar-Dienst führt keine Zugriffsprotokolle; der Reverse Proxy (Zoraxy) sieht IPs, sein Logging ist offen (`decisions.md`).
- [B] Secrets: `deploy/swarm/stack.yaml` nutzt Swarm-Secret `showernow_db_password` (`DB_PASSWORD_FILE=/run/secrets/db_password`); `.env` heißt immer `.env`, wird von `setup.sh` geschrieben, enthält nie Secretwerte.
- [B] Wettereinheit: der WMS-Wert ist Akkumulation mm/5 min, nicht mm/h (`dwd-validation.md`). Die UI-Schwelle 0,1 mm/h ist ausdrücklich noch keine Push-Ereignisdefinition (`data-contract.md`).

## 2. Datenminimierung und Alternative ohne Serverdaten

### 2.1 Variante S (Server-Push, empfohlen für „bei geschlossener App“)

Der Server speichert je aktiviertem Ort das Minimum:

| Feld | Zweck | Anmerkung |
|---|---|---|
| APNs-Gerätetoken | Zustellung | wechselt; bei 410 löschen [U] |
| Installationskennung (zufällig, UUID) + Hash des Installationsgeheimnisses | Autorisierung von Änderungen/Löschen | Secret im Keychain, Server speichert nur Hash; kein Konto |
| `grid_version`, Zelle (x, y) des Serverrasters | Auswertung | **keine** Koordinaten, **keine** Ortsnamen; App rechnet Koordinate lokal in die Zelle |
| Schwellenstufe, Vorlauf (z. B. 10/20/30 min), optional Ruhezeit | Regel | wenige Enumerationswerte |
| Sprache (de/en) | Meldungstext | alternativ Text komplett in der App per Notification-Service-Extension [U]: nein, nur Schlüssel + Zahlen im Payload reichen |
| `created_at`, `last_seen_at`, `last_notified_*` | Ablauf, Wiederholsperre | nur zuletzt, keine Historie |

Nicht speichern: exakte Position, Ortsnamen, IP (Anwendung loggt nicht), Standortverlauf, Geräte-/Werbe-IDs, Zustellprotokolle über das nötige Maß hinaus. Dynamischer „aktueller Standort“ ist für die erste Ausbaustufe **ausgeschlossen** (`concept-v2.md` verlangt ohnehin nur zuletzt übermittelte Zelle; Hintergrundstandort bräuchte Always-Berechtigung, eigener Entscheid).

Zellgröße: [B] Das Serverraster ist das Pixelraster des Ingests (1024 × 1311 px über ca. 1124 km × 1439 km EPSG:3857, also etwa 1,1 km pro Pixel in Web-Mercator-Metern, in Deutschland real etwa 0,7 km Ost-West). Eine solche Zelle ist **weiterhin personenbezogen** (`concept-v2.md` §6.2), also keine Anonymisierung. [A] Gröbere Speicherung (z. B. 3 × 3 Pixel zu einer Zelle) verschlechtert die Warnung nur wenig, da die DWD-Auflösung ohnehin 1 km beträgt, und senkt die Genauigkeit des Ortsbezugs; als Entscheidung E3 ausgewiesen.

Löschung/Ablauf: sofort bei 410 `Unregistered`/`BadDeviceToken` [U]; Installation ohne `last_seen_at`-Aktualisierung (App-Start sendet leisen „Heartbeat“ nur wenn Pushs aktiv) nach 60 Tagen [A] löschen; „Alle Daten löschen“-Endpunkt (DELETE mit Installationsgeheimnis); Backups: Aufbewahrung der DB-Sicherung muss kürzer oder gleich der Löschfrist dokumentiert sein, sonst im Datenschutztext nennen [U, Betrieb prüfen].

### 2.2 Variante L (ohne Ortsdaten auf dem Server): Background Refresh + lokale Mitteilungen

Idee: `BGAppRefreshTask` lädt `latest.json`/Slots (Ganzbilder ohne Ortsbezug), wertet Pixel lokal aus, plant lokale `UNNotificationRequest`.

Grenzen [U, Apple-Doku zu BackgroundTasks/UserNotifications, nicht neu geprüft]:
- Ausführungszeitpunkt bestimmt das System (Nutzungsmuster, Akku, Low Power, Netz, Force-Quit sperrt Hintergrundstart); typisch selten und unregelmäßig, nicht im 5-Minuten-Takt. Für „Regen in 20 Minuten“ ist das nicht verlässlich.
- Lokale Mitteilungen lassen sich nur mit Zeit-/Ortstrigger planen, nicht von neuen Daten auslösen; geplante Meldungen wären zum Auslösezeitpunkt veraltet (Prognose ändert sich pro Lauf).
- Standort-Trigger (Region Monitoring) kennt kein Wetter.
- Stille Pushes (`content-available`) als Weckruf werden gedrosselt und sind best effort, also kein Ersatz.

Ehrlicher Vergleich:

| Kriterium | S: Server-Push | L: lokal |
|---|---|---|
| Datenschutz | Token + Zelle auf Server (personenbezogen, offenlegungspflichtig) | nichts neu auf dem Server; stärkstes Argument |
| Zuverlässigkeit bei geschlossener App | gut, aber best effort (APNs) | schwach, vom iOS-Scheduling abhängig |
| Aktualität | Prüfung nach jedem Lauf (ca. 3,5 min nach Nominalzeit) | höchstens bei Wake-ups |
| Aufwand | Backend + APNs-Key + Datenschutzänderungen | nur App; Hintergrundmodus `fetch` |
| Akku | gering | zusätzliche Hintergrundläufe |

Fazit [A]: L erfüllt das Produktversprechen („zuverlässige Warnung“) nicht; L nur als **Zusatz** (Hinweis bei App-Start/Foreground, oder Rückfall wenn Push abgelehnt, deckt `concept-v2.md` §4.6) sinnvoll. Keine zwei unkoordinierten Warnsysteme gleichzeitig aktiv schalten (Doppelmeldungen).

## 3. Backend-Entwurf

### 3.1 Tabellen (Entwurf, Migration `003_push.sql` später)

- `push_install(id CHAR(36) PK, secret_hash BINARY(32), token VARBINARY(64), env ENUM('sandbox','production'), locale CHAR(2), created_at, last_seen_at, token_updated_at)`
- `push_sub(id PK, install_id FK ON DELETE CASCADE, grid_version SMALLINT, cell_x SMALLINT, cell_y SMALLINT, threshold TINYINT, lead_min TINYINT, quiet_from/quiet_to optional, enabled, last_state TINYINT, last_event_id VARCHAR(40), last_sent_at, created_at)`; Index `(grid_version, cell_x, cell_y)`.
- `push_outbox(id PK, sub_id FK ON DELETE CASCADE, dedupe_key VARCHAR(64) UNIQUE, payload_kind, payload_json, apns_collapse_id, expires_at, attempts, next_attempt_at, status, created_at)`; zugestellt/abgelaufen nach kurzer Frist (Stunden) löschen. Keine Dauerprotokolle.
- Leader nutzt vorhandene Leader-Tabelle (Name `push`, kein neues Schema). [A]

### 3.2 Auswertung nach jedem Lauf

1. Trigger: nach erfolgreichem `publish` (Replica, die den Lauf veröffentlichte) oder periodisch beim Leader (empfohlen, siehe 3.3), der den neuesten `PublishedRun` mit noch nicht ausgewertetem `run_id` liest (`push_state.last_run_id`, 1 Zeile).
2. Je **eindeutiger Zelle** (`SELECT DISTINCT grid_version, x, y` über aktivierte Subs) die 25 Slot-Werte lesen, nicht je Nutzer. Pixel→Klasse im Speicher: die 25 WebP-Slots decodieren (libwebp ist bereits eingebunden) und nur die abonnierten Pixel lesen (~O(Zellen), nicht O(Pixel)).
3. Regeln pro Sub anwenden: Regenbeginn = „aktuell trocken (Slots ≤ 0 unter Schwelle) und in den nächsten `lead_min` ein Slot ≥ Schwelle“. [A] Ereignis-Kennung = (sub, run-unabhängiger Beginn gerundet auf 15 min).

**Kernfrage: Pixel → Regenintensität aus dem WebP?** [B/A] Das gespeicherte Bild ist die DWD-**Darstellung** (Palette mit 259–260 verschiedenen RGBA-Werten laut `ImagePipeline`, lossless, deshalb exakt rückführbar auf Palettenfarben). Es ist eine Klassenfarbe, kein Messwert:
- Bei den Schwellen „kein Regen / leicht / mäßig / stark“ ist die Ableitung zuverlässig **wenn** die Zuordnung Farbe → Intensitätsklasse aus der DWD-Legende (SLD des Layers `dwd:Niederschlagsradar`, GetLegendGraphic/GetStyles) bestätigt und als Tabelle fest hinterlegt ist. Diese Zuordnung liegt im Repo **nicht** vor [U].
- Das Bild enthält zusätzlich Maske/Rand (weiß, grau, magenta, laut `backend-radar-cache.md` §1b) und Transparenz; die Nicht-Regen-Klassen müssen explizit ausgeschlossen werden. Randpixel der Abdeckung nicht auswerten.
- Genauigkeit: Klassengrenzen der Palette, Einheit mm/5 min vs. mm/h der Legende klären [U]; Subpixel-Resampling (WMS mit 1024 px statt nativ 900 × 1100 Raster) kann Werte benachbarter Zellen mischen [A]; Palette ist nur dort ein exaktes Abbild, wo DWD nicht interpoliert.
- Alternative bei Bedarf: Rohwerte aus RV-HDF5 (`raw*gain+offset` bestätigt in `dwd-validation.md`) über zweiten Ingest und eigenen Parser; Mehraufwand und Parser-Risiko (`concept-v2.md` §5.3), aber exakte mm/5 min. GetFeatureInfo pro Ort scheidet aus (Ortsbezug im DWD-Request, Last).

Empfehlung [A]: Stufe 1 Palette (grobe Stufen, nur „Regen beginnt/endet“ mit 2–3 Intensitätsklassen); HDF5 nur, wenn Tests zeigen, dass Klassen zu grob sind.

### 3.3 Genau ein Versender bei 2–3 Replicas

- Leader `push` über das vorhandene `acquireLeader` (Lease z. B. 60 s, Erneuerung vor jedem Batch, bei Verlust sofort stoppen wie `Backfiller`). Nur der Leader wertet aus und sendet.
- Zusätzliche Absicherung gegen Split-Brain/Lease-Ablauf: `dedupe_key` UNIQUE in `push_outbox` (INSERT IGNORE), `apns-collapse-id` = Ereignis-Kennung (iOS ersetzt dann eine Doppelzustellung durch dieselbe Meldung [U]).
- Auswertungsstand `last_run_id` wird in derselben DB-Transaktion wie das Einfügen der Outbox-Zeilen gesetzt; kein Netzwerk in Transaktionen (`concept-v2.md` §5.4). Versand liest die Outbox (`FOR UPDATE SKIP LOCKED` oder Owner/Lease-Spalte), sendet, markiert; Absturz zwischen Senden und Markieren kann zu Duplikaten führen (akzeptiert, Abschnitt 3.5).

### 3.4 Entprellung und Wiederholsperre

- Zwei-Zustands-Automat je Sub (`dry`/`wet-expected`) mit Hysterese: Meldung erst, wenn die Bedingung in **zwei aufeinanderfolgenden Läufen** gilt (Prognosesprünge) [A]; Rücksetzen auf `dry` erst nach ≥ 30 min trocken.
- Wiederholsperre: höchstens 1 Meldung je Sub und 60–90 min [A]; Ruhezeit (Nacht) optional; keine Meldung, wenn Lauf älter als 20 min (Regel `decisions.md`) oder Slots unvollständig.
- Überlappende Orte desselben Geräts: ein Push je Gerät und Ereignisfenster zusammenfassen (Orte in einem Text), `thread-id` je Ort.

### 3.5 Zustellung, Rate-Limits, Fehler

APNs (alles [U], Apple-Doku „Sending notification requests to APNs“, „Handling notification responses from APNs“, „Establishing a token-based connection to APNs“):
- HTTP/2 an `api.push.apple.com` (Produktion) bzw. `api.sandbox.push.apple.com` (Entwicklung); `apns-topic` = Bundle-ID, `apns-push-type: alert`, `apns-priority` 10 für zeitnahe Warnung, `apns-expiration` kurz (z. B. Prognosefenster, 15–20 min), `apns-collapse-id`; Payload ≤ 4 KB, nur Text-Schlüssel und Zahlen, keine Ortsnamen.
- Auth: JWT (ES256) mit .p8, Key-ID, Team-ID; Token höchstens ~1 h wiederverwenden, nicht öfter als etwa alle 20 min neu erzeugen; sonst `429 TooManyProviderTokenUpdates`. Verbindungen wiederverwenden (keine Verbindung je Nachricht), wenige parallele Streams.
- Fehler: 410 `Unregistered`/400 `BadDeviceToken`/`DeviceTokenNotForTopic` → Install löschen; 403 `ExpiredProviderToken` → JWT neu; 429 `TooManyRequests` und 5xx → Backoff mit Jitter, begrenzte Wiederholung, Meldung nach Ablauf verwerfen; Netzfehler → Outbox.
- Best effort: APNs garantiert weder Zustellung noch Zeitpunkt; Duplikate sind möglich. Der Produkttext darf keine Garantie versprechen (`concept-v2.md` §5.2).
- Last [A]: pro Lauf nur Subs mit Zustandswechsel; erwartbar klein.
- Der Dienst ruft bei APNs nur Token + Payload ab; kein Eigen-Logging von Tokens (kein Klartext in Logs).

## 4. App-Entwurf

- Berechtigungsfluss: Mitteilungsberechtigung erst nach einer eigenen Erklärung im Ort-Einstellungsdialog („Regenwarnung für diesen Ort“) anfragen (`UNUserNotificationCenter.requestAuthorization([.alert,.sound])`), nicht beim Start. Bei Ablehnung: Schalter zeigt Hinweis + Link zu den Systemeinstellungen; lokale Hinweise nur im Vordergrund. Einmalige Datenschutzinformation **vor** erster Aktivierung (`concept-v2.md` §6.4). `.timeSensitive` nicht verwenden (braucht Entitlement, hier unnötig) [U].
- Registrierung: nach Zustimmung `UIApplication.registerForRemoteNotifications()`; Token in `didRegisterForRemoteNotificationsWithDeviceToken` an `PUT /push/v1/installations/{id}` (HTTPS, Installationsgeheimnis im Header); jeder App-Start aktualisiert Token + `last_seen`; Fehler `didFail…` sichtbar machen. App-Abgleich: Liste der serverseitigen Abos anzeigen (`GET`), Löschen je Ort und „Alle Serverdaten löschen“.
- Einstellungen je Ort: Schalter, Vorlauf (10/20/30 min), Mindestintensität (leicht/mäßig/stark), Ruhezeit. Ortsname und Koordinate bleiben lokal, übertragen wird nur die Zelle (die App nutzt dieselben Bbox-/Raster-Konstanten wie das Backend, versioniert über `grid_version`; Rasterwechsel erfordert Neuregistrierung durch die App).
- Projekt: Capability „Push Notifications“ erzeugt `aps-environment`-Entitlement (`development` bei Debug-Signing; beim Archivieren/TestFlight/App Store setzt Xcode-Signing `production` ein [U]). Hintergrundmodus „Remote notifications“ nur für stille Pushes, hier nicht nötig. Kein App-Gruppen-, Extension- oder Entitlement-Ausbau in Phase 1. Meldungstext aus `loc-key`/`loc-args` im Payload (lokalisiert in der App), keine Service-Extension nötig [A].
- Apple-Developer-Seite (nur beschrieben, **nichts angelegt**): App-ID/Bundle-ID mit aktivierter Capability „Push Notifications“ (Provisioning-Profile danach neu erzeugen, Xcode „automatic signing“ erledigt es [U]); ein **APNs-Auth-Key (.p8)** unter Certificates, Identifiers & Profiles → Keys (Häkchen APNs; ein Key gilt für alle Apps des Teams, Sandbox und Produktion, nur einmal herunterladbar, Anzahl pro Konto begrenzt [U]); benötigte Werte: Key-ID (10 Zeichen), Team-ID, Bundle-ID als `apns-topic`. Bundle-ID/Team-ID sind laut `AGENTS.md` vorläufig; Änderung entwertet Registrierungen.
- Sandbox vs. Produktion [U]: Xcode-Debug-Builds erhalten Sandbox-Tokens, TestFlight- und App-Store-Builds Produktionstokens. Ein Token gilt nur in seiner Umgebung (falscher Endpunkt → `BadDeviceToken`). Server speichert `env` je Install: die App meldet es (Build-Konfiguration: DEBUG → sandbox, sonst production); der Sender wählt den Host danach. TestFlight testet daher den Produktionsweg; Sandbox nur für Xcode-Läufe.

## 5. Datenschutz und App-Privacy (Auswirkungen)

- Bisher [B]: Radar-Dienst sieht keinen Ort, keine Cookies; App-Privacy-Variante A („keine Daten erhoben“, begründet in `apple-externe-tests.md`). Mit Push ändert sich das **grundlegend**: der Server speichert Gerätetoken + Zelle dauerhaft pro Installation.
- Apple App Privacy (Fragebogen in App Store Connect) [U, Apple-Doku „App privacy details“]: Angabe von **Device ID** (Push-Token/Installationskennung) und **Coarse Location** (Zelle ca. 1 km; Apple kennt „Coarse“ ≈ < 3 km² ; ob eine Zelle darunter fällt oder als „Precise“ gelten sollte, ist zu entscheiden, Empfehlung: konservativ als Coarse deklarieren und Zelle nicht feiner speichern), Zweck „App Functionality“, nicht für Tracking, mit Nutzer verknüpft = Ja (stabile Installationskennung) [A]. Die Aussage „Daten werden nicht erhoben“ (Variante A) entfällt, sobald Push live ist.
- Datenschutzerklärung (`/datenschutz` im Backend, `docs-site/content` in beiden Repos zu synchronisieren, siehe `decisions.md`): neuer Abschnitt „Regenwarnungen (optional)“: Zweck, gespeicherte Daten (Token, Installationskennung, Rasterzelle ~1 km, Einstellungen, Zeitpunkte), Rechtsgrundlage Art. 6 Abs. 1 lit. a/b DSGVO (Einwilligung bzw. Vertragsdurchführung, vom Verantwortlichen zu bestimmen), Empfänger Apple (APNs, Übermittlung von Token + Meldungstext), Speicherdauer (Löschfristen aus 2.1), Rechte (Auskunft/Löschung per In-App-Funktion, da keine Kontoidentität zur Identifizierung), Hinweis, dass die Zelle potenziell personenbezogen ist und der Reverse Proxy IPs sehen kann. Impressum/Verantwortliche Stelle nötig [U].
- DSGVO-Grundsätze (Art. 5, 25, 32) als Prüfmaßstab: Datenminimierung, Zweckbindung, Speicherbegrenzung, Privacy by Design, Sicherheit der Verarbeitung (TLS, Hash des Geheimnisses, Token nie im Log). Auftragsverarbeitung/Hosting: Betrieb in Eigenregie, Zoraxy-Logging klären. DPIA-Notwendigkeit bei dieser Größenordnung voraussichtlich nein [A, keine Rechtsberatung].
- In-App-Texte: Info-Sheet „Datenschutz“ ergänzen; Erklärung vor Aktivierung zeigt exakt die gespeicherten Felder.
- Zuordnung von Missbrauch: Registrierung ohne Konto ist leicht missbrauchbar (Token-Spam); Rate-Limit pro Netz ohne IP-Speicherung schwierig. Optionen: Begrenzung der Subs je Installation (z. B. 10), globales Limit am Reverse Proxy, App Attest (erst später) [A].

## 6. Secrets im Swarm

Analog zu `showernow_db_password` [B]:
- Zwei Swarm-Secrets: `showernow_apns_key` (Inhalt der .p8-Datei), optional `showernow_apns_key_id`/Team-ID als normale Variablen in `.env` (nicht geheim, aber nicht committen, wenn privat). Namen über `.env` konfigurierbar (`APNS_KEY_SECRET`, Standard `showernow_apns_key`), wie `DB_PASSWORD_SECRET`.
- Im Stack: `secrets: [db_password, apns_key]`, Umgebung `APNS_KEY_FILE=/run/secrets/apns_key`, `APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_TOPIC`, `APNS_ENV` (`sandbox|production|both`); Dienst liest Datei nur beim Start/Reload und loggt nie den Inhalt.
- `setup.sh`: Secret aus Datei (`APNS_KEY_FILE` Pfad, nie Wert in `.env`/Argumenten), `docker secret create`; Rotation = neues Secret mit neuem Namen, Stack-Update, altes entfernen; alter Key bleibt bei Apple bis zum Widerruf gültig.
- Nie im Repo, nie in Dockerfile, nie in Agent-Chats; `.p8` bleibt zusätzlich in Nutzer-Backup (Passwortmanager). Ohne Key startet der Push-Teil deaktiviert; der Radar-Dienst läuft unverändert weiter (Entkopplung, `concept-v2.md` §Optionale Infrastruktur).

## 7. Arbeitspakete (Reihenfolge, Dateibesitz, Tests)

Alle ausführenden Agents frisch (`docs/team.md`). Backend-Pakete im Schwesterrepo (Dateibesitz dort), App-Pakete hier.

| # | Paket | Besitz | Abhängig | Test ohne echtes APNs |
|---|---|---|---|---|
| P0 | Entscheidungen E1–E8 (Nutzer), Doku in `decisions.md` | docs | | |
| P1 | Farb→Intensität-Tabelle aus DWD-Legende (SLD) + Maske; Messreihe an echten Läufen | Backend `Sources/RadarCore/RainClass.swift`, Tests | P0 | Unit-Tests mit Fixture-WebP/PNG |
| P2 | Schema `003_push.sql`, `PushRepo`-Protokoll, `MemoryPushRepo`, `MariaPushRepo` | Backend `Repo`-Dateien push | P0 | Repo-Vertragstests wie vorhanden (Memory + MariaDB-Container) |
| P3 | Push-API (`/push/v1/…` PUT/GET/DELETE), Auth mit Geheimnishash, Limits | Backend `PushApi.swift` | P2 | Vapor-Tests, keine Netzwerkzugriffe |
| P4 | Auswertung + Zustandsautomat + Outbox, reine Funktion (Slots, Subs, Uhr) | Backend `PushEvaluator.swift` | P1, P2 | Tabellentests (Beginn, Ende, Hysterese, Sperre, veraltete Läufe) |
| P5 | `ApnsSender`-Protokoll, `FakeApnsSender` (Antwortcodes 200/410/429/5xx skriptbar), JWT-Erzeugung (ES256, Testkey) | Backend `Apns*.swift` | P2 | Fake-Gateway als lokaler HTTP/2-Server in Tests; Test: 410 löscht, 429 Backoff, Collapse-ID |
| P6 | Leader-Schleife `push` (acquireLeader), Zusammenbau, Konfiguration, Stack/Secret, `setup.sh` | Backend `main.swift`, `deploy/swarm/*` | P3–P5 | Zwei Instanzen gegen MemoryRepo: genau ein Versender; Leader-Verlust stoppt |
| P7 | Datenschutzseite `/datenschutz` + Doku | Backend `docs-site/content` und `docs/` | P0 | Texttest (Link-/Pflichtabschnitte) |
| P8 | App: `PushRegistration`-Client, Ort-Einstellungen, Berechtigungsfluss, Entitlement, Info-Sheet | App `Weather/…` (neue Dateien), `project.yml`, Info-Sheet | P3 (Vertrag) | `URLProtocol`-Mock, Fake-Notification-Center; UI-Test nur Flusslogik |
| P9 | End-to-End Sandbox: echtes Gerät, Debug-Build, Sandbox-Key, Test-Endpunkt (nur dev) | Nutzer + Build-Agent | P6, P8 | manuell |
| P10 | TestFlight-Produktionsweg, App-Privacy-Update, Datenschutz live | Nutzer | P9 | manuell |

Parallel möglich nach P0: P1, P2/P5-Protokolle, P8-UI-Skelett (höchstens drei Worker; Build-/Simulator-Ressourcen genau ein Verantwortlicher). Kein Paket legt Signing-/Store-Ressourcen an.

Was **nur der Nutzer** tun kann: Entscheidungen E1–E8; APNs-Key in Apple Developer erzeugen und laden, Push-Capability an der Bundle-ID aktivieren; Key als Swarm-Secret auf dem Server anlegen; App-Privacy-Angaben und Datenschutz-URL in App Store Connect ändern; Zoraxy-Logging prüfen/festlegen; Test auf echtem Gerät und Sandbox/TestFlight; Impressum/Verantwortliche Stelle und rechtliche Bewertung; Entscheidung über Hosting/Backups.

## 8. Quellen (Apple, vor Umsetzung neu zu lesen) [U]

developer.apple.com/documentation/usernotifications (Registering your app with APNs; Asking permission to use notifications), …/usernotifications/sending-notification-requests-to-apns, …/handling-notification-responses-from-apns, …/establishing-a-token-based-connection-to-apns, …/setting-up-a-remote-notification-server; …/backgroundtasks (BGAppRefreshTask); developer.apple.com/app-store/app-privacy-details; Art. 5, 6, 13, 17, 25, 32 DSGVO (eur-lex.europa.eu, gesetze-im-internet.de/ bdsg).

## 9. Entscheidungen für den Nutzer (mit Empfehlung)

- **E1 Feature überhaupt starten?** Es ist der Bruch der Zusage „keine Serverdaten“ (App-Privacy Variante A entfällt). Empfehlung: ja, aber opt-in je Ort, nach der nutzbaren App (`decisions.md` Punkt 5), erst nach Build-12-Stand.
- **E2 Variante S vs. L.** Empfehlung: S für Push bei geschlossener App; L nur als Zusatz bei Ablehnung. Nicht beides gleichzeitig als Warnquelle.
- **E3 Rastergröße auf dem Server.** Empfehlung: Pixelraster des Ingests (~1 km) und nicht feiner; Alternative 3×3 gröber für mehr Schutz (Genauigkeit sinkt leicht).
- **E4 Datenquelle der Intensität.** Empfehlung: Stufe 1 aus Palettenfarben (grobe Klassen, Legendentabelle belegen), HDF5 erst bei Bedarf.
- **E5 Meldungsregel.** Empfehlung: nur „Regen beginnt in N min“ (N = 10/20/30), Hysterese 2 Läufe, 60–90 min Sperre, Standard-Schwelle „leicht“; „Regen endet“ erst später; kein dynamischer Standort in Phase 1.
- **E6 Aufbewahrung.** Empfehlung: 60 Tage Inaktivität, sofort bei 410, DELETE in der App, Backupfrist dokumentieren; Outbox nur Stunden.
- **E7 Rechtsgrundlage/Verantwortlicher/Impressum, Hosting-Logs (Zoraxy).** Empfehlung: Einwilligung (Opt-in) als Grundlage, Zoraxy ohne IP-Zugriffslog oder mit Kürzung; vor Livegang klären, ggf. juristisch prüfen lassen.
- **E8 Missbrauchsschutz.** Empfehlung: Limit Subs je Install (10) und Installs gesamt, Rate-Limit am Proxy; App Attest später, erst bei realem Missbrauch.
- **E9 Bundle-ID/Team-ID final?** Empfehlung: erst festlegen, bevor APNs-Key/Capability eingerichtet werden, da `apns-topic` und Profile daran hängen.

## 10. Nicht geprüft

Alle Apple-Aussagen (Abschnitte 3.5, 4, 5, 8) nicht neu gelesen; Farb→Intensität-Zuordnung nicht verifiziert; keine Last-, Leader- oder Zustellmessung; Live-Zustand des Swarm unbekannt (siehe `status.md`); Rechtsfragen nicht beurteilt; kein Build, kein Test.
