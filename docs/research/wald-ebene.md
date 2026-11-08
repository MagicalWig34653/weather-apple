# Waldebene (Temperatur-/Feuchtekarte, Paket P3)

Stand 08.11.2026. Zweck: statische Orientierungsebene "Waldfläche" für Temperatur und Feuchte, ohne Einfluss auf Werte. Nutzerentscheidung: nur bei Temperatur/Feuchte, ca. 550 m, im Bundle höchstens ca. 1 MB, nichts umrechnen.

## Quelle und Lizenz (Primärquellen, abgerufen 08.11.2026)

- Datensatz: ESA WorldCover 10 m 2021 v200, Zenodo-Eintrag https://zenodo.org/records/7254221 (DOI 10.5281/zenodo.7254221, veröffentlicht 28.10.2022). Lizenz laut Eintrag: Creative Commons Attribution 4.0 International (CC BY 4.0).
- Attribution laut https://esa-worldcover.org/en/data-access ("The ESA WorldCover product is provided free of charge, without restriction of use"; Lizenz CC BY 4.0). Wortlaut für Karten: `© ESA WorldCover project [year] / Contains modified Copernicus Sentinel data ([year]) processed by ESA WorldCover consortium`; Jahr 2020 oder 2021 passend zur Kartenversion. **Festgelegt für v200: `© ESA WorldCover project 2021 / Contains modified Copernicus Sentinel data (2021) processed by ESA WorldCover consortium`** (Abweichung von der Spec-Schreibweise "(2020/2021)", die auf der Seite nicht steht). Der Zenodo-Eintrag selbst nennt keinen Attributionstext (Abschnitt Citation leer); Zitat für Publikationen: `ESA WorldCover 10 m 2021 v200. https://doi.org/10.5281/zenodo.7254221`.
- Zusätzlich anzeigen: Veränderungshinweis (CC BY 4.0 verlangt Angabe von Änderungen): "Auf ca. 550 m gemittelter und in 4 Stufen gerundeter Waldanteil, eigene Färbung" (steht auch in der JSON-Datei).
- Klassenschlüssel: 10 = Tree cover (Pixelwert in den Kacheln). Nicht geprüft: Copernicus HRL Tree Cover Density, BKG (nicht nötig, WorldCover bleibt); keine juristische Prüfung.

## Daten und Werkzeug

- Download: `https://esa-worldcover.s3.eu-central-1.amazonaws.com/v200/2021/map/ESA_WorldCover_10m_2021_v200_<Kachel>_Map.tif`, 3x3-Grad-Kacheln (36000 x 36000, uint8, EPSG:4326, Deflate, 1024er Kacheln, mit Overviews). Benötigt: N45..N54 x E003..E015 = 20 Kacheln, davon **19 vorhanden** (N54E003 liefert 404: reines Meer). Download gemessen ca. 1,5 GB (Plan schätzte 1,9 GB); Overviews wurden nicht genutzt, da Mittelung aus den 10-m-Pixeln genauer und lokal in 82 s machbar ist.
- Werkzeug `tools/forest_overlay.py` (Python 3, Abhängigkeiten numpy, tifffile, Pillow mit WebP; GDAL/cwebp nicht nötig). Es mittelt je Zielpixel den Anteil Klasse 10 (EPSG:3857, Radar-BBOX `612257.5,5942074,1736584,7381298`, 2048 x 2622 px, ca. 549 m; Plan nannte 2621, Rundung ergibt 2622), quantisiert den Alpha-Wert auf 4 Stufen und schreibt verlustfreies RGBA-WebP (Grün 34/120/52, Alpha = Anteil) plus Metadaten.
- Reproduktion (Rohdaten in ein Verzeichnis außerhalb des Repos, nie committen):

```
python3 -m venv VENV && VENV/bin/pip install numpy pillow tifffile
VENV/bin/python tools/forest_overlay.py download RAWDIR
VENV/bin/python tools/forest_overlay.py build RAWDIR Weather/Resources/Forest
```

- Ausgabe: `Weather/Resources/Forest/forest-de-v1.webp` (857 046 Byte) und `forest-de-v1.json` (Bounds, Größe, Alpha-Stufen 0/85/170/255, Quelle, DOI, Lizenz, Attribution, Veränderungshinweis, Erzeugungsdatum, Kachelliste).

## Größe (Abweichung vom Plan)

Volle Auflösung (256 Alpha-Stufen) ergibt 3,99 MB und sprengt das Ziel. Gemessen (verlustfrei): 16 Stufen 1,89 MB, 8 Stufen 1,39 MB, 5 Stufen 1,05 MB, **4 Stufen 0,86 MB (gewählt)**; verlustbehaftetes Alpha-WebP (alpha_quality 30 bis 100) 2,2 bis 4,8 MB, also schlechter. Die Karte zeigt damit Waldanteil in 4 Klassen (rund 0 / 1/3 / 2/3 / voll); für Orientierung ausreichend. Wunsch nach feinerer Abstufung bei ca. 1 MB nur durch gröbere Pixel (z. B. 1024 px breit) möglich.

## Prüfung (Waldanteil 0..100 %, Mittel über ca. 11 x 11 km, Quantisierung beachten)

Schwarzwald (48,0 N 8,2 E) 63, Bayerischer Wald (49,1 / 13,2) 95, Harz (51,75 / 10,6) 77, Thüringer Wald (50,65 / 10,9) 89, Pfälzerwald (49,3 / 7,9) 99; offen: Münsterland (52,0 / 7,6) 36, Nord (52,1 / 7,3) 21, West (51,95 / 7,2) 27, Köln-Zentrum (50,94 / 6,96) 33 bei 11 km Fenster, 8 bei 5 x 5 Pixeln; Ostsee 0. Sichtprüfung des Gesamtbilds (weiß hinterlegt): Mittelgebirge, Alpen, Thüringer Wald, Harz klar erkennbar, Meer leer. Nicht geprüft: Abgleich gegen eine zweite Quelle, Darstellung in der App (Einbindung ins Target ist Aufgabe P5).

## Hinweise für P5

- Dateien in `Weather/Resources/Forest/` per Xcode-Target einbinden; WebP wird von iOS nativ gelesen (Dekodiergröße 2048 x 2622 x 4 = 21,5 MB; als Bild-Overlay auf die BBOX legen, bei Bedarf ohne Interpolation/nearest).
- Deckkraft setzt die App (Alpha-Stufen sind bereits der Anteil).
- Quellzeile und Veränderungshinweis aus `forest-de-v1.json` übernehmen, nur bei eingeblendetem Wald.
