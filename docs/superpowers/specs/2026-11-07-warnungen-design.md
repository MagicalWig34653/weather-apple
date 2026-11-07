# Design: Teilprojekt 1 "Warnungen (Unwetter, Frost, Glatteis)"

Stand: 7. November 2026 (freigegeben, §9 beantwortet, W0 erledigt, siehe Plan `docs/superpowers/plans/2026-11-07-warnungen-plan.md`). Nur Spezifikation, kein Code. Kennzeichnung: **[B]** am Code/Dokument gelesen (Quelle genannt), **[G]** am 07.11.2026 an Primärquelle geprüft, **[A]** Annahme/Entwurf, **[N]** nicht geprüft. Basis: `docs/research/unwetter-temperatur-frost.md`, `docs/research/push-regionen.md`, `docs/decisions.md`, Backend-Repo (Schwesterrepo, Pfade relativ zu dessen Wurzel).

## 1. Ziel und Nicht-Ziele

**Ziel.** Amtliche DWD-Warnungen (Unwetter allgemein, Frost, Glatteis/Glätte) für gespeicherte Orte und Gebiete (a) als Push bei geschlossener App und (b) als Ansicht in der App (Liste und Karte aller aktiven Warnungen). Text, Stufe und Zeiten unverändert vom DWD, mit Quelle und Ausgabezeit und dem Hinweis "Kein Ersatz für amtliche Warnkanäle (WarnWetter-App, NINA)".

**Nicht-Ziele.** Keine eigene Bewertung oder Umformulierung von Warntexten. Kein NINA/MoWaS, keine Critical Alerts, keine Live Activity. Kein Standort-/Unterwegs-Warnen. Keine eigene Frost-/Glätteschätzung aus ICON-D2 (Teilprojekt 2) und keine Temperatur-/Feuchte-/Waldkarte (Teilprojekt 3); beide nur über die Schnittstellen in 3.7. Kein Hitze-, UV- und Nebelwarnen in v1.

## 2. Befunde, die den Entwurf bestimmen

- **Glätte führt der DWD [G]:** `warnkriterien.html` listet Glätte/Glatteis: Stufe 1 "Glätte (vereinzelt)" (Rutschgefahr durch überfrierende Nässe oder Reif), Stufe 2 "Markante Glätte", Stufe 3 "Glatteis" (Beeinträchtigungen auf allen Verkehrswegen), Stufe 4 "Extremes Glatteis". Frost: Stufe 1 "Frost" (verbreitet unter 0 °C, bis 800 m), Stufe 2 "Strenger Frost" (< -10 °C). Das ist Glätte durch Wetter auf Verkehrswegen, kein amtlicher Straßenzustand (Straßenwetterdienste der Länder/Meistereien): Straßenzustand ist **nicht** Teil dieses Teilprojekts. Glätte ohne DWD-Warnung (z. B. lokal, unterhalb der Warnschwelle) gehört zu Teilprojekt 2. **[G] 07.11.2026 12:38, echte Meldungen (6 x FROST, Stufe 1):** siehe 3.2a. **[N]** bleibt: ob und unter welchem Ereigniscode/Namen der Feed Glätte (Stufe 1/2) von Glatteis (3/4) trennt, die Codes für Gewitter/Sturm/Regen/Schnee/Tauwetter und Werte von `severity` 2 bis 4. W1 belegt das zuerst (Task 1 im Plan).
- **Stufenabbildung [A]:** CAP `severity` Minor/Moderate/Severe/Extreme = Stufe 1/2/3/4 (Wetterwarnung / Markante / Unwetter / Extremes Unwetter). Zu bestätigen in W1.
- **Bestehende Push-Kette [B]** (`Sources/RadarCore/`): `PushService.tick` (Leader-Lease über `repo.acquireLeader`, Evaluation, `dispatch` aus `push_outbox`, APNs mit Backoff 30 s bis 600 s und 5 Versuchen, Purge nach 60 Tagen Inaktivität); `push_outbox` hat `UNIQUE dedupe_key VARCHAR(64)`, `collapse_id`, `payload_json VARCHAR(2048)`, `expires_at`, **FK `sub_id -> push_sub(id)`**, und `dueOutbox` verbindet `push_sub` mit `push_install` für Token/Umgebung. `push_sub` hat `cell_x/cell_y NOT NULL`, Schwelle 1..15 (Regen), `kind` (0 Ort, 1 Kreis, `006_push_region.sql`). `PushEvaluator` ist **pixelbasiert** (Zustände dry/pending/notified, `maxRunAge` 20 min, `repeatLock` 60 min) und für Ereignismeldungen nicht geeignet. Payload-Muster `PushEvaluator.payload` setzt `mutable-content: 1`, `thread-id` = Abo-ID, optional `interruption-level: time-sensitive`. `/v1/status` führt `capabilities` (`regions`, `live_activity`, `live_activity_regions`, `device_link`; `Api.swift`). Letzte Migration ist `015_push_eval_trace.sql`.
- **Notification Service Extension [B]** (App-Repo): `WeatherNotificationService/NotificationService.swift` liest `thread-id` -> Name aus `NotificationNameStore` (App Group `group.de.linolaske.showernow`) und hängt " · Name" an `content.body` an; ohne Eintrag, bei Fehler oder Zeitablauf bleibt der Text. Das funktioniert auch für wörtlichen Text (nur bei leerem Body wird der `loc-key` aufgelöst).

