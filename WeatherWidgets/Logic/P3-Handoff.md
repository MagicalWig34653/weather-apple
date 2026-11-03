# P3: Widget-Logik

Stand: 3. November 2026. Nur `WeatherWidgets/Logic/**` und `WeatherTests/Widget*` geändert; keine Views, keine Änderungen an P0/P1, Projekt oder Shared, kein Commit/Push. Vorgabe für diesen Auftrag: keine Teilagents, keine Builds/Simulatorläufe. `docs/status.md` und `docs/decisions.md` sind außerhalb des erlaubten Schreibumfangs; Integration bitte dort verlinken.

## Ergebnis und API für P6/P4

- `PlaceEntity.swift`: `PlaceEntity` (UUID, Name ohne Koordinaten), `PlaceEntityQuery`, `WeatherWidgetIntent` mit optionalem Parameter `place`. Query liefert ausschließlich aktuelle gespeicherte Orte. Standard ist `selectedPlaceID`, sonst erster gespeicherter Ort. Leerer Store liefert keine Option. Eine ausdrücklich konfigurierte, inzwischen gelöschte UUID fällt nicht auf einen anderen Ort zurück. Ohne konkrete Konfiguration löst der Loader die letzte App-Auswahl bei jedem Aufruf erneut auf.
- `WeatherWidgetProvider.swift`: `WeatherWidgetProvider: AppIntentTimelineProvider`, `WeatherWidgetEntry: TimelineEntry`. Für P6: `AppIntentConfiguration(kind: WeatherWidgetKind.forecast, intent: WeatherWidgetIntent.self, provider: WeatherWidgetProvider()) { entry in … }`. Der vorhandene P0-Bundle/Placeholder bleibt unverändert; Integration muss den neuen Widget-Typ im Bundle eintragen und den Placeholder ablösen.
- `WidgetTimelineBuilder.swift`: `build(for:at:)` liefert `Plan(entries:reloadDate:)`; Raster sofort und alle 5 Minuten bis einschließlich +60 Minuten, Reload-Anforderung +15 Minuten, Provider setzt `.after`. Keine Schleifen oder Hintergrundtimer. Systembudget kann den Reload verzögern. Alle Einträge verwenden denselben Lauf und berechnen `RainOutlook` für ihren jeweiligen Zeitpunkt neu.
- `WeatherWidgetEntry`: `date`, `place`, `forecast` (Samples für den Zwei-Stunden-Verlauf), `outlook`, `source` (`live/cache/unavailable`), `issue`, `referenceTime`, `dataAge` (Sekunden am Entry-Zeitpunkt), `deepLinkURL` (ausschließlich `WidgetDeepLink.url(for:)`). UI setzt `.widgetURL(entry.deepLinkURL)` und zeigt Datenzeitpunkt/Veraltung; fehlender Ort hat keinen Deep Link. `issue` unterscheidet `noSavedPlaces/placeUnavailable/storageUnavailable/forecastUnavailable`. Bei vorhandenem Cache bleibt die Regenaussage bis zur Frischegrenze nutzbar; `source == .cache` kennzeichnet den Fallback.
- `WidgetForecastLoader.swift`: genau ein DWD-Client-Aufruf je Timeline-Anforderung, bei Erfolg Cache-Schreibversuch; bei Fehler ausschließlich Cache des gewählten Ortes. Cache-Schreibfehler verwerfen keine erfolgreiche Prognose. Snapshot nutzt nur Cache, Placeholder kein IO; keine Galerie-Netzabfragen. Nach asynchronem Abruf werden Existenz/Koordinaten erneut geprüft, bevor Daten angezeigt/geschrieben werden. Ein Koordinatenwechsel während des Abrufs verwirft dessen Resultat.
- P4 verwendet denselben Kind-Wert `"ShowerNowForecast"` für `WidgetCenter.shared.reloadTimelines(ofKind:)`. Diese Hooks bleiben P4-Aufgabe.
- P7 kann Builder/Loader als Quellzugehörigkeit wiederverwenden; die Dateien liegen gemäß Besitzplan in der iOS-Extension, derzeit nicht im Watch-Target. Der iOS-Provider ist kein fertiger Watch-Provider (dort insbesondere Empfehlungen ergänzen).

Shared-Frischevertrag unverändert: `RainForecast`/`RainOutlook` werten **mehr als** 20 Minuten als veraltet, genau 20 Minuten noch frisch; auch >60 Sekunden zukünftige Läufe sind veraltet. Zusätzlich zum Raster gibt es einen Entry bei `referenceTime + maximumAge + 0.001 s`, sofern innerhalb der Timeline. So bleibt eine Trocken-Aussage nicht bis zum nächsten Rasterpunkt sichtbar. Falls „ab 20 Minuten“ strikt einschließlich gemeint ist, die gemeinsame Regel in Shared abstimmen, nicht nur die Widget-Darstellung ändern.

## Prüfstand

