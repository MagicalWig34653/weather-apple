# Unwetterwarnungen, Temperatur-/Feuchtekarte mit Wald, Frostmeldungen (Recherche)

Stand: 7. November 2026 (alle Abrufe am 07.11.2026, ca. 11:10-11:40 UTC). Reine Recherche, kein Produktcode, kein Deploy.
Kennzeichnung: **[G]** am 07.11.2026 geprüft (Quelle genannt), **[A]** Annahme/Rechnung, **[N]** nicht geprüft/offen.
Basis im Repo: `weitere-radarkarten.md` (Lizenz, WMS), `push-benachrichtigungen.md`, `push-regionen.md`, Backend `PushEvaluator`/`PushGrid`/Live Activity (`docs/decisions.md` beider Repos).

## 1. Unwetterwarnungen (amtliche DWD-Warnungen)

**Zugang [G]**
- CAP 1.2 auf `https://opendata.dwd.de/weather/alerts/cap/`: Verzeichnisse `{DISTRICT,COMMUNEUNION}_{DWD,CELLS,EVENT}_{STAT,DIFF}` (Landkreis- oder Gemeinde-Basis; Aktualisierungsstrategie DWD/zellen-/ereignisbezogen; STAT = gesamte aktuelle Lage, DIFF = nur neue/aktualisierte/aufgehobene Meldungen), je Sprache (DE/EN/ES/FR/MUL) als ZIP; `..._LATEST_...zip` zeigt auf die letzte Produktion. Aktuell keine Warnlage: ZIPs leer (22 Byte).
- Aktualisierung [G, DWD "CAP Verarbeitungshinweise" v2.1.8]: Produktion bis zu 1x pro Minute; bei unveränderter Lage künstliche Produktion alle 10 min (DIFF dann leer); keine harte Echtzeitzusage. DWD empfiehlt, Meldungen mit Ausgabezeit > 20 min nicht mehr zu versenden, und alle ca. 15 min den eigenen Zustand mit STAT abzugleichen (verpasste Updates).
- Warnzellen: `WARNCELLID` (9-stellig, z. B. `101001000` = Stadt Flensburg), Liste `cap_warncellids_csv.csv` (11 828 Zeilen, Spalten WARNCELLID;NAME;KURZNAME;CCC;BL) und Shapefiles (Gemeinden, Landkreise, Seegebiete, Küste) auf der DWD-Hilfeseite `https://www.dwd.de/DE/leistungen/opendata/hilfe.html`. Dort auch CAP-DWD-Profil v2.1.14 (PDF).
- Alternativ [G]: GeoServer `maps.dwd.de/geoserver` mit WFS/WMS-Layern `dwd:Warnungen_Gemeinden`, `Warnungen_Landkreise`, `Warngebiete_*` (Geometrie, gut für Kartendarstellung); JSON `https://www.dwd.de/DWD/warnungen/warnapp/json/warnings.json` (JSONP `warnWetter.loadWarnings({...})`, Feld `copyright`, Last-Modified 11:05 UTC; **inoffiziell dokumentiert, [N] Stabilitätszusage**). Empfehlung: CAP DIFF+STAT als Quelle, kein JSONP.
- Frostwarnungen existieren als offizielles Ereignis [G, `dwd.de/.../warnkriterien.html`]: Stufe 1 "verbreitet Lufttemperatur unter dem Gefrierpunkt in Lagen bis 800 m", Stufe 2 "überörtlich oder anhaltend < -10 °C". Keine Saisonbegrenzung genannt, Bodenfrost dort nicht aufgeführt. Damit deckt Feature 1 einen Teil von Feature 3 amtlich ab.

