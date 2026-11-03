# Faltbares iPhone (iPhone Duo): Kompatibilität für ShowerNow

Stand: 3.11.2026. Recherche ohne Repo-Änderung/Build. Kennzeichnung: **[belegt]** = Apple-Primärquelle, **[sekundär]** = nur Drittseiten, **[Annahme]** = Hypothese.

## 1. Gerät

- **Name: iPhone Duo** [belegt]. Vorgestellt 9.9.2026 ("Surprise and Shine", sekundär BGR/NPR), Vorbestellung 16.10., Verkauf 23.10.2026 (weitere Märkte 30.10.). Quelle: https://www.apple.com/uk/newsroom/2026/09/apple-unveils-iphone-duo/
- Betriebssystem: iOS 27, ausgeliefert mit **iOS 27.1** [belegt, gleiche Quelle].
- Displays [belegt]: Innen 7,6" (7,58" als Rechteck), Außen 5,4" (5,36"), beide Super Retina XDR, ProMotion, Always On. "Both displays share the same aspect ratio". Dynamic Island verläuft **vertikal** an der Seite beider Displays und erweitert sich für Live Activities.
- Faltmechanik [belegt]: Scharnier aus über 100 Teilen, Magnete zum Schließen; zugeklappt nutzbar über das Außendisplay, aufgeklappt Innendisplay. Unter-Display-Kamera innen [sekundär BGR].
- Pixelgrößen (aus App-Store-Connect-Screenshotspezifikation, belegt): Außen 1398 x 2034, Innen 2007 x 2853 (Hoch; Quer vertauscht). Seitenverhältnis ca. 0,687 (alle Displays gleich; passt rechnerisch). **Scale/Punktgröße nicht in Primärquelle gefunden**; [Annahme] 3x ergäbe ca. 466 x 678 pt bzw. 669 x 951 pt: im Simulator verifizieren.
- Neue Software auf Duo (iOS 27.1) [belegt]: Split View (erstmals iPhone, auch zwei Fenster derselben App), StandBy auf beiden Displays (neue Kalender-/Wetter-Faces), zwei Home-Screen-Seiten aufgeklappt mit Today View links.

## 2. Vorgaben für Entwickler

Hauptquelle: Apple Tech Talk "Prepare your app for iPhone Duo", https://developer.apple.com/videos/play/tech-talks/111461/ [belegt].

- **Xcode 27.1+** nötig; Simulator über **Device Hub**; Knöpfe zum Öffnen/Schließen/Drehen/Falten.
- **Simulator-Gerätetyp: `iPhone Duo`** (`com.apple.CoreSimulator.SimDeviceType.iPhone-Duo`), lokal in Xcode 27.2 (27B52) per `xcrun simctl list devicetypes` bestätigt. Lokal ist **noch kein Gerät dieses Typs angelegt** (`simctl list devices available` zeigt keines); Laufzeit iOS 27.2 vorhanden.
- **Größenklassen** [belegt]: Außendisplay wie normales iPhone (Hochformat compact x regular; Quer compact x compact). Innendisplay: **regular x regular**. Innendisplay ignoriert `supportedInterfaceOrientations`, also Layout nach Size Class statt Orientierung. SwiftUI `horizontalSizeClass`/`verticalSizeClass`.
- **Zuklappen/Aufklappen** ändert die Fenstergröße: App muss live umlayouten.
- **SDK-Verhalten** [belegt]: Alte SDK: App läuft, vertraute Größe/Seitenverhältnis (außen: Platz links von Statusleiste/Kamera). iOS-27-SDK: Inhalt reicht links neben Statusleiste. **iOS-27.1-SDK**: bis zum Bildschirmrand, Standard-Navigations-/Toolbar-Buttons werden vertikal unter der Statusleiste angeordnet.
- **Safe Area asymmetrisch**: nicht mit festen Werten, `safeAreaInsets` je Seite nutzen. `UIScreen.main` ersetzen (`traitCollection.displayScale`, `windowScene.screen`); zwei Displays.
- **Neue APIs (iOS 27.1)**: `ReservedRegion` (SwiftUI) / `UIViewReservedRegion` (UIKit) für eigene Leisten außerhalb der Safe Area. Konzentrische Ecken: `ConcentricRectangle` / `UICornerConfiguration`.
- **TabView**: Standard-Tabs auf beiden Displays; Sidebar auf Innendisplay per `.defaultTabBarPlacement(.sidebar)`. Sheets sind innen zentriert.
- **Info.plist**: `UIRequiresFullScreen` wird weiter beachtet, App wird beim Öffnen/Schließen trotzdem skaliert [belegt]. Weitere Schlüssel (Multitasking-Opt-in) in Primärquelle nicht genannt; **offen**. Split View: App ziehen, auf beiden Seiten testen [belegt].
- **Live Activities/Dynamic Island/Widgets**: Apple-Newsroom bestätigt vertikale Dynamic Island mit Live-Activity-Erweiterung und Widgets/Today View. Entwicklerdetails (Layouts, Limits) **nicht in Primärquelle gefunden**; Xcode-27.1-Release-Notes waren per Fetch leer. [sekundär, unverifiziert] Hinweis auf Bug: Dynamic-Island-Live-Activities falsch dimensioniert bei `EmptyView`-Konfiguration mit `isDynamicIslandLimitedInWidth` (iOS 27.x); selbst prüfen.
- Kamera-/Falt-APIs: keine Primärquelle gefunden; für ShowerNow irrelevant.

