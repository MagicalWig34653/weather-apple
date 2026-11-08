# Temperatur- und Feuchtekarte Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax. Projektregel (`docs/team.md`): jedes Paket erhält einen frischen ausführenden Agent, höchstens drei parallel, Hauptagent koordiniert nur, **pro Repo genau ein Agent mit Build/Test** (APP: `xcodebuild`, BE: `swift test`). Jeder Agent liest zuerst `docs/status.md`, `docs/decisions.md`, die Spec und die Repo-`AGENTS.md`, meldet `post_progress` mit voller Todolino-Aufgaben-ID und aktualisiert `docs/status.md` seines Repos. Nur tatsächlich ausgeführte Prüfungen als erfolgreich melden.

**Goal:** Ebenen "Temperatur" und "Feuchte" (Taupunkt, optional relative Feuchte) mit Zeitleiste +48 h, Legende und Quelle im Radar-Bildschirm; Quelle serverseitig umschaltbar (`TEMP_SOURCE=wms|icon_d2|off`, Fallback ICON-D2 -> WMS, ohne App-Update); einblendbare Waldebene (WorldCover) nur zur Orientierung.

**Architecture:** Neue Vorhersage-Ebenen im vorhandenen Layer-System des Backends (`LayerSpec`, `LayerIngestor`, `/v1/layers/<id>/latest.json`). Öffentliche IDs `temperature`, `dewpoint`, `humidity` lösen zur Anfragezeit auf interne Speicher-IDs je Quelle auf (`temperature_wms`, `temperature_d2`, `dewpoint_d2`, `humidity_d2`). Variante A holt WMS-Bilder (wie Luftdruck), Variante B lädt ICON-D2-GRIB2 (eigener Dekoder, libbz2), projiziert auf die Radar-BBOX und färbt gestuft. Die App zeigt nur Ebenen mit vorhandenem Manifest (Muster `pressureEU`). Wald: statisches Bild im App-Bundle.

**Tech Stack:** Swift 6 / Vapor 4 (BE, `swift test`), SwiftUI/MapKit/XCTest (APP, `xcodebuild`), Python 3 Stdlib für Werkzeuge (Wald, Palettenprüfung), libbz2 (neu, nur Paket P4).

**Spec:** `docs/superpowers/specs/2026-11-08-temperatur-feuchte-karte-design.md`. **Repos:** APP `/Users/linolaske/Development/Xcode/weather`, BE `/Users/linolaske/Development/PhpstormProjects/weather`. Pfade ohne Präfix gelten im jeweils genannten Repo; "APP"/"BE" davor sagt, welches.

## Global Constraints

- Nur Entwicklung, **kein Produktiv-Deploy**, kein Serverzugriff, keine Geheimnisse. Standardwerte: `TEMP_SOURCE=off`, `LAYERS` ohne `temperature` (Feature bleibt ohne Konfiguration unsichtbar).
- Keine Waldkorrektur, kein "gefühlt", keine Frost-/Glättelogik (Teilprojekt 2 später). Legende sagt "Modell, kein Messwert".
- Kartenabrufe ohne Ortsangabe; Wertabfrage lokal aus dem Bild; keine neue Datenkategorie, keine Debuglogs mit Kennungen.
- Interne Layer-IDs höchstens 16 Zeichen (`layer VARCHAR(16)`); Läufe/Slots der Quellen getrennt speichern.
- Skala und Farben nicht nur als Farbe: numerische Legende, `spokenLabel`, Wertabfrage; Palette gegen Farbfehlsichtigkeit geprüft (Skript).
- Unbekannte `scale`/`source` in der App: kein erratenes Raster, nur Hinweistext (Fail-closed).
- GRIB: Schablonen 3.0 und 5.0 mit Bitmap, Gitter 1215 x 746; alles andere verwerfen (`invalid`) und auf A zurückfallen.
- Quellenvermerke: DWD "Quelle: Deutscher Wetterdienst" + Veränderungshinweis; Wald "(c) ESA WorldCover project 2021 / Contains modified Copernicus Sentinel data (2020/2021) processed by ESA WorldCover consortium" (Wortlaut in P3.1 gegen die Nutzungsbedingungen prüfen).
- Wald im App-Bundle: Ziel höchstens 1 MB, Messwert in `docs/status.md`.

## Wellen und Abhängigkeiten

