# Weitere Karten neben dem Regenradar (Recherche)

Stand: 31. Oktober 2026 (Messungen ca. 05:20-05:40 UTC). Reine Recherche, keine Implementierung, kein Produktcode.
Kennzeichnung: **[G]** gemessen/abgerufen am 31.10.2026, **[A]** Annahme, **[N]** nicht geprüft.
Dienst: `https://maps.dwd.de/geoserver/ows`, WMS 1.3.0, GetCapabilities (1,0 MB, 206 Layer) und echte GetMap-/GetLegendGraphic-Abrufe.
Testbild: BBOX `46,5,56,16` (EPSG:4326, lat/lon-Achsenfolge), 1024x1024 px, 1 Request je Layer.

## 1. Lizenz und Quellenangabe

- [G] DWD Rechtliche Hinweise (`dwd.de/DE/service/rechtliche_hinweise/...`, abgerufen 31.10.2026): Alle frei zugänglichen Geodaten und Geodatendienste des DWD stehen unter **CC BY 4.0**, Weiterverwendung nur mit "ordnungsgemäßer Quellenkennzeichnung". Das deckt sich mit der bestehenden Annahme in `decisions.md` (CC BY 4.0 + GeoNutzV, "Quelle: Deutscher Wetterdienst", Veränderungshinweis). Der Capabilities-Eintrag verweist ebenfalls auf `dwd.de/copyright`; `Fees: none`.
- [G] Satellitenlayer: Die Rechtsseite nennt als Quellen für Satellitendaten **EUMETSAT** und NOAA. [A] Für Satellitenbilder zusätzlich "Quelle: DWD, EUMETSAT" anzeigen; ob EUMETSAT-Nutzungsbedingungen über CC BY hinaus etwas verlangen, ist [N] (vor Umsetzung prüfen).
- [A] Gilt unverändert: keine Zusicherung von Verfügbarkeit/Servicelevel für Open Data; Fair-Use-Last ist durch ein Backend-Muster besser kontrollierbar als durch Tile-Direktabruf.
- Warnungen: Inhalt ist DWD-Amtsprodukt; [A] eine App darf Warnungen anzeigen, aber die Rechtsseite enthält Hinweise zur Darstellung amtlicher Warnungen; Wortlaut zu Warn-Disclaimern [N]. Kein "Warnungsersatz" (Entscheidung in `decisions.md`).

## 2. Ergebnis je Karte

| Karte | Layer (verifiziert 31.10.2026) | Zeit | Eignung |
|---|---|---|---|
| Wolken/Satellit | `dwd:Satellite_meteosat_1km_euat_rgb_day_hrv_and_night_ir108_3h` | nur 3 h-Raster | eingeschränkt |
| Luftdruck | `dwd:Icon_reg025_fd_sl_PMSL` (Isolinien) | stündlich, Vorhersage | gut |
| Temperatur | `dwd:Icon_reg025_fd_sl_T2M` | stündlich, Vorhersage | gut, aber grob |
| Wind | `dwd:Icon_reg025_fd_sl_UV10M` (Windfiedern) | stündlich, Vorhersage | mäßig |
| Blitze | `dwd:Blitzdichte` | 5 min, Beobachtung | gut, wenig Daten |
| Warnungen | `dwd:Warnungen_Landkreise` (+ `Warnungen_Gemeinden`) | ohne Zeitdimension | anders (Vektor/aktuell) |

### 2.1 Wolken / Satellit