**Lizenz [G]** `dwd.de/DE/service/rechtliche_hinweise/rechtliche_hinweise.html`: frei zugängliche Geodaten (alle meteorologischen Wetter- und Klimainformationen mit Ortsbezug) unter CC BY 4.0 mit Quellenvermerk; DWD-FAQ 1.2: kostenfrei, ausdrücklich auch für wirtschaftliche Angebote; Open-Data-Server ohne Verfügbarkeitszusage (`dwd.de/DE/leistungen/opendata/opendata.html`). Weitergabe als Push an Endnutzer ist nach dieser Lesart zulässig, eine ausdrückliche Aussage zu Warnungen/Push fehlt aber [N]: die Rechtsseite und die FAQ erwähnen Warnungen nicht, der Disclaimer-Text wurde nicht gelesen. **Empfehlung** (konservativ [A]): Text und Stufe unverändert übernehmen, Quelle "Deutscher Wetterdienst" und Ausgabezeit zeigen, deutlicher Hinweis "Kein Ersatz für amtliche Warnkanäle (WarnWetter-App, NINA)" (deckt sich mit Entscheidung "Kein Warnungsersatz"); vor Livegang kurze schriftliche Rückfrage an DWD (`CAP@dwd.de`, Adresse aus dem Verarbeitungshinweis) sinnvoll.

**Abgrenzung NINA [N/A]:** NINA/MoWaS (BBK) ist Bevölkerungs- und Katastrophenschutz (Gefahrenlagen, Länder/Leitstellen); DWD-Wetterwarnungen laufen dort zusätzlich ein. Die NINA-API-Nutzungsbedingungen konnten nicht gefunden werden (Doku nur inoffiziell via bundesAPI) -> nicht verwenden. ShowerNow bleibt Wetter-App ohne Anspruch auf Bevölkerungsschutz.

**Bewertung:** machbar, **geringer Aufwand**, kein Rasterprodukt nötig. Textdaten klein (ZIP < 300 KB je Produktion beobachtet).
**Kleinste erste Version:** Backend pollt `COMMUNEUNION_DWD_DIFF` (DE) alle 60 s [A: 1 Request/min, ETag/Last-Modified wenn vorhanden, sonst Dateiname `..._LATEST_...` per Zeitstempel] und alle 15 min STAT; Warnung -> Abo-Treffer per `WARNCELLID`. Gemeinde-Basis statt Landkreis, damit die Zelle zum Ort passt. App: Abo "Unwetterwarnungen ab Stufe 3 (Unwetter)" für **gespeicherte Orte**; zur Zuordnung muss der Client die WARNCELLID kennen: Ort -> Gemeinde braucht Geometrie (eingebettete vereinfachte Shapes + Punkt-in-Polygon auf dem Gerät, also **keine Koordinate zum Server**; nur WARNCELLID wird übermittelt, grobe Gebietskennung wie in `push-regionen.md`).
**Wiederverwendung Push-Kette:** Outbox, APNs, Hysterese (`PushEvaluator`-Muster: pending/notified/Wiederbewaffnung) und Datenschutzmodell passen; Auslöser ist aber **ereignisbasiert** (CAP-Identifier, Update/Cancel/AllClear), nicht pixelbasiert; dafür eigene kleine Tabelle `warn_sub(warncell_id, min_severity)` und `warn_sent(alert_id, installation)`. Update-Meldungen (`references`) nicht doppelt senden. Live Activity: nicht nötig. Zeitkritisch ("Time Sensitive") nur für höchste Stufe; "Critical Alerts" nicht anstreben (Apple-Entitlement, siehe `live-activities-und-kritische-mitteilungen.md`).
**Risiken:** Stufen-/Inhaltsfehler dürfen nicht kaschiert werden (Text 1:1); Sturm/Gewitter sind kurzfristig, 1-min-Takt aber ohne Echtzeitgarantie; Haftung/Disclaimer; WARNCELLID-Änderungen bei Gemeindereformen (CSV regelmäßig, z. B. quartalsweise, abgleichen [A]).

## 2. Temperatur- und Feuchtekarte mit Waldeinfluss