| Welle | Pakete (parallel, getrennter Dateibesitz) | Voraussetzung | Sofort startbereit |
|---|---|---|---|
| 1 | **P1** (BE: Skalen-Vertrag, Variante A, Schalter, Alias/Fallback), **P2** (APP: Ebenen, Manifest, generische Legende, Zeitleiste), **P3** (APP-Daten: Wald-Rohdaten und Werkzeug, **kein xcodebuild**) | Spec freigegeben | ja, alle drei |
| 2 | **P4** (BE: ICON-D2-Ingest), **P5** (APP: native Legende, Wertabfrage, Waldebene) | P4 nach P1 (Config/Spec/Skalen-Datei); P5 nach P1.0 (Skalen-JSON), P2 und P3 | nein |
| 3 | **P6** (Abschluss: Doku, Rollout-Checkliste, Quellenseite, Messungen) | P4, P5 | nein |

Dateibesitz (keine Überschneidung innerhalb einer Welle): **P1** `BE Sources/RadarCore/{Layers,Config,ConfigRegistry,Api,TempSource}.swift`, Anbindung in `LayerIngestor.swift`/`Manifest.swift` (nur Spec-/Alias-Stellen), `BE Sources/radar/Radar.swift` (Schleifen), `BE deploy/swarm/stack*.yaml`/`settings`-Tabellen, `BE docs-site/content/{api,betrieb}.md`, `BE docs/fixtures/scales/`, `BE tools/check_palette.py`, Tests `BE Tests/RadarCoreTests/Temp*Tests.swift`. **P2** `APP Weather/Data/RadarLayer.swift`, `APP Weather/Map/RadarLayerLegend.swift` (Hinweise/Legendenbild), `APP Weather/Views/{RadarScreen,InformationSheet}.swift` (nur Einhängepunkte), `APP WeatherTests/RadarLayerTests.swift`, Fixtures `layer-temperature-*.json`. **P3** `APP tools/forest_overlay.py`, `APP Weather/Resources/Forest/` (Daten), `APP docs/research/wald-ebene.md`. **P4** `BE Sources/RadarCore/{GribDecoder,Bzip2,MercatorRender,TempScale,Icon2D*}.swift`, `BE Sources/CBz2/` (System-Library), `BE Package.swift`, `BE Dockerfile`, Tests `BE Tests/RadarCoreTests/{Grib,Icon2D}*Tests.swift`, Fixtures; **Absprache:** `Layers.swift`/`Config.swift`/`Radar.swift` gehören nach P1 dem P4-Agenten. **P5** `APP Weather/Map/{TemperatureScale,ForestOverlay,PixelReadout}.swift`, `APP Weather/Map/RadarLayerLegend.swift` (Legendenpanel), `APP Weather/Resources/de.lproj|en.lproj/Localizable.strings` (nur `TEMP_*`/`FOREST_*`), Tests `APP WeatherTests/{TemperatureScale,PixelReadout,Forest}Tests.swift`. **P6** Doku beider Repos.

---

## P1: Backend Vertrag, Variante A, Schalter, Alias/Fallback (BE)

**Aufwand:** L. **Nach:** Spec. **Build/Test:** `cd /Users/linolaske/Development/PhpstormProjects/weather && swift test --filter Temp` (Memory-Repo, ohne DB), vor Abschluss volle Suite.

### Task P1.0: Skalen-Vertrag und Palette

**Files:** Create `BE docs/fixtures/scales/scales-v1.json`, `BE tools/check_palette.py`; Modify `BE docs-site/content/api.md` (Abschnitt "Temperatur- und Feuchtekarten").

**Interfaces (Produces):** JSON `{ "schema": 1, "scales": [ { "id": "t2m-d2-v1", "unit": "°C", "min": -30, "max": 40, "step": 1, "label_every": 5, "bands": [ { "from": -30, "hex": "#RRGGBB" } ] } ] }`; Skalen `t2m-d2-v1` (-30..40, 1 K), `td-d2-v1` (-20..24, 1 K), `rh-d2-v1` (0..100, 5 %). Werte unter `min`/über `max` gehören zur ersten/letzten Klasse (Beschriftung "unter -30", "über 40").

- [ ] **Step 1:** Palette entwerfen (monotone Helligkeit je Skala, Temperatur divergierend um 0 °C, keine reine Rot/Grün-Nachbarschaft); `tools/check_palette.py` (Stdlib) simuliert Protanopie/Deuteranopie/Tritanopie (Machado-Matrizen) und prüft, dass benachbarte 5-K-Beschriftungsstufen CIE76-Abstand mindestens 10 haben; Skript gibt Tabelle aus, Ergebnis in `docs/status.md`.
- [ ] **Step 2:** `scales-v1.json` schreiben, Skript laufen lassen (nur tatsächlich ausgeführtes Ergebnis melden).
- [ ] **Step 3:** `api.md`: öffentliche IDs, Manifest-Zusatzfelder `source` (`wms`|`icon_d2`) und `scale` (nur bei `icon_d2`), Verhalten bei `off`/Ausfall (404), `legend` bei `wms`, Beispielmanifeste für beide Quellen.
- [ ] **Step 4:** Commit `docs: Vertrag und Skalen Temperatur-/Feuchtekarte`. Die JSON-Datei danach vom Lead (oder P2/P5-Agent) per Kopie in `APP WeatherTests/Fixtures/scales-v1.json` und `APP Weather/Resources/scales-v1.json` übernommen.

