# Fortsetzbarer Arbeitsstand

Stand: 1. November 2026 (Verdichtung; Einzelheiten und frühere Prüfprotokolle stehen in Git, ab `a15ca77` rückwärts, sowie in `research/`, `signing.md`, `testflight-upload.md`).

Kurzfassung: Letzter hochgeladener Build ist **Build 13** (`0.1.0 (13)`, Quelle `f1310e8`). Backend-Stand und Betreiberaufgaben: Schwesterrepo (`docs/status.md` dort).

## Builds

| Build | Quelle | Upload (MEZ) | Inhalt / Hinweise |
|---|---|---|---|
| 1/2 (`de.linolaske.weather`) | `0f48cb5` | 28.10.; Build 1 abgelehnt (`90474`), Build 2 17:35:36 angenommen | Namenskonflikt mit Weather; kein belegter nutzbarer Build |
| 3 (`de.linolaske.showernow`) | `2e500fc` | 28.10. 17:51:38 | Intern über TestFlight vom Nutzer bestätigt |
| 4 | `6750d0e` | 28.10. 18:17:29 | Glass-Slider, lokale Einordnung (Foundation Models) |
| 5 | `c474893` | 28.10. 19:14:17 | P0-Korrekturen |
| 6 | `87915f8` | 28.10. 20:01:53 | Budgetiertes Vorladen (50 MB RAM-Cache) |
| 7 | `1c093dd` | 30.10. 06:31 | Mobilfunk-Prefetch, Slider-Feedback |
| 8 | `cdd5735` | 30.10. 11:49 | Vollständiges Vorladen; Upload mit Xcode 27.2 abgelehnt (Exit 70), mit 27.1 angenommen |
| 9 | `0c5e22f` | 30.10. 21:29 | Radar-Cache-Backend zuerst, DWD-Fallback |
| 10 | `b106f1e` | 30.10. 21:49 | Korrigierter Datenschutztext, intern-only |
| 11 | `ae0f428` | 31.10. 04:55 | Maximale Vergangenheit/`history.json`, feines Scrubben, robuste Ortsprognose; erstmals ohne internal-only |
| 12 | `de280c1` | 31.10. 21:15:02 bis 21:16:17 | Siehe unten |
| 13 | `f1310e8` | 1.11. 20:45:43 bis 20:47:04 | Siehe unten |

**Build 12** (`0.1.0 (12)`), Quellencheckpoint `de280c1`, Xcode 27.1 (27A9275): Exit 0, `EXPORT SUCCEEDED`, `Upload succeeded`, letzte Meldung `Uploaded package is processing`. Inhalt laut `git log ae0f428..de280c1`: adaptiver Poll-Takt für `latest.json` (`d6f5dff`); Links Support/Über im Info-Sheet (`b02b21d`); Datenmengenanzeige entfernt, aufklappbare DWD-Legende (`141d38b`); Sonnenstand-Baustein `SolarPosition` (`199a188`); UI-Test-Reparatur (`ecf7175`) und VoiceOver-Aktion am Zeitslider (`bc08c5d`); Capability Push (`2c442c3`); Push App-Seite (`297b8b8`); Kartenebenen Luftdruck/Blitze/Wolken (`5e04b75`); Push-Testmeldung und Zeitkritisch (`d2c6f2f`); Ebene Sonne (`3aaf189`); Buildnummer 12 (`de280c1`). Vorab volle Tests iPhone 18 Pro Simulator: 266 Unit- und 7 UI-Tests, 0 Fehler. IPA: `aps-environment=production`, `time-sensitive=true`, `get-task-allow=false`, `codesign --verify` ok, `testFlightInternalTestingOnly=false`, SHA-256 `ee0705154d72c339bcea375d67e02dd1b9d7a85e2ff82383bfaa9b10ef439ad1`. Verarbeitung bei Apple, Installierbarkeit und externe Zuordnung nicht geprüft.
**Build 13** (`0.1.0 (13)`), Quellencheckpoint `f1310e8` (Buildnummer auf Welle-2-Stand `f5d9e96`), Xcode 27.1 (27A9275): Exit 0, `EXPORT SUCCEEDED`, `Upload succeeded`, letzte Meldung `Uploaded package is processing`. Inhalt laut `git log de280c1..HEAD`: Ebenenwahl oben rechts mit Ladepille (`1806425`), Datenschutz/Support/Über als Sheets und Sport-Texte (`e0aae71`), Regionen (Umkreis) mit Kreisvorschau (`fc59335`, `821116d`), `Localizable.strings` de/en (`821116d`), Luftdruck Europa (nur bei Backend-Meldung) und Sonne mit sichtbarem Kanal (`f5d9e96`). Export: `aps-environment=production`, `time-sensitive=true`, `get-task-allow=false`, `codesign --verify --strict --deep` ok, CFBundleVersion 13, IPA-SHA-256 `75ca540ec0712c17d4767f91893cc49e03cfdef2b8666ffc145e2eb3d07976aa`. Optionen wie Build 12 (`testFlightInternalTestingOnly=false`).


