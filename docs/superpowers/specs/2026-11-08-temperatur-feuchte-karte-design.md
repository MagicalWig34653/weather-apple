# Design: Teilprojekt 3 "Temperatur- und Feuchtekarte"

Stand: 8. November 2026 (Entwurf zur Freigabe, Nutzerentscheidungen in §9). Nur Spezifikation, kein Code. Kennzeichnung: **[B]** am Code/Dokument gelesen (Quelle genannt), **[G]** am 08.11.2026 (09:17-09:25 UTC) an Primärquelle geprüft oder gemessen, **[A]** Annahme/Entwurf/Rechnung, **[N]** nicht geprüft. Basis: `docs/research/unwetter-temperatur-frost.md` (§2), `weitere-radarkarten.md`, `backend-radar-cache.md`, `hochaufloesend-und-global.md`; Muster: `2026-11-07-warnungen-design.md`. Repos: App (APP) `/Users/linolaske/Development/Xcode/weather`, Backend (BE) `/Users/linolaske/Development/PhpstormProjects/weather`. Plan: `docs/superpowers/plans/2026-11-08-temperatur-feuchte-karte-plan.md`.

## 1. Ziel und Nicht-Ziele

**Ziel.** Zwei neue Kartenebenen im Radar-Bildschirm: **Temperatur** (2 m) und **Feuchte** (Taupunkt, optional relative Feuchte), stündlich, Vorhersage bis +48 h, mit Zeitleiste, Legende und Quelle wie die vorhandenen Ebenen. Dazu eine einblendbare **Waldebene** nur zur Orientierung. Die Datenquelle der Ebenen ist **serverseitig umschaltbar** (`TEMP_SOURCE=wms|icon_d2|off`), ohne App-Update.

**Nicht-Ziele.** Keine Waldkorrektur der Temperatur, kein "gefühlt", keine Umrechnung der Waldebene in Werte. Keine Frost-/Glätteschätzung und keine Push-Auslöser (Teilprojekt 2, kommt danach, siehe 3.8). Keine Messkarte (Stationspunkte) in v1. Keine Ortsabfrage am Server (kein Standort im Kartenabruf). Keine neue Infrastruktur, keine kostenpflichtigen Dienste.

## 2. Befunde, die den Entwurf bestimmen