### Task P1.1: Konfiguration und Schalter (TDD)

**Files:** Modify `BE Sources/RadarCore/Config.swift`, `ConfigRegistry.swift`, `deploy/swarm/stack.yaml` (Umgebung durchreichen, Muster `LAYERS: ${LAYERS:-}` [B `stack.yaml:33`]); Create `BE Sources/RadarCore/TempSource.swift`; Test `BE Tests/RadarCoreTests/TempSourceTests.swift`.

**Interfaces:** `public enum TempSource: String { case off, wms, icon_d2 }`; `Config.temp: TempConfig { source, d2Params: Set<String> (td_2m Standard), fallbackWarm: Bool (true), d2MaxAgeHours: Int (7), wmsLayer: String, d2RunIntervalHours: Int (3) }`; Umgebungsvariablen `TEMP_SOURCE`, `TEMP_D2_PARAMS`, `TEMP_FALLBACK_WARM`, `TEMP_D2_MAX_AGE_HOURS`, `TEMP_WMS_LAYER`, `TEMP_D2_RUN_INTERVAL_HOURS` (3|6); alle in `ConfigRegistry` als `.live`; `LayerCatalog.parse` akzeptiert `temperature` als Hauptschalter (Neustart).

- [ ] **Step 1:** Failing tests: Parsing (Standard `off`, ungültiger Wert wirft `ConfigError` wie bei `LAYERS`), `d2Params` nur aus `{t_2m, td_2m, relhum_2m}`, Grenzen der Zahlen.
- [ ] **Step 2:** Implementieren, `ConfigRegistry`-Zeilen mit deutscher Beschreibung, `stack.yaml`/Tabellen-Check (`deploy/` Skript `check-config-tables.sh`, falls vorhanden, ausführen und Ergebnis melden [N, Skriptname im Repo suchen]).
- [ ] **Step 3:** Tests PASS, Commit `feat: Konfiguration TEMP_SOURCE und Parameter`.

### Task P1.2: LayerSpec `temperature_wms` und Stil-Parameter (TDD)

**Files:** Modify `BE Sources/RadarCore/Layers.swift`; Test `BE Tests/RadarCoreTests/TempLayerSpecTests.swift`.

- [ ] **Step 1:** Failing test: `LayerSources.mapURL(spec: temperature_wms, ...)` enthält `LAYERS=dwd%3AIcon-eu_reg00625_fd_gl_T`, `STYLES=icon-eu_reg00625_fd_gl_t_isoarea_tkb`, `TIME`, `DIM_REFERENCE_TIME` (Muster bestehender Luftdruck-Test); Spec-ID ≤ 16 Zeichen; Rückfalllayer `dwd:Icon_reg025_fd_sl_T2M` mit Stil leer.
- [ ] **Step 2:** `LayerSpec` um `wmsStyle: String = ""` erweitern (init-Default, `resized` kopiert), `mapURL` setzt `STYLES`. Neue Specs `temperature_wms` (Legende `GetLegendGraphic` mit `style=...` [G Beispiel in Spec 3.4]), die Specs der B-Ebenen legt erst P4 an. `LayerCatalog.order`/Status berücksichtigen interne IDs.
- [ ] **Step 3:** `publishCadenceSeconds` je Spec parametrisierbar (6 h für WMS-Läufe, 3 h später für D2) und Test.
- [ ] **Step 4:** Commit `feat: Ebene temperature_wms (WMS, Stil)`.

### Task P1.3: Auflösung öffentliche -> interne Ebene und Fallback (TDD)

**Files:** Create `BE Sources/RadarCore/TempResolver.swift`; Modify `BE Sources/RadarCore/Api.swift` (`parseLayerRoute`, Layer-Zustände, `buildStatus`, Cache-Schlüssel), `Manifest.swift` (`source`, `scale`); Test `BE Tests/RadarCoreTests/TempResolverTests.swift`.

**Interfaces:** `TempResolver.resolve(publicID: String, config: Config, latest: (String) -> Date?, now: Date) -> String?` (interne ID oder nil = 404). Regeln: `off` -> nil; `wms`: `temperature` -> `temperature_wms`, `dewpoint`/`humidity` -> nil; `icon_d2`: `temperature` -> `temperature_d2`, wenn jüngster Lauf höchstens `d2MaxAgeHours` alt, sonst `temperature_wms` falls dessen Lauf höchstens 18 h alt, sonst nil; `dewpoint`/`humidity` -> `*_d2` (nur wenn in `d2Params` und frisch), sonst nil.

