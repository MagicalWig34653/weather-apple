# Eigenentwurf des Nutzers (Icon Composer), 3.11.2026

Paket des Nutzers: `design/Icon/eigenentwurf.icon` (unverändert, Handarbeit). Ergänzte Kopie: `design/Icon/eigenentwurf-final.icon`. Vorschauen: `design/Icon/eigenentwurf/previews/{original,final}/`, Render-Skript `design/Icon/eigenentwurf/render.sh` (ictool). Galerie: `design/Icon/overview/` (neue Zeile "Eigenentwurf").

## Befund (Original)

Motiv: Regenradar als vier konzentrische Konturen: Front (Blau, links grauer Hintergrund sichtbar), Band (Grün), gelbe Zone, roter Kern. Drei Gruppen, vier Ebenen (Kern und gelbe Zone nutzen dieselbe SVG, `01-rain-core.svg`, in Scale 0.95 bzw. 1.94). Glas an, Specular an.

- Standard: stark und lesbar, klare Radarfarben, Staffelung gut. Bei 29 px bleibt die Form als bunter Fleck mit rotem Punkt lesbar; Detailkonturen verschwinden.
- Dark: Hintergrund Dunkelblau (vom Nutzer) gut. Gelbe Zone UND roter Kern waren beide reinweiß: Kern und Zone verschmolzen, es blieb ein Weißfleck (Staffelung verloren, nur feine Glaskante).
- Tinted: Kern und gelbe Zone beide Weiß 1.0, ebenfalls verschmolzen; Hintergrund hatte keinen Tinted-Wert (System-Ableitung, fast Schwarz/Grau, funktioniert, aber nicht gesteuert).
- Formatregel (Dark nur per Specializations): erfüllt, kein Basis-fill. Artboard-rect in den SVGs: keines (reine `path`), Glas-Glanz funktioniert.

## Änderungen (nur `eigenentwurf-final.icon/icon.json`)

Motiv, Form, Position, Größe, Standardfarben, Glas-Parameter unverändert.

| Stelle | Dark | Tinted |
|---|---|---|
| Hintergrund | unverändert (srgb 0.106/0.188/0.294 nach 0.063/0.118/0.204) | NEU: Verlauf extended-gray 0.14 nach 0.08 |
| gelbe Zone (Ebene 2 in Gruppe 1) | NEU: srgb 1.000/0.843/0.400 (Amber, vorher Weiß) | NEU: extended-gray 0.86 (vorher 1.0) |
| roter Kern | unverändert Weiß 1.0 | unverändert Weiß 1.0 (nahezu weiß, hellste Ebene) |
| Band | unverändert (Mint 0.490/0.957/0.737) | unverändert (Grau 0.769) |
| Front | unverändert (Cyan 0.318/0.827/0.890) | unverändert (Grau 0.522) |

Warum: Amber trennt die gelbe Zone vom weißen Kern und bleibt farblich zur Standardansicht (Gelb) konsistent. Tinted: Kern 1.0, Zone 0.86, Band 0.77, Front 0.52, Hintergrund 0.14/0.08 gibt eine monotone Staffelung von innen nach außen und tiefen Hintergrund.

## Prüfungen (3.11.2026)

- Geprüft: ictool-Renders Standard 1024/120/60/29, Dark, Tinted-Dark, Tinted-Light (alle Bilder angesehen; Dark: Staffelung Weiß/Amber/Mint/Cyan/Nachtblau, Tinted: vier Stufen sichtbar). `actool` (iphoneos und watchos, Min-Target 26.0) kompiliert; im iOS-Katalog Light, Dark und Tintable-Renditions je Gruppe; watchOS-Katalog nur Light (Standard bei watchOS erwartungsgemäß).
- Schema: `supported-platforms` identisch zum produktiven `AppIcon.icon` (circles watchOS, squares shared); Position-Angaben (scale, translation-in-points) sind Icon-Composer-Standard.
- NICHT geprüft: Darstellung auf Gerät/Simulator, Xcode-Build des gesamten Projekts, App-Store-Validierung, Tinted mit anderen Tintfarben als 0.58/0.8 (außer Tinted-Light), visionOS/macOS.

## Übernahme in Build 16