## 3. Architektur und Komponenten

### 3.1 Datenfluss (Überblick)
DWD CAP -> **Ingest** (Leader, Backend) -> Tabelle aktiver Warnungen -> **Auslöser** (Abgleich mit Abo-Warngebieten) -> `push_outbox` -> bestehender Dispatch/APNs -> Gerät (**NSE** ergänzt Ortsnamen/Quelle). Parallel: `GET /v1/warnings/active` -> **App** filtert lokal nach den eigenen Warngebieten.

### 3.2 Backend-Ingest (W1)
- Quelle `COMMUNEUNION_DWD_DIFF` (Gemeindebasis) und `..._STAT`, Sprache DE; EN zusätzlich, solange Installationen mit `locale=en` existieren (Text in der Installationssprache, sonst DE). Poll DIFF alle 60 s (bedingte Anfrage, `_LATEST_`-ZIP), STAT alle 15 min zum Abgleich (DWD-Empfehlung [G]); fehlt ein DIFF (Lücke > 90 s zwischen `Last-Modified`), sofort STAT. ETag/`304` ist belegt [G] (3.2a); DIFF-Poll deshalb bedingt mit `If-None-Match`.
- Nur der Leader (eigener Leasename `warn`, gleiches Verfahren wie `PushService.leaderName`) lädt, parst (CAP 1.2 XML in einer ZIP, ZIP-Größen < 300 KB [G]) und schreibt; Replikate sind zustandslos.
- Parser: `identifier`, `sent`, `msgType` (Alert/Update/Cancel), `references`, `event`/`eventCode II`, `severity`, `urgency`, `onset`, `expires`, `headline`, `description`, `instruction`, `WARNCELLID`s (`geocode`). Unbekannte Ereignisse werden gezählt, nicht gespeichert.
- Typzuordnung [A]: `severe_weather` = Gewitter, Sturm/Orkan, Starkregen/Dauerregen, Schneefall/Schneeverwehung, Tauwetter; `frost` = Frost/Strenger Frost; `ice` = Glätte/Glatteis. Hitze, UV, Nebel: in v1 ignoriert (Frage 1).