- **Variante A, WMS-Layerliste [G]** (GetCapabilities `https://maps.dwd.de/geoserver/ows?service=WMS&version=1.3.0&request=GetCapabilities`, 974 KB, 08.11.2026 09:17 UTC): 2-m-Temperatur gibt es als `dwd:Icon_reg025_fd_sl_T2M` (ICON global, 0,25°, Stil `icon_reg025_fd_sl_t2m_wmc_isoarea`, Zeit `PT1H`, Referenzzeiten 6-stündlich, Legende 88x505) und als **`dwd:Icon-eu_reg00625_fd_gl_T`** (ICON-EU 0,0625° etwa 7 km, Höhe `elevation` Standard 2 m, Läufe 00/06/12/18, bis +120 h, Stile `..._isoarea_tkb` und `..._isoarea_isa`). **Es gibt keinen 2-m-Feuchte- oder Taupunkt-Layer:** nur `dwd:Icon_reg025_fd_pl_RELHUM` (Druckniveaus 75 bis 1000 hPa, Standard 1000 hPa, kein 2-m-Wert), `dwd:RBSN_RH` (Stationspunkte) und `dwd:GefuehlteTemp*` (gefühlt, ausgeschlossen). Variante A liefert also **nur Temperatur**; Feuchte nur über B.
- **GetMap-Test A [G]** (Radar-BBOX, 1024x1311, WMS 1.1.1 wie `LayerSources.mapURL`): T2M 18 KB PNG in 0,6 s; ICON-EU `..._T` mit Stil `tkb` 29 KB in 0,7 s, +48 h und +120 h liefern ebenfalls PNG. Optik: T2M zeigt 0,25°-Blöcke (ca. 25 px), ICON-EU `tkb` glatte Flächen; beide in **5-K-Klassen** (Legende `tkb`: -50 bis +50 °C). Ohne `STYLES` liefert ICON-EU den 4-Bit-Stil `isa` (zu grob). Eigener Stil per SLD [N].
- **Variante B, ICON-D2 [G]** (`https://opendata.dwd.de/weather/nwp/icon-d2/grib/`): Läufe 00, 03, ..., 21 UTC (8 je Tag), Verzeichnis `<HH>/<var>/`, Dateiname `icon-d2_germany_regular-lat-lon_single-level_<YYYYMMDDHH>_<SSS>_2d_<var>.grib2.bz2` (`SSS` 000 bis 048 = **49 Dateien je Variable und Lauf, für Läufe 03, 06, 09, 12 bestätigt**), Variablen `t_2m`, `relhum_2m`, `td_2m` vorhanden (zusätzlich `tmin_2m`, `tmax_2m`, `t_g`). Größen bz2 je Stunde: `t_2m` 1,07 MB, `relhum_2m` 1,05 MB, `td_2m` 0,92 MB (entpackt je 1,62 MB). Lauf 06 UTC: Stunde 0 um 06:44, Stunde 48 um 07:21 UTC veröffentlicht, also komplett nach etwa 80 min.
- **GRIB-Aufbau [G]** (drei Dateien heruntergeladen und Abschnitte per Skript gelesen): GRIB2, Gitter Schablone 3.0 (regular lat/lon), **1215 x 746 Punkte, 0,02°** (ca. 2,2 km Nord-Süd, ca. 1,4 km Ost-West bei 51 °N), lat 43,18 bis 58,08, lon -3,94 bis 20,34 (überdeckt die Radar-BBOX), Scan-Modus 64; Packung **Schablone 5.0 (einfache Packung), 16 Bit, mit Bitmap** (754 862 von 906 390 Punkten gültig). Werte per Skript dekodiert: `t_2m` 259,9 bis 290,0 K, `relhum_2m` 29,4 bis 100 %, `td_2m` 249,5 bis 288,4 K (plausibel). **Ein eigener Dekoder (einfache Packung + Bitmap, ca. 150 Zeilen) genügt; eccodes und libaec sind nicht nötig**, solange DWD die Schablone 5.0 behält (Prüfung zur Laufzeit, sonst Ausfall -> Fallback A).
- **Renderprobe [G]** (Python, Radar-BBOX 1024x1311, bilineare Mercator-Projektion, `t_2m` Stunde 12): verlustfrei WebP bei glattem Farbverlauf **481 KB**, bei **1-K-Stufen 80 KB**, bei 2-K-Stufen 41 KB; verlustbehaftet q90 glatt 38 KB. Projektion + Färbung 2,5 s in Python [A: in Swift deutlich schneller]. Folge: **gestufte Farbskala (1 K Temperatur, 1 K Taupunkt, 5 % rel. Feuchte)** statt glatter Verlauf.
- **Wald, Quellen [G/N]:** ESA WorldCover 2021 v200 (10 m, Zenodo 7254221 Lizenz `cc-by-4.0` [G], Kacheln 3 x 3° als COG auf `esa-worldcover.s3.eu-central-1.amazonaws.com/v200/2021/map/`, Beispielkachel N48E009 95 MB [G]). Copernicus HRL Tree Cover Density (Lizenztext der Produktseite nicht lesbar) und BKG Basis-DLM (Umfang Vegetation) bleiben **[N]**. Genauigkeit WorldCover insgesamt 76,7 % (aus `unwetter-temperatur-frost.md`, nicht neu geprüft).
- **Lizenz DWD [G]** (`dwd.de/DE/service/rechtliche_hinweise/rechtliche_hinweise.html`, 08.11.2026): Weiterverwendung unter CC BY 4.0 mit ordnungsgemäßer Quellenkennzeichnung; eine ICON-D2-spezifische Abweichung wurde nicht gesucht [N].
- **Backend-Muster [B]:** `LayerSpec`/`LayerCatalog` (`Layers.swift`: Anbieter, WMS-Layer, `kind` forecast/observation, `bbox`, `fixedWidth`, `legend`, `modificationNotice`, Attribution); `LayerIngestor.tickForecast` (Leader-Lease `layer:<id>`, Läufe 6-stündlich, Slot 0 vorab prüfen, 49 Slots, `layerPublish`), `LayerManifest.build` (`/v1/layers/<id>/latest.json`, Schema 1), `GET /v1/status` mit `capabilities` und `layers[{id,enabled,has_data,...}]` (`Api.swift` `buildStatus`), `LAYERS` ist Einstellung mit Wirkung **nur beim Neustart** (`ConfigRegistry.swift:196`, Schleifen je Ebene beim Start `Radar.swift:427`), Replikate zustandslos (`RADAR_REPLICAS` Standard 2, `stack.yaml:144`), je Ebene genau ein Leader. Bild-Pipeline: PNG -> WebP verlustfrei (`ImagePipeline`), Speicher in MariaDB `layer_slot` (Migration 004), Auslieferung über denselben Bild-Cache.
- **App-Muster [B]:** `RadarLayer` (`Weather/Data/RadarLayer.swift`: Enum mit `selectable`, `backendLayers`, `isOfferedWhenUnavailable`; neue Ebenen erscheinen erst, wenn das Manifest da ist, wie `pressureEU`), `RadarLayerManifest` (Slots, `legend`, Attribution), `RadarLayerLegendPanel` (Hinweis, Legende, Quellzeile; Legendenbild nur für `.lightning`, `allowedHosts` `maps.dwd.de`/`view.eumetsat.int`), `MapLegend`/`MapLegendEntry` (feste Klassen mit `spokenLabel`), Prefetch-Fenster `prefetchSlotLimit` (Europa 13, Dekodierung 17,8 MB je Bild), `maximumForecastRunAge` 18 h, Zeitleiste `TimelineScrub` arbeitet auf Manifest-Slots.

