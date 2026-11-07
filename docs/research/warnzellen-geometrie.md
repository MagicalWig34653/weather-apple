# Warnzellen-Geometrie (Gate W3.1)

Stand der Prüfung: 07.11.2026. Alle Zahlen stammen aus eigenen Abrufen am selben Tag (Rohdateien nicht im Repo).

## Quellen (geprüft)

| Quelle | URL | Befund |
|---|---|---|
| WFS (aktuell) | `https://maps.dwd.de/geoserver/dwd/ows?service=WFS&version=2.0.0&request=GetFeature&typeNames=dwd:Warngebiete_Gemeinden&outputFormat=application/json` | Layer `dwd:Warngebiete_Gemeinden`, "Warngebiete des DWD auf Gemeindebasis". 11 214 Features (`resultType=hits`), alle `MultiPolygon`, WGS84 lon/lat, Koordinaten auf 4 Nachkommastellen (ca. 10 m). GeoJSON 11,1 MB, gzip 1,7 MB. |
| Shapefile-ZIP | `https://www.dwd.de/DE/leistungen/opendata/help/warnungen/cap_gemeinden_shape_zip.zip` (Link auf `.../opendata/hilfe.html`, "Gebiete für CAP-Warnungen auf Gemeindeebene") | 1,95 MB ZIP, `DWD_PVW_COMMUNE_QUARTER.shp/.dbf/.shx/.prj`, Dateidatum 28.02.2022, WGS84. `.shx` ergibt 11 214 Datensätze (gleiche Zahl wie WFS; Inhaltsgleichheit nicht geprüft). Ältere Fassung, Seite führt sie als Stand 04.2021. |
| Zuordnungstabelle | `https://www.dwd.de/DE/leistungen/opendata/help/warnungen/cap_warncellids_csv.csv` | 582 KB, `WARNCELLID;NAME;KURZNAME;CCC;BL`, 11 828 Zeilen (alle Ebenen: Gemeinde, Kreis, See, Küste). Enthält keine Geometrie. |
| Feed | `https://opendata.dwd.de/weather/alerts/cap/COMMUNEUNION_DWD_STAT/` | Verzeichnis verfügbar. |

Update-Rhythmus: nicht dokumentiert gefunden. Das Shapefile trägt Stand 2022, im WFS steht "2021 (Daten modifiziert)" bei den BKG-Flächen. Änderung an Gebieten ist selten, aber nicht ausgeschlossen (offen: DWD-Ankündigung, [N]).

## ID-Schema (geprüft am WFS)

- `WARNCELLID` ist 9-stellig, Präfix `8` + 8-stelliger AGS (`801051061` = AGS `01051061` Krempel): bei 10 971 von 10 971 Zellen mit gesetztem Präfix-8-Schema passt `ID[1:] == AGS` (10 969 Typ 8, dazu 2 Typ-7-Zellen mit AGS-Übereinstimmung).
- Typ 8 = Gemeinde (10 969), Typ 7 = Stadtbezirk/Ortsteil großer Städte (245, z. B. `714713003` Leipzig-Nordost, Nürnberg-Stadtbezirke `7095640xx`).
- 28 Gemeinde-IDs mit Präfix 8 aus der CSV haben keine Geometrie (u. a. `802000000` Hamburg, `804011000` Bremen, `805111000` Düsseldorf, `801003000` Lübeck, `801051034` Friedrichskoog): große Städte sind in der Geometrie nur über Typ-7-Zellen abgedeckt. Ob der Feed für diese Städte Typ-7- oder Typ-8-IDs liefert, ist in der Stichprobe nicht aufgefallen (siehe unten), aber nicht vollständig belegt.
- Kreis-/Landkreis-IDs (Präfix 1/5/9) gehören zur Ebene `DISTRICT_*` und stehen nicht im Gemeinde-Layer.

## Stichprobe Feed gegen Geometrie

`COMMUNEUNION_DWD_STAT/Z_CAP_C_EDZW_LATEST_PVW_STATUS_PREMIUMDWD_COMMUNEUNION_DE.zip` (66 KB, 6 Meldungen am 07.11.2026 13:22): 2 305 verschiedene `WARNCELLID`, alle 2 305 im WFS-Layer vorhanden (2 182 Typ 8, 123 Typ 7), 0 fehlend. Nur eine Momentaufnahme mit wenigen Meldungen. Gegen die ältere Shapefile-Fassung nicht geprüft.

## Lizenz (teilweise geprüft, Gate offen)