- [G] **Das Satelliten-WMS ist für Animation zu grob:** Layer `Satellite_meteosat_1km_euat_rgb_day_hrv_and_night_ir108_3h`, Abstract: "Bereitstellung alle 3 Stunden zu den Zeiten 00, 03, ... 21 UTC, da Abgabe als Opendata-Daten". Zeitdimension `2026-10-29T18:00Z/2026-10-31T03:00Z/PT3H` (ca. 36 h Vergangenheit, keine Vorhersage). Ein zweiter Layer `Satellite_worldmosaic_3km_world_ir108_3h` (IR 10.8, Welt) ist ebenfalls 3-stündlich.
- [G] Projektion EPSG:4326 (laut Capabilities nur diese; EPSG:3044-BBox gelistet), Abdeckung laut Capabilities-BBox 23-77 °N, 54 °W-54 °O (ganz Europa).
- [G] Bild Deutschland 1024 px: PNG 172.831 B (RGB, undurchsichtig, nachts graues IR), 0,3 s; verlustfreies WebP lokal 42.934 B. `image/webp` wird vom Dienst **nicht** angeboten (XML-Fehler).
- [G] Legende: GetLegendGraphic liefert nur 20x20 px (keine sinnvolle Legende); RGB-Komposit (Tag HRV, Nacht IR) braucht eine eigene Erklärung ("hell = dicke/hohe Wolken").
- [G] **Echte 15-/60-Minuten-Wolkendaten gibt es nur als Rohdaten:** `opendata.dwd.de/weather/satellite/clouds/` mit `CTH/` (Wolkenobergrenze, `CTHin202610310500.nc.bz2`, ca. 0,6-0,9 MB, NetCDF, Stand 05:17-05:22 UTC) und `TS/` (`TSfc...nEA.nc.bz2`, Abdeckung Europa/Afrika, ca. 0,3-0,8 MB), Takt ca. 10-15 min [G aus Verzeichnislisting; Inhalt und Geometrie nicht geöffnet, N]. Zusätzlich `radiation/sis` und `sid` (Strahlung, nicht Wolkenbild).
- Bewertung: **WMS = 8 Bilder in 24 h**: als Standbild "Wolken vor X Stunden" brauchbar, als Animation nicht vergleichbar mit Radar. Backend-Nutzung: sehr leicht (8 Slots/Tag x 43 KB = ca. 0,35 MB/Tag). NetCDF (`CTH`/`TS`) wäre fein, aber neuer Dekoder + Rendering + Georeferenzierung im Backend = hoher Aufwand [S: mehrere Tage, nicht im vorhandenen Muster].
- Aufwand WMS: gering (Tage <= 1). Aufwand NetCDF-Wolkenkarte: hoch. Nutzen/Aufwand der WMS-Variante hängt an der Erwartung des Nutzers; ehrlich als "3-stündlich" kennzeichnen.

### 2.2 Luftdruck

- [G] Es gibt **keine Messfeld-Karte**, sondern Modellvorhersage. Layer: `dwd:Icon_reg025_fd_sl_PMSL` (ICON global regional-ausgeschnitten, 0,25 Grad, MSL-Druck). Zeit `2026-10-29T18:00Z/2026-11-07T12:00Z/PT1H`, `REFERENCE_TIME` 6-stündlich (00/06/12/18 UTC; 6 Läufe sichtbar). Ca. 9 Tage Vorhersage, Raster 1 h. Außerdem `Aicon_reg025_fd_sl_PMSL` (KI-Modell AICON, PT3H, 12 Läufe, 3-stündlich) und `Icon-eps_reg025_fd_sl_PMSL` (Ensemble).
- [G] Stil: `icon_reg025_fd_sl_pmsl_wmc_isoline_label` (Isobaren mit Beschriftung). Mit `TRANSPARENT=true` echte Transparenz (PNG 70.736 B, davon 17.329 nicht transparente Pixel; verlustfreies WebP ohne Transparenz gemessen 14.044 B, mit Transparenz kleiner [A]); ohne `TRANSPARENT` kommt ein deckender weißer Hintergrund.
- [G] Legende: GetLegendGraphic 219x40 px (Isobarenhinweis), klein und nur als Hinweis brauchbar.
- [G] Layer `Icon-eu_reg00625_fd_sl_QFF` (ICON-EU, 0,0625 Grad, feiner) liefert für einen Testzeitpunkt (31.10. 12 UTC) `internalError` "No data available for NinJo NWP data request: model ICON6_NEST" [G Fehler]; Ursache (Datenlücke im Cluster, Reference-Time nötig?) ungeklärt: nicht für den Produktivweg annehmen.
- Eignung: sehr gut für das Backend-Muster: ein Ganzbild je Stunde und Lauf, deterministisch. Isolinien sind besonders datensparsam. Kein GRIB/Rohdatenaufwand nötig; Rohdaten (ICON GRIB unter `opendata.dwd.de/weather/nwp/icon/`) wären nur nötig, falls eigene Darstellung gewünscht ist [N, nicht geprüft]. Aufwand: gering bis mittel (neue Layer, zeitliche Dimension mit Vorhersagehorizont, Referenzzeit bestimmen).

### 2.3 Temperatur

- [G] `dwd:Icon_reg025_fd_sl_T2M` (2 m, ICON, 0,25 Grad). Zeit/Referenz wie PMSL (PT1H, 6-stündlicher Lauf, bis 07.11.). Stil `..._wmc_isoarea`. Echte Messwerte nur als Stationspunkte (`dwd:RBSN_T2m`, 2m-Temperatur an RBSN-Stationen, Layer vorhanden; Aktualität/Dichte [N]).
- [G] 1024-px-PNG 16.669 B, 8-Bit-Palette; Legende 88x505 px (brauchbar). **Optik:** blockige 0,25-Grad-Zellen (Pixelraster sichtbar), eher grob für Deutschland (ca. 28 km); kein feines Temperaturfeld. [A] Für "Gefühl der Temperatur" ok, für Ortsgenauigkeit nicht.
- Eignung: wie Luftdruck; zusätzlicher Layer `GefuehlteTemp` vorhanden [N, nicht abgerufen].

