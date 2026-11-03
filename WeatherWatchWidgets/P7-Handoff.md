# P7: Watch-Komplikationen

Stand: 3. November 2026. Umsetzung nur in `WeatherWatchWidgets/` und `WeatherTests/WatchWidgetLogicTests.swift`. Konkreter Nutzerauftrag hat Vorrang vor allgemeiner Agentpflicht: keine Teilagenten, kein Commit/Push, keine App-Builds. P0–P5 erhalten; gesperrte Projekt-/App-/Shared-/Widget-Dateien unverändert. Status und Entscheidungen sind ebenfalls gesperrt; diese Übergabe ist der dauerhafte P7-Arbeitsstand.

## Dateien und Ergebnis

- `WeatherWatchWidgetsBundle.swift`: P0-Platzhalter ersetzt durch `WatchRainWidget`, `AppIntentConfiguration` mit wiederverwendetem `WeatherWidgetIntent`; Familien accessoryCircular, accessoryRectangular (auch Smart Stack), accessoryInline, accessoryCorner. Kind **`ShowerNowWatchForecast`**.
- `WatchWidgetProvider.swift`: Watch-Adapter; verwendet unveränderte P3-Typen `WidgetForecastLoader`, `WidgetTimelineBuilder`, `WeatherWidgetEntry`, `PlaceEntity` und `WeatherWidgetIntent`. Keine Kopien dieser Quellen, keine zweite Frische-/Auswertungslogik. Ortsempfehlung je gespeichertem Watch-Ort; bei leerem oder unlesbarem Store eine Setup-Empfehlung ohne konkreten Ort. Empfehlungen lesen weder Prognosecache noch Netzwerk. Auswahl, Direktabruf, Cache-Fallback, Snapshot ohne Netzwerk, Nachprüfung nach Abruf und Deep Link kommen aus P3. Raster 5 Minuten/+60 Minuten, Reload-Anforderung +15 Minuten unverändert.
- `WatchWidgetPresentation.swift`: lokalisiert RainOutlook-Zustände und getrennte Fehler (keine Orte, Ort entfernt, Speicher nicht verfügbar); unvollständige Daten ergeben keine Trocken-Aussage. Shared/P3-Frischevertrag unverändert: **mehr als 20 Minuten**, genau 20 Minuten noch frisch; >60 Sekunden zukünftige Läufe ebenfalls stale. P5 hat eine strengere lokale Anzeige (`>=20 Minuten`); P7 folgt ausdrücklich dem wiederverwendeten P3-Vertrag, keine neue globale Entscheidung.
- `WatchRainWidgetView.swift`: alle vier Familien, Ortsname im Rechteck und Corner-Label, Zeile bewusst kurz; VoiceOver nennt Ort, Status, Alter des DWD-Laufs und Cache-Fallback. Sichtbar ist der absolute Laufzeitpunkt (lokales Zeitformat), damit verzögerte Reloads kein eingefrorenes relatives Alter vortäuschen. Stale ist in jeder Familie ausgeschrieben; auch Corner enthält Zeit/Status direkt, unabhängig von der Unterstützung externer Labels. Rechteck kennzeichnet gespeicherten Cache und DWD. `.widgetURL(entry.deepLinkURL)` stammt ausschließlich aus `WidgetDeepLink`; bei fehlendem Ort kein Link.
- `WatchWidgetPreviews.swift`: Debug-Previews für vier Familien sowie veralteten Cache und leeren Store. Kein Preview-Makro erforderlich.
- `de.lproj/Localizable.strings`, `en.lproj/Localizable.strings`: je 28 Schlüssel, einschließlich der unveränderten deutschen P3-AppIntent-Schlüssel mit englischer Übersetzung im Watch-Bundle.
- `WeatherTests/WatchWidgetLogicTests.swift`: sechs portable XCTest-Fälle, geschützt durch `WATCH_WIDGET_LOGIC_TESTS`; bestehender iOS-Testlauf führt diese Datei ohne passende Quellen und Bedingung nicht aus.

## Tatsächlich ausgeführte Prüfungen

