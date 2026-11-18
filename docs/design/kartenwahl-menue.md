# Kartenwahl: natives Menü mit Untermenüs (Skizze, Schritt 1)

Stand 17.11.2026. Nur Entwurf, noch nichts implementiert. Karte 0ED83DF9 in Todolino.

## Ist-Zustand (Code)

- `Weather/Views/RadarScreen.swift`, `layerMenu` (ca. Zeile 296): ein flaches `Menu` (Kapsel oben rechts: Symbol der aktiven Ebene, Titel, Chevron) mit einer `Section "Kartenebene"` (ein `Button` je Ebene, Häkchen statt Symbol bei aktiver Ebene, `.disabled` bei nicht verfügbar, Hinweis im Titel in Klammern) und einer zweiten Section mit "Daten neu laden".
- Ebenenmodell: `Weather/Data/RadarLayer.swift`, `enum RadarLayer` (radar, pressure, pressure_eu, lightning, clouds, cloudmask = "Sonne", temperature, dewpoint, humidity; Hilfsebene cloudmask_vis). `selectable` bestimmt die Reihenfolge; `symbolName`, `title`, `spokenName`, `frameCaption`, `overlayOpacity`, `pollInterval` hängen je Case daran. Genau eine Ebene aktiv (`store.activeLayer`), Wechsel über `store.layers.select(_:)`; Verfügbarkeit über `LayerAvailability` und `offeredLayers` (neuere Ebenen erscheinen erst, wenn das Backend sie meldet).
- `.radar` ist der DWD-Pfad (Cache-Backend mit DWD-Fallback), alle anderen Ebenen nur über `/v1/layers/<id>/`.
- Weitere Darstellungsoptionen: Wald-Overlay als `@AppStorage(ForestPreference.key)`, gesetzt im Legendenpanel (`Weather/Map/RadarLayerLegend.swift`), nicht im Kartenmenü. Warnungen: eigener Button. Eine Basiskarten-Wahl (Standard/Satellit) gibt es nicht.
- Beim Wechsel: `isPlaying = false`, Legende schließen, dann `select`. Tests: `RadarLayerTests`, `RadarLocalizationTests`; UI-Test-IDs `radar-layer-<rawValue>`, `radar-layer-menu`, `radar-refresh`.
- Neu nötig: `radar_eu` (OPERA, Europa) und später `radar_world` (NOAA RRQPE) als Cases; der Radar-Sonderpfad (`== .radar`) gilt nur für DWD, OPERA/Welt laufen als Backend-Ebenen ohne DWD-Fallback.

## Menüstruktur (Vorschlag)

Natives SwiftUI-`Menu`; Untermenüs per verschachteltem `Menu` (Chevron kommt vom System), Mehrfach-Schalter mit `.menuActionDismissBehavior(.disabled)`.

```
 Kapsel: [ Symbol aktive Ebene  Titel  v ]

 +--------------------------------------------+
 |  [cloud.rain] [cloud] [bolt] [thermometer] |  ControlGroup (Symbolreihe, Schnellwahl)
 +--------------------------------------------+
 |  Regenebenen                          >    |  Untermenü
 |     (o) cloud.rain  DWD, Deutschland       |
 |     ( ) globe.europe.africa  OPERA, Europa |
 |     ( ) globe  Welt (später), Hinweis      |
 |  Zusatzebenen                         >    |
 |     cloud       Wolken (Satellit)          |
 |     sun.max     Sonne                      |
 |     bolt.fill   Blitze                     |
 |     gauge.with.dots.needle.33percent Luftdruck (D / Europa)
 |     thermometer.medium Temperatur          |
 |     humidity    Feuchte (Taupunkt / relativ)
 |  Darstellung                          >    |
 |     tree  Wald anzeigen (Schalter)         |
 |  ----------------------------------------  |
 |  arrow.clockwise  Daten neu laden          |
 +--------------------------------------------+
```

ControlGroup-Reihe (4 Symbole, je ein Tipp = Ebene): Regen (aktuelle Regenebene), Wolken, Blitze, Temperatur. Rest über Untermenüs. Aktive Ebene: Häkchen/gefüllt statt Ersatz des Ebenensymbols.

Welt-Eintrag: Untertitel "aus Satellitendaten geschätzt, ungenauer"; erst anzeigen, wenn entschieden und das Backend `radar_world` meldet (`isOfferedWhenUnavailable = false` wie `pressureEU`).

## Symbole (SF Symbols)

| Eintrag | Symbol |
|---|---|
| Regen DWD | cloud.rain (vorhanden) |
| Regen OPERA Europa | globe.europe.africa |
| Regen Welt | globe |
| Wolken | cloud (vorhanden) |
| Sonne | sun.max |
| Blitze | bolt.fill |
| Luftdruck | gauge.with.dots.needle.33percent |
| Temperatur | thermometer.medium |
| Feuchte | humidity |
| Darstellung / Wald | paintpalette, tree |
| Neu laden | arrow.clockwise |

Die Kapsel zeigt weiter Symbol und Titel der aktiven Ebene.

## Verhalten bei Ebenenwechsel

- Wie heute: Wiedergabe stoppen, Legende schließen, `layers.select`. Wechsel zwischen Regenebenen (DWD/OPERA/Welt) behält die Position "Jetzt".
- Menü schließt nach Ebenenwahl; Schalter unter "Darstellung" schließen es nicht.
- Nicht verfügbare Ebenen: ausgegraut mit Hinweis (`LayerAvailability.hint`); neue, noch nicht gemeldete Ebenen ganz ausgeblendet (wie `pressureEU`).
- Quellzeile je Ebene (DWD, OPERA, NOAA) aus dem Manifest.

## Accessibility

- Jeder Eintrag behält `accessibilityLabel` = `spokenName` plus ", ausgewählt"; Untermenüs mit Label "Regenebenen, Untermenü".
- ControlGroup-Symbole brauchen eigene Labels und `accessibilityInputLabels` (Voice Control: Ebenennamen).
- `RADAR_LAYER_MENU_HINT` an die neue Struktur anpassen. Dynamic Type: Kapsel zeigt ab Accessibility-Größen nur das Symbol (bleibt).
- Identifier `radar-layer-<rawValue>` bleiben; neu `radar-layer-group-rain|extra|display`.

## Lokalisierung (de/en)

- Neue Schlüssel in beiden `.strings` (Parität): `LAYER_RADAR_EU_TITLE/SPOKEN`, später `LAYER_RADAR_WORLD_*` samt Hinweistext, `RADAR_MENU_GROUP_RAIN/EXTRA/DISPLAY`, `RADAR_MENU_FOREST`.
- `NSLocalizedString` mit Key und deutschem `value:`, keine deutschen Literale in `Text/Label` (sonst `hardcoded-ui`).
- Abnahme: `tools/check_l10n.sh --strict` mit Exit 0; `RadarLocalizationTests` und `RadarEnglishTests` erweitern.

## Aufwand

Gering bis mittel: Hauptänderung in `layerMenu`, neue Enum-Cases samt Switches (Titel, Symbol, Takt, Alter, Opazität, Caption), Backend-Pfad für `radar_eu`. Keine neue Persistenz nötig. Simulator-Screenshot des Ist-Zustands in Schritt 1 nicht erstellt (kein Build gelaufen).
