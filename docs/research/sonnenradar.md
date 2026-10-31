# Sonnenradar: Wolken plus Sonnenstand (Entwurf und Machbarkeit)

Stand: 31. Oktober 2026, Abrufe ca. 09:55-10:10 UTC. Reiner Entwurf, kein Produktcode.
Kennzeichnung: **[G]** gemessen/abgerufen am 31.10.2026, **[A]** Annahme, **[N]** nicht geprüft.
Baut auf `wolkenradar-quellen.md` (EUMETView, Lizenz Core/CC BY 4.0) und `weitere-radarkarten.md` auf.

## Kurzfazit und Empfehlung

- Fachlich sinnvoll und machbar. Es gibt **zwei Wege**: (A) eigene Ableitung aus Wolkenmaske plus Sonnenhöhe, (B) fertiges DWD-Produkt "Solar Surface Irradiance" (SIS, W/m²) als Rohdaten.
- **Empfehlung:** Start mit A (EUMETView `msg_fes:clm`, 15 min, plus Sonnenstand im Backend ins Bild gebacken). B (DWD SIS NetCDF, Ausschnitt "DE") als Phase 2 prüfen: fertige Strahlung inkl. Wolkendicke, aber NetCDF-Dekodierung nötig.
- Ehrlich: Das Ergebnis ist ein **Rückblick auf die letzten 25-40 min**, keine Vorhersage (Kurzfristextrapolation nur als Option, Abschnitt 3).
- Reihenfolge: erst Wolkenebene (Satellit) in der App, dann Sonnenradar als zusätzlicher Modus derselben Ebene.

## 1. Fachlicher Entwurf und fertige Produkte

Idee A, "Sonnenkarte": Pro Pixel Wolkenzustand (klar/bewölkt) kombinieren mit Sonnenhöhe h: h <= 0 Nacht (ausblenden/abdunkeln), 0 < h < ca. 6 Grad Dämmerung/schwaches Licht, sonst Tag. Ergebnis: "wo scheint die Sonne" = Tag und klar. Terminator (Tag/Nacht-Grenze) ergibt sich aus h = 0 gratis.

**Fertige offene Produkte (geprüft):**
- [G] **DWD Open Data `weather/satellite/radiation/sis/` und `sid/`** (SIS = Globalstrahlung, SID = direkte Strahlung), Quelle Meteosat/SEVIRI, **Takt 15 min**, Verzeichnislisting zeigt bei Abruf 09:58 UTC Dateien bis Slot 09:30 (Veröffentlichung 09:48-09:54, **Latenz ca. 20-25 min**). Varianten je Slot: `...FDv3.nc` (Vollscheibe, 27 MB), `...EAv4.nc(.bz2)` (Europa/Afrika, 53 MB, bz2 8,7 MB), **`...DEv3.nc` (nur Deutschland, 100 KB)**. 45 DE-Dateien im Verzeichnis (ab 30.10. 22:30, ca. 11 h Rückblick).
- [G] DE-Datei `SISin202610310930DEv3.nc`: NetCDF classic, per CDO erzeugt (`sellonlatbox,5,16,46,57`), Raster **221 x 221 (0,05 Grad, ca. 5 km), lon 5-16, lat 46-57**, Variable `SIS` (`downwelling_shortwave_flux_in_air`, "solar surface irradiance", W m-2), Daten offenbar 16-bit gepackt [A, Skalierung nicht ausgelesen]. Meta-XML: "SPECMAGIC_now Version 3.0", GRID LAT-LON.
- [A] Lizenz: DWD Open Data, CC BY 4.0 [laut `weitere-radarkarten.md`]; Quellenangabe DWD plus EUMETSAT/Meteosat. Für SIS-Datensatz-Lizenz nicht einzeln geprüft [N].
- [G] **DWD-WMS (`maps.dwd.de/geoserver/ows`, GetCapabilities 980 KB):** keine Echtzeit-Strahlungs-/Sonnenscheinlayer. Gefunden nur Klimatologie (`sunshine_year`, `Prob_sunny_days`, `global_radiation_year`, `SISMM_annual_map_normals_1981_30`) und UV (`UVI_Global_CL/CS`, `UV_Dosis_*`: Vorhersage-/Klimaprodukte, nicht Wolkenradar). Für Live-Sonne nicht nutzbar.
- [G] **EUMETView:** keine SIS-/Strahlungs-Layer (Namensfilter sis/sid/rad/sun/solar/flux: nur `clm`, `cth`, `rgb_cloudtype`). `msg_fes:clm` (Zeitdimension 2020-09-01 bis 09:30 UTC, PT15M, Default 09:30) und `mtg_fd:rgb_cloudtype` (ab 2025-06-01, PT10M, Default 09:10).
- [N] CM SAF (SARAH-3 u. a.): `wui.cmsaf.eu` antwortete HTTP 200, `opendata.dwd.de/climate_environment/CMSAF/` 404; CM SAF-Klimadatensätze sind zeitlich verzögert (Klimareihen), für Echtzeit nicht geeignet [A]. Lizenz/Zugang nicht geprüft.