**Daten [G]**
- ICON-D2 Open Data `https://opendata.dwd.de/weather/nwp/icon-d2/grib/HH/<var>/`: 2,2 km, Läufe alle 3 h (00..21 UTC), bis +48 h stündlich (49 Dateien je Lauf/Variable, Lauf 03 und 18 bestätigt 99 Einträge = 2 Gitter x 49), GRIB2 bz2; **icosaedrisch und regular-lat-lon** (`..._regular-lat-lon_single-level_..._t_2m.grib2.bz2`). Variablen u. a. `t_2m` (ca. 1,05 MB bz2 je Stunde, regular), `td_2m` (0,93 MB), `relhum_2m`, `tmin_2m`, `tmax_2m`, `t_g` (Bodenoberfläche), `clct`, `u_10m`, `t_so`, statisch `hsurf`, `fr_land`, `plcov`, `lai`. Es gibt **kein 5-cm-Temperaturfeld**. Quelle Auflösung/Takt: `dwd.de/EN/ourservices/nwp_forecast_data/nwp_forecast_data.html`. Eintreffzeiten/Latenz [N], Zeitstempel im Listing unplausibel zur Laufzeit, nicht belegt.
- Volumen [A]: T2M+Td2M ca. 2 MB je Stunde -> ca. 100 MB je Lauf, 8 Läufe/Tag ~0,8 GB/Tag Download; reduzierbar auf 4 Läufe und 24 h. Ein GRIB2-Decoder (Swift, eccodes/C) fehlt im Backend [A], ist der Hauptaufwand.
- Bereits abrufbar ohne GRIB: WMS `dwd:Icon_reg025_fd_sl_T2M` (0,25°, stündlich, global ICON, bekannt grob, siehe `weitere-radarkarten.md`), `dwd:Icon-eu_reg00625_fd_gl_T`, Stationen `dwd:RBSN_T2m`/`RBSN_RH` [G Layer vorhanden, Inhalt nicht geprüft].
- Messwerte [G]: Stationsliste `weather_reports/poi/<id>-BEOB.csv` (stündlich, 974 Dateien; u. a. Temperatur 2 m, Taupunkt, rel. Feuchte, Temperatur 5 cm, Min 5 cm 12 h), CDC `observations_germany/climate/10_minutes/air_temperature/{now,recent}` (10 min). Stationen sind punktuell und stehen meist im Freiland.
- Rasteranalyse Messung [G]: HOSTRADA `climate_environment/CDC/grids_germany/hourly/hostrada/` (u. a. `air_temperature_mean`, `dew_point`, `humidity_relative`, `urban_heat_island_intensity`), 1 km, monatliche Dateien (ca. 170 MB), jüngste Datei Stand 25.10.2026 = Analyse/Archiv, **nicht für aktuelle Lage**. RADOLAN enthält kein Temperaturfeld.
- Konsequenz: aktuelle Temperatur-/Feuchtekarte = **ICON-D2 Analyse/Kurzfrist (Stunde 0..n)** als Modellfeld; Stationen nur zur Plausibilisierung. In ICON-D2 steckt Vegetation (`plcov`, `lai`) bereits modellintern, aber bei 2,2 km nur grob; ein Wald-Kleinrelief fehlt.

**Waldebene [G, soweit genannt]**
- Copernicus HRL Tree Cover Density (2018-heute, 10 m, Europa; "full, open and free" nach Delegierter VO 1159/2013; Download laut EEA-Katalog nach Registrierung, genaue Lizenz-/Attributionsklausel der Produktseite **[N]**) `land.copernicus.eu/en/products/high-resolution-layer-forests-and-tree-cover`.
- ESA WorldCover 2021 v200: 10 m, CC BY 4.0, Klasse "Tree cover" (>= 10 % Baumbedeckung), Gesamtgenauigkeit 76,7 % (Klassengenauigkeit [N]); Attribution "(c) ESA WorldCover project / Contains modified Copernicus Sentinel data (2020/2021) processed by ESA WorldCover consortium" (nach Earth-Engine-/Planet-Katalog, `worldcover2021.esa.int`).
- BKG Basis-DLM: dl-de/by-2-0, Quellenvermerk "(c) GeoBasis-DE / BKG", NAS/Shape, Aktualisierung quartalsweise; ob Vegetationsflächen im Open-Data-Umfang liegen, **[N]** (`sg.geodatenzentrum.de/.../nutzungsbedingungen_basis-dlm_eng.pdf`). CORINE (100 m) für Karte zu grob, [N] Details.
- Einbindung [A]: einmalig offline (nicht im Backend-Betrieb) auf z. B. 250-500 m Baumanteil (0..100 %) aggregieren, als 8-Bit-Raster (Deutschland ca. 1 000 x 1 300 Pixel bei ~700 m, passend zum bestehenden Push-/Radar-Raster 1024x1311, ca. 1-2 MB PNG/WebP) mit App oder Backend ausliefern; Lizenzvermerk in Quellenzeile. Aggregation/Lizenzprüfung ist ein eigener kleiner Auftrag.