## 3. Architektur und Komponenten

### 3.1 Datenfluss

DWD (WMS **oder** ICON-D2-GRIB) -> Backend-Leader (Ingest, Render, WebP) -> MariaDB `layer_slot` -> Replikate/Bild-Cache -> `GET /v1/layers/<id>/latest.json` und `.../<run>/<slot>.webp` (ohne Ortsangabe) -> App (Overlay, Legende, Zeitleiste). Wald: statisches Bild im App-Bundle, kein Serverabruf.

### 3.2 Öffentliche Ebenen und interne Speicher-IDs

Öffentlich (App): **`temperature`**, **`dewpoint`**, **`humidity`** (rel. Feuchte). Intern gespeichert getrennt je Quelle: `temperature_wms`, `temperature_d2`, `dewpoint_d2`, `humidity_d2` (neue `LayerSpec`; getrennte Läufe und Slots, damit ein Wechsel nie Läufe verschiedener Quellen mischt [A]). Die Routen `/v1/layers/temperature|dewpoint|humidity/...` lösen **zur Anfragezeit** auf die aktive interne ID auf (kleine Änderung in `Api.swift` `parseLayerRoute`, Status, Cache-Schlüssel `layer:<interne ID>/...`; Eingriffstiefe [N], im Paket zu prüfen). Das Manifest nennt zusätzlich `source` (`wms`|`icon_d2`) und `scale` (Skalen-ID, 3.5).

### 3.3 Schalter und Fallback (Laufzeit, ohne App-Update)

| Einstellung | Wirkung | Wirksam |
|---|---|---|
| `LAYERS` enthält `temperature` | Ingest-Schleifen der internen Ebenen existieren (Hauptschalter) | Neustart |
| `TEMP_SOURCE` = `off` (Standard) / `wms` / `icon_d2` | `off`: Ebenen antworten 404, kein Ingest-Abruf; `wms`: nur `temperature` (A); `icon_d2`: `temperature`, `dewpoint`, optional `humidity` (B) | **live** (Dashboard-Einstellung, `ConfigRegistry` `.live`) |
| `TEMP_D2_PARAMS` = `td_2m` (Standard), optional `t_2m,td_2m,relhum_2m` | welche B-Ebenen Last verursachen; `t_2m` ist bei `icon_d2` immer dabei | live |
| `TEMP_FALLBACK_WARM` = `true` (Standard) | bei `icon_d2` läuft A als Warmstand weiter (nur `temperature`, ca. 200 Abrufe/Tag) | live |
| `TEMP_D2_MAX_AGE_HOURS` = 7 | ist der jüngste ICON-D2-Lauf älter, liefert `temperature` den A-Lauf (falls frisch), `dewpoint`/`humidity` 404 | live |

