# Luftdruck als Farbflaeche (Recherche)

Stand: 1. November 2026, Abrufe ca. 06:40-06:45 UTC (Modelllauf 00 UTC). Reine Recherche, kein Produktcode.
Kennzeichnung: **[G]** gemessen/abgerufen, **[A]** Annahme/Schaetzung, **[N]** nicht geprueft. Lizenz DWD: CC BY 4.0 (Quellenangabe noetig).

## 1. Styles des DWD-GeoServers (GetCapabilities `maps.dwd.de/geoserver/dwd/ows`)
- [G] `Icon_reg025_fd_sl_PMSL` hat genau **einen** Style: `icon_reg025_fd_sl_pmsl_wmc_isoline_label` (SLD per GetStyles: Transformation `ras:Contour`, Intervall 5 hPa, Linien, dicke weisse/schwarze Linie bei 1025 hPa, Textlabel). Einheit hPa (Legende JSON: "Pressure in hPa"). Es gibt **keinen** Flaechenstyle fuer MSL-Druck am deterministischen ICON.
- [G] Verwandte Layer, ebenfalls nur Linien: `Aicon_reg025_fd_sl_PMSL` (`..._isoline_label`), `Icon-eu_reg00625_fd_sl_QFF` (`..._qff_isolines`, `..._qff_isolines_dense`), `Icon_reg025_fd_pl_GH` (nur `..._isoline_label`, Geopotential auf Druckflaechen).
- [G] **Einzige Flaechenstyles mit Druckbezug** sind Ensemble-Layer: `Icon-eps_reg025_fd_sl_PMSL` Style `icon-eps_reg025_fd_sl_pmsl_wmc_spread_isoarea` (Ensemble-Spread, Streuung statt Druckwert, kein Hoch/Tief) sowie `Icon-eps_reg025_fd_pl_GH/SP` (Spread). Fachlich nicht gleich dem Druckfeld.
- [G] Fremden Style auf PMSL-Layer (`styles=icon_reg025_fd_sl_t2m_wmc_isoarea`, `icon-eps_..._spread_isoarea`): HTTP 200, 900x600 PNG, aber **leer/weiss** (Werte ausserhalb der Farbskala); `..._qff_isolines_dense` auf PMSL liefert wieder Linienbild (170 KB). Styles sind an Datenbereich gebunden, kein Trick.
- [G] Beobachtung: GetMap benoetigt `time` und `dim_reference_time` aus Capabilities; falsche Referenz gibt `InvalidDimensionValue`/leere Bilder (T2M/GH im Test mit Referenz des PMSL-Laufs: 508-Byte-Fehlerantwort; Referenzlisten je Layer verschieden: PMSL 6-stuendlich, andere 3-stuendlich).

## 2. Eigene SLD (SLD_BODY / SLD)
- [G] GetMap mit `SLD_BODY` (RasterSymbolizer, ColorMap `ramp` 980-1040 hPa, Deckkraft 0,7): Antwort `Dynamic style usage is forbidden`. Der DWD-Server erlaubt keine dynamischen Styles. `SLD=<URL>` ist damit sehr wahrscheinlich ebenfalls gesperrt [A, nicht einzeln getestet]. REST-Stylezugriff: 401. **Weg 2 ist gesperrt.**