**Fund (1.11.2026), behoben in Build 13:** Build 12 enthält keine `Localizable.strings`; bei echten Regenmeldungen würde dort der rohe Schlüssel `RAIN_STARTS_IN` erscheinen. Build 13 enthält `de.lproj`/`en.lproj` mit `Localizable.strings` (im exportierten Paket nachgewiesen).

## In Build 13 enthalten (seit Build 12, ab `a15ca77`)

- **Ebenenwahl oben rechts statt Refresh-Knopf** (`1806425`): Glaskapsel mit Symbol, Name, Chevron; „Daten neu laden“ im Menü (`radar-layer-menu`); Spinner statt Symbol beim Laden; Legendenknopf bleibt rechts.
- **`SlotFeedbackGate`** (`1806425`): Ladepille „Radar für HH:mm lädt …“ erst nach 0,7 s ununterbrochenem Warten, mindestens 0,6 s sichtbar, Fehler sofort; Werte sind Startwerte (nur am Gerät beurteilbar).
- **Datenschutz/Support/Über als ephemere WebView-Sheets** (`e0aae71`, `SitePageSheet`; nonPersistent, JavaScript aus, nur eigener Host), **Sport-Texte** statt Radfahren.
- **Regionen (Umkreis)** (`fc59335`, `821116d`): Mittelpunkt + Radius 5/10/25 km, Auslöseanteil 1/10/25 %, bis 3 Regionen (zählen im 10er-Limit), Anlegen mit Kreisvorschau in „Deine Orte“, Fähigkeitsprüfung über `GET /v1/status` (`capabilities` enthält `regions`; sonst ausgegraut, nie eine Regionsanfrage). Feldabgleich `821116d` gegen Backend `34e6416` (Feldnamen, Wertebereiche, Mittelzelle, 409-Codes per JSON, `region_limit` auch für das Zellbudget 8000). Kein eigener Knopf in der Kartenansicht.
- **`Localizable.strings` de/en für Push-Texte** (`821116d`), `PushRegionWireTests`; siehe Fund oben.
- Docs: Entwurf Regenwarnungen für Regionen (`db445f1`), Recherchen Karten/Wolken (`28c7c12`), Luftdruck-Farbfläche (`9ed2536`).
- Geprüft (Stand `821116d`, älter): volle `WeatherTests` 300 Tests, 0 Fehler (iPhone 18 Pro Simulator); UI-Suite zuletzt nach `1806425` (7 UI-Tests grün), danach nicht erneut; Sichtprüfung per Screenshot für Ebenenmenü, Regionen-Abschnitt und Kreisvorschau.

## Einreichung Build 13 und Reviews (1.11.2026)