Die Ingest-Schleife liest `TEMP_SOURCE` je Takt (der `ConfigProvider` wird ohnehin je Takt gelesen [B, `LayerIngestor` `configProvider`]); `off` beendet Abrufe sofort, vorhandene Daten werden nicht ausgeliefert. Abruf-Takt für B: 3 h (Läufe), konfigurierbar `3|6` [A]. `publishCadenceSeconds` (derzeit fest 6 h für Vorhersageebenen, `Layers.swift`) muss je Spec 3 h werden, sonst meldet die Staleness-Prüfung falsch [B].

### 3.4 Variante A (WMS, minimale Last)

Spec `temperature_wms`: Anbieter `dwd`, Kind `forecast`, Schritt 3600 s, **Standardlayer `dwd:Icon-eu_reg00625_fd_gl_T` mit Stil `icon-eu_reg00625_fd_gl_t_isoarea_tkb`** (7 km, glattere Flächen), Rückfalllayer `dwd:Icon_reg025_fd_sl_T2M` (Einstellung `TEMP_WMS_LAYER`); neues Feld `wmsStyle` in `LayerSpec` und `LayerSources.mapURL` (heute `STYLES=` leer [B]). Radar-BBOX, 1024 px, PNG -> WebP verlustfrei (18 bis 29 KB PNG [G]). Last auf DWD: 49 GetMap je Lauf, 6-stündlich = **ca. 200 Anfragen/Tag**, sequentiell mit `layerPauseSeconds` (wie Luftdruck, derselbe Code) [A]. Legende: DWD-Legendenbild (`GetLegendGraphic`, in Manifest `legend`, Host `maps.dwd.de` erlaubt [B]), Klassen 5 K. Quelle "Quelle: Deutscher Wetterdienst" (`RadarConstants.attribution`) plus Veränderungshinweis (z. B. "Datenbasis: Deutscher Wetterdienst (ICON-EU), Lufttemperatur 2 m bildlich wiedergegeben") [A, Wortlaut im Paket]. Nachteil: keine Feuchte, grobe Auflösung, Stil nicht änderbar.

### 3.5 Variante B (ICON-D2-Ingest)

- **Abruf:** Leader-Lease je interner Ebene (wie `layer:<id>`). Je Lauf (neuester und vorheriger geprüft) Stunde 0 vorab prüfen, dann 49 Dateien nacheinander (`.grib2.bz2`, Pause `layerPauseSeconds`), Lauf gilt als komplett, wenn Stunde 48 vorliegt; Backoff bei Fehlern, `RunUnavailable` wie `LayerIngestor` [B]. Datenmenge je Lauf (Download, bz2): `t_2m` 53 MB, `td_2m` 45 MB, `relhum_2m` 51 MB (je 49 x 1,07/0,92/1,05 MB) [G aus Dateigrößen, A Hochrechnung]. **Bei 8 Läufen/Tag: t+td 0,78 GB/Tag, t+td+rh 1,2 GB/Tag; bei 6-stündigem Takt die Hälfte.** Fair Use: ein Abruf je Datei und Lauf, unabhängig von der Nutzerzahl [A].
- **Decoder (Entscheidung):** **eigener Swift-Dekoder** (GRIB2 Abschnitte 1/3/4/5/6/7, Schablonen 3.0 und 5.0, Bitmap) statt eccodes. Begründung: Dateien sind einfach gepackt [G]; eccodes bräuchte System-Bibliothek plus Definitionsdateien im Runtime-Image (Größe nicht gemessen [N]), erhöht Angriffsfläche und Build-Zeit. Unbekannte Schablone, Gitterabweichung (Größe, Scan-Modus, Referenzzeit) oder Wertebereich außerhalb -90..60 °C bzw. 0..100 % -> Lauf verworfen (`invalid`), Fallback A. **bz2** hat Foundation nicht: Bindung an `libbz2` per System-Library-Target (Build `libbz2-dev`, Runtime `libbz2-1.0`); Dockerfile-Änderung klein, Image-Größe +~0,1 MB [A], im Paket per `docker build` zu belegen [N]. Prozess `bunzip2` wird nicht verwendet.
- **Render:** bilineare Interpolation vom 0,02°-Gitter auf die Radar-BBOX (Mercator, 1024x1311), Zellen ohne Bitmap-Wert transparent, Farbzuordnung per fester Skala, **gestufte Bänder** (3.6), Ausgabe WebP verlustfrei. Gemessen 80 KB je Slot bei 1 K Stufen [G]. **Speicher:** 49 Slots x 80 KB x 3 Ebenen = **ca. 12 MB je Lauf**, bei 2 aufbewahrten Läufen ca. 24 MB in `layer_slot`; Schreiblast ca. 94 MB/Tag (8 Läufe) [A]. Bild-Cache (`CACHE_MAX_MB` 64): Hot-Set je Ebene ca. 4 MB [A].
- **CPU/RAM [A, nicht gemessen]:** je Datei bz2-Entpacken (1,6 MB), Dekodieren 0,75 Mio. Werte, Rendern 1,3 Mio. Pixel; Python-Probe 2,5 s, Swift Release erwartet unter 0,5 s; ein Lauf (147 Dateien) ca. 1 bis 3 min CPU des Leaders, einmal je Lauf, **unabhängig von der Zahl der Replikate/Nutzer**; Spitze RAM unter 50 MB (eine Datei plus Bild). Nur der Leader rechnet, Replikate bleiben zustandslos [B].
- **Skala-ID:** Manifest-`scale` z. B. `t2m-d2-v1`, `td-d2-v1`, `rh-d2-v1`. Die App kennt die Skalen als Tabelle (Bandgrenzen, Farben, Beschriftung); **unbekannte Skala -> Legende nur als Hinweistext, kein erratenes Raster**.

