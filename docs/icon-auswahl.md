# App-Symbol-Auswahl (entfernt am 6.11.2026)

**Entfernt (6.11.2026, Nutzerentscheidung):** Das neue Icon (`AppIcon.icon`, V4B Sektor 90° mit Verlauf) gilt endgültig überall. Alle Alternativ-Icons (`Weather/Resources/Icon/Alternates/`), `IconPreviews.xcassets`, `AppIconOption`, `IconPickerView`, der Abschnitt "App-Symbol" im Info-Sheet, `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES`, `tools/check-icon-options.sh`, `AppIconOptionTests` und die UI-Tests `testIconPickerListsAllOptions`/`testSwitchingAppIconAndBack` sind gelöscht. Design-Quellen unter `design/Icon` bleiben. Wiederherstellung per Git: Stand vor dem Entfernungs-Commit (Build 20, Commit `9ca5176`), z. B. `git checkout 9ca5176 -- Weather/Icons Weather/Resources/Icon/Alternates`. Der Rest dieser Datei ist historisch.

# App-Symbol-Auswahl (Build 18, erweitert in Build 19)

Stand: 4. November 2026. Auftrag des Nutzers: Das App-Symbol soll in der App frei zwischen allen bisherigen Vorschlägen einschließlich des alten gewählt werden können. d1, d3 und d4 (`eigenentwurf-dark`) sind bewusst nicht enthalten.

## Recherche (Primärquellen, abgerufen 4.11.2026)