- `swiftc -parse` für alle P3-Swift-Dateien und Widget-Tests erfolgreich.
- Whitespace-Prüfung mit `git diff --no-index --check` für alle sieben neuen P3-Dateien erfolgreich; getestete Swift-Quelldateien mit den Repository-Dateien bytegleich abgeglichen.
- Swift-6-Typecheck aller Shared- und P3-Logikquellen mit dem installierten macOS-SDK (Xcode 27.2) erfolgreich; umfasst AppIntents und WidgetKit, keinen App-Build.
- Temporärer macOS-SwiftPM-Harness (Swift 6, Xcode 27.2, `--build-system native`): sämtliche Shared- und P3-Logikquellen einschließlich AppIntent/WidgetKit kompiliert; **16 Tests erfolgreich, 0 Fehler** (13 WidgetLogicTests, 3 WidgetIntentTests). Tests umfassen Raster/Reload-Zeit, Countdown, Deep Links, exakten Shared-Frischewechsel, zukünftige Läufe, leeren/defekten Store, explizit gelöschte IDs, Cache-Fallback/defekten Cache, Cache-Schreibfehler, Löschung/Koordinatenänderung während Abruf und Snapshot ohne Netzabruf. Kein Package im Repo eingeführt. Erster Lauf fand einen inzwischen korrigierten Sendable-Capture im Test. SwiftPM-Standardengine hielt danach den Prozess/Build-Lock; beide Versuche beendet, finaler Lauf in frischem temporärem Verzeichnis. Ausschließlich Umgebungswarnungen zu nicht schreibbaren SwiftPM-Benutzercaches und zur veralteten Option `native`, keine Swift-Compilerwarnungen.

## Reproduzierbare portable Prüfung (macOS mit Xcode/Swift 6)

Aus dem Repo-Wurzelverzeichnis; erzeugt nur einen temporären Harness, übernimmt unveränderte Quellen und benötigt weder App Group noch Netz/Simulator:

```sh
P3_HARNESS=$(mktemp -d /tmp/weather-p3.XXXXXX)
export P3_HARNESS
python3 - <<'PY'
import os, shutil
from pathlib import Path
root = Path(os.environ['P3_HARNESS'])
sources = root / 'Sources/WeatherWidgets'
tests = root / 'Tests/WeatherWidgetsTests'
sources.mkdir(parents=True)
tests.mkdir(parents=True)
(root / 'Package.swift').write_text('''// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "WidgetLogicHarness", platforms: [.macOS(.v14)], targets: [.target(name: "WeatherWidgets"), .testTarget(name: "WeatherWidgetsTests", dependencies: ["WeatherWidgets"])])
''')
for path in [*Path('Shared').rglob('*.swift'), *Path('WeatherWidgets/Logic').glob('*.swift')]:
    shutil.copy(path, sources / path.name)
for path in Path('WeatherTests').glob('Widget*Tests.swift'):
    shutil.copy(path, tests / path.name)
PY
CLANG_MODULE_CACHE_PATH="$P3_HARNESS/clang-cache" \
SWIFTPM_MODULECACHE_OVERRIDE="$P3_HARNESS/swift-cache" \
swift test --disable-sandbox --build-system native --package-path "$P3_HARNESS"
```

Die Apple-Protokolle wurden mit den installierten Swift-Interfaces von WidgetKit/AppIntents abgeglichen: [AppIntentTimelineProvider](https://developer.apple.com/documentation/widgetkit/appintenttimelineprovider), [EntityQuery](https://developer.apple.com/documentation/appintents/entityquery). Die Web-Dokumentationsseiten lieferten nur ihre JavaScript-Hülle; der SDK-Typecheck prüft die verwendeten Signaturen.

## Integration und offene Prüfungen

- Gesperrtes `project.yml`: Neue Tests verwenden `@testable import WeatherWidgets`, weil P3-Typen nur in diesem Modul liegen. Vor dem regulären WeatherTests-Lauf benötigt der Build-Verantwortliche eine explizite Test-Abhängigkeit auf WeatherWidgets und muss prüfen, ob sich die Extension im Host-Test laden lässt. Falls nicht: P3-Logik und Shared gemeinsam in separatem Logik-Testtarget kompilieren (wie im Harness), statt die Typen doppelt in Weather und WeatherWidgets zu importieren. Projekt anschließend durch den zuständigen Agent neu generieren.
- Gesperrter Bundle-Stub `WeatherWidgets/WeatherWidgetsBundle.swift`: P6-Widget registrieren. Erst dann wird der neue Provider tatsächlich ausgeführt.
- Gesperrtes Shared: kein zwingender API-Änderungsbedarf. Bekannte P1-Grenze bleibt: Ortsprüfung und Cache-Schreiben sind keine gemeinsame Transaktion. Eine Löschung exakt zwischen letzter Prüfung und Schreiben kann weiterhin eine Cachedatei hinterlassen; spätere Widget-Aufrufe lesen sie ohne existierenden Ort nicht. Vollständige Serialisierung/Tombstones müssten mit P1/P4 abgestimmt werden.
- Nicht ausgeführt: iOS-Targetbuild, WeatherTests im App-Projekt, UI-/Widget-Snapshots, Signing, App-Group-Verhalten auf Gerät, echtes Widget-Reload-Budget/Speicherverbrauch, Live-DWD-Abfragen. Claude führt die Integration und regulären Simulatorprüfungen aus. Kein Erfolg dieser Prüfungen ist hier behauptet.