### 3.6 Legende, Farbe, Barrierefreiheit

- Skalen: Temperatur -30 bis +40 °C in 1-K-Bändern (Legende beschriftet 5-K-Schritte), Taupunkt -20 bis +24 °C in 1-K-Bändern, rel. Feuchte 0 bis 100 % in 5-%-Bändern [A, Endpalette im Paket nach CVD-Simulation (Farbfehlsichtigkeit) festlegen].
- **Nicht nur Farbe:** (1) numerische Legende mit `spokenLabel` je Klasse (Muster `MapLegendEntry` [B]); (2) **Wertabfrage lokal**: Antippen eines Punkts (und für VoiceOver der Kartenmitte/ausgewählter Ort) liest die Pixelfarbe des angezeigten Bildes und nennt das Band ("etwa 7 bis 8 °C"), **ohne Koordinate an den Server** (nur bei bekannter `scale`, sonst nicht angeboten); (3) Nulllinie (0 °C) als zusätzliche dünne Kontur im B-Bild [A, optional]; (4) Feuchte-Legende mit Worten (trocken ... schwül) nur mit belegten Schwellen [N, bis dahin nur Zahlen]. Dynamic Type und Reduce Motion wie bestehende Legende.
- **Feuchte-Parameter, Empfehlung:** **Taupunkt zuerst.** Er ist unabhängig von der Tageszeit (rel. Feuchte schwankt mit der Temperatur, nachts hoch, mittags niedrig), beschreibt Schwüle und Trockenheit der Luftmasse und wird für die spätere Frostschätzung gebraucht (Reif); `td_2m` ist mit 0,92 MB die kleinste Datei [G]. **Relative Feuchte** ist vertrauter und kommt als zweite, per Flag zuschaltbare Ebene (`humidity`); in der App ein Menüpunkt "Feuchte" mit Umschalter Taupunkt / relative Feuchte, wenn beide vorhanden sind. Für den Umschalter kein neuer Abruf ohne Bedarf: nur die gewählte Ebene wird geladen.

### 3.7 App (Ebene, Zeit, Wald, Quelle)

