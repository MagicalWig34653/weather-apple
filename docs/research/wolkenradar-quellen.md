# Wolkenradar / Satellitenbilder: genauere Quellen als der DWD-Layer (Recherche)

Stand: 31. Oktober 2026, Abrufe ca. 05:25-05:35 UTC. Reine Recherche, kein Produktcode.
Kennzeichnung: **[G]** gemessen/abgerufen am 31.10.2026, **[A]** Annahme, **[N]** nicht geprüft.
Ausgangslage: DWD-WMS-Satellitenlayer nur 3-stündlich (siehe `weitere-radarkarten.md`, 2.1).

## Kurzfazit

- [G] **EUMETView (EUMETSAT) liefert Wolkenbilder im 10-Minuten-Takt (MTG-I/FCI) bzw. 15-Minuten-Takt (MSG/SEVIRI)**, ohne Registrierung, mit EPSG:3857. Das passt direkt zum vorhandenen Backend-Muster (ein georeferenziertes Bild pro Zeitslot per WMS-GetMap).
- Nur Vergangenheit, keine Vorhersage. Neuestes Bild war beim Abruf ca. 28 min alt.
- Rechtlich offen: Quellenangabe nach EUMETSAT-Datenpolitik Pflicht; ob jeder Layer "Core" (CC BY 4.0) ist, ist je Layer nicht verifiziert (Abschnitt 3).

## 1. EUMETView WMS (view.eumetsat.int)

- [G] Endpunkt `https://view.eumetsat.int/geoserver/wms` (auch `/ows`), WMS 1.3.0/1.1.1, GetCapabilities 282 KB, 116 Layer, `Fees: none`, `AccessConstraints: none`, keine Authentifizierung/API-Key. GWC-TMS-Wurzel antwortet 200; ein WMTS-Capabilities-Abruf scheiterte (400) [G], WMTS daher nicht nutzbar/ungeprüft.
- [G] Projektion: Service-weit `EPSG:3857`, `EPSG:4326`, `CRS:84`, polare u. a. Echte GetMap-Abrufe in EPSG:3857 mit BBOX Deutschland+Umland (`556597,5621521,1780000,7361866`), 1024x1024, liefen für alle getesteten Layer.
- [G] Formate: `image/png`, `image/jpeg`, `image/png; mode=8bit`, `image/vnd.jpeg-png`, `image/geotiff`, GIF u. a.; **kein WebP** (Backend konvertiert lokal). Zeitdimension per `TIME=...` (ISO 8601, `nearestValue`), Default = jüngster Slot.
- Hinweis [G]: Gelegentlich HTTP 500 (1 von ca. 20 Abrufen, bei Wiederholung ok) und Antwortzeiten 0,2-12 s: Backend braucht Retry und Timeout.

### Relevante Layer (Zeitdimension aus Capabilities, [G])

| Layer | Inhalt | Takt | Archiv ab |
|---|---|---|---|
| `mtg_fd:rgb_geocolour` | Geo Colour RGB (MTG-I FCI), Tag/Nacht | 10 min | 23.09.2024 |
| `mtg_fd:rgb_truecolour` | True Colour (nur Tag) | 10 min | 23.09.2024 |
| `mtg_fd:rgb_cloudtype` | Cloud Type RGB (Dicke/Höhe/Phase) | 10 min | 01.06.2025 |
| `mtg_fd:rgb_cloudphase`, `rgb_fog` | Wolkenphase, Nebel/tiefe Wolken | 10 min | [N] |
| `mtg_fd:ir105_hrfi`, `vis06_hrfi` | FCI IR 10.5 / VIS 0.6 µm, "1 km" laut Abstract | 10 min | 23.09.2024 |
| `msg_fes:ir108`, `vis006`, `rgb_eview`, `rgb_natural` | SEVIRI IR/VIS/RGB, Europa-Ausschnitt | 15 min | 2020 / 2022 |
| `msg_fes:clm`, `msg_fes:cth` | Wolkenmaske, Wolkenobergrenze (abgeleitet) | 15 min | 01.09.2020 |
| `msg_rss:rgb_natural_nrt` u. a. | Rapid Scan (5 min), nur Teilgebiet | 5 min [A] | [N] |
| `mtg_fd:li_afa` | Blitze (MTG-LI, akkumulierte Blitzfläche) | 5 min | 30.05.2025 |
| `mtg_fd:h40b` | kombiniertes FCI/MW-Niederschlagsprodukt | [N] | [N] |
| `mumi:worldcloudmap_ir108` | Geo-Ring IR 10.8 | 3 h | wie DWD |