### 3.2a Befund echter Meldungen (07.11.2026 12:38) [G]
- Feed `COMMUNEUNION_DWD_STAT/Z_CAP_C_EDZW_LATEST_PVW_STATUS_PREMIUMDWD_COMMUNEUNION_DE.zip`: 66 612 Bytes, 6 XML-Dateien, alle `event` = `FROST`, `severity` = `Minor` (= Stufe 1), `urgency` = `Immediate`, `certainty` = `Likely`, `responseType` = `Prepare`, `status` = `Actual`, `scope` = `Public`, `msgType` = `Alert`, `source` = `PVW`, `language` = `de-DE`, `category` = `Met`. DIFF-ZIP: 2 Alert-Dateien, kein Update/Cancel, keine `references`. Frost-Meldungen haben je 1285 `area`-Elemente.
- `eventCode`-Liste: `PROFILE_VERSION`=2.1.14, `LICENSE`, **`II`=22** (nicht `eventCode II`), `GROUP`=`FROST`, `AREA_COLOR`. `identifier` = `2.49.0.0.276.0.DWD.PVW.<epoch-ms>.<uuid>.DEU`. Zeiten mit Offset (`+01:00`), Server rechnet nach UTC.
- **Gebietsangabe:** `info/area` enthält (a) zuerst ein oder mehrere `area` mit `areaDesc`="polygonal event area" und `polygon`, **ohne** `geocode`; (b) danach je Gemeinde ein `area` mit `areaDesc` (z. B. "Stadt Roßwein") und `geocode`/`valueName`=`WARNCELLID`, `value` 9 Ziffern. Der Parser nimmt nur (b) und ignoriert Polygone. Die `_CELLS_`-Variante enthielt am 07.11. gleich große Dateien (338 006 Bytes je Meldung) wie `_DWD_`; Unterschied nicht geprüft, wir bleiben bei `_DWD_`.
- **HTTP:** Verzeichnislisting nginx, ZIPs liefern `ETag` und `Last-Modified`; bedingte Anfrage mit `If-None-Match` ergab `304`. Dateien `..._MUL.zip` (alle Sprachen, 462 KB) überschreiten die 300-KB-Annahme; wir laden `_DE`/`_EN` (je ca. 66 KB, DIFF ca. 11 KB). ZIP-Dateiname enthält Zeitstempel (`20261107113320`) und `LATEST`.
- `GET .../cap/` listet zusätzlich `COMMUNEUNION_EVENT_*` und `DISTRICT_*`; nicht benötigt.
- Fixture (gekürzt): Backend `docs/fixtures/warnings/cap-frost-alert.xml`.

### 3.3 Speicher und Migration `016_warnings.sql` (W1)
Rückwärtskompatibel, additiv, `IF NOT EXISTS` wie die bisherigen Migrationen:
- `warn_alert(identifier PK, kind, severity, onset, expires, sent, headline_de/en, text_de/en, instruction_de/en, status, supersedes)` und `warn_alert_cell(identifier, warncell_id)`; abgelaufene/aufgehobene Zeilen werden nach 24 h entfernt (Purge im Leader-Takt von `PushService`).
- `push_sub` bekommt für Warnabos Zeilen mit `kind = 2` ("warning", `cell_x/cell_y = 0`, `threshold = 1`; die NOT-NULL-Spalten bleiben unberührt). Damit gelten Identität, Besitz, Cascade-Löschung, Outbox-FK, `dueOutbox` und 60-Tage-Löschung **ohne Änderung der Auslieferung**. Zusatztabellen `warn_sub(sub_id PK FK, types_mask, min_sev_weather, min_sev_frost, min_sev_ice, time_sensitive)` und `warn_sub_cell(sub_id, warncell_id)`.
- Pflichtänderung am Bestand: `evaluationSubscriptions` und die Zähler für Limits (10 Abos, Regionen) müssen `kind = 2` ausschließen, sonst lädt der Regenauswerter Warnabos mit Dummy-Zelle. Warnabos zählen nicht zum 10er-Limit; eigenes Limit [A]: höchstens 10 Warnabos je Installation, höchstens 64 Warngebiete je Abo und 128 je Installation.
- `warn_sent` (Dedupe/Sperre): `(sub_id, chain_id, kind, last_severity, last_sent_at)`; `chain_id` = Identifier der ersten Meldung einer `references`-Kette.