- **Ebenen:** `RadarLayer` erhält `temperature`, `dewpoint`, `humidity` (Rohwerte = öffentliche IDs), in `selectable` und `backendLayers`, **`isOfferedWhenUnavailable = false`** (nur sichtbar, wenn das Manifest 200 liefert; damit bei `TEMP_SOURCE=off` oder Ausfall weder Menüpunkt noch Fehlermeldung, Muster `pressureEU` [B]). Symbole z. B. `thermometer.medium` und `humidity` [N, SF-Symbole-Verfügbarkeit prüfen]. Deckkraft 0,75 bis 0,85 (opak gefärbte Fläche über Basiskarte) [A]. Prefetch-Fenster begrenzen (Bild dekodiert ca. 5,4 MB; 49 Bilder = 260 MB zu viel, Fenster ca. 13 wie `pressureEU` [B/A]).
- **Zeitleiste:** `kind=forecast`, 49 Slots stündlich, Slot 0 = Analyse/Stunde 0 ("Modell"), bis +48 h; Beschriftung "Vorhersage" (Muster `frameCaption` [B]). **Messung:** nicht in v1. Es gibt kein aktuelles Temperaturraster als Messung (HOSTRADA ist Archiv, Stationen nur Punkte [aus `unwetter-temperatur-frost.md`, G dort]); die Zeitleiste kennzeichnet die Ebene durchgehend als Modell.
- **Legendenpanel:** erweitert um Skalenliste (B) oder DWD-Legendenbild (A, Manifest `legend`), Hinweis "Modellprognose, kein Messwert; Waldkorrektur und gefühlte Temperatur sind nicht enthalten", Quellzeile aus Manifest, Schalter "Wald".
- **Waldebene:** getrennter Schalter im Legendenpanel (nur bei Temperatur/Feuchte angeboten [A]), Beschriftung "Waldfläche zur Orientierung, ohne Einfluss auf die Werte". **Quelle: ESA WorldCover 2021, Klasse 10 (Baumbedeckung), CC BY 4.0.** Offline-Vorverarbeitung (einmalig, Werkzeug `tools/forest_overlay.py`, Eingabe 20 COG-Kacheln N45 bis N54 x E003 bis E015, ca. 1,9 GB Download [A]) zu **Waldanteil je Pixel 0..100 %** auf dem Radar-BBOX-Raster **2048 px breit** (ca. 0,55 km/Pixel), Ausgabe als transparentes grünes Bild (Alpha = Anteil) in WebP. **Ablage: im App-Bundle** (`Weather/Resources/Forest/`), nicht auf dem Server: statisch, offline, kein Netz, kein Serverabruf, kein Datenschutzthema; Nachteil: Änderung braucht App-Release, Größe geht in den Download ein [A: Ziel höchstens 1 MB, im Paket zu messen]. Vektor (Polygone) wurde verworfen (Deutschland sehr viele Polygone, Größe und Zeichenlast [A, nicht gemessen]). Bei starkem Zoom sieht man Pixelblöcke von ca. 550 m; das ist für Orientierung gewollt, eine zweite feinere Stufe wäre eigener Auftrag (Frage 3). Quellzeile: "© ESA WorldCover project 2021 / Contains modified Copernicus Sentinel data (2020/2021) processed by ESA WorldCover consortium" [Wortlaut aus Recherche, im Paket gegen die WorldCover-Nutzungsbedingungen zu prüfen, N] plus Veränderungshinweis; erscheint nur bei eingeblendetem Wald.
- **Quelle/Attribution:** aus Manifest (`attribution`, `modification_notice`, neu `source`); Infoseite "Quellen" ergänzt DWD ICON/ICON-D2 und WorldCover.

### 3.8 Schnittstellen zu Teilprojekt 2 (Frost/Glätte), nur Abgrenzung

Teilprojekt 2 kommt **nach** dieser Karte. Wiederverwendbar bleiben: der **ICON-D2-Downloader und GRIB-Dekoder** (zusätzliche Variablen `tmin_2m`, `t_g` ohne neuen Code im Dekoder; Punktwert statt Bild: Zelle des 0,02°-Gitters aus den dekodierten Rohwerten, **die Rohwerte werden in dieser Karte nur zum Rendern genutzt und nicht gespeichert**; eine Speicherung für Teil 2 wäre dort zu entscheiden), die Skalen/Läufe-Verwaltung, Capability-/Flag-Muster und `TEMP_SOURCE`-Staleness. Diese Spec legt keine Frost-Tabellen an.

## 4. Fehler, Ausfall, Sonderfälle