### 2.4 Wind

- [G] `dwd:Icon_reg025_fd_sl_UV10M`: Stil `..._wmc_windbarbs` (Windfiedern), Zeit-Dimension als Einzelliste (143 Werte, `elevation=10.0`), Referenzzeit 6-stündlich. Nur 51 nicht transparente Pixel im Testausschnitt 46-56 N/5-16 O bei 1024 px [G]: Fiedern erscheinen sehr klein/spärlich; Lesbarkeit auf dem Handy [N, Bild nicht visuell gesichtet].
- [G] `dwd:Aicon_reg025_fd_sl_UV10M` (3-stündlich) ohne Fiederstil. Auch `RBSN_FF` (Stationswind) vorhanden [N].
- Eignung: technisch wie Temperatur; **UI-Wert gering**, solange nur Windfiedern geboten werden. Besser später als eigene Darstellung (Pfeile/Partikel aus GRIB-Rohdaten), dann hoher Aufwand.

### 2.5 Blitze

- [G] `dwd:Blitzdichte` (NowCastMIX-Blitzdichte): **5-Minuten-Raster**, Zeitdimension `2025-07-02T16:10Z/2026-10-31T05:15Z/PT5M` (also zum Abrufzeitpunkt aktuell, Beobachtung, Historie lang); Blitze der letzten 15 min, generische Einheit 0-127 ("0 bis 3000 Blitze pro Einheit und 100 km2"). Abdeckung laut Capabilities-BBox ab 46,95-54,9 °N, ab 1,7 °O (Deutschland und Umland), EPSG:4326.
- [G] Abruf 31.10.: 6.608 B PNG, WebP lokal 88 B; im Testfenster 0 nicht transparente Pixel, da aktuell keine Blitze. Einzelabruf 0,3 s. Legende 119x344 px (brauchbar).
- Eignung: sehr gut als zweite Zeitebene neben Radar, gleiche Schrittweite (5 min). Bildgröße minimal, daher fast kostenlos zu cachen. Nutzen steigt im Sommer; im Herbst oft leer.

### 2.6 Warnungen

- [G] `dwd:Warnungen_Landkreise`, `Warnungen_Gemeinden`, `Warnungen_Kueste`, `Warnungen_Binnenseen` (alle ohne Zeitdimension, aktuelle Lage). 1024-px-PNG 116.973 B (Gesamtkarte, Hintergrund deckend), Legende 306x160 px.
- [G] Maschinenlesbar: `opendata.dwd.de/weather/alerts/cap/` (CAP-Dateien, z. B. `COMMUNEUNION_DWD_STAT`, `..._DIFF`), Verzeichnis 05:20 UTC aktualisiert.
- Bewertung: Warnungen sind ein **eigener Funktionsblock** (Standortbezug, Texte, Schweregrade, Push), keine Zeitkartenebene. Entscheidung `decisions.md` ("kein Warnungsersatz") und Push-Planung beachten. Nicht als Kartenebene zuerst.

## 3. Vergleich Muster

- **Backend-Cache** (Ganzbild-WebP je Slot, wie Radar): passt für Luftdruck, Temperatur, Blitze, Satellit. Pro Ebene: 1-2 Layer-Abrufe je neuem Slot statt hunderter Tiles; DWD-Last bleibt klein. Gemessene Einzelabrufe 0,25-0,36 s.
- **Direkter WMS-Tile-Abruf** (wie jetzt Radar-Fallback): für Isolinien/Isoareas ungeeignet, weil Beschriftungen und Rasterblöcke je Tile geschnitten werden [A]; nicht empfohlen.
- Geometrie: Radar im Backend ist EPSG:3857; die neuen Layer liefern EPSG:4326 (auch `EPSG:3857` ist laut Capabilities nicht gelistet bei den geprüften Layern [N, Liste nur teilweise gesichtet]). [A] Der Backend-Abruf muss entweder `CRS=EPSG:3857` je Layer testen oder im Client reprojiziert werden; nicht geprüft.
- Zeitmodell: Radar hat 5-min-Analyse + 25 Prognoseschritte. PMSL/T2M/Wind haben 1-h-Prognose mit Referenzzeit; Satellit 3 h; Blitze 5 min (nur Vergangenheit). Das `latest.json`-Schema müsste je Ebene einen eigenen Slot-Katalog führen (`step_minutes` je Layer).