**Wissenschaftlicher Befund [G/A]:** Waldüberschirmung puffert Temperaturen: Maxima unter Kronen im Mittel ca. 4 °C kühler (CNRS-Meldung zu De Frenne et al., Nature Ecol. Evol. 3, 744-749, 2019, DOI 10.1038/s41559-019-0842-1; Zahl aus Pressemeldung, nicht im Paper verifiziert), Minima bei Kälte eher **wärmer**, ca. +1 °C (nur Konferenzabstract, [N]). Das ist stark standort-, jahreszeit- und wetterabhängig (Strahlungstage vs. bedeckt, Laub an/aus, Höhe, Hang).
**Ehrliche Bewertung:** Eine pauschale "Wald = x °C kühler"-Korrektur ist **nur an klaren, windschwachen Strahlungstagen im Sommer** sinnvoll und bei Nacht/Winter teils falsch herum (Frostsenken, Kaltluft sammelt sich in Tälern/Lichtungen, im Bestand oft milder). Empfehlung: Darstellung als **"Schätzung: Waldeinfluss"**, nicht als Messwert.
- Sommer-Tag-Modell [A, zu testen]: `T_Wald = T_2m_ICON - k * baumanteil * s`, `s` = Strahlungsfaktor aus `1 - clct` und Sonnenstand (Mittag), `k` ca. 0-4 °C; nachts/Winter keine Korrektur oder nur Hinweis. Nicht angeben: Genauigkeit in °C ohne Validierung gegen Stationen (Wald-/Freilandpaare, z. B. DWD-Stationen im Wald, [N]).
- Feuchte: relative Feuchte unter Kronen höher, Taupunkt kaum verändert; daher Feuchte-Karte als `relhum_2m`/`td_2m` ohne Waldkorrektur, ggf. schlichter Hinweis. Gefühlt/Schwüle-Karte (Taupunkt) ist die verständlichere Darstellung [A].

**Bewertung:** Temperaturkarte (Modellfeld, ohne Wald) **machbar, mittlerer Aufwand** (GRIB-Decoding + Farbskala + Slots wie Radar); Wald-Overlay **machbar, aufwändig und wissenschaftlich heikel**; Feuchtekarte gleiche Pipeline, geringer Zusatzaufwand.
**Kleinste erste Version:** (a) Temperatur 2 m + Taupunkt als zusätzliche Kartenebene, **0,25°-WMS-Layer `Icon_reg025_fd_sl_T2M` als Zwischenschritt** ohne Backend-Last (grobe Auflösung bekannt, nicht waldfähig); (b) danach Backend-Ingest ICON-D2 regular-lat-lon T2M/Td2M/relhum_2m (4 Läufe/Tag, 24 h) als Bild je Stunde wie bestehende Ebenen (`LAYERS`-Schalter); (c) Waldebene als statische Textur mit Schalter "Waldeinfluss (Schätzung)" nur für Sommertag; ohne Validierung nicht ausliefern.
**Risiken:** Speicher/CPU des Swarm bei GRIB (neues Image-Paket, libeccodes), Vegetations-Lizenzklauseln (HRL), falsche Präzision, Konflikt mit "Frostsenke"-Aussagen bei Nacht.