**GetMap-Test heute (Deutschland+Umland, EPSG:3857, 600x853, PNG):** [G] `msg_fes:clm` HTTP 200, 60 KB, 2,7 s, Farben: weiß = bewölkt, grün = klar über Land, blau = klar über Wasser [A, Legende per Sichtprüfung; GetLegendGraphic liefert nur 20x20]. Blockig (SEVIRI-Pixel ca. 3-5 km, über Deutschland [A]). [G] `rgb_cloudtype` 1,1 MB, 1,4 s: detailreich, aber **Bildausschnitt oben rechts schwarz** (Kachel fehlte/nicht berechnet, Ursache unbekannt, evtl. Teilslot 09:10 [A]); Backend muss Bilder auf Vollständigkeit prüfen, Retry. `rgb_cloudtype` ist ein RGB-Bild (kein Klartext-Wolkentyp), daher nicht direkt per Pixel klassifizierbar [A]; `clm` ist der saubere, binäre Weg.
- Grenze von A: `clm` kennt nur klar/bewölkt, keine Wolkendicke. Dünne Cirren zählen als "bewölkt", obwohl die Sonne scheint. SIS (B) enthält die Dicke implizit.

## 2. Sonnenstand berechnen

- **Algorithmus:** NOAA General Solar Position (Fourier-Näherung, Deklination und Zeitgleichung je Slot einmal, pro Pixel nur Stundenwinkel plus 3 Trig-Aufrufe). Meeus/SPA nur bei höherem Genauigkeitsbedarf, hier unnötig.
- **Selbsttest [G]** gegen JPL Horizons (Sonne, topozentrisch, `ssd.jpl.nasa.gov/api/horizons.api`, 31.10.2026 Berlin 52,5 N/13,4 O; 21.6.2026, 21.12.2026, 20.3.2027 bei 48 N/8 O; je 5 Zeitpunkte, Vergleichsskript in Scratchpad, nicht eingecheckt): **Höhenfehler maximal 0,36 Grad, Azimutfehler maximal 0,34 Grad** (Horizons ohne Refraktion [A]). Für Farbstufen (Schwelle 0 und 6 Grad) und Anzeige "Sonne in x min" völlig ausreichend; Sonnenauf-/untergang liegt damit auf etwa 1-2 min genau [A, abgeleitet aus 0,36 Grad bei ca. 0,25 Grad/min Flachwinkel]. Refraktion (ca. 0,5 Grad am Horizont) optional addieren.
- **Wo rechnen:**
  - Backend, eingebacken: 1 PNG je Slot (Nacht/Dämmerung/Tag-klar/Tag-bewölkt). Passt zum bestehenden Slot-Cache, App bleibt einfach, Bild konsistent auf allen Geräten, geringe Datenmenge (Palettenbild wenige KB). Nachteil: Backend rechnet Pixel (221x221 bis 1024x1024, trivial); fester Zeitpunkt = Slot-Zeit.
  - App, Overlay: Backend liefert nur Wolkenmaske, App berechnet Sonnenhöhe pro Pixel (z. B. kleines Raster 64x64 plus Interpolation, Metal/Core Image) und kann **auch für künftige Zeitpunkte** den Terminator zeigen (Sonne ist deterministisch). Mehr Client-Code, aber kein Backend-Mehraufwand.
  - **Empfehlung: Hybrid.** Backend liefert die Wolkenmaske ohnehin (Wolkenebene). Terminator/Nachtschattierung und "Sonne in x min am Ort" **in der App** (billig, wenige Zeilen, auch für Zukunft), Klar/Bewölkt-Färbung ebenfalls in der App aus der Maske (Palette). So braucht Sonnenradar **kein eigenes Backend-Paket**. Nur Phase 2 (SIS) braucht Backend.

## 3. Darstellung, Legende, Ortsbezug, Grenzen

