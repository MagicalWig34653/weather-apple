# Showers: niedrigste unterstützbare OS-Version

Stand 17.11.2026, Xcode 27.2 (SDK iOS/watchOS 27.2). Nur Recherche, nichts am Projekt geändert.

## Methode

Neben der Code-Suche (grep nach `@available`, Frameworks, SwiftUI-APIs) wurde das ganze Schema `Weather`
(App, Widgets, Live Activity, Notification Service, Watch-App, Watch-Widgets) mehrmals für den Simulator
gebaut, jeweils mit per Kommandozeile abgesenktem Deployment-Target und `-IDEBuildingContinueBuildingAfterErrors=YES`.
DerivedData lag im Scratchpad, das Repo blieb unverändert. Der Compiler meldet dabei jede API über dem Ziel
mit "only available in iOS X". Das ist verlässlicher als grep.

| Lauf | Ergebnis |
|---|---|
| iOS 16.0 / watchOS 9.0 | 258 Fehler (iOS 16.1 bis 26.0, watchOS 10.0) |
| iOS 17.0 / watchOS 10.0 | nur Ziel `Weather` rot (iOS 17.2, 18.0, 26.0); Widgets, NSE, Watch und Watch-Widgets grün |
| iOS 18.0 / watchOS 10.0 | nur 32 Fehler, alle iOS 26.0 (Glas, FoundationModels, MKMapItem) |
| iOS 26.0 / watchOS 10.0 | **BUILD SUCCEEDED** |

Testziele wurden nicht mitgebaut. `WeatherTests` nutzt XCTest und an einer Stelle swift-testing
(`WeatherTests/ModelLayerSourcesTests.swift`). Das betrifft nur die Tests und hängt nicht vom Ziel-OS ab.

## 1. Heutige Deployment-Targets

| Ort | iOS | watchOS |
|---|---|---|
| `project.yml:4-6` (options.deploymentTarget, gilt für alle Ziele) | 27.0 | 27.0 |
| `Configuration/Base.xcconfig:6,9` | 27.0 | 27.0 |

Kein Ziel setzt einen eigenen Wert. Es gibt kein macOS- und kein visionOS-Ziel. Die Geräteklassen sind iPhone und iPad (`1,2`).
Die Swift-Sprachversion ist 6.0. Es gibt **keine einzige** `@available`- oder `#available`-Weiche im Code.
Keine Funktion der App braucht wirklich iOS 27 oder watchOS 27.

## 2. Features, Mindestversion, Fundstelle, Ersatz

### iOS: was über iOS 18 hinausgeht (blockiert 18.x)

| Feature | Min. | Fundstelle | Ersatz und Aufwand |
|---|---|---|---|
| Liquid Glass `glassEffect` | 26.0 | `Weather/Views/RadarScreen.swift:84,91,99,116,132,460,501,815`, `Weather/Views/TimelineScrub.swift:188`, `Weather/Map/RadarLegend.swift:75`, `Weather/Map/RadarLayerLegend.swift:264` | Ein Hilfs-Modifier `glassOrMaterial(in:)` mit `#available(iOS 26)`, sonst `.background(.regularMaterial, in: shape)`. Etwa 1,5 h. |
| `GlassEffectContainer`, `glassEffectID` (Morphing der Legende) | 26.0 | `RadarScreen.swift:139,152,607` | Ein Wrapper, der unter iOS 26 ohne Container läuft (kein Morph). Etwa 1 h plus Sichtprüfung. |
| FoundationModels (lokale Einordnung: `SystemLanguageModel`, `LanguageModelSession`, `@Generable`) | 26.0 | `Weather/Intelligence/ForecastInterpretation.swift:5,21,23,140-143,167-169` | Typen mit `@available(iOS 26, *)` markieren. Die Sektion `ForecastInterpretationSection` unter iOS 26 ausblenden oder den Text "nicht verfügbar" zeigen. Etwa 1-2 h. |
| `MKMapItem.location` / `.address` (Ortssuche) | 26.0 | `Weather/Views/PlacesSheet.swift:83,90` | Unter iOS 26 `item.placemark.coordinate` und `placemark.title` nutzen. Diese APIs sind ab 26 veraltet, daher ist eine Weiche nötig. Etwa 0,5 h. |

### iOS: was über iOS 17 hinausgeht (blockiert 17.x)

| Feature | Min. | Fundstelle | Ersatz und Aufwand |
|---|---|---|---|
| Zoom-Übergang der Sheets `navigationTransition(.zoom)` und `matchedTransitionSource` | 18.0 | `RadarScreen.swift:204,206,207,810` | `#available`, sonst normales Sheet ohne Zoom. Etwa 0,5 h. |
| `Color.mix(with:by:)` (Scrub-Glühen) | 18.0 | `Weather/Views/ScreenGlow.swift:62` | Eigene RGB-Interpolation oder feste Farben. Etwa 0,5 h. |
| Live Activity per Push starten (`pushToStartToken`, `pushToStartTokenUpdates`) | 17.2 | `Weather/Push/RainActivityManager.swift:49-50` | `#available(iOS 17.2)`. Darunter nur lokaler Start über den vorhandenen Fallback `Activity.request` (Zeile 142). Etwa 0,5 h. |