| Befund | Quelle |
|---|---|
| `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` ("Alternate App Icon Sets"): zusätzliche App-Icon-Namen, die im Produkt enthalten sind und zur Laufzeit als Alternativen verfügbar sind; Alternative zu `--include-all-app-icons` (`ASSETCATALOG_COMPILER_INCLUDE_ALL_APPICON_ASSETS`) mit genauerer Kontrolle. Primäres Icon: `ASSETCATALOG_COMPILER_APPICON_NAME`. | [Build Settings Reference](https://developer.apple.com/documentation/xcode/build-settings-reference) (Abschnitt Asset Catalog Compiler) |
| `setAlternateIconName(_:completionHandler:)`: Name wie im Schlüssel `CFBundleAlternateIcons` der Info.plist; `nil` zeigt das primäre Icon (`CFBundlePrimaryIcon`). Wechsel nur, wenn `supportsAlternateIcons` wahr ist. Xcode erzeugt die `CFBundleIcons`-Einträge aus den Build-Settings. Handler läuft auf einer UIKit-Queue, nicht zwingend auf der Main-Queue; bei Fehler bleibt `alternateIconName` unverändert. In mit dem visionOS-SDK gebauten Apps ohne Wirkung. | [UIApplication.setAlternateIconName](https://developer.apple.com/documentation/uikit/uiapplication/setalternateiconname(_:completionhandler:)) |
| Eine Icon-Composer-Datei (`.icon`) im Projekt ersetzt den bisherigen Icon-Katalog; das System rendert Plattformen/Darstellungen/Größen daraus. Die Datei muss in den Bundle-Ressourcen liegen. | [Creating your app icon using Icon Composer](https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer) |

Nicht aus einer abgerufenen Primärseite belegt (Allgemeinwissen, im Simulator zu prüfen): Das System zeigt bei jedem Wechsel einen Alert ("Symbol geändert"), der sich mit öffentlicher API nicht unterdrücken lässt; watchOS bietet keine alternativen App-Symbole (Watch-App behält ihr primäres Icon). Letzteres folgt hier auch aus der Konfiguration: `ALTERNATE_APPICON_NAMES` ist nur im Target `Weather` gesetzt.

## Umsetzung

- 19 Alternativen (Build 18: 16, Build 19: V4B ersetzt, drei V4B-Varianten neu; siehe Abschnitt "V4B-Varianten") als `.icon`-Pakete in `Weather/Resources/Icon/Alternates/` (Namen `Alt<ID>`: `AltKarte` = Build-15-Icon, `AltEigenentwurf` = `eigenentwurf-final`, `AltV2A`..`AltV5C`). Kopien der Entwurfspakete ohne Motiv- oder Formatänderung; v2/v3 enthalten teils Basis-`fill` neben Specializations, ihre Dark-Darstellung ist daher nur eingeschränkt (Leitfaden Abschnitt 8). Standard bleibt `AppIcon` (d2, Nachtradar).
- `project.yml`: Pakete als Ressourcen im Target `Weather`, `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` mit allen 19 Namen. Widgets, Watch-App und Watch-Widgets unverändert.
- `Weather/Icons/AppIconOption.swift` (Liste mit ID, deutschem/englischem Namen, Kurzbeschreibung, `alternateIconName`), `Weather/Icons/IconPickerView.swift` (Raster, Auswahlmarkierung, `supportsAlternateIcons`, Fehleranzeige), Einstieg über Abschnitt "App-Symbol" in `InformationSheet`. Die App-Oberfläche ist deutsch; englische Namen sind hinterlegt und werden bei englischer Systemsprache verwendet.
- Vorschauen: `Weather/Resources/IconPreviews.xcassets` (20 PNG, 160 px, mit `ictool` Default-Darstellung aus den Paketen gerendert, zusammen etwa 1 MB).
- Konsistenzprüfung: `tools/check-icon-options.sh` (Optionsliste, `project.yml`, Paketordner, Vorschaukatalog).
- Hinweis in der Oberfläche: Systemhinweis bei jedem Wechsel; Apple Watch behält das Standard-Symbol; Widgets nicht betroffen.

Die Prüfergebnisse stehen am Ende dieser Datei (Abschnitt "Prüfungen").

## Prüfungen (4.11.2026, Xcode 27.1 per `DEVELOPER_DIR`, iPhone-Simulator iOS 27.0)

- `xcodegen generate`, `tools/check-icon-options.sh` ("OK: 16 Alternativen konsistent"), Schema `Weather` Simulator-Build ohne Signing: erfolgreich; `WeatherWatch` (watchOS-Simulator) erfolgreich.
- actool-Ergebnis im gebauten `Weather.app`: `Info.plist` enthält unter `CFBundleIcons` und `CFBundleIcons~ipad` je 16 `CFBundleAlternateIcons`-Einträge (`CFBundleIconName` = `AltEigenentwurf`, `AltKarte`, `AltV2A`..`AltV5C`), primär `AppIcon`; `Assets.car` enthält Renditions aller 16 Alternativen (981 Einträge mit Präfix `Alt`, u. a. `AltV4D_Assets/...`). Alternative Icons liegen also im Asset-Katalog, nicht als lose Dateien.
- Tests: 416 Unit (410 bisherige + 6 `AppIconOptionTests`), 0 Fehler. UI: 9 Tests; im Volllauf schlug nur das bekannte flaky `testTimelineAtMaximumDynamicTypeKeepsControlsSeparate` fehl (einzeln wiederholt grün); `testIconPickerListsAllOptions` (alle 17 Optionen erreichbar, Standard ausgewählt, Hinweis) und `testSwitchingAppIconAndBack` grün. Der Volllauf lief vor dem Hinzufügen von `testSwitchingAppIconAndBack`; dieser Test lief danach einzeln grün.
- Wechsel im Simulator tatsächlich ausgeführt (UI-Test): Auswahl von "Tropfen-Pin" (V4D) löst den Systemhinweis "Du hast das Symbol für „Showers“ geändert." mit OK aus; nach Bestätigung ist die Option markiert, und der Home-Screen zeigt das neue Symbol (Screenshot nach Home); Zurückwechseln auf "Nachtradar" zeigt wieder das Radar-Symbol. Der Alert ist im Accessibility-Baum nicht zuverlässig erreichbar; der Test bestätigt ihn über SpringBoard-Button oder, als Rückfall, per Koordinate (simulatorspezifisch).
- Nicht geprüft: Gerät (iPhone/iPad Hardware), Dark/Tinted-Darstellung der Alternativen auf dem Home-Screen, Alert-Verhalten und Texte auf Geräten, iPad-Layout, Watch (hier nur: Watch-Target hat keine Alternativen), englische Oberfläche (die App-UI ist nur deutsch).

## Paketgröße und Upload (Build 18)

IPA-Größe lokal exportiert: Build 17 8.409.378 Byte, Build 18 87.749.697 Byte (+79,3 MB), da `Assets.car` alle Renditionen der 16 Alternativen enthält (je etwa 4,5 bis 6,8 MB). Build 18 ist hochgeladen (siehe [testflight-upload.md](testflight-upload.md)). Mögliche spätere Verkleinerung: weniger Alternativen, Pakete mit weniger Ebenen/Darstellungen. Nicht gemessen: Downloadgröße nach App Thinning.

## V4B-Varianten (Build 19, 4.11.2026)

Befund: Die im Repo eingecheckte `design/Icon/v4/v4b.icon` (und damit `AltV4B` in Build 18) war die vom Nutzer geänderte Fassung (Hintergrund `extended-gray:0.25`, große gelbe Wolke oben rechts, grüner Sektor). Das Original (leuchtend blauer Verlauf, weißer Punkt, drei Ringe, halbtransparenter weißer Sektor mit drei Segmenten, kleine gelbe Wolke) wurde mit `design/Icon/v4/generate_v4.py b` neu erzeugt und per `ictool` gegen `design/Icon/v4/previews/v4b-default.png`/`v4b-dark.png` geprüft: mittlere Abweichung etwa 0,2 von 255 je Kanal, nur 0,1 % der Pixel (Kantenglättung) über 2/255, Sichtvergleich identisch.

| Paket (design/Icon/v4) | App-Eintrag (`Alt...`) | Anzeigename | Inhalt |
|---|---|---|---|
| `v4b-original.icon` | `AltV4B` | Radar und Wolke | Original, unverändert |
| `v4b-eigen.icon` | `AltV4BEigen` | Radar und Wolke (eigene Fassung) | Nutzerfassung, byteidentisch gesichert |
| `v4b-sektor90.icon` | `AltV4BS90` | Radar und Wolke, Sektor 90° | Original, Sektor 0° bis 90° |
| `v4b-sektor90-uebergang.icon` | `AltV4BS90V` | Radar und Wolke, Sektor 90° mit Verlauf | wie Sektor 90°, Sektorfüllung mit Verlauf der Nutzerfassung |

Erzeugt mit `design/Icon/v4/make_sektor90.py`; Vorschauen (Default/Dark/Tinted 1024, 60 px) und Tafel `vergleich.png` in `design/Icon/v4/previews-v4b/` (`render.sh`).

**Verlauf der Nutzerfassung** (`v4b-eigen.icon/icon.json`, Ebene `Sweep 1`, `sw1.svg`, Blend `normal`, Ebenen-Deckkraft 1): Default-Fill `linear-gradient` von `display-p3:0.44053,0.82207,0.44527` mit Alpha 0,30 nach `extended-srgb:0.204,0.780,0.349` mit Alpha 1,0 (beides Grün), `orientation` start (0,0) nach stop (1, 0,814), also schräg von oben links nach unten rechts (etwa 39° unter der Waagerechten, y nach unten, Einheitsquadrat). Der Blau-Grün-Übergang entsteht, weil das halbtransparente Grün über dem blauen Hintergrund liegt: zur Mitte hin (transparent) scheint das Blau durch, nach außen wird es deckend grün. Dark: keine Verlaufsfüllung, `solid srgb:0.749,0.816,1.0` (Hellblau); Tinted: `extended-gray:0.65`. Die Nutzerfassung hat nur einen Sektor (kein Dreisegment).

**Sektor 0° bis 90°:** Winkelkonvention der SVGs (`pt()` in `generate_v4.py`): Kompasswinkel, 0° = oben (12 Uhr), im Uhrzeigersinn, Mittelpunkt (512, 512) = weißer Punkt, Radius 372. Original: `sw1` -8° bis 80°, `sw2` 30° bis 80°, `sw3` 60° bis 80°. Neu: `sw1` 0° bis 90°, `sw2` 40° bis 90°, `sw3` 70° bis 90° (Segmentgrenzen proportional, Viertelkreis von 12 bis 3 Uhr). Wolke, Ringe, Punkt und Farben bleiben wie im Original; die Wolke (Zentrum 648/352) deckt etwa die Mitte des Viertelkreises teilweise ab, der Keil bleibt an Bogen, Kanten und unten sichtbar, daher nicht versetzt. `v4b-sektor90`: Segmentdeckkraft wie im Original (0,18/0,30/0,50).

**Sektor 90° mit Verlauf:** Fill aller drei Sektor-Ebenen = Verlauf der Nutzerfassung (Default: Grün, Alpha 0,30 nach 1,0; Dark: Hellblau `0.749,0.816,1.0` Alpha 0,30 nach 1,0, nur über `fill-specializations`; Tinted unverändert grau). Verlaufsrichtung wie in der Nutzerfassung (etwa 39°), aber auf die Bounding-Box des Viertelkreises skaliert (start/stop im Einheitsquadrat, siehe Skript), damit der Verlauf im kleinen Sektor sichtbar bleibt; Ebenen-Deckkraft 0,75/0,45/0,45 (Original 0,18/0,30/0,50), sonst wäre das Grün zu blass.

### Prüfungen Build 19 (4.11.2026, Xcode 27.1, iPhone-18-Pro-Simulator, Kopie unter /private/tmp, ohne Signing)

- `xcodegen generate`, `tools/check-icon-options.sh`: "OK: 19 Alternativen konsistent".
- Tests: 416 Unit, 0 Fehler. UI im Volllauf: 9 Tests, 1 Fehler in `testSwitchingAppIconAndBack` (Testfehler beim Wechsel auf V4D, dessen Zeile durch die neuen Optionen weiter unten liegt; Koordinaten-Rückfall für den Systemhinweis). Test auf die neue Option `V4BS90V` umgestellt und einzeln wiederholt: grün; `testIconPickerListsAllOptions` (jetzt 20 Optionen) im Volllauf grün; das flaky `testTimelineAtMaximumDynamicTypeKeepsControlsSeparate` trat nicht auf. Ein erneuter Volllauf nach der Testanpassung wurde nicht ausgeführt.
- Wechsel im Simulator: Auswahl "Radar und Wolke, Sektor 90° mit Verlauf" bestätigt den Systemhinweis; Home-Screen-Screenshot zeigt das Radar mit Viertelkreis-Sektor und Grün-Verlauf; Rückwechsel auf Standard ausgeführt.
- Gebautes `Weather.app`: je 19 `CFBundleAlternateIcons` in `CFBundleIcons` und `CFBundleIcons~ipad` (enthält `AltV4B`, `AltV4BEigen`, `AltV4BS90`, `AltV4BS90V`), `CFBundleVersion` 19.
- Nicht geprüft: Gerät, Dark/Tinted der neuen Alternativen auf dem Home-Screen (nur per `ictool` gerendert, siehe `vergleich.png`).

Build 19 hochgeladen (siehe [testflight-upload.md](testflight-upload.md)); IPA 107.082.362 Byte (Build 18: 87.749.697).

## Neues Standard-Symbol (6.11.2026)

- Standard (`AppIcon`) ist jetzt die Nutzerfassung `design/Icon/v4/v4b-sektor90-uebergang Kopie.icon` (V4B Sektor 90° mit Verlauf, überarbeitet; 6 Assets). Das bisherige Standard-Symbol (d2, "Nachtradar") bleibt als Alternative `AltNachtradar`; alle übrigen Alternativen unverändert (jetzt 20).
- Die Watch-App nutzt weiter `AppIcon.icon` und zeigt damit ebenfalls das neue Symbol.
- Geprüft: `xcodegen generate`, `tools/check-icon-options.sh` (20 konsistent), `AppIconOptionTests` (6, 0 Fehler). Build 20 (`3cf089f`): Volllauf 416 Unit und 9 UI-Tests, 0 Fehler; archiviert und hochgeladen 6.11.2026 (IPA 114.203.666 Byte, 20 Alternativen im Paket, siehe [testflight-upload.md](testflight-upload.md)). Nicht geprüft: Gerät, Dark/Tinted des neuen Standards auf Hardware.
