# Fortsetzbarer Arbeitsstand

Stand: 31. Oktober 2026.

## Aktueller Stand

- **Build 11 (`0.1.0 (11)`)** aus Quellencheckpoint `ae0f428` (Code `847e9ff` plus Buildnummer 11) am 31.10.2026 von 04:55:25 bis 04:57:12 Uhr MEZ mit Xcode 27.1 (27A9275) nach TestFlight hochgeladen: Exit 0, `Upload succeeded`, letzter Serverzustand `Uploaded package is processing`; erstmals OHNE `testFlightInternalTestingOnly` (Wert `false`). Verarbeitungsabschluss, Installierbarkeit und externe Zuordenbarkeit sind nicht belegt. Details: [signing.md](signing.md), [testflight-upload.md](testflight-upload.md).
- **Kandidat Build 12** (Buildnummer im Repo weiterhin 11, kein Archiv/Upload): Build 11 plus adaptiver Poll-Takt für `latest.json` (`d6f5dff`) plus Links „Support“ und „Über ShowerNow“ im Info-Sheet.
- **Live-Messung vom 31.10.2026 04:59 MEZ (Messung des Auftraggebers, hier nicht erneut geprüft):** `/datenschutz`, `/marketing` und `/support` antworten HTTP 200; `history.json` liefert noch 404. Folgerung: Der Swarm ist älter als `sha-e80b6b8` (vermutlich `sha-6402a6a`, nur Vermutung). Der Inhalt des Apple-Abschnitts der Datenschutzseite ist nur im Backend-Repo bestätigt. Die App hängt von keiner dieser Seiten ab (die Links öffnen nur den Browser).

### Änderungen für Build 12 (Kandidat)

- **Support-/Über-Links (31.10.2026):** `RadarBackendConfig.supportURL` (`https://showernow.linolaske.de/support`) und `marketingURL` (`/marketing`) neben `privacyPolicyURL`; im Info-Sheet drei gleich gestaltete `Link`-Zeilen mit Accessibility-Hinweis und Kennungen `privacy-policy-link`, `support-link`, `marketing-link`. Neuer Test `SiteLinkTests` (https, Host gleich Radar-Host, Pfade). Geprüft: volle `WeatherTests` 154 Tests, zwei Läufe 0 Fehler; normaler Simulatorbuild (`generic/platform=iOS Simulator`) erfolgreich; Sichtprüfung iPhone 18 Pro (Light, temporärer, wieder entfernter XCUITest): alle drei Links sichtbar, gleiche Gestaltung. Nicht geprüft: Tippen/Safari-Ziel, Dark, iPad, VoiceOver, Dynamic Type, UI-Suite.
- **Adaptiver Poll-Takt (`d6f5dff`):** `RadarPollSchedule` (Fenster N+165 s bis N+300 s im 5-min-UTC-Raster, 10 s ± 2 s; sonst 60 s; Backoff 20/30/60 s nach leerem Fenster und bei Fehlern; Low Power/Low Data nur 60 s), Schleife `WeatherStore.runRadarPolling`. Regeln und Lastrechnung (1,4 bis 2,0 Requests/min statt 1) in [decisions.md](decisions.md). Geprüft: 15 neue Tests `RadarPollScheduleTests`; volle `WeatherTests` 153 Tests, zwei Läufe 0 Fehler; Simulatorbuild erfolgreich. Nicht geprüft: Gerät, Live-Backend (echte Ankunftszeiten), UI-Tests.

### Inhalt von Build 11 gegenüber Build 10