- **Stufen (Vorschlag):** Nacht (h <= 0, dunkel/halbtransparent, kein Wolkeninhalt); Dämmerung (0-6 Grad, bläulich, "wenig Licht"); Tag und klar = "sonnig" (gelb/warm); Tag und bewölkt = "bewölkt" (grau, transparent); optional "heiter" nur mit SIS (Strahlung relativ zur Clear-Sky-Strahlung: > 70 % sonnig, 30-70 % heiter, < 30 % trüb) [A, Schwellen zu testen]. Farbenblind-tauglich (Helligkeit plus Farbe), Legende im vorhandenen Radar-Stil (aufklappbar).
- **Ortsansicht:** Abfrage von Pixel am Ort über die letzten Slots: "Seit 09:30 sonnig, Wolkenfeld aus West" und Aufgang/Untergang/Höhe aus Abschnitt 2 ("Sonne bis 16:48"). "Sonne in 30 min am Ort" nur als **Kurzfristextrapolation** [A]: Wolkenfeld per Verschiebung (Bewegungsvektor aus 2-3 Slots, optisch/Block-Matching) fortschreiben. Nicht bewiesen; im Entwurf als Option, deutlich als "Schätzung" kennzeichnen. Seriöser: Vorhersage aus Modellwolkenbedeckung (DWD ICON-D2 `CLCT` [N, nicht geprüft]).
- **Ehrliche Grenzen:** nur Vergangenheit (Bildalter 25-40 min, DWD SIS 20-25 min nach Slot); nur Wolkenbedeckung ohne Dicke/Höhe bei `clm`; **kein Schattenwurf** (Parallaxe: Wolken in 8-10 km Höhe werfen Schatten verschoben, bei niedriger Sonne mehrere zehn km [A]); Pixel 3-5 km (SEVIRI) bzw. 5 km (SIS) grob für Stadtteile; Nebel/Hochnebel kann als klar fehlklassifiziert werden [A, ungeprüft]; "klar" bei Schnee/Eis unsicher [A]; Aktualität 10-15 min Takt; Dämmerungsgrenze rein geometrisch. Keine Garantie (EUMETSAT Art. 8.2).
- **Attribution:** "Contains modified EUMETSAT Meteosat data 2026", DWD-Quelle bei SIS, Hinweis auf Verarbeitung.

## 4. Aufwand und Pakete (Schätzungen, [A])

Voraussetzung: **Wolkenebene (Satellit, `msg_fes:clm`-Slots im Backend) existiert.** Ohne sie kann Sonnenradar nur eigenständig clm-Abruf nachbauen (+1-2 Tage Backend).

| Paket | Inhalt | Dateibesitz (vorläufig) | Aufwand | Abhängigkeit |
|---|---|---|---|---|
| S1 Sonnenstand | NOAA-Rechner, Tests gegen Horizons-Werte, Terminator/Nacht-Raster | App: neue Datei Sonnenstand-Modul plus Tests | 0,5-1 Tag | keine |
| S2 App-Overlay | Karte: Maske plus Stufen, Legende, Ortszeile "Sonne bis ..." | App-Kartenview/Legende | 2-3 Tage | Wolkenebene, S1 |
| S3 Backend-Maske | `clm` je Slot holen, Palette/WebP, `latest.json`, Vollständigkeitscheck, Retry | Backend-Repo (Wolkenjob) | 1-2 Tage | Wolkenebene-Job |
| S4 SIS-Variante (Phase 2) | `DEv3.nc` laden, NetCDF decodieren, Raster zu Bild (Mercator/Overlay), 15-min-Job | Backend-Repo | 3-4 Tage | S3-Muster, Entscheidung |
| S5 Extrapolation (Option) | Bewegungsvektor, Verschiebung, Hinweis | Backend oder App | 3-5 Tage, Qualität offen | S3, Nutzerfreigabe |

## 5. Offene Punkte / vor Start prüfen

1. [N] SIS-Skalierung (scale_factor/add_offset), Fehlwerte nachts, Georeferenz-Detail (Pixelmitte) per NetCDF-Lesen prüfen (hier fehlten netCDF4/GDAL lokal).
2. [N] `clm`-Legende offiziell (Klassencodes) und Randverhalten im Nachtbereich (Wolkenmaske nachts aus IR, ohne Tagbild verfügbar?) stichprobenartig an Nachtslot testen.
3. [N] DWD-SIS-Lizenzfeld und Namensnennung bestätigen.
4. Entscheidung Nutzer: A zuerst, B später? Kurzfristextrapolation gewünscht?