### 3.4 Auslöser (W2)
Reine, getrennt testbare Funktion `WarnEvaluator.decide(sub, alert, previous, now) -> Send | Suppress(reason)` (Muster `PushEvaluator.step`):
- **Frische:** Push nur, wenn `now - sent <= 20 min` (DWD-Empfehlung [G], gleiche Konstante wie `PushEvaluator.maxRunAge`) und `expires > now`. Ältere Meldungen erscheinen nur in der App.
- **Treffer:** Warngebiet-Schnittmenge mit `warn_sub_cell`, Typ aktiv, Stufe >= Schwelle des Typs.
- **Neu (Alert):** Push. **Update:** Push nur bei höherer Stufe, anderem Typ oder deutlich früherem Beginn (> 1 h); sonst nur App-Liste. **Cancel/Ablauf:** kein Push (Entwarnung wäre eine Aussage des DWD, die wir nicht erfinden), App entfernt die Warnung.
- **Sperre/Hysterese:** je (Abo, Typ) Wiederholsperre 60 min (wie `repeatLock`), außer bei höherer Stufe. Eine Kette sendet nie doppelt.
- **Dedupe:** `dedupe_key = sha256(sub_id | identifier)` als 64 Hex-Zeichen (passt in `VARCHAR(64)`; `INSERT IGNORE` wie bisher); `collapse_id = sub_id:kind` (<= 64 Byte), damit ein Update die ältere Mitteilung desselben Typs ersetzt. `expires_at = min(expires, now + 6 h)`.
- Auslösetakt: nach jedem Ingest-Lauf (nicht pixel-/laufgebunden), im Leader von `warn`; Versand nutzt `dispatch` unverändert. Wo der Takt in `Radar.swift` aufgehängt wird, ist **[N]** (nur `PushService(...)` in `Radar.swift:145` gesehen).

### 3.5 API-Vertrag (W0, vor W2/W4 festzuschreiben in `docs-site` `api.md`)
- `GET /v1/status`: `capabilities` erhält `"warnings"` (Anzeige/Ingest vorhanden) und `"warnings_push"` (Push aktiv). Ohne Flag bietet die App weder Einstellung noch Push-Abo an (Muster `live_activity_regions`).
- `GET /v1/warnings/active`: ohne Authentifizierung, **ohne Ortsangabe**, bundesweit alle aktiven Warnungen (`id`, `kind`, `severity`, `onset`, `expires`, `sent`, `headline`, `text`, `instruction`, `warncell_ids`, `source: "dwd"`, `fetched_at`), `Cache-Control` kurz, Sprache per `Accept-Language`. Das Gerät filtert lokal; es verlässt dadurch keine Gebietskennung das Gerät, nur das Abo (3.6) nennt Warngebiete.
- Abo: `GET/POST /v1/push/installations/{id}/warn-subscriptions`, `PUT/DELETE .../warn-subscriptions/{subId}` (Pfade an `PushApi.swift` ausgerichtet; Auth wie die Push-Routen). **Festgeschrieben in W0:** Backend `docs-site/content/api.md`, Abschnitt "Amtliche Warnungen". Body: `warncell_ids` (je 9 Ziffern, gegen die DWD-Liste geprüft), `types`, `min_severity` je Typ, `enabled`, `time_sensitive`. Fehler: `400 invalid`, `409 warn_limit`, `409 warncell_unknown`, `429` wie bisher.
- Payload: `aps.alert.title` = DWD-Überschrift, `body` = DWD-Text (gekürzt auf <= 900 Byte, Gesamtpayload < 1900 Byte wegen `VARCHAR(2048)`), `thread-id` = Abo-ID, `mutable-content: 1`, `interruption-level: time-sensitive` nur bei Stufe 4 oder gesetztem Schalter; `type: "warning"`, `kind`, `severity`, `sent` (ISO). Kein Ortsname, keine Koordinate.

