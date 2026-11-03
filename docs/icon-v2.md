# App-Icon v2 (Entwurf, nicht integriert)

Stand: 3. November 2026. Nutzerwunsch: neues Icon mit Icon Composer, weniger, aber kräftigere Farben, weniger Elemente, keine kleinen Elemente, Apple-Stil. Das produktive `Weather/Resources/Icon/AppIcon.icon` (Radar-Kartenmotiv, Entscheidung in `decisions.md`) ist unverändert; Übernahme erst nach Freigabe des Nutzers (Build 16).

## Analyse des aktuellen Icons
Vollflächige Karte mit Straßen, Fluss, Grünflächen, drei Blob-Regenflächen (zwei Größen) und kleinem Kern: etwa 8 Farben (Grün in zwei Tönen, Beige, Cyan, Weiß/Grau der Straßen, Blau, Grün, Gelb) und mehr als 15 Einzelformen. Dünne Straßen (12 bis 35 px, unter 3 %), der kleine zweite Regenfleck und der Kern verschwinden bei 60/29 px; Farben sind pastellig; ein einziger flacher Layer, daher keine Tiefe über Glas-Ebenen.

## Varianten (echte `.icon`-Pakete, Generator `design/Icon/v2/generate_v2.py`)
| Variante | Paket | Inhalt | Farben |
|---|---|---|---|
| v2a Radar (Marke bleibt) | `design/Icon/v2/v2a.icon` | drei konzentrische Scheiben | Blau, Grün, Gelb |
| v2b Wolke + Tropfen | `design/Icon/v2/v2b.icon` | weiße Wolke, ein gelber Tropfen (2 Glas-Ebenen) | Blau, Weiß, Gelb |
| v2c Tropfen (reduziert) | `design/Icon/v2/v2c.icon` | ein weißer Tropfen mit transparentem Ring | Blau, Weiß |

Kleinstes Element je Variante über 11 % der Icon-Höhe (Kern v2a 24 %, Tropfen v2b ca. 24 %). Keine Texte, keine Schatten-/Verlaufsspielerei; Tiefe nur über Apples Glas-Ebenen (`glass: true`, Specular, neutraler Schatten). Vorschauen: `design/Icon/v2/previews/` (Default, Dark, Tinted 1024 px; 60 und 29 px sowie 6-fach vergrößert).

## Empfehlung: v2b
Liest sich sofort als Regen, auch bei 29 pt (Wolke klar, Tropfen als gelber Punkt erkennbar); drei Farben mit starkem Kontrast; zwei große Formen auf getrennten Ebenen, wie von Apple empfohlen. v2a behält das Radarmotiv und ist robust, wirkt bei 29 pt aber wie ein Zielscheiben-/Aufnahme-Symbol und sagt "Regen" weniger direkt. v2c ist am ruhigsten, aber generisch (Wassertropfen), und sein Dark-Rendering ist unbrauchbar (siehe unten).

## Befunde aus den Renderings
- Dark: Das System ordnet Farben automatisch um; `fill-specializations` im Hintergrund wurden von `ictool` nicht sichtbar angewendet (Dark-Hintergrund ist neutral schwarz). v2b Dark: Wolke wird blau, Tropfen bleibt gelb (gut lesbar). v2a Dark: Außenring wird grau, sonst gut. v2c Dark: Tropfen wird ebenfalls blau und verschwindet im Ring (nicht verwendbar ohne Layer-Fill für Dark).
- Tinted: monochrom aus Luminanz; v2b bleibt lesbar (Wolke hell, Tropfen gedämpft).
- Wie im früheren Befund (`icon.md`) wurden mehrere separate SVG-Layer in einem Dokument zuvor unvollständig gerendert (v2a-Kern fehlte bei drei Layern); v2a ist daher ein Layer. v2b (zwei Layer) wurde mehrfach vollständig und byteidentisch gerendert.

## Übernahme (nach Freigabe)
1. `Weather/Resources/Icon/AppIcon.icon` durch `design/Icon/v2/v2b.icon` ersetzen (Ordnername `AppIcon.icon` beibehalten). `project.yml` verweist bereits auf den Pfad; `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon` gilt für App (Zeile 36) und Watch-App (Zeile 94) und bleibt gleich, die Watch nutzt dasselbe Paket (`supported-platforms` enthält `circles: watchOS`).
2. Buildnummer 16, `xcodegen generate`, Build durch den Build-Agent, Archiv-Validierung (Watch-Icon war bei Build 15 der Blocker).
3. `decisions.md` ergänzen (Nutzerwahl), `icon.md` und README-Verweis aktualisieren.

## Quellen
- Apple, WWDC25 Session 361 "Create icons with Icon Composer" (developer.apple.com/videos/play/wwdc2025/361): sechs Darstellungen (Default, Dark, Clear hell/dunkel, Tinted hell/dunkel), Ebenen nach Farbe/Element trennen, Glas, Fill/Opacity pro Variante; abgerufen 3.11.2026 über Websuche (Zusammenfassung, nicht Volltext).
- Apple, "Adopting Liquid Glass" (developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass): System ergänzt Reflexion, Schatten, Highlights; volle, einfache Formen mit Ebenen.
- Create with Swift, "Crafting Liquid Glass app icons with Icon Composer" (Zweitquelle).
- Nicht im Volltext geprüft: aktuelle HIG-Seite "App icons" (Raster-/Sicherheitsabstände); Abstände hier nach Augenmaß: Motiv innerhalb etwa 8 % bis 92 % des 1024er-Canvas.

## Geprüft / nicht geprüft
Geprüft: `ictool` 27.1 rendert alle drei Pakete in Default, Dark, TintedDark (1024 px) und 60/29 px; Vorschauen angesehen; Default-Wiederholung byteidentisch; `actool` kompiliert das aktuelle Paket (Referenz). **Nicht geprüft:** Icon-Composer-GUI-Ansicht, Clear-Darstellungen, `actool`-Kompilierung der v2-Pakete im Gesamtbuild, Anzeige auf Gerät/Watch, Watch-Rundmaske, handgestaltete Dark-/Tinted-Layerfarben, Kontrast-Messung.
