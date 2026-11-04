# App-Symbol-Auswahl (Build 18)

Stand: 4. November 2026. Auftrag des Nutzers: Das App-Symbol soll in der App frei zwischen allen bisherigen Vorschlägen einschließlich des alten gewählt werden können. d1, d3 und d4 (`eigenentwurf-dark`) sind bewusst nicht enthalten.

## Recherche (Primärquellen, abgerufen 4.11.2026)

| Befund | Quelle |
|---|---|
| `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` ("Alternate App Icon Sets"): zusätzliche App-Icon-Namen, die im Produkt enthalten sind und zur Laufzeit als Alternativen verfügbar sind; Alternative zu `--include-all-app-icons` (`ASSETCATALOG_COMPILER_INCLUDE_ALL_APPICON_ASSETS`) mit genauerer Kontrolle. Primäres Icon: `ASSETCATALOG_COMPILER_APPICON_NAME`. | [Build Settings Reference](https://developer.apple.com/documentation/xcode/build-settings-reference) (Abschnitt Asset Catalog Compiler) |
| `setAlternateIconName(_:completionHandler:)`: Name wie im Schlüssel `CFBundleAlternateIcons` der Info.plist; `nil` zeigt das primäre Icon (`CFBundlePrimaryIcon`). Wechsel nur, wenn `supportsAlternateIcons` wahr ist. Xcode erzeugt die `CFBundleIcons`-Einträge aus den Build-Settings. Handler läuft auf einer UIKit-Queue, nicht zwingend auf der Main-Queue; bei Fehler bleibt `alternateIconName` unverändert. In mit dem visionOS-SDK gebauten Apps ohne Wirkung. | [UIApplication.setAlternateIconName](https://developer.apple.com/documentation/uikit/uiapplication/setalternateiconname(_:completionhandler:)) |
| Eine Icon-Composer-Datei (`.icon`) im Projekt ersetzt den bisherigen Icon-Katalog; das System rendert Plattformen/Darstellungen/Größen daraus. Die Datei muss in den Bundle-Ressourcen liegen. | [Creating your app icon using Icon Composer](https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer) |

Nicht aus einer abgerufenen Primärseite belegt (Allgemeinwissen, im Simulator zu prüfen): Das System zeigt bei jedem Wechsel einen Alert ("Symbol geändert"), der sich mit öffentlicher API nicht unterdrücken lässt; watchOS bietet keine alternativen App-Symbole (Watch-App behält ihr primäres Icon). Letzteres folgt hier auch aus der Konfiguration: `ALTERNATE_APPICON_NAMES` ist nur im Target `Weather` gesetzt.

## Umsetzung

- 16 Alternativen als `.icon`-Pakete in `Weather/Resources/Icon/Alternates/` (Namen `Alt<ID>`: `AltKarte` = Build-15-Icon, `AltEigenentwurf` = `eigenentwurf-final`, `AltV2A`..`AltV5C`). Kopien der Entwurfspakete ohne Motiv- oder Formatänderung; v2/v3 enthalten teils Basis-`fill` neben Specializations, ihre Dark-Darstellung ist daher nur eingeschränkt (Leitfaden Abschnitt 8). Standard bleibt `AppIcon` (d2, Nachtradar).
- `project.yml`: Pakete als Ressourcen im Target `Weather`, `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` mit allen 16 Namen. Widgets, Watch-App und Watch-Widgets unverändert.
- `Weather/Icons/AppIconOption.swift` (Liste mit ID, deutschem/englischem Namen, Kurzbeschreibung, `alternateIconName`), `Weather/Icons/IconPickerView.swift` (Raster, Auswahlmarkierung, `supportsAlternateIcons`, Fehleranzeige), Einstieg über Abschnitt "App-Symbol" in `InformationSheet`. Die App-Oberfläche ist deutsch; englische Namen sind hinterlegt und werden bei englischer Systemsprache verwendet.
- Vorschauen: `Weather/Resources/IconPreviews.xcassets` (17 PNG, 160 px, mit `ictool` Default-Darstellung aus den Paketen gerendert, zusammen etwa 1 MB).
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