- [ ] **Step 1:** Failing tests für alle Zeilen der Regeltabelle inkl. Altersgrenzen (Zeit gemockt).
- [ ] **Step 2:** Resolver implementieren; `Api.swift` löst `/v1/layers/<öffentlich>/...` per Resolver auf, Cache-Schlüssel `layer:<intern>/...`, Status-`layers` führt öffentliche IDs mit `enabled`/`has_data` (nach Resolver), Manifest ergänzt `source` und (bei D2) `scale`. **Prüfpunkt [N]:** Auswirkung auf `layerStates`/Cache-Löschen (`CacheAdminRepo`, "clear cache" je Ebene `layer:<id>/`); Test für Cache-Admin mit interner ID.
- [ ] **Step 3:** Tests PASS, Commit `feat: Ebenen-Alias und Fallback fuer Temperatur/Feuchte`.

### Task P1.4: Ingest folgt `TEMP_SOURCE` (TDD)

**Files:** Modify `BE Sources/RadarCore/LayerIngestor.swift` (nur Takt-Gate), `BE Sources/radar/Radar.swift` (Schleife für `temperature_wms` bei `LAYERS` mit `temperature`); Test `BE Tests/RadarCoreTests/TempIngestGateTests.swift`.

- [ ] **Step 1:** Failing test: Takt mit `TEMP_SOURCE=off` ruft die Abruf-Funktion nicht auf (Fake `fetch` zählt), `wms` ruft ab, `icon_d2` mit `fallbackWarm=true` ruft A ab, mit `false` nicht.
- [ ] **Step 2:** Gate in `tick()` (liest `config` je Takt), `Radar.swift` startet die Schleife nur, wenn `LAYERS` `temperature` enthält.
- [ ] **Step 3:** Voller `swift test`, Commit `feat: Ingest-Gate nach TEMP_SOURCE`.

### Task P1.5: Dokumentation und Übergabe

- [ ] `BE docs-site/content/betrieb.md`: Flags, Reihenfolge Rollout (Spec §7), Lastangabe A (ca. 200 Abrufe/Tag). `BE docs/status.md` und `BE docs/decisions.md` aktualisieren (Alias-Entscheidung, `VARCHAR(16)`), Ergebnisse der Prüfläufe (Anzahl Tests, Palettenskript). Todolino `post_progress`.

---

## P2: App Ebenen, Manifest, generische Legende, Zeitleiste (APP)

**Aufwand:** M. **Nach:** Spec (Manifest-Vertrag aus Spec 3.2/3.4; keine Abhängigkeit von P1). **Build/Test:** `xcodebuild` laut `README.md`, Schema `Weather`, iPhone-Simulator ohne Signing; **dieser Agent ist in Welle 1 der einzige mit `xcodebuild` im APP-Repo.**

### Task P2.1: Ebenen im Modell (TDD)

**Files:** Modify `APP Weather/Data/RadarLayer.swift`; Test `APP WeatherTests/RadarLayerTests.swift`; Fixtures `APP WeatherTests/Fixtures/layer-temperature-wms.json`, `layer-temperature-d2.json`, `layer-dewpoint-d2.json` (Muster `layer-pressure.json`).

- [ ] **Step 1:** Failing tests: `RadarLayer.temperature/dewpoint/humidity` mit Rohwerten `temperature`, `dewpoint`, `humidity`; in `selectable` und `backendLayers`; `isOfferedWhenUnavailable == false`; `offeredLayers` zeigt sie erst bei `availability == .available`; Titel "Temperatur", "Feuchte (Taupunkt)", "Feuchte (relativ)"; Schritt 60 min, `frameCaption` "Vorhersage"/"Modell"; Manifest-Parser nimmt Fixtures an (Slots 49, `source`, optional `scale`).
- [ ] **Step 2:** Implementieren (Switches in allen `RadarLayer`-Properties vollständig, sonst Compilerfehler), `RadarLayerManifest` um optionale Felder `source: String?`, `scale: String?` erweitern (fehlende Felder = nil, bestehende Fixtures unverändert grün). `prefetchSlotLimit` 13, `overlayOpacity` 0,8, `maximumForecastRunAge` bleibt 18 h.
- [ ] **Step 3:** Tests PASS, Commit `feat: Temperatur- und Feuchteebenen im Modell`.

### Task P2.2: Legende und Hinweise (generisch)