### iOS: Grundlage ab iOS 17.0 (darunter großer Umbau)

| Feature | Min. | Fundstelle (Auswahl) | Ersatz |
|---|---|---|---|
| Observation `@Observable`, `@Bindable`, `@ObservationIgnored`, `.environment(obj)` | 17.0 | `Weather/Models/WeatherStore.swift:29`, `Weather/Push/PushManager.swift:147`, `Weather/Warnings/...`, `Weather/Data/RadarLayer.swift:428`, `Weather/App/WeatherApp.swift:27-30` und 7 weitere Klassen | Umbau auf `ObservableObject`/`@Published`. Viele Stunden (über 15 h), nicht lohnend. |
| `onChange(of:initial:_:)` mit zwei Parametern | 17.0 | rund 20 Stellen | Mechanisch ersetzbar |
| `ContentUnavailableView` | 17.0 | `RadarScreen.swift:746`, `SitePageSheet.swift:91` | Eigene Leeransicht |
| MapKit für SwiftUI (`Map(position:)`, `MapCircle`, `Marker`) | 17.0 | `Weather/Views/RegionViews.swift:30-39` | `MKMapView`-Wrapper. Die Hauptkarte `RadarMap` ist schon ein UIKit-`MKMapView` (iOS 3+). |
| `sensoryFeedback` | 17.0 | `RadarScreen.swift:505,547,552,557` | `UIImpactFeedbackGenerator` |
| `navigationDestination(item:)` | 17.0 | `PlacesSheet.swift:104,107` | |
| Widgets: `AppIntentConfiguration`, `WidgetConfigurationIntent`, `containerBackground`, `#Preview(as:widget)` | 17.0 | `WeatherWidgets/Views/WeatherWidgetViews.swift:18,142`, `WeatherWidgets/Logic/PlaceEntity.swift:52` | Auf iOS 16 nur mit SiriKit-Intent-Definition. Großer Aufwand. |
| ActivityKit (Live Activity, Dynamic Island, `ActivityContent`, `staleDate`) | 16.1 / 16.2 | `RainActivityManager.swift`, `WeatherWidgets/LiveActivity/RainLiveActivity.swift` | |
| Swift Charts | 16.0 | `RadarScreen.swift:695-710` | |
| `onGeometryChange`, `presentationDetents`, `NavigationStack`, `scrollBounceBehavior` (16.4), `isolated deinit` (`Weather/Map/RadarPrefetch.swift:465`) | höchstens 17 | | Bei Ziel 17 ohne Fehler |

Nicht verwendet: SwiftData, TipKit, interaktive Widget-Buttons (`Button(intent:)`), Control Widgets und String Catalogs
(die Lokalisierung läuft über `NSLocalizedString` mit `value:`). Die Web-Seite ist `WKWebView` als `UIViewRepresentable`
und nicht die neue SwiftUI-`WebView` (iOS 26). Sie ist also unkritisch.

### watchOS

| Feature | Min. | Fundstelle | Bemerkung |
|---|---|---|---|
| `AppIntentConfiguration` und `AppIntentRecommendation` (Watch-Widgets) | 10.0 | `WeatherWatchWidgets/WeatherWatchWidgetsBundle.swift:13`, `WeatherWatchWidgets/WatchWidgetProvider.swift:24-32` | watchOS 9 bräuchte SiriKit-Intents. Lohnt nicht, weil watchOS 9 und 10 dieselben Uhren unterstützen. |
| `containerBackground(.fill.tertiary, for: .widget)` | 10.0 | `WeatherWatchWidgets/WatchRainWidgetView.swift:12` | |
| `onChange(of:initial:_:)` | 10.0 | `WeatherWatch/Radar/WatchRadarView.swift:32-55`, `WatchPlacesView.swift:55`, `WeatherWatchApp.swift:20` | |
| `MKMapSnapshotter.Options.preferredConfiguration` | 10.0 | `WeatherWatch/Radar/WatchMapBackdrop.swift:131` | |

**Die Watch-App und die Watch-Widgets bauen mit watchOS 10.0 ohne jede Änderung.**

## 3. Ergebnis

**(a) Ohne Codeänderung:** iOS **26.0** und watchOS **10.0**. Es reicht, die zwei Werte in `project.yml` und
`Base.xcconfig` zu ändern und XcodeGen neu laufen zu lassen. Der Build ist verifiziert.
Watch-Empfehlung: mindestens 26.0. Ein iPhone mit iOS 26 oder 27 koppelt in der Praxis mit Uhren auf watchOS 26 oder 27.
Ein Ziel unter 26 bringt deshalb kaum echte Nutzer, schadet aber auch nicht.