- Swift-6-Typecheck mit Xcode 27.2 und **echtem watchOS-27-SDK**, Ziel `arm64_32-apple-watchos27.0`: sämtliche P7-Swift-Dateien einschließlich Debug-Previews plus Shared und die drei benötigten P3-Dateien erfolgreich. Abschließend `-warnings-as-errors`, keine Warnungen. Dies prüft SwiftUI/WidgetKit/AppIntents-Signaturen, ist kein App-/Extension-Build und prüft keine Projekt-Zielzugehörigkeiten.
- Temporärer macOS-SwiftPM-Harness: unveränderte Shared- und drei P3-Quellen, P7-Provider/Presentation sowie die neue Testdatei; **6 Tests, 0 Fehler**. Prüft Countdown bis stale, gemeinsame exakte Frischegrenze, zukünftige Läufe, Regenende, unvollständige Daten/Regensicherheit, fehlende/entfernte Orte und Speicherfehler, Deep Link des Orts sowie Empfehlungen ohne Prognose-/Netzwerkzugriffe. Finaler Harness mit dem korrigierten `let intent` erneut erfolgreich. Nur Umgebungswarnungen über nicht schreibbare SwiftPM-Benutzercaches und veraltete Option `native`.
- Syntaxprüfung der anfänglichen P7-Dateien und der neuen Testdatei mit `swiftc -frontend -parse` erfolgreich; finaler SDK-Typecheck deckt auch spätere UI-/Preview-Änderungen ab.
- `plutil -lint` für beide Localizable.strings erfolgreich; Python-Prüfung: identische Schlüsselmengen, keine doppelten Schlüssel, gleiche Formatplatzhalter. `git diff --check` und separate Whitespace-Prüfung neuer Dateien erfolgreich.
- Initialer SDK-Typecheck mit dem iOS-Provider als zusätzlicher Quelle scheiterte nachvollziehbar: `WeatherWidgetProvider` besitzt keine unter watchOS verpflichtende `recommendations()`-Methode. Deshalb nur die drei plattformgeeigneten P3-Dateien einbinden; P7 hat einen eigenen dünnen WidgetKit-Adapter. Die anfänglichen Warnungen (unveränderte Intent-Variable, veraltete Preview-Namen) sind behoben.

### Reproduzierbarer SDK-Typecheck