## 3. Frostmeldungen (Übergangszeit)

**Kriterien [A, abgeleitet; Schwellen zu validieren]**
- Auslöser: ICON-D2 `t_2m` (und `tmin_2m`) im Zeitfenster der kommenden Nacht < 0 °C am Ort ("Frost") bzw. < 1 bis 2 °C zusätzlich mit klarem Himmel (`clct` niedrig) und Wind schwach (`u_10m` < ca. 2-3 m/s) als "Bodenfrost-Risiko" (Strahlungsfrost: Boden/5 cm oft 2-4 °C kälter als 2 m). Taupunkt < 0 °C verstärkt Raureif/Frost, hoher Taupunkt/Nebel kann abschwächen. `t_g` (Boden) als Zusatzindikator; 5-cm-Prognose fehlt [G], Beobachtung 5 cm nur an Stationen [G].
- Saison [A]: Sept/Okt bis Mai, schaltbar; amtlich nur Lufttemperatur < 0 °C (Stufe 1, bis 800 m) [G]. Vorlauf: Abendmeldung (z. B. 16-19 Uhr) für die folgende Nacht, Zeitpunkt wählbar; Modellvorlauf 6-24 h realistisch, bei 2,2 km Auflösung **Frostsenken/Täler nicht aufgelöst** -> Fehlalarm in beide Richtungen (Kaltluftseen unterschätzt, Stadteffekt überschätzt). Die kleinste, ehrliche Aussage: "Frost möglich" statt "Frost".
- Hysterese/Wiederholsperre: je Ort einmal pro Nacht, erneut erst nach Frostfreiheit >= 24 h; Absage ("Frostgefahr gebannt") nicht senden [A].

**Bewertung:** **machbar, mittlerer Aufwand** (erste Version sehr günstig): Variante A ohne eigene Modellverarbeitung = amtliche DWD-Frostwarnung (Stufe 1) über die Warnungs-Pipeline aus Abschnitt 1 (Lizenz/Zeitplan geklärt, keine Rasterkosten); Variante B = Modellpunktwert (Ort/Zelle), benötigt dasselbe GRIB-Ingest wie Abschnitt 2 (nur ein Punkt je Abo, Pixelzugriff statt Bild, Gridzelle wie `PushGrid`). Variante A deckt vermutlich viele Fälle, aber nicht Garten-/Bodenfrost knapp über 0 °C (Warnschwelle "verbreitet unter 0 °C").
**Kleinste erste Version:** Warn-Pipeline + Filter `EVENT=FROST` für gespeicherte Orte (Saison Okt-Mai); Modellpunktwert als zweiter Schritt, klar als "Schätzung für 2 m, Bodenfrost möglich".
**Risiken:** Fehlalarme -> Abmeldungen; Kaltluftsenken; Nutzer erwartet Messgenauigkeit am eigenen Garten.

## 4. Last, Datenschutz, Empfehlung

- Backend [A]: Warnungen = ein kleiner Poll/min (< 1 MB/min) plus Abo-Tabelle nach WARNCELLID, vernachlässigbar neben Radar. GRIB (Temp/Feuchte/Frost) ist die einzige echte neue Last (siehe oben, ~0,4-0,8 GB/Tag Download, Dekodierung je Lauf einmalig, unabhängig von Abozahl wie beim Radar). Nur Leader dekodiert und legt Ergebnisse in MariaDB/Dateien ab; Replikate bleiben stateless; Fair-Use bei DWD: einmaliger Abruf je Lauf, bei Download-Fehlern Backoff.
- Datenschutz: nur gebietsbezogene Kennungen speichern (WARNCELLID oder Rasterzelle, kein Verlauf, keine Ortsnamen); Gemeindezuordnung auf dem Gerät. `/datenschutz` und App-Privacy-Angaben vor Livegang ergänzen (neue Zwecke), Text nicht jetzt geändert.
- Live Activity/Hysterese: Frost und Warnungen brauchen keine Live Activity; vorhandene Outbox/APNs/Time-Sensitive/Wiederholsperre wiederverwenden, aber getrennte Abo-Typen und eigene Notification-Kategorien (Nutzer soll Warnung/Frost/Regen einzeln schalten).
- **Reihenfolge-Empfehlung:** 1) Unwetterwarnungen (inkl. Frost-Ereignis) in der App anzeigen und per Push (kleinste Einheit, kaum Last), 2) Temperatur-/Taupunktkarte per vorhandenem WMS-Layer, dann ICON-D2-Ingest, 3) Frost-Modellmeldung auf dem ICON-D2-Ingest, 4) Waldeinfluss zuletzt und nur als Sommer-Tag-Schätzung nach Validierung.