- **Externe TestFlight-Prüfung:** Build 13 wurde vom Nutzer ab 1./2.11.2026 zur Prüfung für **externe** Tests eingereicht; Ausgang der Prüfung **offen**. Der Testtext „Was soll getestet werden“ wurde formuliert.
- **Codex-Review** (gpt-6.1-sol, medium, statisch, nichts ausgeführt), 4 Befunde:
  - P1 `PushManager.swift:505`: Wird eine Region während des ersten POST gelöscht, bleibt das Abo serverseitig bestehen.
  - P2 `PushManager.swift:507`: `needsUpload = false` durch eine alte Antwort überspringt eine zwischenzeitliche Änderung.
  - P2 `RadarMap.swift:256`: Veralteter vis-Request überschreibt die Karte.
  - P2 `SitePageSheet.swift:129`: `.other`-Navigationen ohne Host-/Schemaprüfung.
  - Dazu Testlücken (je Befund fehlen Regressionstests).
- **Backend-Security-Review:** [research/security-review-backend-2026-11-01.md](research/security-review-backend-2026-11-01.md): 0 kritisch, 2 hoch (H1/H2), 5 mittel, 9 niedrig.
- **Befunde behoben (2.11.2026, auf `main`, in **keinem** Build; Build 13 unberührt):** alle 4 bestätigt und mit zuerst fehlschlagenden Regressionstests behoben. (1) P1 `PushManager`: Antwort-ID einer inzwischen gelöschten Region/Ortes wird zur serverseitigen Löschung vorgemerkt (`discardLate`). (2) P2 `PushManager`: `needsUpload=false` nur, wenn die hochgeladene Anfrage dem aktuellen Stand entspricht, sonst läuft die Synchronisation erneut (gilt auch für Orte). (3) P2 `RadarMap`: vis-Ergebnis wird nur noch gezeichnet, wenn Overlay, vis-Loader, Maskenslot und ausstehende Anfrage noch passen (`SunVisibleMatch.shouldApply`); Fallback setzt die Anfrage zurück. Die Zuordnungsprüfung ist getestet, der Coordinator-Pfad selbst nicht. (4) P2 `SitePageSheet`: Host-/https-Regel gilt für jede Navigationsart (`navigationDecision`), Hauptframe-Antworten fremder Hosts werden verworfen (`allowsResponse`); nur Linktipps im Hauptframe öffnen extern (https/http/mailto). Geprüft: `WeatherTests` einzeln 321 Tests, 0 Fehler; UI-Tests 7, 0 Fehler (iPhone 18 Pro Simulator). Nicht geprüft: WKWebView-Verhalten im Gerät/Simulator (Redirect-Fälle), Karte mit echten vis-Bildern.
- **Nächste Schritte:** (1) Build 14 mit diesen Fixes erst nach Prüfungsausgang von Build 13. (2) Danach Backend-Härtung H1/H2/M1/M2 im Schwesterrepo.

## Geprüft / nicht geprüft

Build 13 (1.11.): `WeatherTests` einzeln mit Xcode 27.1 auf iPhone 18 Pro Simulator: 315 Tests, 0 Fehler; UI-Suite nicht erneut gelaufen. Archiv, lokaler Export, Upload (Exit 0) erfolgreich; Apple-Verarbeitung und Installierbarkeit von Build 13 **nicht geprüft**.

Vom Nutzer am Gerät bestätigt: Push-Registrierung und Glocke funktionieren; die Luftdruck-Ebene erscheint. Alles Weitere ist nicht gerätegeprüft.

Per Test/Simulator belegt: Unit-Tests (siehe oben), Archiv/Export mit Entitlements, Parser/Frische/Zeitachsen der Ebenen gegen Fixtures im Backend-Format, Request-Formate und Retries des Push-Gateways, Sonnenstand gegen JPL Horizons, Klassifizierung der `clm`-Farben an echten Bildern.