- [G] Abdeckung MTG-I: ca. 77 °S-77 °N, 81 °W-81 °O (Vollscheibe, Europa inklusive). Legende: GetLegendGraphic liefert nur 20x20 px ("raster"), eigene Erklärung nötig.
- [G] Latenz: Um 05:28 UTC war der jüngste Slot 05:00 UTC (Alter 28 min, Slot-Beginn = Scanbeginn [A]). Data-Store-Eintrag FCI-L1c `EO:EUM:DAT:0662` zeigte Scan 05:10-05:19 UTC, veröffentlicht 05:12 [G]; WMS-Rendering hinkt also ca. 10-20 min hinterher.
- [G] Bildgrößen (1024 px, Deutschland, 05:00 UTC, nachts): Geocolour PNG ca. 2,0 MB / JPEG 145 KB; IR 10.8 SEVIRI PNG 324 KB / JPEG 22 KB; IR 10.5 FCI PNG 129 KB / JPEG 23 KB; EView PNG 139 KB / JPEG 8 KB; Cloudtype PNG 16 KB (vermutlich nachts leer). True-Colour/Natural liefern nachts praktisch Leerbilder (PNG je 18.397 B) [G, Inhalt nur geschätzt].
- [G] Optik (Geocolour, Sichtprüfung): nachts Wolken als bläulich-weiße Fläche, Stadtlichter, schneebedeckte Alpen. Sehr detailreich, aber auf eine Karte mit Radar-Overlay [A] nur als Basislayer sinnvoll (Bild deckend, nicht transparent). IR 10.8 ist nachts monochrom und kontrastarm.
- [A] Echte Pixelgröße über Deutschland bei FCI ca. 2 km (Nadir 1-2 km, bei 50 °N größer): ein Vielfaches feiner als nur 3 Bilder pro Tag, aber gröber als Radar (1 km).
- Eignung Backend-Muster: **sehr gut.** Ein GetMap pro Slot mit festem BBOX/EPSG:3857, JPEG/WebP lokal, 6 Slots/Stunde. Datenmenge [A]: 144 Slots/Tag x ca. 60-150 KB (WebP/JPEG) = 9-22 MB/Tag je Layer; 12 h Verlauf = 72 Bilder.

## 2. EUMETSAT Data Store / API (api.eumetsat.int)

- [G] Katalog `https://api.eumetsat.int/data/browse/collections` (191 Einträge) und OpenSearch `.../data/search-products/1.0.0/os?pi=EO:EUM:DAT:0662` antworten ohne Anmeldung (107.854 Produkte). Download-URL-Muster `.../data/download/1.0.0/collections/<ID>/products/<ID>` im Treffer [G]; der Download selbst benötigt nach EUMETSAT-Doku Registrierung und OAuth-Token [A, nicht getestet].
- [G] Beispiele: `EO:EUM:DAT:0662` = MTG FCI L1c (FDHSI, Vollscheibe, ZIP, 10-min-Takt), `EO:EUM:DAT:MSG:HRSEVIRI` (SEVIRI 0°). Rohdaten, groß (FCI-Vollscheibe [N] hunderte MB je Slot) und mit Kalibrierung/Reprojektion verbunden: Aufwand Satpy o. ä. [A].
- Bewertung: nur nötig für eigene Darstellung/Kanäle. Für fertige Bilder ist WMS einfacher. Neue Registrierung und Zugangsdaten im Backend nötig ([N] Rate Limits).

## 3. Nutzungsbedingungen und Quellenangabe (EUMETSAT-Datenpolitik)

- [G] Quelle: EUMETSAT Data Policy (PDF, Jan. 2026, `www-cdn.eumetsat.int/files/2026-01/45173 - Data_Policy.pdf`), Art. 4-6:
  - "Core"-Daten: frei, weltweit, **CC BY 4.0** (Art. 5.1); Weiterverteilung erlaubt (Art. 6.1).
  - Core umfasst u. a. alle SEVIRI-/FCI-/LI-**Derived Products** und **Advanced Image Products** sowie Level-1-Stundendaten und Level-1-Daten mit Latenz >= 1 h.
  - **Level-1-Daten mit Latenz < 1 h sind "Recommended"** (Lizenz, evtl. Gebühr; Art. 5.2/Anhang I). Weitergabe der numerischen Originaldaten ist dort verboten (Art. 6.2).
  - EUMETView ist laut Policy ein Dienst "ohne Zugang zu numerischen Originaldaten" (Anzeige/Karten).
  - Pflicht (Art. 6.3): Attribution `[Contains modified] EUMETSAT [Meteosat/Metop] [data/product] [Jahr]`, z. B. "Contains modified EUMETSAT Meteosat data 2026" (an Anzeige anpassbar).
  - Gewährleistungsausschluss/Haftungsausschluss (Art. 8.2): kein Service Level.