## 3. Rohdaten (opendata.dwd.de)
- [G] ICON-EU regulaer lat-lon (0,0625 Grad, 904.689 Punkte = ca. 657x1377): `icon-eu/grib/00/pmsl/icon-eu_europe_regular-lat-lon_single-level_<YYYYMMDDHH>_<hhh>_PMSL.grib2.bz2`, Stunden 000-120; ca. 0,93 MB bz2 je Stunde. Laeufe 00/06/12/18 UTC.
- [G] ICON global (`icon/grib/<run>/pmsl/..._icosahedral_...`): 2.949.120 Punkte auf **Icosaeder-Gitter** (Template 3.101, 2,9 MB bz2 je Stunde, 000-180 h); Interpolation auf lat-lon braucht Gitterdatei (separater Download) [N]. Regulaere ICON-Variante nur ueber `icon/grib/.../` mit `regular-lat-lon` pruefen [N].
- [G] Packung: **Template 5.42 (CCSDS/AEC, 16 Bit)**. Kein Simple Packing; Dekodierung braucht libaec (AEC) bzw. eccodes. In Swift: libaec per C-Interop (Linux `libaec-dev`) plus eigenes GRIB2-Section-Parsing (Sections 3/5/7 sind schlicht), alternativ `eccodes` als Systembibliothek [A]. Aufwand Dekoder 1-2 Tage [A]. Kein eccodes/grib_ls auf dieser Maschine.
- [A] Rechenzeit: Dekodieren 0,9 Mio. Werte < 0,5 s; Rendern Farbflaeche (Bilinear plus Colormap, optional Contour-Linien) in Swift/CoreGraphics oder eigener Pixelschleife 1024x1050: < 0,3 s. 49 Slots (48 h) x 4 Laeufe: ca. 1 GB bz2 Download je Lauf bei 1 h-Raster (49 x 0,93 MB = 45 MB je Lauf, 180 MB/Tag), unkritisch; Last ca. 1 min CPU je Lauf.
- Rendern ist **nicht** aus dem WMS-Linienbild ableitbar (nur Isolinien, keine Werte je Pixel).

## 4. Fachlich ersetzbar durch andere WMS-Flaechen?
- [G] Nur Layer mit eigener Flaeche: 2m-Temperatur (`..._t2m_wmc_isoarea`, 22 Klassen, Legende 88x505), Niederschlag, relative Feuchte, Omega, Temperatur auf Druckflaechen. Keiner zeigt Hoch/Tief. Temperaturfeld ist **kein Ersatz** fuer Druck (korreliert nur lose). Geopotential auf Druckflaeche (500 hPa GH) hat nur Linien. Fazit: kein WMS-Ersatz, Hoch/Tief als Flaeche nur ueber Rohdaten.

## 5. Empfehlung und Aufwand
1. **Variante C (GRIB ICON-EU, eigenes Rendering im Backend)** ist der einzige Weg zur echten Farbflaeche. Europa-Ausschnitt reicht (die App braucht kein globales Feld).
   - Backend (ca. 3-5 Tage): GRIB2-Parser + libaec-Anbindung, Download bz2 je Stunde (Lauf aus Verzeichnisliste), Bilinear/Colormap 980-1040 hPa in Mercator (BBOX wie Linien-Layer), neuer `LayerSpec` `pressure_area` (Provider `dwd_opendata`, Manifest mit Legende), WebP mit Alpha ca. 20-60 KB je Slot [A], Speicher: 49 Slots x 2 Laeufe ca. 3-6 MB. Neue Systemabhaengigkeit libaec auf Linux/Docker.
   - App (ca. 1 Tag): Legende hPa-Skala (Verlauf mit Zahlen 980/1000/1020/1040), Deckkraft 0,5-0,7; als Basis unter den vorhandenen WMS-Isobaren-Layer legen (zwei Bilder uebereinander; Linien liefert weiterhin DWD-WMS, 1 Bild-Overlay je Ebene im Code noetig [A]).
   - Option: Isolinien im selben Rendering (Marching Squares) und DWD-WMS-Linien weglassen; spart Abruf, kostet 1 Tag mehr.
2. **Kein Farboverlay ueber WMS/SLD moeglich**: Weg 1 und 2 sind gesperrt/nicht vorhanden. Ohne Backend-Aufwand bleibt nur die jetzige Isobaren-Ebene, ggf. mit besserer Legende.
3. Ungeprueft: Rohdaten-Lizenzangabe/Quellenzeile im Detail, Template 3.0 Scan-Reihenfolge (Normal bei lat-lon, aber nicht dekodiert), tatsaechliche Dateigroessen aller 49 Stunden, Ausfalle/Verzoegerung der Laeufe (typ. ca. 3-4 h nach Termin [A]), libaec im Docker-Image, AICON/EPS-Raw.