- Layer-Abstract: "Copyright GeoBasis-DE / BKG (http://www.bkg.bund.de) 2019 (Daten modifiziert)". Feld `COPYRIGHT` je Feature: 10 979 mal "© GeoBasis-DE / BKG 2021 (Daten modifiziert)" (identisch mit dem `LICENSE`-Wert in den CAP-Meldungen).
- **Nicht einheitlich:** 235 Features (alle Typ 7, Stadtbezirke) tragen andere Rechteangaben: 112 mal OpenStreetMap/ODbL 1.0 (2017), 97 mal Geoportal Berlin, 10 mal **CC BY-NC-SA 3.0 DE** (Nürnberg, `7095640xx`; nicht kommerziell, ShareAlike), dazu Düsseldorf (4), Stuttgart (3, dl-de/by-2-0), Saarbrücken (3), Kaiserslautern (2), Freiburg (2), Dortmund (2, dl-de/by-2-0).
- Pauschale Aussage "GeoNutzV / CC BY 4.0" für die Warngebiete ist **nicht belegt**: Die Nutzungsbedingungen-Seite des DWD ließ sich in diesem Lauf nicht auswerten (kein Treffer auf "GeoNutzV"). Ohne Primärtext keine Lizenzaussage; Rechtsprüfung offen (Nutzer/DWD-Anfrage `opendata@dwd.de`).
- Folgerung: Bündelung der BKG-Flächen (Quellenvermerk "© GeoBasis-DE / BKG 2021 (Daten modifiziert)" plus DWD-Hinweis) ist plausibel, aber die 10 Nürnberger Zellen (NC-SA) sind für eine App im Store problematisch, die ODbL-/Stadtquellen brauchen eigene Vermerke. Entscheidung Lead nötig.

## Größe und Vereinfachung

Rohdaten: 179 467 Punkte, 11 519 Ringe. Geplantes Binärformat `WGEO1` (Int32 lat/lon E5): rechnerisch ca. 1,8 MB (Schätzung, nicht gebaut). Die DWD-Geometrie ist bereits grob (4 Dezimalstellen), eine Vereinfachung ist für die Größe nicht nötig; Sollgrenze 8 MB aus W3.2 ist weit unterschritten. Genauigkeit: Ringe sind bereits DWD-eigene Generalisierung; Randpunkte können an Grenzen falsch zugeordnet sein, dort gilt "kleinste ID" (W3.3).

## Empfehlung

1. **App-Bundle** (eine Datei `WarnGeometry.bin`, ca. 2 MB): kein Netz, kein Datenschutzeffekt, passt zur Spec (Zuordnung nur auf dem Gerät). Download beim ersten Start bringt Offline-Fehler und DWD-Abhängigkeit ohne Nutzen; Server-Lookup würde Koordinaten übertragen und widerspricht der Spec 5 (verworfen).
2. **Quelle:** WFS-Export (aktueller als das ZIP), Aufbereitung mit `tools/warn_geometry.py` aus GeoJSON statt Shapefile (Stdlib `json`); dann entfällt der Shapefile-Parser. Plan W3.2 entsprechend anpassen.
3. **Vor Bündelung klären:** Lizenztext DWD (Nutzungsbedingungen), Umgang mit den 235 Typ-7-Zellen (Option A: nur die 10 NC-SA-Zellen auslassen und Nürnberg auf Stadt-/Kreisebene `DISTRICT` ersetzen; Option B: DWD um Klarstellung bitten). Impressum/Info-Sheet mit Quellenvermerken.
4. **Aufwand:** W3.2 klein (S), bei Option A zusätzlich Sonderfall Nürnberg. **Risiken:** Lizenzmischung, Gebietsreformen (Server antwortet `409 warncell_unknown`, Geometrie nur mit App-Update), Großstädte nur über Typ-7-Zellen (Feed liefert sie laut Stichprobe so, nicht vollständig belegt), Update-Rhythmus unbekannt.

## Alternative ohne Lizenzrisiko

Stand 07.11.2026, eigene Abrufe am selben Tag. Rohdateien nur im Scratchpad, nicht im Repo.

### (1) BKG VG250 / VG250-EW (Gemeinde-/Kreisgrenzen, selbst gebaut)