### 3.6 App (W3-W6)
- **Zuordnung (W3):** gebündelte, vereinfachte Gemeinde-Geometrie (DWD-Shapefile, Aufbereitung per Skript unter `tools/`, Größe/Lizenz der Shapes **[N]**, Annahme: wenige MB als Binärdatei) und Punkt-in-Polygon auf dem Gerät: Ort -> eine WARNCELLID; Gebiet (Kreis) -> alle Gemeinden, die den Kreis schneiden (<= 64). Veraltete IDs nach Gebietsreformen: Server lehnt mit `409 warncell_unknown` ab, die App zeigt "Warngebiete veraltet, bitte App aktualisieren"; Aktualisierung der Geometrie nur mit App-Updates.
- **Einstellungen (W4):** Bereich "Warnungen" nur bei Capability: Schalter je Typ (Unwetter, Frost, Glatteis/Glätte), Mindeststufe je Typ (Standard [A]: Unwetter ab Stufe 3, Frost ab Stufe 1, Glätte ab Stufe 2), "Zeitkritisch", Hinweis "Kein Ersatz für amtliche Warnkanäle". Die Abos werden je gespeichertem Ort/Gebiet angelegt; der lokale Name bleibt im `NotificationNameStore` (Abo-ID -> Name).
- **Warnansicht (W5):** Liste (Typ, Stufe als Text und Symbol, Zeitraum, DWD-Text, "Quelle: Deutscher Wetterdienst, ausgegeben HH:MM", Datenalter) und Karte (gebündelte Polygone der betroffenen Gemeinden; MapKit-Overlays wie `Weather/Map/`). Ansicht und Filter arbeiten lokal auf `GET /v1/warnings/active`; Standard zeigt Warnungen der gespeicherten Orte, umschaltbar auf alle. Offline/Fehler: letzter Stand mit Alter, kein erfundener Inhalt.
- **Push-Text/NSE (W6):** Die Extension hängt wie bisher " · Name" an, ergänzt für `type = warning` die Zeile "Quelle: DWD, ausgegeben HH:MM" (Zeit aus `sent`, Gerätezeitzone) und bei Wegfall der Extension steht serverseitig mindestens "Quelle: DWD" im Text. Der Disclaimer steht in Einstellungen, vor der Systemabfrage und in der Warnansicht (die Mitteilung selbst bleibt kurz).
- **Barrierefreiheit/Lokalisierung:** Stufe nie nur farbig (Wort "Stufe 3 Unwetter" plus Symbol), VoiceOver-Label je Warnung als ein Satz, Dynamic Type, Kartenalternative ist die Liste, Reduce Motion beachten. Oberfläche de/en (`Localizable.strings`); DWD-Text in der Sprache des Geräts (DE oder EN), sonst DE mit Hinweis.

### 3.7 Schnittstellen zu Teil 2 und 3 (nur Abgrenzung)
- Teil 2 erzeugt ebenfalls `WarnEvent` (Quelle `estimate`, Typ `frost_possible`/`ice_possible`, Stufe 0) und nutzt dieselben Tabellen `warn_sub`/`warn_sub_cell`, `warn_sent`, `WarnEvaluator` (Sperre, Dedupe), Payload-Schema und NSE. Unterschied: kein CAP-Ingest; Ort = Mittelpunkt der Warngemeinde (aus der öffentlichen WARNCELLID-Liste serverseitig, keine Gerätekoordinate), Text ist ausdrücklich "Schätzung", nie DWD-Quelle. Ein gemeinsamer Typ-Schalter "Frost" deckt amtlich und Schätzung; die Aufteilung entscheidet Teil 2.
- Teil 3 (Karte) wiederverwendet nichts aus diesem Teilprojekt außer den gebündelten Gemeindeflächen.

## 4. Fehler, Ausfall, Sonderfälle
- **DWD nicht erreichbar:** Backoff (60 s, 2 min, 5 min), Leader behält den letzten Stand; `/v1/warnings/active` liefert `fetched_at`, die App zeigt das Alter und ab > 30 min "Warnungen eventuell nicht aktuell". Kein Push aus Daten, die nach STAT-Abgleich nicht bestätigt sind.
- **Veraltete Meldungen (> 20 min):** kein Push (3.4); beim Backend-Neustart oder Leader-Wechsel verhindert `warn_sent` Doppelversand, STAT-Initiallauf sendet nur frische Meldungen.
- **Duplikate:** DIFF und STAT liefern dieselbe Meldung; Dedupe über `identifier` und `warn_sent`.
- **Update/Cancel:** siehe 3.4; Verweise (`references`) bilden Ketten, eine Meldung mit unbekannter Referenz wird als neue Kette behandelt.
- **Sperre:** 60 min je (Abo, Typ); Stufenanstieg durchbricht sie. APNs-Fehler: Verhalten der bestehenden Outbox.
- **Abgelaufene Warnung im Outbox-Stau:** `expires_at` der Outbox verwirft sie ungesendet (bestehendes Verhalten [B]).