## 5. Offene Fragen an den Nutzer

1. Warnungen: Nur Anzeige oder Push? Ab welcher Stufe (Markant/Unwetter/Extrem), oder alle Frostwarnungen? Zusätzlich DWD kurz schriftlich um Bestätigung bitten (empfohlen)?
2. Reichen gespeicherte Orte als Gebiet, oder sollen auch aktueller Standort/Umkreis warnen (Datenschutz: Standort müsste grob an Server)?
3. Temperaturkarte: Zwischenlösung mit 0,25°-WMS akzeptabel, oder gleich ICON-D2 (neue GRIB-Pipeline im Backend, Aufwand mittel bis hoch)?
4. Wald: Reicht "Schätzung, nur Sommer/Tag" mit Hinweis oder lieber ganz weglassen? Zustimmung zu Copernicus-/WorldCover-Vermerken in der Quellenzeile?
5. Frost: Amtliche Warnung genügt (Variante A) oder zusätzlich eigene "Frost möglich"-Schätzung inkl. Bodenfrost? Zeitpunkt der Abendmeldung und Saison (Sep-Mai?)?

## Quellen (abgerufen 07.11.2026)
- https://opendata.dwd.de/weather/alerts/cap/ , `.../txt/`
- DWD CAP Verarbeitungshinweise v2.1.8 (PDF): https://www.dwd.de/DE/leistungen/opendata/help/warnungen/cap_dwd_implementation_notes_de_pdf.pdf ; Hilfe/WARNCELLID-CSV/Shapes: https://www.dwd.de/DE/leistungen/opendata/hilfe.html
- https://www.dwd.de/DE/service/rechtliche_hinweise/rechtliche_hinweise.html ; https://www.dwd.de/DE/leistungen/opendata/opendata.html ; https://www.dwd.de/DE/leistungen/opendata/faqs_opendata.html
- https://www.dwd.de/DE/wetter/warnungen_aktuell/kriterien/warnkriterien.html
- https://opendata.dwd.de/weather/nwp/icon-d2/grib/ ; https://www.dwd.de/EN/ourservices/nwp_forecast_data/nwp_forecast_data.html
- https://opendata.dwd.de/climate_environment/CDC/grids_germany/hourly/hostrada/ ; https://opendata.dwd.de/weather/weather_reports/poi/ ; CDC 10-min `observations_germany/climate/10_minutes/air_temperature/`
- https://maps.dwd.de/geoserver/ows (GetCapabilities, WFS/WMS) ; https://www.dwd.de/DWD/warnungen/warnapp/json/warnings.json
- https://land.copernicus.eu/en/products/high-resolution-layer-forests-and-tree-cover ; https://worldcover2021.esa.int ; https://sg.geodatenzentrum.de/web_public/gdz/dokumentation/eng/nutzungsbedingungen_basis-dlm_eng.pdf
- De Frenne et al. 2019, https://doi.org/10.1038/s41559-019-0842-1 ; https://www.cnrs.fr/en/press/hotter-it-gets-more-forests-act-thermal-insulators
- NINA API (inoffiziell): https://nina.api.bund.dev/ (Bedingungen nicht gefunden)