## 3. App Store Connect

Quelle: https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/ [belegt]

| Display | Hoch | Quer |
|---|---|---|
| Außen | 1398 x 2034 | 2034 x 1398 |
| Innen | 2007 x 2853 | 2853 x 2007 |

- Aktuell **optional**; **ab April 2027 Pflicht** für Apps mit iOS-27.1-SDK oder neuer. Mit Duo-Screenshots zeigt die Produktseite ein "Optimized for iPhone Duo"-Hinweis (Badge). PNG/JPEG ohne Alpha (sekundär).

## 4. Checkliste ShowerNow (SwiftUI, MapKit, Widgets, Live Activity, Watch)

1. Duo-Simulator (Gerät anlegen, iOS 27.2) starten; App in Außen/Innen, Auf-/Zuklappen, Drehen, Split View links/rechts prüfen (kein Zustandsverlust, Radar-Karte, Zeitleiste).
2. Layout nach Size Class: Innendisplay regular x regular (iPad-ähnlich, Sidebar/Zwei-Spalten erwägen); keine festen Breiten/`UIScreen.main`/Orientierungsannahmen (im Code suchen).
3. Mit iOS-27.1-SDK bauen: Navigationsleisten/Toolbars vertikal, Safe Area asymmetrisch; Overlays auf der Karte (Zeitleiste, Buttons, Attribution) gegen Safe Area/ReservedRegion prüfen.
4. MapKit: Kamera/Region bleibt beim Fold-Resize stabil; Kartenüberlagerungen und Rechtetext nicht abgeschnitten.
5. Live Activity: Kompakt/Minimal/Expanded in vertikaler Dynamic Island; Bug-Hinweis `isDynamicIslandLimitedInWidth` prüfen; Sperrbildschirm-Layout.
6. Widgets: Größen auf Außen-Home-Screen, Today View, StandBy-Wetter-Faces; Timelines laufen auch bei Größenwechsel.
7. `UIRequiresFullScreen` in `Configuration/Info.plist` prüfen: nicht setzen (wäre Skalierung; Multitasking/Split View soll möglich sein). Orientierungen auf Innendisplay wirkungslos.
8. Watch: unverändert (kein Duo-Bezug gefunden).
9. App Store: Screenshots Duo (außen + innen) spätestens bis April 2027 vorbereiten; optional früher für Badge.
10. Offen: Scale/Punktgrößen, Multitasking-Plist-Schlüssel, Widget-/Live-Activity-Regeln aus Apple-Dokumentation nachlesen (Release Notes Xcode/iOS 27.1 waren nicht abrufbar).

## 5. Lokale Prüfung (3.11.2026)

- Gerätetyp `iPhone Duo` (Modell `iPhone19,4`, `minRuntimeVersion` 27.1) ist in Xcode 27.2 vorhanden. `simctl create "ShowerNow Duo" ...iPhone-Duo ...iOS-27-2` scheiterte mit "Incompatible device": die Laufzeit iOS 27.2 (24B8117) enthielt den Duo nicht in `supportedDeviceTypes`. Später verschwand die iOS-27.2-Laufzeit ganz (nur 27.0 sichtbar). **Scale/Punktgröße: weiterhin nicht gemessen**; kein Duo-Gerät angelegt (keine UDID).
- Nicht geprüft: Außen/Innen, Falten, Quer, Dynamic Type, Split View, Live-Activity-Optik. Nächster Versuch, sobald eine Laufzeit ab 27.1 mit Duo-Unterstützung verfügbar ist (`simctl list runtimes -j`, `supportedDeviceTypes` auf `iPhone-Duo` prüfen).
- Statischer Befund: keine belegten Probleme (siehe docs/status.md).

## 6. Vorschläge für Build 16 (nicht angewendet, ungetestet)

1. `Weather/Views/RadarScreen.swift` (Overlay-VStack mit `header`, `forecastCard`, Buttonleiste, ca. Zeilen 83-123): Auf dem Innendisplay (regular x regular, ca. 7,6") würden Karte und Karten sich über die volle Breite strecken. Optional Breite begrenzen, z. B. `.frame(maxWidth: 560)` plus `.frame(maxWidth: .infinity, alignment: .leading)` am VStack, nur bei `horizontalSizeClass == .regular`. Erst nach Sichtprüfung entscheiden.
2. Ebenso `timeline` (`safeAreaInset`, ca. Zeile 121): optional Breitenbegrenzung bei regular.
3. Sheets (`presentationDetents([.medium,.large])` in RadarScreen.swift:632 und SitePageSheet.swift:85): auf dem Innendisplay zentriert; Layout der Inhalte sichten, kein Eingriff nötig belegt.
4. Live Activity (`WeatherWidgets/LiveActivity/RainLiveActivity.swift:44`, `frame(maxWidth: 48)`): in vertikaler Dynamic Island prüfen; Hinweis auf `isDynamicIslandLimitedInWidth`-Bug (sekundär).
5. `Configuration/Info.plist`: `UIRequiresFullScreen` nicht setzen (ist nicht gesetzt); Orientierungen bleiben.