- Quelle: `https://gdz.bkg.bund.de/index.php/default/verwaltungsgebiete-1-250-000-stand-31-12-vg250-31-12.html` (und `...-mit-einwohnerzahlen-...vg250-ew-31-12.html`). Seitentext: "Datenlizenz Deutschland Namensnennung 2.0" (dl-de/by-2-0), kostenfrei, Nutzer "Jedermann", Stand 31.12.2025, Fortführung jährlich.
- Quellenvermerk laut Seite: "© BKG (Jahr des letzten Datenbezugs) dl-de/by-2-0, Datenquellen: [Link]", plus Veränderungshinweis (die Geometrie würde vereinfacht). Ob die Einbindung in ein App-Bundle ausdrücklich erlaubt ist, steht nicht auf der Seite; dl-de/by-2-0 erlaubt allgemein Vervielfältigung, Veränderung und Weitergabe mit Namensnennung (Lizenztext selbst in diesem Lauf nicht gelesen).
- Format/Größe (HEAD-Abruf, nicht heruntergeladen): GeoPackage UTM32s ZIP 70,6 MB, Shape GK3 ZIP 64,9 MB; Quelle `https://daten.gdz.bkg.bund.de/produkte/vg/vg250_ebenen_1231/aktuell/`. Maßstab 1:250 000 (DLM250-ausgerichtet). Attributnamen (AGS etc.) nicht geprüft. Zum App-Bundle wäre Vereinfachung nötig (nicht gebaut, Größe unbekannt).
- Mapping Gemeinde: DWD-ID Typ 8 = `8` + AGS (am WFS belegt, siehe oben), also AGS direkt nutzbar. **Lücken (geprüft am WFS):** 245 Typ-7-Zellen (29 Stadt-Präfixe, z. B. Berlin 71, München 25) haben in VG250 keine Gemeinde-Entsprechung; die Großstadt-Gemeinde-IDs (28 ohne Geometrie) ebenso. Für diese Städte bliebe nur die Kreisebene (die Stadt ist selbst Kreis). Stadtbezirks-Genauigkeit entfällt ohne OSM/Stadt-Daten.
- Zusätzlich: Kreis-Zellen der Küste/Inseln (Typ 10, "Binnenland"/"Küste") und 87 Gemeinde-AGS5 ohne Typ-1-Kreiszelle (Küstenkreise, z. B. 01051 Dithmarschen, 03352, 03452) lassen sich nicht rein aus VG250 ableiten. Insgesamt: eigene Pipeline, mittlerer Aufwand (M), Sonderfälle manuell.

### (2) Kreisebene

- WFS-Layer `dwd:Warngebiete_Kreise` (Capabilities geprüft): 402 Features, GeoJSON 0,9 MB, 78 812 Punkte (Binärformat deutlich unter 1 MB). **Alle 402** tragen `COPYRIGHT` "© GeoBasis-DE / BKG 2021 (Daten modifiziert)"; keine OSM-/CC-NC-SA-/Stadtquellen (Gemeindelayer: 235 abweichende Vermerke nur bei Typ 7).
- IDs: 310 Zellen Typ 1 (ID = `1` + 5-stellige Kreis-AGS + `000`, z. B. `103157000` Kreis Peine, `105315000` Köln, `109564000` Nürnberg, `111000000` Berlin, `102000000` Hamburg), 92 Zellen Typ 10 mit Präfix 9 (Küsten-/Inselkreise geteilt "Binnenland"/"Küste", z. B. `903352001`/`903352002` Cuxhaven; `909184999` Kreis und Stadt München).
- Feed: `https://opendata.dwd.de/weather/alerts/cap/DISTRICT_DWD_STAT/` existiert (Verzeichnis geprüft, wie `COMMUNEUNION_DWD_STAT/`, Dateien gleichen Namensschemas `..._DISTRICT_DE.zip`). Ob alle 402 Zell-IDs dort vorkommen und die Warninhalte zu COMMUNEUNION konsistent sind, **nicht geprüft**.
- Genauigkeitsfolge: Warnung gilt für den ganzen Kreis; Gemeindeebene (11 214 Zellen) entfällt. Bei kleinräumigen Gewittern/Starkregen häufiger Fehlalarm für Orte am anderen Kreisende, bei Küste/Inseln mit geteilten Zellen besser. Produktentscheidung nötig, ob akzeptabel.

### (3) Lizenz des DWD

- `https://www.dwd.de/DE/leistungen/opendata/hilfe.html`: nennt keine GeoNutzV; verweist nur auf "Open Data Nutzungsbedingungen" (Rechtliche Hinweise, Stand 07.2017). COUNTY/COMMUNEUNION-Begriffe stehen dort nicht.
- `https://www.dwd.de/DE/service/rechtliche_hinweise/rechtliche_hinweise_node.html` (Auszug): frei zugängliche Geodaten und Geodatendienste dürfen "unter CC BY 4.0 weiterverwendet werden, wenn ein Quellenvermerk beigefügt wird"; Geodaten seien "alle bereitgestellten meteorologischen Wetter- und Klimainformationen mit Ortsbezug". Fremddaten: "Geobasisdaten stammen von den Vermessungsverwaltungen der Länder und dem Bundesamt für Kartographie und Geodäsie (BKG)"; Inhalte Dritter bedürfen "gegebenenfalls der vorherigen Zustimmung der jeweiligen Rechteinhaber". GeoNutzV wird nicht erwähnt.
- Bewertung: Die Warngebiete sind DWD-Geodatendienst mit CC BY 4.0-Aussage, aber die zugrunde liegenden Flächen sind BKG-Fremddaten mit dem Vermerk "© GeoBasis-DE / BKG"; ein eigener Metadatensatz mit Nutzungsbedingungen zum Layer wurde nicht gefunden/gelesen. Für die Kreis-Zellen ist die Kette DWD (CC BY 4.0) plus BKG (dl-de/by-2-0, beide Namensnennung, ohne NC/SA) konsistent; juristisch nicht abschließend geprüft.