**Files:** Modify `APP Weather/Map/RadarLayerLegend.swift` (Hinweistexte `hint`, `title`, `toggleHint` für neue Ebenen; Legendenbild für `temperature` mit `source == wms` über `RadarLegendImageLoader`, Host `maps.dwd.de` bereits erlaubt [B]), `APP Weather/Views/InformationSheet.swift` (Quellenliste durchläuft `selectable` [B `:155`], prüfen).

- [ ] **Step 1:** Failing tests (`RadarLegendTests`): Hinweistext nennt "Modellprognose, kein Messwert" und enthält weder "gefühlt" noch "Wald"-Korrekturhinweise; `legend`-Referenz aus Manifest wird nur bei Host-Whitelist geladen.
- [ ] **Step 2:** Implementieren; bei `scale != nil` und noch ohne Skalentabelle (P5) nur Hinweistext + Quellzeile (Fail-closed).
- [ ] **Step 3:** Commit `feat: Legendenhinweise Temperatur/Feuchte`.

### Task P2.3: Karte und Zeitleiste

**Files:** Modify `APP Weather/Views/RadarScreen.swift`/`APP Weather/Map/RadarMap.swift` nur wo Ebenen-Switches existieren (grep `.pressure`).

- [ ] **Step 1:** Prüfen, dass Overlay (`RadarImageOverlay`, Bounds aus Manifest) und `TimelineScrub` ohne Spezialfall laufen (Ebene `forecast`, 49 Slots); Spezialfälle nur ergänzen, wenn ein Switch exhaustiv ist.
- [ ] **Step 2:** UI-Test mit DEBUG-Stub (Muster `-UITestWarnings`): Ebenenmenü zeigt Temperatur erst mit Fixture-Manifest, Legende öffnet, Zeitleiste bei XXXL Dynamic Type bedienbar (bestehende Testhilfen).
- [ ] **Step 3:** Voller Lauf `Weather` melden (Anzahl Unit/UI), `docs/status.md` aktualisieren, Todolino `post_progress`.

---

## P3: Waldebene Rohdaten und Werkzeug (APP, ohne xcodebuild)

**Aufwand:** M. **Nach:** Spec. **Kein `xcodebuild`, keine Änderung an Swift- oder Projektdateien.**

### Task P3.1: Lizenz und Quelle festschreiben (Gate)

**Files:** Create `APP docs/research/wald-ebene.md`.

- [ ] **Step 1:** Primärquellen lesen und mit URL und Abrufdatum festhalten: WorldCover 2021 v200 Nutzerhandbuch/Lizenz (CC BY 4.0, **exakter Attributionswortlaut**), Kachelraster/Download (`esa-worldcover.s3.eu-central-1.amazonaws.com/v200/2021/map/`, Kachelliste für Deutschland), Klassenschlüssel (10 = Tree cover). Optional Gegenprüfung Copernicus HRL Tree Cover Density (Lizenzklausel) und BKG; **nur Geprüftes als geprüft**.
- [ ] **Step 2:** Entscheidung dokumentieren (WorldCover bleibt, wenn Lizenz bestätigt); bei Abweichung Lead fragen.

### Task P3.2: Werkzeug und Rohdaten

**Files:** Create `APP tools/forest_overlay.py`; Output `APP Weather/Resources/Forest/forest-de-v1.webp` und `forest-de-v1.json` (Bounds EPSG:3857 der Radar-BBOX, Breite/Höhe, Quelle, Erzeugungsdatum, Attribution).

- [ ] **Step 1:** Werkzeugprüfung: `which gdalinfo gdalwarp cwebp` (lokal: GDAL **nicht** installiert, `cwebp` vorhanden [G 08.11.]); falls GDAL fehlt, `brew install gdal` (kostenlos) oder eigener COG-Leser mit `zlib` (Stdlib) im Skript; Entscheidung dokumentieren.
- [ ] **Step 2:** 20 Kacheln (N45..N54 x E003..E015, ca. 1,9 GB [A], nur die tatsächlich nötigen) in ein Verzeichnis **außerhalb des Repos** laden (nicht committen), Klasse 10 -> Anteil je Zielpixel (Radar-BBOX `612257.5,5942074,1736584,7381298`, 2048 px Breite, Höhe nach Seitenverhältnis 2621) durch Mittelung in EPSG:3857, Ausgabe als RGBA (Grün, Alpha = Anteil x Deckkraft), WebP verlustfrei oder alpha_q 100, Größe messen.
- [ ] **Step 3:** Sichtprüfung (Screenshot im Scratchpad, nicht eingecheckt), Größe und Schritte in `wald-ebene.md`; Reproduzierbarkeit (Befehl, Version der Daten). Commit `feat: Waldebene Rohdaten und Werkzeug`. Rohkacheln nie committen (`.gitignore` prüfen).

---

## P4: Backend ICON-D2-Ingest (BE)