Nicht geprüft: echte Zustellung echter Regenmeldungen und Anzeige der Texte, Regionen gegen ein Live-Backend, Scrub-Gefühl (Schwellen 40/90/150 pt) und Ladepille am Gerät, Wolken-/Sonnenoptik und Deckkraft mit echten Bildern, Nachtdarstellung der Sonne im Screenshot, Dark/iPad/VoiceOver/Dynamic Type, Low-Power-/Low-Data-Pfade, Bildgrößen bei echtem Regen, Verarbeitung von Build 12/13 bei Apple.

## Offene Punkte (Entwicklung)

1. **Backend-Welle 2 in der Oberfläche** (Backend `881edeb`; verdrahtet 1.11., lokal committet, nicht gebaut/hochgeladen): `RadarLayer.pressureEU` (`pressure_eu`, Menü „Luftdruck Europa“, direkt hinter „Luftdruck“) und Hilfsebene `cloudmaskVis` (`cloudmask_vis`, nicht wählbar). **Verfügbarkeit:** `pressureEU` erscheint nur, wenn das Manifest `available` meldet (`RadarLayerStore.offeredLayers`/`isOffered`); bei 404/unbekannt/nicht erreichbar fehlt der Eintrag ganz, kein Banner; verschwindet die aktive Ebene, fällt die Karte still auf das Radar zurück. Europa-Ausdehnung kommt aus `manifest.bounds` der Ebene. **Sonne:** Zeitachse bleibt die der 15-min-`cloudmask`-Slots; `refresh(.cloudmask)` holt (nur bei verfügbarer Maske) das `cloudmask_vis`-Manifest mit; `RadarLayerStore.sunVisibleManifest` nur, wenn frisch (2 h) und gleiche Ausdehnung/Größe wie die Maske. Je Maskenslot wählt `SunVisibleMatch.nearest` den nächsten vis-Slot (höchstens 10 min Abstand, sonst nur Maske); `RadarMap.Coordinator.syncVisible` lädt genau dieses eine Bild (kein Prefetch, nichts bei Strom-/Datensparmodus), die Maske wird sofort gezeichnet und nach Eintreffen des vis-Bilds neu gezeichnet (Composer-Cache-Schlüssel enthält die vis-URL). Speicher: Sonnen-Ebene 3 dekodierte Masken + 2 vis + 4 komponierte Bilder (Deutschland etwa 45 MB), `DecodedImageCache` 48 MB je Loader, Europa nur 2 Bilder; `pressureEU` Prefetch 13 Slots. `cloudmask_vis_eu` bewusst nicht eingebunden (Sonne bleibt Deutschland). Zeitzone fremder Orte: Gerätezeitzone (`SunPlace.timeZone`), kein Geocoding. **Schwellen `VisibleChannel.clear/cloud` (130/230) sind Startwerte**, mit echten Bildern nachzumessen; Backend hatte die Ebenen am 1.11. noch nicht aktiv (404), also **keine Livebilder, kein Live-Backend geprüft**; auch nicht geprüft: Optik/Flackern beim Nachladen des vis-Bilds, tatsächlicher Speicherverbrauch am Gerät, Europa-Karte auf dem Gerät, Menü mit aktivem `pressure_eu`. Geprüft: volle `WeatherTests` 315 Tests, 0 Fehler (iPhone 18 Pro Simulator, einzeln); UI-Tests 7, 0 Fehler. Neue Tests: Europa-Manifest/-Bounds, Angebot nur bei Meldung, stiller Rückfall, vis-Hilfsebene (404/stale/andere Ausdehnung), kein Hilfsabruf ohne Sonne, Slot-Zuordnung inkl. Lücke, Composer-Schlüssel.
2. Kartenzugang zur Regionenverwaltung (bisher nur über „Deine Orte“); Radius in Zellen nicht an der Karte nachgemessen.
3. Extrapolation „Sonne in 30 min“ nicht begonnen (Nutzer wollte sie zuletzt; als „Schätzung“ kennzeichnen).
4. Druck-Farbfläche als Option: nur über GRIB-Rohdaten (libaec) im Backend, 3 bis 5 Tage ([research/druck-farboverlay.md](research/druck-farboverlay.md)); Nutzer hat nicht entschieden.
5. Live Activities später; Critical Alerts nicht beantragen (Empfehlung, [research/live-activities-und-kritische-mitteilungen.md](research/live-activities-und-kritische-mitteilungen.md)).
6. Push: `env` je Build-Konfiguration (`sandbox` Debug, `production` Release), Backend hat nur eine `APNS_ENV` je Betrieb; systemseitig abgeschaltete Mitteilungen löschen Abos nicht; Ort ohne Radarabdeckung nicht aktivierbar.
7. Tests: UI-Test `testRadarControlsOpenDetailsAndReturnToCurrentFrame` flaky; Parallelitäts-Crashes („signal kill before establishing connection“) bei gleichzeitigen Läufen; `DWDDataTests` bei `-test-iterations` nicht wiederholbar; Banner „Einige Radarkacheln fehlen“ im DWD-Fallback möglich.
8. Widgets, Watch, iPad-/Mac-Oberflächen folgen laut [plan.md](plan.md).