- Maximale Vergangenheit (1/2/6/12/24/48 h, Standard 2 h, Info-Sheet), `history.json`-Anbindung ([data-contract.md](data-contract.md)), Vorlade-Obergrenze 40 MB ([timeline-prefetch.md](timeline-prefetch.md)), Link „Datenschutzerklärung“, `project.yml` `TARGETED_DEVICE_FAMILY '1,2'`. Volle `WeatherTests` damals 118 Tests (25 neue `RadarHistoryTests`), drei Läufe, zwei grün, einmal der bekannte Kaltstart-Flake (inzwischen als Testaufbau-Fehler behoben, siehe unten). Im Simulator lief gegen das Live-Backend der Fallback (history.json 404): Hinweis „Historie nicht verfügbar“ sichtbar; Historie gegen ein Backend mit `history.json` ist ungetestet.
- Feines Scrubben und Animationsfenster (30.10.): `TimelineScrubSlider`, Logik in `Weather/Views/TimelineScrub.swift`, [timeline-build5.md](timeline-build5.md). 8 Tests `TimelineScrubTests`; volle Suite 126 Tests, zwei Läufe 0 Fehler. Sichtprüfung iPhone 18 Pro Light: Slider als Slider, Koordinaten-Drag bewegt Thumb/Zeit, Look unverändert. Nicht geprüft: Gestengefühl am Gerät (Schwellen 40/90/150 pt, Faktoren 1/0,5/0,25/0,1 sind Startwerte), VoiceOver, Dark, iPad, Dynamic Type, Haptik.
- Robuste Ortsprognose und Ortssuche-Datenschutz (31.10.): `DWDClient.fetch` (max. 3 Requests bei 502/503/504 und transienten `URLError`), neue `DWDDataError`-Fälle, letzte gültige Prognose je Ort (10 Orte) mit Altersanzeige, Datenschutztext Karte/Ortssuche. Diagnose: [research/diagnose-ortsprognose-ortssuche.md](research/diagnose-ortsprognose-ortssuche.md). 12 Tests `ForecastResilienceTests`; volle Suite 138 Tests, zwei Läufe 0 Fehler (ein erster Lauf scheiterte infrastrukturell: "Test crashed with signal term"). Nicht geprüft: Sichtprüfung des Fehlerzustands (kein Test-Hook).
- Test-Flakiness `RadarPrefetchTests` (31.10.): Ursache Testaufbau (statisches Prefetch-Budget nicht zurückgesetzt; verspätete `stopLoading`), kein Produktionsfehler; behoben, Belege in [prefetch-tests.md](prefetch-tests.md).

## Nächste Schritte

a. **Betreiber:** Backend auf dem Swarm auf `sha-e80b6b8` (oder neuer) aktualisieren, `.env`-Variablen prüfen, danach `history.json`, `/datenschutz`, `/support`, `/marketing` live prüfen. Ohne Update zeigt die App „Historie nicht verfügbar“.
b. **Betreiber:** Build 11 nach Verarbeitung in App Store Connect einer externen Gruppe zuordnen und Testinformationen ausfüllen ([apple-externe-tests.md](apple-externe-tests.md)).
c. **Gerätetest Build 11:** Scrub-Geste (Schwellen 40/90/150 pt sind Startwerte), Historie nach Backend-Update, Fallback auf den DWD-Weg.
d. **Build 12** nach Gerätefeedback (Poll-Takt und Links sind enthalten; Buildnummer dann setzen, Archiv/Upload per Releaseauftrag).
e. **Offene Produktentscheidungen:** Variante A/B der App-Privacy-Angaben, Rechtsprüfung/Impressum, Wortlaut des Veränderungshinweises, Zoraxy-Logs ([decisions.md](decisions.md)).
f. **Technische Restpunkte:** UI-Test `testNewMapPlaceCanBeSavedRenamedPersistedAndDeleted` vorbestehend rot; `DWDDataTests` bei `-test-iterations` im selben Prozess nicht wiederholbar (statischer Zustand); Banner „Einige Radarkacheln fehlen“ im DWD-Fallback weiter möglich (rechnerisch etwa 70 % je Frame bei Fehlerrate 1/3 und 3 Versuchen, nur Fallbackweg); Bildgrößen bei echtem Regen messen; Georeferenz/Echo-Rand/Transparenz bei Regen sowie iPad Querformat/Dark ungeprüft; Slider-Pille bleibt „lädt“, wenn nie ein `RadarLoadState` eintrifft (keine Zustandsunterscheidung). Widgets/Watch, Push, iPad-/Mac-Oberflächen folgen laut [plan.md](plan.md).

## Historie der Builds

Hashes, Zeiten und Prüfnachweise je Build: [signing.md](signing.md) und [testflight-upload.md](testflight-upload.md). Dort fehlende Zahlen stehen hier.

