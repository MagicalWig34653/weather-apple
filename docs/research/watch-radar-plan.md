# Watch: Radarkarte mit Zeitsteuerung per Digital Crown

Stand: 3. November 2026. Reiner Plan, kein Produktcode. Nutzerwunsch vom 3.11.2026: Karte in der Watch-App, Zeit per Digital Crown drehen (wie die Zeitleiste in der iPhone-App). Baut auf `widgets-watch-plan.md` und `WeatherWatch/P5-Handoff.md` auf.

Kennzeichnung: **[B]** im Repo gelesen; **[S]** im installierten Xcode-27.2-SDK (watchOS-Header/Swiftinterfaces) belegt; **[L]** am Live-Backend gemessen (3.11.2026, nur lesende GET-Abrufe); **[A]** Annahme; **[U]** ungeprüft, am Gerät/Simulator klären.

## 1. Machbarkeit

**Kartenebene auf watchOS [S]**
- SwiftUI `Map` (`Map` seit watchOS 7, `MapContentBuilder`, `MapCameraPosition`, `Marker`, `Annotation`, `MapPolygon`, `MapCircle`, `MapPolyline`, `MapReader`/`MapProxy`, `mapStyle`) ist ab watchOS 10 verfügbar (`_MapKit_SwiftUI.swiftinterface`).
- **Nicht** verfügbar auf watchOS: `MKTileOverlay`, `MKOverlayRenderer`, `MKMapView.addOverlay(_:level:)` (alle `API_UNAVAILABLE(watchos)`). Kein eigener Bild-Overlay-Renderer wie `RadarImageOverlay` (iPhone, [B]) möglich; der iPhone-Weg ist nicht portierbar.
- Verfügbar: `MKMapSnapshotter`/`MKMapSnapshot.point(for:)` (watchOS 1.0, `preferredConfiguration` ab watchOS 10) [S]. Damit lässt sich ein statisches Kartenbild (Apple-Karte) rund um den Ort erzeugen und die Pixelposition jeder Koordinate berechnen.
- Radar als Vektor (`MapPolygon` je Pixel/Zelle) wäre technisch möglich, aber bei hunderten Zellen je Bild und Bildwechsel pro Crown-Detent zu teuer [A]; verworfen.

**Zeitsteuerung [S]**
- `digitalCrownRotation(detent:from:through:by:sensitivity:isContinuous:isHapticFeedbackEnabled:onChange:onIdle:)` für `BinaryInteger` und `BinaryFloatingPoint` vorhanden: ganzzahliger Detent-Index = Slot-Index, Haptik pro Detent eingebaut (`isHapticFeedbackEnabled`), `onIdle` zum Nachladen/Prefetch nach Stillstand. Ältere Variante mit Binding + `by:` ebenfalls vorhanden.

**Radardaten [L]** (`latest.json` live am 3.11.2026, Schema 1)
- Ein Bild für ganz Deutschland: WebP 1024 x 1311 px, EPSG:3857, bbox [612257, 5942074, 1736584, 7381298] (WGS84 5,5 bis 15,6 O / 47,0 bis 55,1 N). Gemessenes Beispielbild: **7.208 B**, unveränderliche URL (`Cache-Control: public, max-age=31536000, immutable`), Antwort 0,19 s.
- `latest.json`: **37 Slots mit 5-Minuten-Raster**, 12 Analysen (-1 h) und 25 Vorhersagen (bis +2 h). `history.json`: nur Analysen, 5-Minuten-Raster, `history_hours` 72. Die Achse ist damit 5 Minuten, nicht 15 (die 15-Minuten-Achse gilt nur für `cloudmask`-Ebenen) [L, B `RadarHistory.swift`].
- Pixelauflösung ca. 1,1 km/px in Mercator (ca. 0,7 km am Boden bei 51 N) [A, gerechnet aus bbox]. Ausschnitt ±40 km um den Ort ≈ 75 x 75 px; auf der Uhr (ca. 200 pt) also stark vergrößert, wirkt grob, aber so grob ist auch das DWD-Raster.