## 5. Datenschutz (freigabepflichtig)
- Der Server speichert nur Warngebiets-IDs (Gemeinde) je Abo, keine Koordinaten, keine Ortsnamen, keine Ortshistorie; Zuordnung Ort -> Gemeinde nur auf dem Gerät; Aktivwarnungen werden ohne Ortsangabe abgerufen.
- Passung zum Bestand [B]: Abos speichern heute Rasterzelle (Ort ca. 0,7 km, Kreismittelpunkt ca. 2 km) plus Installations-ID/Token. Eine Gemeinde ist je nach Größe gröber oder ähnlich genau; mehrere Gemeinden je Gebiet sind eine Gebietsgrenze, kein Bewegungsprofil. Aber: die Kombination "Regen-Abo-Zelle + Warngemeinde" derselben Installation ist ein zusätzliches, präziseres Merkmal (Schnittmenge) und kein neuer Datentyp.
- **Es entsteht eine Datenschutzänderung:** neuer Zweck "Unwetter-/Frost-/Glatteiswarnungen" mit neuen Datenfeldern (Warngebiets-IDs). Datenschutztext (`/datenschutz`, `docs-site/content/datenschutz.md`) und App-Privacy-Angaben (Kategorien voraussichtlich unverändert: Device ID, Coarse Location; Zweck App Functionality [A]) müssen vor Livegang ergänzt werden. **Nicht live ändern; Entwurf als W7, Freigabe durch den Nutzer.** Löschung unverändert (Cascade, 410, 60 Tage).
- Keine identifizierenden Debuglogs; Beobachtung nur über feste Zählerlabels (Muster `PushObserver` [B]).

## 6. Tests
- Backend: Parser gegen Fixtures (handgebaute Minimalfälle nach CAP-Profil, echte Meldungen sobald vorhanden **[N]**); `WarnEvaluator`-Tabellentests (neu, Update höher/gleich, Cancel, > 20 min, Sperre, Dedupe, Kettenbruch); Repo-Vertragstests Memory/MariaDB (inkl. Ausschluss `kind = 2` aus Regenauswertung und 10er-Limit); API-Tests (Validierung, Limits, Rückwärtskompatibilität: alte Clients unverändert); `FakeApnsSender` statt echtem APNs.
- App: Punkt-in-Polygon (Randpunkte, Gemeindegrenzen, Kreis -> Gemeinden), Gateway mit `URLProtocol`-Mock, Einstellungs-Zustände nach Capability, Textbausteine de/en, NSE-Textlogik (`NotificationNameTests` erweitern), Accessibility-Label-Tests.
- Nur am Gerät/DWD prüfbar: echter Push im Warnfall, Kartenoptik, Feed-Verhalten bei realer Warnlage.

## 7. Rollout
1. W0 Vertrag + Entscheidungen; W1/W2 Backend mit Flags `WARN_INGEST_ENABLED` und `WARN_PUSH_ENABLED` (beide aus); Migration `016` vor Deploy (rückwärtskompatibel).
2. Deploy Backend; Ingest an (nur Anzeigedaten); Beobachtung (Zähler, Feed-Alter).
3. App (W3-W6) nach Capability `warnings`; ältere Backends ohne Flag zeigen nichts. Upload Build wie bisher.
4. **Push scharf (`warnings_push`) erst nach** (a) Antwort des DWD auf die Rückfrage (**Nutzeraufgabe: `CAP@dwd.de` fragen, ob Weitergabe der Warnungen als Push an Endnutzer mit Quellenangabe zulässig ist; nicht selbst senden**, [N] bis zur Antwort) und (b) Freigabe des Datenschutztexts. Reihenfolge Backend -> App, Push-Schalter zuletzt.