## Nutzeraufgaben (Checkliste)

- [ ] Backend aktualisieren: `update.sh --pull-scripts --force`, `LAYERS` um die neuen IDs ergänzen, ALTER-Recht für Migrationen 005/006, danach `/v1/status` prüfen (`capabilities` mit `regions`). Details: Backend `docs/status.md`.
- [ ] Datenschutztext `/datenschutz` und App-Privacy (Variante B) freigeben, **vor** Livegang von Push/Regionen.
- [ ] Zoraxy-Logging/Rate-Limit (E7/E8), Rechtsprüfung/Impressum.
- [ ] App Store Connect: Build 13 einer externen Gruppe zuordnen, Testinformationen ausfüllen ([apple-externe-tests.md](apple-externe-tests.md)).
- [ ] APNs-Key anlegen und Push im Swarm aktivieren: [apns-einrichtung.md](apns-einrichtung.md).
- [ ] Gerätetests: Scrub-Schwellen 40/90/150 pt, Ladepille, Legende, Sonnenradar, Empfindlichkeitsstufen 0,4/2/7,5 mm/h, echte Regenmeldung (mit Build 13).
- [ ] Entscheidung Druck-Farbfläche.

## Repository und lokale Konfiguration

- Dieses Repo: https://github.com/MagicalWig34653/weather-apple; Schwesterrepo: https://github.com/MagicalWig34653/weather-backend (Radar-Cache-Backend in Swift/Vapor, produktiv unter https://showernow.linolaske.de; Messung: [research/backend-radar-cache.md](research/backend-radar-cache.md)).
- Private lokale Pfade ausschließlich in der ignorierten `LOCAL_WORKSPACE.md`; Vorlage `LOCAL_WORKSPACE.example.md`.

## Prototyp-Umfang (Kurzfassung)

- XcodeGen-Projekt, Swift 6, iOS 27, Identität in `Configuration/Base.xcconfig` (ShowerNow, `de.linolaske.showernow`, Team `J2DU2P47XW`, Universal, Compliance `false`).
- MapKit-Radarkarte (Backend-Cache zuerst, DWD-Fallback, Analyse, Vorhersage, Play/Pause, adaptiver Poll), Zusatzebenen (Luftdruck, Blitze, Wolken, Sonne) nur über den Backend-Cache, direkte DWD-Punktprognose ([data-contract.md](data-contract.md)), Ortssuche/-speichern, optionaler Standort, Swift Charts, lokale Einordnung, Push je Ort (Opt-in) und Regionen.
- Speicher: Punktprognosen im Speicher, Radar-Tiles im RAM-Cache (50 MB), kein Festplatten-Netzwerkcache. Details: [timeline-prefetch.md](timeline-prefetch.md), [performance.md](performance.md), [app-glass.md](app-glass.md), [build-and-test.md](build-and-test.md).
- Früher Prototyp, keine fertige Version 1. Arbeitsweise: `AGENTS.md`, `team.md`.