**Datenweg [B]**
- `Weather/Data/RadarBackend.swift` (`RadarBackendConfig`, `RadarManifest`, `RadarBounds`, `RadarImageGeometry`, `RadarBackendClient`) und `RadarHistory.swift` importieren nur `Foundation` und hängen nur an `RainForecast.maximumAge` (liegt in `Shared/`). Sie können ohne Umbau in das Target `WeatherWatch` aufgenommen werden (Eintrag in `project.yml` oder `git mv` nach `Shared/`). `RadarImageDecoder`/`DecodedImageCache` liegen in `RadarImageOverlay.swift` (zusammen mit MapKit-iOS-Typen) und werden für die Uhr neu, klein geschrieben statt gezogen.
- WebP-Dekodierung per ImageIO auf watchOS: **[U]**, am Simulator/Gerät prüfen (Fallback: Backend liefert nur WebP; PNG-Variante gäbe es nur mit Backend-Änderung).

**Eine Ausschnitts-/Thumbnail-API ist nicht nötig [L, B].** Ein Gesamtbild kostet ca. 7 KB; 37 Bilder ca. 260 KB (Regenlage größer, Faktor 3 bis 10 [A, `backend-radar-cache.md`], also bis ca. 2,5 MB). Im Backend-Repo (`Sources/RadarCore`) gibt es keine Crop-/Thumbnail-Funktion; Vorschlag nur als spätere Option (siehe 4).

**Speicher [A/U]**: Dekodiertes Gesamtbild = 1024 x 1311 x 4 B = 5,4 MB (transient, jeweils nur eins). Der Ausschnitt (z. B. 160 x 160 px RGBA = 100 KB) wird sofort herausgeschnitten, das Gesamtbild verworfen: 37 Ausschnitte ≈ 4 MB. Das genaue Speicherlimit der Watch-App ist in der Apple-Doku nicht als feste Zahl belegt; Messung am Gerät nötig [U]. Der iPhone-Cache `DecodedImageCache` (48 MB) wird auf der Uhr **nicht** übernommen.

## 2. Varianten

| | A: Bildkarte + Marker | **B: Kartenschnappschuss + Radarausschnitt (empfohlen)** | C: Live-`Map` + Image darüber |
|---|---|---|---|
| Hintergrund | keiner (dunkel, ggf. Landesgrenzen fehlen) | `MKMapSnapshotter` (Apple-Karte, ein Bild je Ort/Zoom) | `Map` mit fester Kamera |
| Radar | Ausschnitt aus WebP als `Image` | Ausschnitt als `Image`, Pixelversatz per `snapshot.point(for:)` und eigener Mercator-Rechnung | Image per `MapProxy.convert` ausgerichtet |
| Ausrichtung | eigene Mercator-Rechnung | Snapshot liefert Referenzpunkte, deterministisch, testbar | Kamera der Live-Karte kann von Rechnung abweichen [U] |
| Orientierung | schlecht | gut (Straßen/Orte) | gut |
| Aufwand/Risiko | klein | mittel | mittel bis hoch, Rendern pro Frame in `Map` |
| Akku | niedrig | niedrig (Snapshot einmal) | höher |

Empfehlung **B**, mit A als Rückfall (Snapshot nicht verfügbar/offline: Radarausschnitt auf dunklem Grund mit Ortsmarker und Entfernungsring). Zoom-Stufen 2 (z. B. 40 km und 100 km), per Doppeltipp/Button, nicht per Crown (die Crown gehört der Zeit).

**Bedienung**: Crown dreht den Slot-Index (Detent je 5 min, Haptik), oben Uhrzeit des Slots ("19:20", Vorhersage mit "+35 min"), Marker "Jetzt" auf der Achse. Play/Pause-Button (Standard: pausiert, startet auf dem aktuellen Slot; Wiedergabe nur im Vordergrund, nicht im Always-on/`isLuminanceReduced`). Zeitbereich Start: -1 h bis +2 h (37 Slots, aus `latest.json`), kein `history.json` auf der Uhr (Option -2 h bis -6 h später, 5-min-Raster, Kosten ca. 7 KB je Slot).
Zeitleiste als schmaler Balken am Rand; Quellen-/Alter-Hinweis wie die iPhone-App (DWD-Quelle, "Stand HH:mm", stale ab 20 min keine Trocken-Aussage) [B: `RadarBackendConfig.maximumDataAge`].