**Aufwand:** L. **Nach:** P1 (Config, Resolver, Specs, Skalen-JSON). **Build/Test:** `swift test --filter 'Grib|Icon2D|Temp'`; Image: `docker build` lokal falls Docker verfügbar [N], sonst CI-Hinweis.

### Task P4.1: GRIB2-Dekoder (TDD)

**Files:** Create `BE Sources/RadarCore/GribDecoder.swift`; Test `BE Tests/RadarCoreTests/GribDecoderTests.swift`; Fixtures `BE Tests/RadarCoreTests/Fixtures/grib/` (kleine GRIB2, siehe Step 1).

**Interfaces:** `public struct GribField { ni: Int, nj: Int, lat1, lon1, dLat, dLon: Double, scanMode: UInt8, referenceTime: Date, forecastMinutes: Int, parameter: (category: UInt8, number: UInt8), values: [Float?] }`; `public enum GribDecoder { public static func decode(_ data: [UInt8]) throws -> GribField }`; Fehler `GribError.unsupported(String)`.

- [ ] **Step 1:** Fixtures: (a) echte Datei per Skript auf wenige hundert Punkte reduziert und neu verpackt oder synthetisch mit dem Python-Referenzcode aus Spec 2 erzeugt (Bitmap, 16 Bit, Referenzwert R, E, D), (b) falsche Schablone (5.42), (c) falsches Gitter. Eine echte Datei (`t_2m`, 1,6 MB) **nicht** einchecken; Test dagegen nur bei gesetzter Umgebungsvariable `ICON_D2_SAMPLE`.
- [ ] **Step 2:** Failing tests: Abschnitte 1/3/4/5/6/7 lesen, Gitter 1215 x 746 und 0,02° Prüfung als Parameter, Werte `(R + X * 2^E) / 10^D`, Vorzeichen-Betrag-Kodierung von E und D, Bitmap, Ablehnung (`unsupported`), abgeschnittene Datei (`invalid`), Referenz-Gegenprobe: echte Datei `t_2m` Minimum 259,90 K / Maximum 289,95 K, `relhum_2m` 29,43/100 %, `td_2m` 249,55/288,43 K für Stunde 12 des Laufs 2026110806 [G 08.11.].
- [ ] **Step 3:** Implementieren (nur Stdlib, 16-Bit Fast-Path, allgemeine Bitbreite), PASS, Commit `feat: GRIB2-Dekoder (Schablonen 3.0/5.0, Bitmap)`.

### Task P4.2: bz2 und Download

**Files:** Create `BE Sources/CBz2/` (System-Library-Target mit `module.modulemap`, `shim.h`), `BE Sources/RadarCore/Bzip2.swift`; Modify `BE Package.swift`, `BE Dockerfile` (`libbz2-dev` im Build, `libbz2-1.0` im Runtime-Stage); Test `BE Tests/RadarCoreTests/Bzip2Tests.swift`.

- [ ] **Step 1:** Failing test: kleine bz2-Daten (Fixture, mit `bzip2` lokal erzeugt) werden entpackt, Größenlimit (zum Beispiel 8 MB) schützt vor Bombe, defekte Daten werfen.
- [ ] **Step 2:** Implementieren (`BZ2_bzBuffToBuffDecompress`), Package/Dockerfile ändern, `swift build` und `swift test` melden; Image-Größe vorher/nachher messen (wenn Docker verfügbar), sonst als nicht geprüft melden.
- [ ] **Step 3:** Commit `feat: bz2-Entpacken (libbz2)`.

### Task P4.3: Projektion, Skala, Bild (TDD)

**Files:** Create `BE Sources/RadarCore/{MercatorRender,TempScale}.swift`; Test `BE Tests/RadarCoreTests/MercatorRenderTests.swift`.

**Interfaces:** `TempScale.load(id:)` aus `scales-v1.json` (als Ressource ins Target oder als Swift-Tabelle mit Test, der JSON und Tabelle vergleicht); `MercatorRender.image(field: GribField, kind: .temperatureC/.dewpointC/.relhumPercent, scale: TempScale, bbox: [Double], width: Int) -> RGBAImage` (bilinear, Zellen ohne Wert transparent, K -> °C, Stufen laut Skala) und anschließend `ImagePipeline.toWebP(lossless: true)`.

- [ ] **Step 1:** Failing tests: Eckpixel und Mitte liefern erwarteten Gitterpunkt (Mercator -> WGS84 `RadarConstants.mercatorToWGS84` [B]), Band-Rundung an Grenzen (0,0 °C, -0,01 °C), Klammerung unter/über Skala, Bitmap-Lücke transparent, Bildgröße 1024 x `RadarConstants.imageHeight`.
- [ ] **Step 2:** Implementieren, Messung der Rechenzeit je Slot (Release) und WebP-Größe mit echter Datei (`ICON_D2_SAMPLE`); Referenz Spec 2: 80 KB bei 1-K-Stufen (Python). Abweichung deutlich über 2x dokumentieren.
- [ ] **Step 3:** Commit `feat: Projektion und Farbskala ICON-D2`.