| Build | Quelle | Upload (MEZ) | Hinweise |
|---|---|---|---|
| 1/2 (`de.linolaske.weather`) | `0f48cb5` (Build 2) | Build 1 abgelehnt (`90474`); Build 2 am 28.10. 17:35:36 angenommen | Namenskonflikt mit Weather; kein belegter nutzbarer Build |
| 3 (`de.linolaske.showernow`) | `2e500fc` | 28.10. 17:51:38 | Intern über TestFlight vom Nutzer bestätigt |
| 4 | `6750d0e` | 28.10. 18:17:29 | Glass-Slider, lokale Einordnung (Foundation Models); 26 Tests |
| 5 | `c474893` | 28.10. 19:14:17 | P0-Korrekturen; 41 Tests, 0 Fehler |
| 6 | `87915f8` | 28.10. 20:01:53 | Budgetiertes Vorladen (50 MB RAM-Cache); 57 Tests |
| 7 | `1c093dd` | 30.10. 06:31:30 bis 06:33:03 | Mobilfunk-Prefetch, Slider-Feedback; 60 Tests; Befund Banner nach schnellem Scrubben |
| 8 | `cdd5735` | 30.10. 11:49:50 bis 11:50:53 | Vollständiges Vorladen (3 Worker, 250 ms, 240 Requests/60 s, 8 MB); 63 Tests; Upload mit Xcode 27.2 von Apple abgelehnt (Exit 70), mit 27.1 angenommen |
| 9 | `0c5e22f` | 30.10. 21:29:44 bis 21:31:14 | Radar-Cache-Backend zuerst, DWD-Fallback; 87 Tests, nach Nachbesserung `b59ec60` 93 Tests |
| 10 | `b106f1e` | 30.10. 21:49:46 bis 21:51:20 | Korrigierter Datenschutztext (`b9ce323`), intern-only |
| 11 | `ae0f428` | 31.10. 04:55:25 bis 04:57:12 | Siehe oben; erstmals ohne internal-only |

Sichtprüfung Build 9 (30.10., iPhone 18 Pro und iPad Air 11-inch, Debug): praktisch kein Regen in Deutschland, daher kein belastbarer Backend-gegen-DWD-Vergleich; Echo-Pixel bei Leipzig/Dresden lagen pixelgleich übereinander; Backendweg ohne Pille/Banner, Fallback mit gelegentlichem Banner (1 von 5 Scrubs); iPad Querformat wegen gedrehten XCUITest-Screenshots nicht bewertet. Build 7: Pille und Timeline überlagern sich nicht. Nebenbefund (Ursache nicht untersucht, später durch Retry/letzte gültige Prognose adressiert): einmalig „Ortsprognose: Die Wetterdaten konnten nicht gelesen werden“.

## Repository und lokale Konfiguration

- Dieses Repo: https://github.com/MagicalWig34653/weather-apple; Schwesterrepo: https://github.com/MagicalWig34653/weather-backend (Radar-Cache-Backend in Swift/Vapor, produktiv unter https://showernow.linolaske.de; Messung: [research/backend-radar-cache.md](research/backend-radar-cache.md)).
- Private lokale Pfade ausschließlich in der ignorierten `LOCAL_WORKSPACE.md`; Vorlage `LOCAL_WORKSPACE.example.md`.

## Prototyp-Umfang (Kurzfassung)

- XcodeGen-Projekt, Swift 6, iOS 27, zentrale Produktidentität in `Configuration/Base.xcconfig` (ShowerNow, `de.linolaske.showernow`, Team `J2DU2P47XW`, Universal, Compliance `false`).
- MapKit-Radarkarte (DWD-Läufe, Analyseframes, Vorhersage, Play/Pause), direkte DWD-Punktprognose ([data-contract.md](data-contract.md)), Ortssuche/-speichern/-umbenennen/-löschen, optionaler Standort nur bei Nutzung, Swift Charts, lokale Einordnung (Foundation Models, manuell), Datenalter- und Messung/Vorhersage-Trennung.
- Speicher: Punktprognosen im Speicher, Radar-Tiles im RAM-Cache (50 MB harte Grenze validierter PNGs), kein Festplatten-Netzwerkcache. Details: [timeline-prefetch.md](timeline-prefetch.md), [performance.md](performance.md), [app-glass.md](app-glass.md), [build-and-test.md](build-and-test.md).
- Früher Prototyp, keine fertige Version 1. Arbeitsweise (Agents, Dateibesitz): `AGENTS.md`, `team.md`.