- [A] RGB-Bilder (Geocolour, Cloudtype, Natural) sind "Advanced Image Products" und damit Core/CC BY. Die **IR-/VIS-Einzelkanal-Layer** (`ir108`, `ir105_hrfi`, `vis006`) sind Level-1-Bilder mit Latenz < 1 h: **Einstufung unklar, möglicherweise Recommended.** Daher für die erste Version RGB-/Derived-Layer bevorzugen [A].
- [N] Eigene Nutzungsbedingungen von EUMETView-WMS (Fair-Use, Last) nicht gefunden; Capabilities sagen "none". Rückfrage bei EUMETSAT-Support (ops@eumetsat.int [A]) vor Produktivstart sinnvoll, vor allem zur Frage: abgeleitete Bildkopien im eigenen Cache-Backend ausliefern. Aus Art. 6.1/7.2 [A] ableitbar zulässig, nicht ausdrücklich bestätigt.
- Auswirkung auf die App: zusätzlich zu "Quelle: Deutscher Wetterdienst" bei Satellitenansicht die EUMETSAT-Zeile anzeigen, Veränderungshinweis (Reprojektion, Kompression).

## 4. DWD Open Data (opendata.dwd.de/weather/satellite)

- [G] Verzeichnisse `clouds/` (`CTH/`, `TS/`) und `radiation/` (SIS/SID). Beispiele 05:00 UTC: `CTHin202610310500.nc.bz2` (636 KB, 05:17 UTC bereit), `CTHin202610310500nEU.nc.bz2` (894 KB, 05:22), `TSfc202610310500EA.nc.bz2` (304 KB), Takt 5-10 min (CTH zusätzlich Ausschnitt "nEU"), Latenz ca. 17-22 min [G aus Verzeichnislisting].
- [G] Format NetCDF (bzip2). CTH = Wolkenobergrenze (m), TS = Temperaturen/Wolkenprodukt [N, Inhalt/Geometrie nicht geöffnet].
- Lizenz: DWD CC BY 4.0 (siehe `weitere-radarkarten.md` 1). Quelle der Satellitendaten ist EUMETSAT [G in dort belegter Rechtsseite].
- Eignung: Backend müsste NetCDF dekodieren, georeferenzieren (vermutlich Geostationär-Projektion [A]), reprojizieren und färben: hoher Aufwand [A]. Nutzen gegenüber EUMETView-WMS gering, außer für Wolkenhöhe.
- [G] DWD-WMS (`maps.dwd.de`): nur 3-stündlich, siehe Vorrecherche.

## 5. Weitere Quellen (kurz)

- [A, nicht geprüft] Copernicus Data Space, Sentinel-3 OLCI (`copernicus:*` Layer in EUMETView, tägliche Mosaike): Polarorbit, 1-2 Überflüge/Tag, kein Wolkenradar. Bei Bedarf als "Satellitenfoto des Tages".
- [N] NOAA/GOES, RainViewer, Meteoblue, OpenWeatherMap-Satellit: nicht untersucht; kommerzielle oder drittbegrenzte Dienste gelten als ungeeignet (Kosten, Lizenz) ohne dass dies hier belegt wäre.
- Echte Wolken-**Vorhersage**: nur über Modell (DWD ICON `CLCT` etc. [N]); als Bild nicht geprüft.

## 6. Empfehlung und Aufwand

1. **EUMETView-WMS `mtg_fd:rgb_geocolour`** (Tag/Nacht, 10 min) als Wolkenansicht; optional `mtg_fd:rgb_cloudtype` für Wolkentyp und `msg_fes:cth`/`clm` als abgeleitete Produkte (15 min). Rückfalloption bei MTG-Ausfall: `msg_fes:rgb_eview` oder `rgb_natural`.
2. Backend: gleicher Ablauf wie Radar, GetMap je Slot mit `TIME`, EPSG:3857, JPEG/WebP lokal, `latest.json` für Satellit separat. Aufwand: **gering bis mittel** (Backend-Job 1-2 Tage, App-Basislayer plus Zeitleiste 2-3 Tage, Attribution/Info 0,5 Tage; [A, Schätzung]).
3. Vorher klären: (a) EUMETSAT-Rückfrage zu abgeleiteten Cache-Kopien und Core-Status je Layer, (b) Retry/Timeout wegen 500er und 0,2-12 s, (c) nachts leere True-Colour-Bilder meiden (Geocolour nehmen), (d) deckende Bilder: Basis-/Overlay-Reihenfolge in der App.
4. Nicht empfohlen für Start: NetCDF-Weg (DWD CTH/TS) und Data-Store-Rohdaten (Dekodierung, Registrierung, hoher Aufwand).
5. Realistisch erwartbar: Alter der Wolkenbilder 25-40 min, keine Vorhersage. Als "Satellit, ca. 10-min-Takt" kennzeichnen, nicht als Nowcast.