Aus dem Repo-Wurzelverzeichnis, mit installiertem Xcode unter `/Applications/Xcode.app` (nur befehlslokales DEVELOPER_DIR):

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc \
  -typecheck -swift-version 6 -D DEBUG -warnings-as-errors \
  -module-cache-path /tmp/weather-p7-modules -module-name WeatherWatchWidgets \
  -target arm64_32-apple-watchos27.0 \
  -sdk /Applications/Xcode.app/Contents/Developer/Platforms/WatchOS.platform/Developer/SDKs/WatchOS.sdk \
  Shared/*.swift Shared/Data/*.swift \
  WeatherWidgets/Logic/PlaceEntity.swift \
  WeatherWidgets/Logic/WidgetForecastLoader.swift \
  WeatherWidgets/Logic/WidgetTimelineBuilder.swift WeatherWatchWidgets/*.swift
```

### Reproduzierbare portable Tests

Aus dem Repo-Wurzelverzeichnis; erzeugt ausschließlich einen temporären Harness, kein Package im Produkt:

```sh
python3 - <<'PY'
from pathlib import Path
import shutil, tempfile
root = Path(tempfile.mkdtemp(prefix='weather-p7-', dir='/tmp'))
sources = root / 'Sources/WeatherWatchWidgets'
tests = root / 'Tests/WatchWidgetTests'
sources.mkdir(parents=True)
tests.mkdir(parents=True)
(root / 'Package.swift').write_text('''// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "WatchWidgetHarness", platforms: [.macOS(.v14)], targets: [
    .target(name: "WeatherWatchWidgets"),
    .testTarget(name: "WatchWidgetTests", dependencies: ["WeatherWatchWidgets"], swiftSettings: [.define("WATCH_WIDGET_LOGIC_TESTS")])
])
''')
paths = [*Path('Shared').rglob('*.swift')]
paths += [Path('WeatherWidgets/Logic') / name for name in ['PlaceEntity.swift', 'WidgetForecastLoader.swift', 'WidgetTimelineBuilder.swift']]
paths += [Path('WeatherWatchWidgets') / name for name in ['WatchWidgetProvider.swift', 'WatchWidgetPresentation.swift']]
for path in paths:
    shutil.copy(path, sources / path.name)
shutil.copy('WeatherTests/WatchWidgetLogicTests.swift', tests / 'WatchWidgetLogicTests.swift')
print(root)
PY
# Den ausgegebenen Pfad für P7_HARNESS einsetzen:
P7_HARNESS=/tmp/weather-p7-XXXXXX
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
CLANG_MODULE_CACHE_PATH=/tmp/weather-p7-clang-cache \
SWIFTPM_MODULECACHE_OVERRIDE=/tmp/weather-p7-swift-cache \
swift test --disable-sandbox --build-system native --package-path "$P7_HARNESS"
```

## Nicht-Geprüftes

Keine Xcode-Projektgenerierung, App-/Extension-Builds, Simulatorstarts, gerenderten Previews/Screenshots, tatsächliche Sprachwahl im Bundle, UI-/VoiceOver-/Dynamic-Type-Prüfungen, Smart-Stack-/Corner-Verhalten auf Zifferblättern, App-Group-Entitlements, WCSession-Zustellung, echtes Reload-Budget, Speicherverbrauch, DWD-Netzabrufe oder Gerätetests. Kein Signing/Archiv/Export/TestFlight. Die vollständige bestehende iOS-Testsuite wurde nicht erneut ausgeführt. Relative Altersangabe in VoiceOver beschreibt den jeweiligen Timeline-Eintrag; sichtbarer Laufzeitpunkt bleibt absolut.

## Wünsche an gesperrte Bereiche / nächste Schritte für Claude

1. **Erforderliche Projektintegration:** Im Target `WeatherWatchWidgets` zusätzlich zu `WeatherWatchWidgets` und `Shared` genau diese bestehenden Quellen einbinden: `WeatherWidgets/Logic/PlaceEntity.swift`, `WeatherWidgets/Logic/WidgetForecastLoader.swift`, `WeatherWidgets/Logic/WidgetTimelineBuilder.swift`. **Nicht** den kompletten Logic-Ordner einbinden: `WeatherWidgetProvider.swift` ist unter watchOS nicht protokollkonform und würde außerdem die P7-TimelineEntry-Konformität doppeln. Anschließend Projekt generieren; beide lproj-Ressourcen und Extension-Einbettung prüfen. Der derzeitige Projektstand kann P7 ohne diese Quellenänderung nicht bauen.
2. **Deep-Link-Ende in Watch-App:** P7 setzt die gültige WidgetDeepLink-URL. `WeatherWatch/` enthält aktuell keinen `onOpenURL`-Handler; Watch-Info.plist hat kein URL-Schema. Im zuständigen P5/P0-Bereich Schema `showernow` und sichere Navigation zum aktuellen gespeicherten Ort mittels `WidgetDeepLink.placeID(from:)` ergänzen. Entfernte/unbekannte ID darf keinen falschen Ort öffnen. Ohne Integration ist Öffnen der passenden Ortsprognose nicht vollständig umgesetzt.
3. **Vordergrund-Reloads:** Nach erfolgreichem Watch-Prognoseabruf sowie Ortslistenänderung/-löschung gezielt `WidgetCenter.shared.reloadTimelines(ofKind: "ShowerNowWatchForecast")` anstoßen; bei geänderten Ortsempfehlungen ggf. `invalidateConfigurationRecommendations()` vorsehen. Keine periodischen Timer ergänzen. Ohne Hooks bleiben Änderungen bis zum nächsten vom System gewährten Reload ausstehend.
4. Für reguläre XCTest-Ausführung passendes Logik-Testtarget mit P7-/P3-/Shared-Quellen und `WATCH_WIDGET_LOGIC_TESTS` verwenden; das iOS-WeatherTests-Target allein deckt P7 nicht ab. Danach Watch-Build und Sichtprüfung aller vier Familien, Smart Stack, leer/offline/stale, de/en und Deep Links nachholen.
5. Dokumentationsverantwortlicher: diese Übergabe in `docs/status.md` verlinken und tatsächliche Integrations-/Buildprüfungen ergänzen; P7 noch nicht als vollständig integriert melden. Keine neue Produkt-/Signing-Entscheidung getroffen.

Primärquellen (3.11.2026): Apple [AppIntentTimelineProvider recommendations](https://developer.apple.com/documentation/widgetkit/appintenttimelineprovider/recommendations()) und [Accessory widgets/Watch complications](https://developer.apple.com/documentation/widgetkit/creating-accessory-widgets-and-watch-complications) geöffnet; Webabruf lieferte JavaScript-Hüllen, Markdown-Verweise konnten vom Browserwerkzeug nicht geladen werden. Konkrete Protokollpflichten und Signaturen wurden daher im installierten WidgetKit-Swift-Interface des watchOS-SDK gelesen und per SDK-Typecheck bestätigt. Keine neue DWD-Schnittstelle eingeführt.