## 4. Schätzung Backend-Speicher und Last

Pro Ebene (WebP verlustfrei, Deutschlandausschnitt 1024 px, [S] aus [G]-Einzelmessungen; Isolinien/Isoareas mit Transparenz klein):

| Ebene | Größe/Slot | Slots (Beispiel) | Speicher | DWD-Abrufe/Tag |
|---|---|---|---|---|
| Satellit | ca. 43 KB | 8/Tag, 48 h | ca. 0,7 MB | ca. 8 |
| Luftdruck | ca. 10-14 KB | 72 h Vorhersage + 4 Läufe/Tag | ca. 1-4 MB | ca. 100-300 |
| Temperatur | ca. 1-5 KB | wie Luftdruck | < 1 MB | ca. 100-300 |
| Blitze | < 1 KB | 288/Tag, 6 h | < 0,3 MB | 288 |

Fazit: Speicher unkritisch (insgesamt wenige MB zusätzlich zum Radar, [A]); die Last entsteht über die Zahl der DWD-Abrufe, nicht über Bytes. Mit Reference-Time-Wechsel alle 6 h müssen Prognoseslots neu geholt werden (z. B. 72 Slots je Lauf = 72 Abrufe je Layer alle 6 h; je Slot 0,3 s, also ca. 22 s Ingest).

## 5. Empfehlung

Reihenfolge:

1. **Luftdruck (Isobaren)**. Frei (CC BY), klare Laie-Information, ein Layer, stündliche Vorhersage bis 9 Tage, kleinste Aufwandsschätzung, passt exakt ins Cache-Muster. Optik prüfen (transparenter Hintergrund, Isobarenbeschriftung auf 0,25 Grad, QFF-Feinlayer nicht verlassen).
2. **Blitze**. 5-Minuten-Beobachtung wie Radar, extrem kleine Bilder, eigener Mehrwert bei Gewitter (Überlagerung mit Radar). Nach Prüfung der Achsen/Projektion im Backend direkt als zweite Zeitebene einbauen.
3. **Wolken/Satellit** in der WMS-Variante (3-stündlich) als Standbildebene "Wolken (3 h)", nur wenn der Nutzer mit dem groben Takt zufrieden ist; sonst später NetCDF-Variante (CTH/TS) mit hohem Aufwand. Temperatur danach (gleicher Aufwand wie Luftdruck, aber grobe Rasteroptik). Wind und Warnungen bewusst später: Wind braucht eigene Darstellung, Warnungen sind eigener Funktionsblock.

Folgen für die UI (Ebenenwahl):
- Eine Ebenenwahl (Schalter/Menü, ein aktives Overlay neben Radar) statt mehrerer gleichzeitiger Layer. Ebenen mit anderer Zeitachse (Satellit 3 h, Isobaren 1 h) brauchen eigene Zeitleiste oder eine Abbildung auf den nächsten verfügbaren Slot; "Vorhersage" vs. "Beobachtung" je Ebene kennzeichnen.
- Pro Ebene eigene Legende (Isobaren: Hinweistext; Temperatur: Farbskala; Blitze: Dichte) und eigener Quellenvermerk (DWD; bei Satellit zusätzlich EUMETSAT).
- Karte bleibt ohne Backend nutzbar: direkter DWD-Abruf nur als Fallback für Radar, nicht für Isolinienebenen.

Folgen für das Backend:
- Pro Ebene eigenes Manifest/Endpunkt (`/v1/<ebene>/latest.json`) nach `data-contract.md`-Schema; je Ebene eigene Referenzzeitverwaltung. Ingest-Last ca. 100-300 Layer-Abrufe je Lauf-Wechsel; Fair-Use-Pausen wie beim Radar.
- Speicher und Bandbreite unbedenklich; die entscheidende Grenze ist die DWD-Abrufzahl und die Pflege weiterer Zeitdimensionen.

## 6. Nicht geprüft

- EUMETSAT-Bedingungen für Satellitenbilder; Inhalt der NetCDF-Dateien; WebP-Größe der transparenten Bilder; EPSG:3857-Abruf und Achsenreihenfolge bei den neuen Layern; QFF-Fehlerursache; Lesbarkeit der Windfiedern; GRIB-Aufwand; Warndarstellungsvorgaben; Wiederholbarkeit der Messungen (je ein Abruf, tagesaktuelle Lage).
