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