## 8. Arbeitspakete (Aufwand grob: S = halber Tag, M = 1-2 Tage, L = 3+ Tage; Agent-Zeit)
| Paket | Inhalt | Dateibesitz | Aufwand | nach |
|---|---|---|---|---|
| W0 | Vertrag (API, Payload, Typen/Stufen), `decisions.md`, Capability-Namen; Belegung `eventCode II`/Glätte am DWD-Profil | Docs (`docs/decisions.md`, `docs-site/api.md` im Backend) | S | - |
| W1 | Ingest, Parser, Migration `016`, Repos Memory/Maria, Tests | Backend `Warn*.swift`, `migrations/016`, `MariaRepo+Warn.swift`, `MemoryRepo+Warn.swift` | L | W0 |
| W2 | `WarnEvaluator`, Dispatch-Anbindung, API-Routen, `evaluationSubscriptions`-Filter, Capabilities | Backend `WarnApi.swift`, `PushService.swift`, `MariaRepo+Push.swift`, `Api.swift` | M-L | W1 (Modelle) |
| W3 | Gemeindegeometrie-Aufbereitung, Punkt-in-Polygon, Kreis -> Gemeinden | App `Weather/Warnings/Matching*`, `tools/` | M | - |
| W4 | `WarnGateway`, Einstellungen, Abo-Verwaltung je Ort/Gebiet | App `Weather/Push/Warn*`, `Weather/Views/Settings*` | M | W0, W3 |
| W5 | Warnansicht Liste und Karte, Barrierefreiheit, de/en | App `Weather/Views/Warnings*`, `Weather/Map/` | M-L | W0, W3 |
| W6 | NSE für `type = warning`, Texte | `WeatherNotificationService/`, `Shared/` | S | W0 |
| W7 | Entwurf Datenschutztext und App-Privacy (freigabepflichtig) | `docs-site/content/datenschutz.md` (Entwurf), `docs/` | S | W0 |
Parallelität: erste Welle (max. 3): W1, W3, W7 (W0 vorab durch den technischen Lead). Zweite Welle: W2, W4, W5. W6 beliebig. Genau ein Verantwortlicher für Simulator/`xcodebuild` je Welle; W3/W5/W6 teilen `Weather.xcodeproj` und werden dort nicht gleichzeitig gebaut.

## 9. Entscheidungen des Nutzers (7. November 2026, beantwortet)
1. **Umfang "Unwetter allgemein":** Gewitter, Sturm, Stark-/Dauerregen, Schnee, Tauwetter. Hitze, UV, Nebel nicht in v1.
2. **Standardstufen Push:** Unwetter ab 3, Frost ab 1, Glätte ab 2.
3. **Entwarnung** nie als Push, nur in der App.
4. **Update-Pushes** nur bei Verschärfung oder deutlich früherem Beginn (> 1 h).
5. **Zeitkritisch** nur bei Stufe 4 plus Nutzerschalter.
6. **Rückfrage an `CAP@dwd.de`:** Nutzeraufgabe (nicht selbst senden). Push bleibt bis Antwort **und** Freigabe des Datenschutztexts aus (Capability `warnings_push`, Flag `WARN_PUSH_ENABLED`).

## 10. Nicht geprüft (Stand dieser Spezifikation)
CAP-Rohfelder nur für `FROST`/Stufe 1 an echten Meldungen belegt (3.2a); offen: Codes für Glätte/Glatteis, Gewitter, Sturm, Regen, Schnee, Tauwetter, `Update`/`Cancel`/`references`, `severity` 2 bis 4; Größe und Lizenz der Gemeinde-Shapes; DWD-Aussage zu Push-Weitergabe; Aufhängung des Takts in `Radar.swift` und exakte Abo-Pfade in `PushApi.swift` (nur Teile gelesen); App-Code außer NSE/`NotificationNameStore`; Datenschutzseiten-Text; Performance von Warn-Abgleich bei vielen Abos (Annahme: gering, Abgleich über Warngebiets-ID-Index).

## 11. Selbstreview
- Widerspruchsprüfung: `push_sub kind = 2` nutzt die vorhandene Outbox (FK) statt Duplikat, verlangt aber den Filter im Regenauswerter (3.3), als Pflichtpunkt in W2 und Test vermerkt. Datenschutz: "keine Koordinaten" gilt, die Kombination mit Regenabo-Zellen ist in 5 benannt.
- Mehrdeutigkeiten behoben: Stufe = 1-4 einheitlich; Zeiten UTC auf dem Server, Anzeige Gerätezeit; Sprache pro Installation.
- Umfang: ein Teilprojekt, 8 Pakete, kein neuer Dienst; Teil 2/3 nur Schnittstelle. Größtes Risiko ist unbelegte Feldzuordnung (W0/W1 zuerst, vor W2/W4).