### (4) Reverse-Geocode (CLGeocoder)

Nicht abgerufen oder getestet (Plattformverhalten nicht an Primärquelle geprüft). Einschätzung (Hypothese): liefert Ortsnamen (`locality`, `subAdministrativeArea`), keine AGS; Zuordnung nur über Namen gegen `cap_warncellids_csv.csv` (Namensdubletten, Schreibweisen "Stadt X"/"Kreis X", Gemeindeverbände). Fehleranfällig und überträgt Koordinaten an Apple, widerspricht dem Gedanken "Ort nur auf dem Gerät". Nicht empfohlen.

### (5) Bewertung und Empfehlung

| Variante | Lizenz | Genauigkeit | Aufwand | Ohne Mail |
|---|---|---|---|---|
| A: DWD-Layer `Warngebiete_Kreise` ins Bundle (<1 MB) | nur BKG-Vermerk, einheitlich, plus DWD CC BY 4.0 | Kreis | S | ja (empfohlen als Start) |
| B: Gemeindelayer ohne die 235 Typ-7-Zellen | gemischt nur bei Typ 7, Rest BKG; Lizenz-Gesamtaussage DWD offen | Gemeinde, Großstädte auf Kreis zu ersetzen | M | mit Restrisiko, Klärung empfohlen |
| C: VG250 selbst bauen | dl-de/by-2-0 eindeutig | Gemeinde, Großstädte/Küste Sonderfälle | M bis L | ja, aber mehr Arbeit, Lücken s. o. |
| D: CLGeocoder | Apple-Bedingungen | Namensmatching unsicher | S | Datenschutzproblem |

Empfehlung: Sofort A (Kreis-Warnzelle, Quellenvermerk "© GeoBasis-DE / BKG 2021 (Daten modifiziert), DWD, CC BY 4.0" im Info-Sheet; Server/Feed auf `DISTRICT_*` ausrichten, `warncell` dann Kreis-ID). Mail an `opendata@dwd.de` parallel für Gemeindegenauigkeit (B) bzw. C als lizenzklarer Ausbau. Offen: DISTRICT-Feed-Vollständigkeit, Produktfreigabe der gröberen Genauigkeit, VG250 nicht heruntergeladen, Lizenztexte selbst nicht gelesen.


## Umsetzung W3 (7.11.2026, Kreisebene)

- Quelle: `https://maps.dwd.de/geoserver/dwd/ows?service=WFS&version=2.0.0&request=GetFeature&typeNames=dwd:Warngebiete_Kreise&outputFormat=application/json`, abgerufen 07.11.2026, 903 893 Bytes, EPSG:4326 in Reihenfolge lon, lat, 402 Features (Polygon/MultiPolygon), `COPYRIGHT` einheitlich "© GeoBasis-DE / BKG 2021 (Daten modifiziert)". Rohdatei nicht im Repo; Aufbereitung: `python3 -I tools/warn_geometry.py --geojson <raw.json> --out Weather/Resources/WarnGeometry.bin`.
- Ergebnis: 402 Zellen, 463 Ringe, 41 301 Punkte (frueher genannte 78 812 Punkte stimmen nicht), 337 409 Bytes (WGEO1, Int32 E5, Aufloesung ca. 1 m; Quelle hat 4 Nachkommastellen). Keine Vereinfachung.
- DISTRICT-Feed `https://opendata.dwd.de/weather/alerts/cap/DISTRICT_DWD_STAT/..._DISTRICT_DE.zip` (7.11.2026 15:52): 111 verschiedene `WARNCELLID` (Wert `<value>` mit 9 Ziffern), alle im Layer. Server und App verwenden dieselbe 9-stellige ID.
- Attribution in der App: "Quelle: Deutscher Wetterdienst, © GeoBasis-DE / BKG 2021 (Daten modifiziert)" (Info-Sheet > Datenquellen).
- Matching: Kreise ueberlappen an den Landmarken nicht (je genau ein Treffer); Kuestenpunkte auf See liegen ausserhalb aller Polygone und werden nur ueber `nearestCell` zugeordnet.