`design/Icon/eigenentwurf-final.icon` nach `Weather/Resources/Icon/AppIcon.icon` kopieren (Ordner ersetzen; Name `AppIcon.icon` behalten) und neu bauen. Das Paket bringt `supported-platforms` (watchOS-Kreis) bereits mit. Empfehlung: übernehmen, danach Simulator-Screenshot Home (hell/dunkel/getönt) und Watch prüfen.

## Dark-Varianten d1-d4 (3.11.2026, Nutzerwunsch: Dark-Farben anpassen)

Anlass: Dark "final" wirkt wie ein Spiegelei (weißer Kern im Amber-Ring), Mint/Cyan sind pastellig-hell (kaum "dunkel"), alle Ebenen gleich hell (kein Fokus). Pakete `design/Icon/eigenentwurf-dark/d1..d4.icon` (Kopien von `eigenentwurf-final.icon`, nur Dark-Werte der vier Ebenen geändert; Hintergrund, Default, Tinted, Motiv, Glas unverändert; Hintergrund Dark bleibt srgb 0.106/0.188/0.294 nach 0.063/0.118/0.204). Erzeugung `build.py`, Render `render.sh` (Dark 1024/120/60/29), Tafel `make_vergleich.py` -> `previews/vergleich.png`.

| Ebene (srgb Dark) | d1 gedämpft | d2 Nachtradar | d3 mono+Akzent | d4 Standard x0,7 |
|---|---|---|---|---|
| Kern | 0.88/0.32/0.16 | 1.00/0.36/0.12 | 1.00/0.72/0.20 | 0.643/0.148/0.069 |
| gelbe Zone | 0.63/0.60/0.249 | 0.66/0.48/0.16 | 0.52/0.70/0.94 | 0.65/0.612/0.176 |
| Band | 0.298/0.57/0.321 | 0.10/0.50/0.50 | 0.27/0.47/0.76 | 0.263/0.601/0.291 |
| Front | 0.221/0.435/0.584 | 0.07/0.30/0.37 | 0.16/0.30/0.52 | 0.162/0.428/0.615 |

d1: Standardtöne um 22 % entsättigt, x0,72. d4: weißer Kern nur als Punkt nicht möglich ohne neue Ebene (Kern und gelbe Zone teilen eine SVG, Motiv bleibt unverändert), daher Kern farbig.

Bewertung (ictool-Renders angesehen, Tafel): d1 stimmig mit Standard, aber matschig, Kern nur mäßig abgesetzt. d2 klarster Fokus (leuchtender Orange-Kern als einziger heller Punkt), echter Nachtcharakter, Front-zu-Hintergrund-Kontrast niedrig aber sichtbar; Farbwelt weicht vom Standard (Blau/Grün) ab, bleibt aber Radar-Logik (kalt außen, warm innen). d3 sehr ruhig, Kern klar, aber gelbe Zone hellblau, leichte Spiegelei-Anmutung (hell um orange) und am weitesten vom Standard. d4 treu zum Standard, Kern dunkelrot und damit kein Fokus, bei 29 px matt. Alle vier: kein Weiß-Fleck mehr; bei 60/29 px bleibt Kern als Punkt lesbar (d2/d3 am deutlichsten).

Empfehlung: d2. Übernahme: Dark-Werte aus `d2.icon/icon.json` in `eigenentwurf-final.icon` bzw. d2 statt final kopieren.

Geprüft: `actool` (iphoneos, Min 26.0) kompiliert d2, Assets.car enthält UIAppearanceLight/Dark und ISAppearanceTintable. NICHT geprüft: Gerät/Simulator, pixelgenaue Dark-Rendition aus Assets.car, Tinted-Wirkung nicht geändert (identisch zu final), Galerie `overview/` nicht erweitert, d1/d3/d4 nicht mit actool kompiliert.

## Entscheidung und Übernahme (3.11.2026)

Nutzer: "nimm erstmal d2". `d2.icon` ersetzt den Inhalt von `Weather/Resources/Icon/AppIcon.icon` (Build 16); altes Icon nach `design/Icon/archiv/AppIcon-build15.icon`. Struktur und `supported-platforms` (circles watchOS, squares shared) identisch zum Vorgänger. Geprüft: `actool` für iphoneos und watchos kompiliert (Assets.car mit UIAppearanceLight/Dark und ISAppearanceTintable); ictool-Renders Default/Dark/TintedDark angesehen, plausibel. NICHT geprüft: xcodebuild-Gesamtbuild, Gerät/Simulator/Watch, Clear, Icon-Composer-GUI.