- Quelle antwortet nicht/unvollständig: Lauf bleibt unveröffentlicht (Muster `layerFail` mit Cooldown [B]); alte Läufe bleiben bis `staleAfter`; die App prüft Alter (`isFresh`, 18 h [B]) und blendet die Ebene bei "zu alt" aus.
- **B fällt aus -> A:** `temperature` liefert A-Lauf (Warmstand), `dewpoint`/`humidity` verschwinden (404, App blendet Menüpunkt aus). Wechselt eine laufende Anzeige die Quelle, lädt die App das neue Manifest (anderer `run`, andere Legende/`scale`), der Nutzer sieht den Hinweis in der Quellzeile.
- A fällt aus (DWD-WMS: gelegentlich HTTP 200 mit XML-Fehler `InvalidDimensionValue` [aus `backend-radar-cache.md`, G dort]): bestehende Prüfung (XML = Fehler, Retry) wiederverwenden [B].
- Unlesbares/geändertes GRIB (Schablone, Gitter, Bereich): `invalid`, Zähler `ingest_run ...:error`, kein Absturz, Fallback A.
- `TEMP_SOURCE=off` im Betrieb: App sieht 404 und blendet die Ebenen beim nächsten Manifest-Abruf aus (Abruf-Rhythmus der Ebenen, höchstens wenige Minuten [A]); bereits geladene Bilder bleiben bis zur Auswahl einer anderen Ebene.
- Diskrepanz an Küste/Grenze: Zellen ohne Bitmap-Wert transparent (kein Wert statt falscher Wert).
- Ehrliche Aussage: ICON-D2 löst Täler/Frostsenken nicht auf; die Legende sagt "Modell, 2 m über Grund".

## 5. Datenschutz

Kartenabruf ohne Ortsangabe wie bei den vorhandenen Ebenen; keine Kennung, kein Cookie [B, Muster]. Die Wertabfrage rechnet **lokal aus dem Bild**. Waldebene im Bundle (kein Abruf). Server speichert nur Bilder und Läufe, keine Nutzerdaten. Keine neue Datenkategorie, **keine Änderung am Datenschutztext erwartet** [A]; vor Livegang prüft der Lead, ob die Quellenseite (Info-Sheet, Landingpage `dataSource`) ergänzt werden muss (nur Quellenangabe, kein Datenschutzthema). App-Privacy-Angaben unverändert [A].

## 6. Tests

BE (`swift test`, Memory-Repo): GRIB-Dekoder gegen **eingecheckte Mini-Fixtures** (eine echte `t_2m`-Datei ist 1,6 MB; stattdessen aus einer echten Datei per Skript ausgeschnittene oder synthetisch erzeugte kleine GRIB2 mit Schablonen 3.0/5.0, plus ein Test mit der echten Datei lokal über Umgebungsvariable), Bitmap, Gitter-/Schablonen-Ablehnung, bz2-Entpacken, Mercator-Projektion (Eckpunkte, Mittelpunkt), Skala (Grenzen, K -> °C), Band-Rundung, Auflösung `TEMP_SOURCE`/Fallback (Zeit gemockt), Route-Alias, `LayerSources.mapURL` mit Stil, Staleness mit 3 h. APP (`xcodebuild test`, Schema `Weather`): `RadarLayerTests` mit Fixtures `layer-temperature.json` (A und B), Menü nur bei Manifest, Legendenskalen (Klassenzahl, `spokenLabel`), Pixel-zu-Wert, Prefetch-Fenster, Wald-Schalter und Quellzeile, UI-Test Legende/Zeitleiste (Dynamic Type). Nicht automatisierbar: Sichtprüfung der Farbskala (Screenshot), VoiceOver am Gerät, Farbfehlsichtigkeit (Simulator-Filter), echter Betrieb auf dem Swarm.

## 7. Rollout

1. Backend deployen mit `TEMP_SOURCE=off` (Standard) und `LAYERS` ohne Eintrag: keine Wirkung; Image mit libbz2 erst mit Paket B (Neuaufbau, **Image-Änderung = normaler Deploy `update.sh`**, keine Migration: `layer_run`/`layer_slot` kennen beliebige Ebenen-IDs [B, Migration 004], `layer` ist `VARCHAR(16)`, die internen IDs haben höchstens 15 Zeichen [B, `migrations/004_layers.sql`]; neue IDs dürfen 16 Zeichen nicht überschreiten).
2. `LAYERS=...,temperature` setzen (Neustart), `TEMP_SOURCE=wms`: A läuft, niedrige Last; App-Build mit Ebene kann parallel entwickelt und gegen A getestet werden.
3. Nach erfolgreichem Paket B: `TEMP_SOURCE=icon_d2` mit `TEMP_D2_PARAMS=td_2m`, Last im Dashboard beobachten (Zähler `ingest_lag`, `ingest_dur`, Download-Fehler); bei zu großer Last zurück auf `wms` oder `off`, **ohne App-Update** (App blendet fehlende Ebenen aus).
4. App-Release mit Ebene und Wald erst, wenn mindestens A produktiv ist; ältere App-Builds ignorieren die Ebenen (kennen die IDs nicht [A]).