### Task P4.4: Ingest-Schleife ICON-D2 (TDD)

**Files:** Create `BE Sources/RadarCore/Icon2DIngestor.swift`; Modify `BE Sources/RadarCore/Layers.swift` (Specs `temperature_d2`, `dewpoint_d2`, `humidity_d2`, `Kind` forecast, `publishCadence` 3 h|6 h), `Radar.swift` (Schleifen), `LayerCatalog.order`; Test `BE Tests/RadarCoreTests/Icon2DIngestorTests.swift` (Fake `fetch`, Memory-Repo).

**Interfaces:** URL-Bau `icon2dURL(run: Date, hour: Int, variable: String) -> String` (`https://opendata.dwd.de/weather/nwp/icon-d2/grib/<HH>/<var>/icon-d2_germany_regular-lat-lon_single-level_<YYYYMMDDHH>_<SSS>_2d_<var>.grib2.bz2` [G]); Lauf gültig bei vorhandener Stunde 48; Pause `layerPauseSeconds`; Leader-Lease je interner Ebene (Muster `LayerIngestor`).

- [ ] **Step 1:** Failing tests: URL-Bau gegen die in Spec 2 genannten echten Namen, Lauf wird erst publiziert, wenn alle 49 Slots gerendert sind (`expectedSlots: 49`), Teilabbruch -> `layerFail` mit Cooldown, Schablonenfehler -> Klasse `invalid` und Zähler, `TEMP_SOURCE != icon_d2` -> kein Abruf, nur `d2Params` Variablen (`t_2m` immer), Aufbewahrung 2 Läufe, 404 auf Stunde 0 -> `RunUnavailable` (nächster Versuch Vorlauf).
- [ ] **Step 2:** Implementieren, Download streaming je Datei (nie alle im Speicher), Rohwerte nach dem Rendern verwerfen.
- [ ] **Step 3:** Voller `swift test`, Commit `feat: ICON-D2-Ingest fuer Temperatur und Feuchte`.

### Task P4.5: Messung und Übergabe

- [ ] Mit realem Lauf (lokal, `RADAR_TEST`-Muster, **kein Swarm**): Download-Zeit, Dekodier-/Renderzeit je Slot, Spitzen-RAM (`/usr/bin/time -l`), WebP-Größen, Gesamtlast je Lauf; Ergebnisse gegen Spec 3.5 (Annahmen 1 bis 3 min, unter 50 MB) in `BE docs/status.md` und `docs-site/content/betrieb.md` eintragen; `docs/decisions.md`: Dekoder-Entscheidung. `post_progress`.

---

## P5: App native Legende, Wertabfrage, Waldebene (APP)

**Aufwand:** M. **Nach:** P1.0 (Skalen-JSON), P2, P3. **Build/Test:** ein einziger `xcodebuild`-Verantwortlicher (nach P2).

### Task P5.1: Skalentabelle und native Legende (TDD)

**Files:** Create `APP Weather/Map/TemperatureScale.swift`, `APP Weather/Resources/scales-v1.json` (Kopie aus BE), Test `APP WeatherTests/TemperatureScaleTests.swift`, Fixture `scales-v1.json`; Modify `RadarLayerLegend.swift` (Legendenpanel, wie `SunLegend`-Block).

- [ ] **Step 1:** Failing tests: Laden und Validieren (schema 1, Bänder sortiert, lückenlos, Farben hex), `MapLegend`-Einträge mit `spokenLabel` ("zwischen 5 und 6 Grad Celsius"), Beschriftung alle 5 Stufen, unbekannte ID -> `nil`.
- [ ] **Step 2:** Implementieren, Legendenpanel zeigt Skala bei bekannter `scale`, sonst DWD-Bild/Hinweis; Umschalter Taupunkt / relative Feuchte, wenn beide Manifeste verfügbar; Strings de/en.
- [ ] **Step 3:** Commit `feat: native Legende Temperatur und Feuchte`.

### Task P5.2: Wertabfrage lokal (TDD)

**Files:** Create `APP Weather/Map/PixelReadout.swift`; Test `APP WeatherTests/PixelReadoutTests.swift`.