**(b) Mit kleinen `#available`-Weichen:**
- **iOS 18.0:** Glas-Helfer (etwa 2,5 h), FoundationModels abschotten (1-2 h) und Ortssuche (0,5 h).
  Dazu kommen Tests auf dem iOS-18-Simulator und eine CI-Laufzeit (1-2 h). **Gesamt etwa 5-7 h.**
- **iOS 17.0:** zusätzlich Zoom-Übergang, `Color.mix` und Push-to-Start (etwa 1,5 h). **Gesamt etwa 7-9 h.**
  Für Live Activities per Push ist praktisch 17.2 nötig. Mit 17.0 starten Live Activities auf 17.0/17.1 nur lokal.
- **Unter 17:** Das lohnt nicht. Observation, App-Intent-Widgets und SwiftUI-MapKit müssten umgebaut werden
  (geschätzt über 20 h). Dabei gewinnt man nur iPhone 8 und X.

**(c) Verlust unter iOS 26:**
- Die eigenen Glas-Flächen (Pillen, Legende, Scrubber, Zeitleiste) werden matt (Material).
  Das Morphing der Legende im `GlassEffectContainer` und die interaktive Glas-Reaktion fallen weg.
- Systemelemente wie Sheets, Toolbars, Suche und Tab-Leisten sehen automatisch im Stil von iOS 18 aus.
- Die KI-Einordnung (Apple Intelligence) fehlt. Sie läuft heute ohnehin nur auf iPhone 15 Pro oder neuer.
- Unter iOS 18 fallen außerdem der Zoom-Übergang der Sheets und das Farbmischen im Glühen weg.
- Unter 17.2 fehlt der Start einer Live Activity per Push.
- Unverändert bleiben Radar, Karten, Widgets, Live Activity, Mitteilungen und die Watch.

## Verbreitung und Geräte

| Quelle | iOS 27 | iOS 26 | iOS 18 | älter |
|---|---|---|---|---|
| TelemetryDeck, Ende Okt. 2026 (Stand 2.11.) | 36,4 % | 55,0 % | 6,6 % | etwa 2 % |
| Apple, App-Store-Geräte am 7.6.2026 (vor iOS 27) | | 79 % aller iPhones, 86 % der letzten 4 Jahre | Rest etwa 21 % (18 und älter, nicht aufgeschlüsselt) | |

Für iOS 27 hat Apple noch keine Zahl veröffentlicht (Stand Okt. 2026). Quellen:
https://telemetrydeck.com/survey/apple/iOS/majorSystemVersions/ ,
https://developer.apple.com/support/app-store/ ,
https://daringfireball.net/linked/2026/10/08/apple-is-slow-rolling-ios-27-adoption-so-far

**Was das heutige Ziel 27 ausschließt:** Rund 63 % der iPhones (alle, die noch auf iOS 26 oder älter sind) können die App nicht installieren.
Mit **iOS 26** kommen etwa 55 Prozentpunkte dazu, ohne Codeänderung.
Mit iOS 18 kommen weitere etwa 6,6 Punkte und die Geräte iPhone XS, XS Max und XR dazu (iOS 26 verlangt iPhone 11 oder neuer).
iOS 17 bringt gegenüber 18 keine neuen Geräte. Beide laufen auf XS/XR und neuer, iOS 16 lief noch auf iPhone 8 und X.
Für iOS 27 nennen die WWDC-Berichte weiter das iPhone 11 und neuer sowie das SE 2. Frühere Gerüchte über den Wegfall des iPhone 11 haben sich nach diesen Berichten nicht bestätigt.
Das sollte vor einer Entscheidung auf Apples Geräteliste geprüft werden.

**Watch:** watchOS 27 läuft nach den Berichten nur auf Series 9, 10 und 11, SE 3, Ultra 2 und Ultra 3.
Das heutige Ziel 27 **schließt Series 6, 7 und 8, SE 2 und Ultra 1 aus**. Sie bleiben auf watchOS 26.
Ein Watch-Ziel 26.0 holt sie ohne Codeänderung zurück. Mit 10.0 kämen theoretisch Series 4 und 5 sowie SE 1 dazu,
die aber an ein iPhone mit iOS 18 oder älter gekoppelt wären. Quellen:
https://appleinsider.com/articles/26/06/08/watchos-27-supported-by-just-five-apple-watch-models ,
https://9to5mac.com/2026/06/08/apple-confirms-watchos-27-will-run-on-apple-watch-series-9/

## Offene Punkte

- Die Gerätelisten für iOS 27 und watchOS 27 stammen aus der Berichterstattung zur WWDC. Sie sollten vor der Entscheidung auf apple.com bestätigt werden.
- Bei einer Absenkung muss die App auf dem echten Ziel-OS getestet werden (Simulator-Laufzeit 26.0 oder 18.x installieren). Der Compiler deckt nur die API-Verfügbarkeit ab, nicht das Laufzeitverhalten.
- Für die Release-Planung: Der Wechsel 27 auf 26 ist eine Zeile in `project.yml` und eine in `Base.xcconfig`.