Quellen: `view.eumetsat.int/geoserver/wms` (Capabilities, GetMap), `api.eumetsat.int/data/...`, `opendata.dwd.de/weather/satellite/`, EUMETSAT Data Policy (2026-01).

## 7. Andere Anbieter (Prüfung 31. Oktober 2026, ca. 09:40 UTC)

Frage: Gibt es neben EUMETSAT/DWD Anbieter mit ähnlich offenen Wolken-/Satellitenbildern für Europa? Kurzfazit: **Nein, nicht gleichwertig.** Die geostationären Satelliten über Europa betreibt EUMETSAT (Meteosat); GOES/Himawari decken Europa nicht ab. Kennzeichnung: [G] = per Abruf bestätigt, [A] = Annahme, [N] = nicht geprüft.

| Anbieter | Europa/DE | Takt, Latenz, Projektion | Zugang | Lizenz/Weitergabe | Eignung |
|---|---|---|---|---|---|
| NASA GIBS (GOES-East/West, Himawari) | **Nein** [G] | 10 min, Zeitachse bis 08:40 UTC [G]; WMTS EPSG:3857, PNG, Level 6/7 [G] | ohne Schlüssel [G] | NASA-Daten offen [A]; Nutzungsbedingungen nicht Wort für Wort geprüft [N] | ungeeignet für DE |
| RainViewer Satellit | **Nein** [G] | `satellite.infrared` in `weather-maps.json` ist leer [G] | API ohne Schlüssel [G] | Free Tier nur privat/Bildung/Community, kommerziell Rückfrage (api.html) [G]; Nutzer erhalten nur persönliche, nicht unterlizenzierbare Lizenz (terms.html) [G] | ungeeignet (leer, Lizenz) |
| OpenWeatherMap-Layer | [N] | [N] | Schlüssel | Preisseite nennt ODbL für Daten [G]; Layer-Bedingungen/Weitergabe nicht geprüft [N] | nicht empfohlen (Kosten/Limits [A]) |
| KNMI Data Platform | NL/Europa-Produkte möglich [A] | API antwortet mit 401 ohne Schlüssel [G] | Registrierung/API-Key | [N] | nur Fallback-Idee [A] |
| Copernicus Data Space / Sentinel | Polarorbit, 1-2 Überflüge/Tag [A] | kein Takt für Wolkenradar | Registrierung | CC BY-artig [A] | nicht für Wolkenradar |
| MeteoSwiss, Météo-France, Met Office | [N] | [N] | Domains im Test nicht erreichbar (Abruf scheiterte, kein Inhalt) [G] | [N] | ungeprüft; nationale Dienste bieten Satellit meist aus Meteosat/EUMETSAT-Daten [A] |

Belegt:
- GIBS-Capabilities (5,8 MB, 200): Layer `GOES-East_ABI_GeoColor`, `GOES-East/West_ABI_Band13_Clean_Infrared`, `Himawari_AHI_*` vorhanden; kein Meteosat-Layer gefunden [G]. Kachel über Deutschland (z3, x4, y2, GeoColor, 08:40 UTC) hat nur 2.768 Byte, also praktisch leer; Kachel Amerika (z3 x2 y3) 92 kB [G]. GOES-East blickt auf Amerika/Atlantik, Himawari auf Ostasien/Pazifik [A].
- RainViewer: Radar vorhanden (`past`/`nowcast`), Satellit-Infrarot-Liste leer [G].

Folgerung: Für Deutschland bleibt **EUMETView-WMS (EUMETSAT, CC BY 4.0, Abschnitt 3)** die einzige offene, schlüsselfreie Bildquelle mit passendem Takt; DWD liefert dieselben Satellitendaten nur als NetCDF/3-stündlich (Abschnitt 4). Weiterverteilung abgeleiteter Bilder aus eigenem Cache ist bei Drittanbietern (RainViewer, OWM) vertraglich nicht gedeckt bzw. ungeklärt; bei GIBS irrelevant, da keine Abdeckung. Ungeprüft: Nutzungsbedingungen von GIBS im Wortlaut, MeteoSwiss/Météo-France/Met Office (Domains nicht erreichbar), KNMI-Datensätze mit Schlüssel.