## 3. Daten, Cache, Akku

- Abruf direkt vom Backend über `RadarBackendClient` (gleiche ephemere URLSession, keine Cookies, kein Standort im Request [B]); der Request sendet **nie** Koordinaten, der Ausschnitt wird lokal berechnet. Entspricht dem Datenschutzversprechen der Karte.
- Ablauf: Ansicht öffnen: `latest.json` (ETag), Slot "jetzt" zuerst laden und anzeigen, danach die übrigen 36 Slots gestaffelt (2 parallel, Nähe zu "jetzt" zuerst), Zielgröße ca. 0,3 bis 2,5 MB. Bei Wiederöffnen innerhalb von 5 min gleicher Lauf: kein Neuabruf (URLs unveränderlich).
- Cache: nur Arbeitsspeicher (Ausschnitte als `CGImage`, LRU nach Ort, höchstens ein Ort), **keine Festplatte** (kein Standortverlauf, wie `RadarBackendPolicy`); optional ein zuletzt gezeigter Frame als Platzhalter ist nicht nötig.
- Prefetch nur im Vordergrund und bei geöffneter Radaransicht, kein Hintergrundabruf, kein Poll; Aktualisieren manuell oder beim erneuten Öffnen. Bei Low-Power-Modus (`ProcessInfo.isLowPowerModeEnabled`) nur aktueller Slot plus ±2 Slots laden [A].
- Fehlerbild wie iPhone: Backend nicht erreichbar: Hinweis "Radar nicht verfügbar", Prognose-Seite bleibt (nicht der DWD-Kachel-Fallback der iPhone-App; zu teuer für die Uhr) [A, Entscheidung E2].
- Netz: Uhr nutzt WLAN/LTE/Proxy über iPhone nach System [A]. Datenvolumen pro Öffnung ca. 0,3 bis 2,5 MB (LTE-Tarife der Nutzer beachten, Hinweistext).

## 4. Backend-Optionen (Schwesterrepo, nur gelesen)

Keine Änderung nötig für die empfohlene Variante. Falls Messungen am Gerät zu viel Daten/Dekodierzeit zeigen: additiv `GET /v1/radar/crop?cx=&cy=&r=` (serverseitig ausgeschnittener Frame, ca. 2 bis 4 KB) oder ein "Filmstreifen"-WebP aller Slots. Nachteile: Ort wird dem Server mitgeteilt (Datenschutz), keine unveränderliche Cache-URL. Deshalb **nicht** vorschlagen, solange Variante B reicht.

## 5. Arbeitspakete (Dateibesitz exklusiv)

| Nr. | Paket | Besitz (schreibend) | Wer |
|---|---|---|---|
| W1 | Radar-Datenschicht Watch: Target-Quellen (`project.yml`: `RadarBackend.swift`, `RadarHistory.swift`, `RadarPollSchedule.swift` bei Bedarf), `WatchRadarStore` (Manifest, gestaffeltes Laden, RAM-Cache, Ausschnitt-Crop), `RadarCrop` (reine Mercator-Rechnung Ort + Radius → Pixelrechteck), WebP-Decode-Check | `WeatherWatch/Radar/WatchRadarStore.swift`, `WeatherWatch/Radar/RadarCrop.swift`, `project.yml` (nur Quellenzeilen) | Codex |
| W2 | Kartenhintergrund: `MKMapSnapshotter`-Wrapper, Ausrichtung Snapshot ↔ Radarausschnitt, Rückfall A | `WeatherWatch/Radar/WatchMapBackdrop.swift` | Codex |
| W3 | Oberfläche: `WatchRadarView` (Crown-Detents, Uhrzeit, Play/Pause, Zoom, Alter/Quelle), Einstieg aus `WatchPlacesView` (ein Link), Lokalisierung de/en | `WeatherWatch/Radar/WatchRadarView.swift`, `WeatherWatch/{de,en}.lproj/Localizable.strings`, kleiner Eingriff `WatchPlacesView.swift` | Claude (Gestaltung, Sichtprüfung) |
| W4 | Tests: `RadarCropTests` (Mercator-Rechnung gegen bekannte Orte, Rand/außerhalb), Slot-Index ↔ Zeit, Ladereihenfolge, Stale-Regel, Cache-Grenze; portabler Harness wie P5 | `WeatherTests/WatchRadarTests.swift` | Codex |
| W5 | Integration/Build/Simulator/Gerät: watchOS-Build, Screenshots Series 11/Ultra, Speicher- und Akkumessung am Gerät, `status.md`, Buildnummer | Build, `docs/status.md` | Claude |