Reihenfolge Backend -> App; Entwicklung beider Seiten parallel gegen den in 3.2/3.5 festgelegten Vertrag (Manifest-Felder `source`, `scale`; Dokumentation in BE `docs-site/content/api.md`, Paket P1).

## 8. Arbeitspakete

Siehe Plan (P1 BE Variante A + Schalter + Vertrag, P2 APP Ebenen/Legende/Zeitleiste, P3 Waldrohdaten, P4 BE ICON-D2, P5 APP Wald + Wertabfrage, P6 Abschluss). Aufwand grob: S = halber Tag, M = 1-2 Tage, L = 3+ Tage.

## 9. Entscheidungen des Nutzers (8. November 2026, vorgegeben)

1. Temperatur **und** Feuchte als Karten (Taupunkt und/oder relative Feuchte). Empfehlung §3.6: Taupunkt zuerst, relative Feuchte zuschaltbar.
2. Beide Quellvarianten bauen, **serverseitig umschaltbar** (`TEMP_SOURCE`), Fallback B -> A, Umschaltung ohne App-Update.
3. Wald nur als einblendbare Orientierungsebene, keine Umrechnung, keine Waldkorrektur, kein "gefühlt".
4. Eigene Frost-/Glätteschätzung (Teilprojekt 2) kommt nach dieser Karte.

## 10. Offene Fragen an den Nutzer

1. **Ebenenname/Parameter:** Reicht Taupunkt als Standard (Empfehlung) mit relativer Feuchte hinter Flag, oder beide von Anfang an aktiv (zusätzlich ca. 51 MB Download je Lauf)?
2. **Erste Quelle im Betrieb:** zunächst `wms` (nur Temperatur) oder gleich `icon_d2`? Läufe alle 3 h (1,2 GB/Tag mit allen drei Variablen) oder 6 h (halbiert)?
3. **Wald-Auflösung:** 550 m (ca. 1 MB, Orientierung) genügt für v1, oder zweite feinere Stufe für starken Zoom gewünscht?
4. Soll der Wald auch über anderen Ebenen (Radar, Wolken) einblendbar sein oder nur über Temperatur/Feuchte (Vorschlag)?
5. Feuchte-Wörter in der Legende ("schwül" usw.) erst nach belegten Schwellen, bis dahin nur Zahlen: einverstanden?

## 11. Nicht geprüft (Stand dieser Spezifikation)

- Eigener SLD/Stil für DWD-WMS (feinere Stufen); ICON-D2-spezifische Lizenzklausel; Lizenztext Copernicus HRL TCD und BKG; exakter Attributionswortlaut WorldCover; Größe/Ladezeit eccodes im Image; `libbz2-1.0` im Basisimage `ubuntu:noble` vorhanden oder nachzuinstallieren; Swift-Laufzeit von Dekoder/Render; Größe des Waldbilds; Eingriffstiefe Alias in `Api.swift`; Performance auf dem Swarm und Last des DWD-Servers bei 150 Dateien je Lauf; ICON-D2 Schablone bleibt 5.0 für künftige Läufe; Farbskala Barrierefreiheit (CVD-Simulation); SF-Symbole; Schwellen für Schwüle-Wörter; Lauf-Stabilität der Läufe 00/15/18/21 (nur 03/06/09/12 Dateizahl geprüft).

## 12. Selbstreview

Abgedeckt: Ziele/Nicht-Ziele (1), Quellen und Befunde mit Belegmarken (2), Komponenten und Schnittstellen (3.2-3.7), Flag-Umschaltung und Fallback (3.3), Last- und Speicherrechnung (3.4/3.5), Legende barrierefrei (3.6), Zeitachse (3.7), Wald (3.7), Attribution (3.4/3.7), Fehler (4), Datenschutz (5), Tests (6), Rollout inkl. Image/Migration (7), offene Fragen (10), Ungeprüftes (11). Widerspruchsprüfung: Feuchte nur in B (2/3.3/4 konsistent); Rohwerte nicht gespeichert (3.8) und Rendern aus denselben Rohwerten (3.5) widersprechen sich nicht; Teilprojekt 2 nur als Abgrenzung. Keine Platzhalter außerhalb benannter [N]/[A]-Punkte.