- [ ] **Step 1:** Failing tests: Pixelfarbe -> Band (exakte Übereinstimmung, Rundungsfehler bei WebP ausgeschlossen weil verlustfrei), transparente Zelle -> "kein Wert", Koordinate -> Pixel (Mercator, Bounds aus Manifest), Ausgabe "etwa 7 bis 8 °C".
- [ ] **Step 2:** Implementieren: Tippen auf die Karte (Overlay aktiv, bekannte `scale`) und VoiceOver-Aktion "Wert in Kartenmitte vorlesen"; **kein Netzzugriff, Koordinate nur lokal**; Test, dass kein Request ausgelöst wird (Mock-URLProtocol zählt 0).
- [ ] **Step 3:** Commit `feat: lokale Wertabfrage Temperatur/Feuchte`.

### Task P5.3: Waldebene

**Files:** Create `APP Weather/Map/ForestOverlay.swift`; Modify `RadarMap.swift` (Overlay-Einhängepunkt), `RadarLayerLegend.swift` (Schalter), Strings; Test `APP WeatherTests/ForestTests.swift`. Resource aus P3 (bei Bedarf `xcodegen generate`, README beachten).

- [ ] **Step 1:** Failing tests: Schalter nur bei Temperatur/Feuchte angeboten, Zustand wird gemerkt (UserDefaults, kein Server), Bounds aus `forest-de-v1.json`, Quellzeile mit exaktem Attributionswortlaut aus P3.1 und Veränderungshinweis nur bei eingeblendetem Wald, Beschriftung "Waldfläche zur Orientierung, ohne Einfluss auf die Werte".
- [ ] **Step 2:** Implementieren (Wiederverwendung der Bounds -> `MKMapRect`-Logik von `RadarImageOverlay` [B, `RadarLayer.swift:243`]; Bild einmal dekodieren, ca. 21 MB RGBA bei 2048 x 2621 [A, prüfen, ggf. kleiner rendern]), Speichermessung im Simulator.
- [ ] **Step 3:** Volllauf `Weather` (Unit + UI), Screenshots Legende/Wald/Dynamic Type ansehen (nicht einchecken), `docs/status.md`, `post_progress`.

---

## P6: Abschluss und Rollout-Vorbereitung (BE + APP, Doku)

**Aufwand:** S. **Nach:** P4, P5.

- [ ] Quellenseite/Info-Sheet und Landingpage-`dataSource` (BE `LandingPage.swift`) um DWD ICON/ICON-D2 und WorldCover ergänzen; Prüfung, ob Datenschutztext unverändert bleibt (Spec 5), Ergebnis in `docs/decisions.md` beider Repos.
- [ ] Rollout-Checkliste (Spec 7) in `BE docs-site/content/betrieb.md` finalisieren; Schalterwechsel-Probe lokal (Memory-Repo): `off` -> `wms` -> `icon_d2` -> Ausfall -> Fallback.
- [ ] `docs/status.md` beider Repos: tatsächlich ausgeführte Prüfungen, **nicht geprüft** (Spec §11 abarbeiten oder bestätigen), nächste Schritte (Deploy mit `TEMP_SOURCE=off`, dann `wms`, dann `icon_d2`; App-Build und TestFlight nur auf Auftrag).

## Spec-Abdeckung (Selbstreview)

| Spec | Paket |
|---|---|
| 2/3.4 Variante A, Stil, Last | P1.2, P1.4 |
| 3.2 Alias öffentliche/interne ID | P1.3 |
| 3.3 Schalter, Fallback, Warmstand | P1.1, P1.3, P1.4 |
| 3.5 ICON-D2 (Abruf, Dekoder, bz2, Render, Speicher, Last) | P4.1 bis P4.5 |
| 3.6 Skala, Legende, Barrierefreiheit, Wertabfrage | P1.0, P5.1, P5.2 |
| 3.7 App-Ebenen, Zeitleiste | P2.1 bis P2.3 |
| 3.7 Wald (Quelle, Werkzeug, Bundle, Attribution) | P3.1, P3.2, P5.3 |
| 3.8 Schnittstellen zu Teil 2 | nur Abgrenzung (Dekoder/Downloader wiederverwendbar) |
| 4 Fehler/Ausfall | P1.3, P1.4, P4.4 |
| 5 Datenschutz | Global Constraints, P5.2 (0 Requests), P6 |
| 6 Tests | Testschritte je Task |
| 7 Rollout, Image | P4.2, P6 |
| 10/11 Offene Fragen/Ungeprüftes | P3.1, P4.2, P4.5, P6 |

Bekannte Lücken: Todolino-Aufgaben je Paket legt der Lead an (Obergruppe `437294E7-8A28-40FC-8769-43C3D621E7F3`); exakte Dateinamen von Hilfsskripten (`check-config-tables.sh`) und Eingriffstiefe in `Api.swift` sind im jeweiligen Paket zu prüfen.