Codex-geeignet: W1, W2, W4 (3 von 5). Reihenfolge: W1 und W4 (Rechnung/Tests) parallel, dann W2, W3, zuletzt W5. Geschätzt 3 bis 5 Arbeitstage Agentenarbeit plus Gerätetest; höchstens 3 Worker gleichzeitig.

## 6. Risiken

1. WebP-Dekodierung auf watchOS per ImageIO nicht belegt [U] (früh im Simulator und am Gerät prüfen; sonst Backend-PNG/Eigendecoder, Mehraufwand).
2. Speicher/Dekodierzeit je Frame (5,4 MB transient) auf kleiner Uhr; Dekodieren seriell auf Hintergrund-Task, Gesamtbild sofort verwerfen.
3. Ausrichtung Snapshot ↔ Radar: `MKMapSnapshot.point(for:)` und Mercator-Rechnung müssen zusammenpassen (Test mit zwei Referenzorten); Karte in Dunkelmodus/Stil abstimmen, Radarfarben auf Karte lesbar.
4. LTE-Datenverbrauch und Akku bei Wiedergabe (nur Vordergrund, kein Poll).
5. `MKMapSnapshotter` braucht Netz für Kartenkacheln; offline Rückfall A nötig.
6. Pixelgrobheit (1 km): Erwartung der Nutzer (keine Regenfront im Straßenmaßstab); im Info-Text benennen.

## 7. Tests

Unit/Harness: `RadarCrop` (Koordinate → Pixel, Ränder, Orte außerhalb der bbox), Slot-Auswahl/Detent-Mapping, Cache-LRU, Stale (>=20 min wie P5), gestaffelter Prefetch mit Fake-Transport, 404/ungültiges Manifest. Simulator: Layout Series 11 / Ultra 3, Dynamic Type, de/en. Nur am Gerät (offen, nicht als erledigt melden): Crown-Haptik, Speicher, Akku/LTE, WebP-Dekodierung, Snapshotter offline, Always-on.

## 8. Datenschutz

Backend-Requests enthalten keine Koordinaten; Ausschnitt lokal. `MKMapSnapshotter` sendet den Kartenbereich an Apple (wie die Karte in der iPhone-App, Apple-Dienst; im Datenschutztext ergänzen). Kein Verlauf, kein Festplatten-Cache, kein Hintergrundabruf, keine Debuglogs mit Orten. Gleiche Regel wie P5.

## 9. Vorschlag Build 16

Kein Umfang vor Gerätetest. Vorschlag: Build 16 enthält W1 bis W3 hinter Hinweis "Radar (Vorschau)" in der Watch-App, falls E1 bestätigt; sonst nur Prognose wie Build 15. TestFlight-/Datenschutzangaben um Karte und Backend-Abruf ergänzen. Abnahme: Simulator zeigt Slots per Crown (Simulator unterstützt Crown mit Mausrad), danach Gerätetest.

## 10. Offene Entscheidungen (mit Empfehlung)

- **E1 Variante**: B (Snapshot + Radarausschnitt) empfohlen; Alternativen A (nur Bildkarte, schnell, ohne Karte), C (Live-`Map` + Image, riskant).
- **E2 Offline/Fehler**: Empfehlung: nur Backend, bei Ausfall Hinweis und kein DWD-Kachel-Fallback auf der Uhr; Alternative: Fallback wie iPhone (viel mehr Code, mehr Daten).
- **E3 Zeitbereich**: Empfehlung -1 h bis +2 h (37 Slots, 5-min-Detents, ohne `history.json`); Alternative -3 h bis +2 h (zusätzliche History-Abfrage, ca. +24 Slots).
