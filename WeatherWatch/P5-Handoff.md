# P5: Watch-App

Stand: 3. November 2026. Umsetzung ausschließlich in `WeatherWatch/` und `WeatherTests/WatchLogicTests.swift`; kein Commit/Push, keine Teilagenten gemäß konkretem P5-Auftrag. Bestehende, nicht committete P0/P1/P4-Arbeit erhalten. Zentrale Status-/Entscheidungsdateien und Projektdateien wegen des begrenzten Schreibumfangs unverändert.

## Ergebnis und Vertrag

- `WeatherWatchApp.swift`: nativer SwiftUI-Einstieg, langlebiger Store und WCSession-Empfänger; Aktivierung bereits beim App-Start, erneutes Lesen im Vordergrund.
- `WatchSession.swift`: WCSessionDelegate, liest nach Aktivierung und bei Empfang den aktuellen **receivedApplicationContext**, auch wenn die Übertragung vor dem App-Start stattfand. Das ausgehende `applicationContext` wird nicht gelesen. Delegate-Ereignisse wechseln zum MainActor; die dort erneut gelesene letzte Liste verhindert, dass verzögerte Callback-Tasks alte Listen zurückspielen.
- Vertrag vom Nutzer/P4: `WCSession.updateApplicationContext(["places": Data])`, `Data = JSONEncoder().encode([SavedPlace])`. Watch dekodiert mit `JSONDecoder().decode([SavedPlace].self, from:)`. Vollständiger Ersatz, `[]` löscht alle Orte; fehlender Schlüssel verändert nichts. Keine Auswahl-ID oder Prognosen im Wire-Format. Ungültiges JSON, doppelte IDs und ungültige geografische Koordinaten erhalten die letzte gültige Liste und zeigen einen Fehler. Gültige Orte außerhalb des DWD-Gebiets bleiben sichtbar, lösen aber keinen Abruf aus.
- `WatchStore.swift`: lokale `PlaceStore`-Persistenz; `ForecastCache` laden/schreiben/bereinigen. Neue Koordinaten bei gleicher ID verwerfen den alten Cache. Gelöschte Orte verlieren ihren Cache; verspätete Antworten dürfen weder entfernte Orte noch frühere Koordinaten zurückschreiben. Umbenennen behält den Cache. Fehler beim Speichern der Ortsliste erhalten den letzten gültigen Stand. Speicherprobleme werden sichtbar angezeigt.
- Direkter Abruf über Shared/DWDClient beim Öffnen einer Ortsprognose, Vordergrundeintritt mit offener Prognose und manuellem Aktualisieren. Keine periodischen Netzabrufe oder Hintergrundortung. DWDClient behält seine vorhandene Fünf-Minuten-Zwischenspeicherung; doppelte gleichzeitige Abrufe eines Orts werden zusätzlich im Store vermieden.
- `WatchPlacesView.swift`: Ortsliste, kompakte Ortsprognose, Laden/Fehler/Offline-Cache, leere Liste „Orte in der iPhone-App speichern“, DWD-Quellenhinweis. Löschen des geöffneten Orts führt zurück zur Liste; Koordinatenänderungen aktualisieren die offene Prognose.
- Prognose aus Shared/RainOutlook; Datenalter bezieht sich auf den DWD-Lauf, nicht die Abrufzeit. Darstellung wird lokal jede Minute neu ausgewertet. **P5-Auftrag: stale ab einschließlich 20 Minuten.** Shared hat aktuell `>20 Minuten`; die Watch verschärft ausschließlich ihre Anzeige auf `>=20 Minuten`, ohne Shared zu ändern. Auch zukünftig datierte Läufe jenseits der Shared-Toleranz bleiben stale. Stale zeigt keine Trocken-Zusage.
- `WatchText.swift`, `de.lproj/Localizable.strings`, `en.lproj/Localizable.strings`: native de/en-Lokalisierung einschließlich Status, Übergangsminuten, Datenalter und Fehlern. Keine persönlichen Debuglogs.

Primärquellen, abgerufen am 3.11.2026: Apple [updateApplicationContext](https://developer.apple.com/documentation/WatchConnectivity/WCSession/updateApplicationContext(_:)) beschreibt den Empfang über Delegate oder receivedApplicationContext; [applicationContext](https://developer.apple.com/documentation/watchconnectivity/wcsession/applicationcontext) beschreibt dagegen den zuletzt gesendeten Kontext. Die vorhandene DWD-Implementierung und ihr Datenvertrag wurden unverändert verwendet; keine neue DWD-Schnittstelle eingeführt und kein Live-DWD-Abruf ausgeführt.

## Tatsächlich geprüft

- Portabler temporärer macOS-SwiftPM-Harness mit Swift 6: unveränderte Shared-Quellen sowie `WatchStore.swift` und `WatchText.swift`; **14 Tests, 0 Fehler**. Abgedeckt: Payload/Round-Trip/Neustart, leerer Listenersatz, ungültige Payloads, Cache/Offline-Fallback, Umbenennen/Koordinatenänderung/Löschung, verspätete Antworten, parallele Abrufe, getrennte Orts-Caches, ältere Läufe, unsupported location, Abbruch, Speicherfehler und Stale-Grenze. SwiftPM meldete lediglich wegen der Sandbox nicht schreibbare globale Caches; Tests liefen erfolgreich durch.
- `xcrun swiftc -frontend -parse WeatherWatch/*.swift`: erfolgreich. Dies ist eine Syntaxprüfung, kein Watch-SDK-Typecheck/Build.
- `plutil -lint WeatherWatch/de.lproj/Localizable.strings WeatherWatch/en.lproj/Localizable.strings`: beide erfolgreich.
- `git diff --check`: erfolgreich. Neue, unversionierte P5-Dateien zusätzlich separat auf nachgestellte Leerzeichen geprüft; de/en-Schlüsselmengen (22 Einträge) und Formatplatzhalter stimmen überein.

### Reproduzierbare portable Tests

`WeatherTests/WatchLogicTests.swift` ist mit `WATCH_LOGIC_TESTS` geschützt: Das bestehende iOS-Testtarget enthält keine Watch-Quellen und führt diese Tests daher **nicht** aus. Der temporäre Harness liegt außerhalb des Repos und benötigt kein neues Package im Produkt. Zum Wiederholen im Repo-Wurzelverzeichnis:

```sh
python3 - <<'PY'
from pathlib import Path
import shutil
root = Path('/tmp/weather-p5-watch-harness')
source = root / 'Sources/WeatherWatchLogic'
tests = root / 'Tests/WeatherWatchLogicTests'
source.mkdir(parents=True, exist_ok=True)
tests.mkdir(parents=True, exist_ok=True)
for file in Path('Shared').rglob('*.swift'):
    shutil.copy(file, source / file.name)
for name in ['WatchStore.swift', 'WatchText.swift']:
    shutil.copy(Path('WeatherWatch') / name, source / name)
shutil.copy('WeatherTests/WatchLogicTests.swift', tests / 'WatchLogicTests.swift')
(root / 'Package.swift').write_text('''// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "WeatherWatchLogic", platforms: [.macOS(.v15)], targets: [
    .target(name: "WeatherWatchLogic"),
    .testTarget(name: "WeatherWatchLogicTests", dependencies: ["WeatherWatchLogic"],
                swiftSettings: [.define("WATCH_LOGIC_TESTS")])
])
''')
PY
CLANG_MODULE_CACHE_PATH=/tmp/weather-p5-clang-cache SWIFTPM_MODULECACHE_OVERRIDE=/tmp/weather-p5-swift-cache swift test --disable-sandbox --package-path /tmp/weather-p5-watch-harness
```

## Nicht geprüft / Übergabe an Claude

P5 selbst führte keine Builds aus. Nachträglich (3.11.2026, Claude): Schema WeatherWatch baut für watchOS-Simulator (Series 12 46mm) und mit Schema Weather erfolgreich; iOS-Volltests 371 Unit + 7 UI grün. Nicht ausgeführt: Watch-Simulator-Start, UI-Tests der Watch, `WatchLogicTests` im Xcode-Lauf (nur per Harness), Signing/Archiv/TestFlight. Der portable Harness prüft keine echte WCSession, keine App-Group-Entitlements und keine Lifecycle-Zustellung. Auf der Watch prüfen: Start mit bereits empfangenem Kontext; Erstübertragung/Umbenennen/Löschen/leer; Offline-Start mit Cache; Empfang im Hintergrund; Wechsel aktive/inaktive Szene; Ortswechsel während Abruf; DWD-Direktabruf über WLAN/Mobilfunk; de/en, kleine Displaygrößen, Dynamic Type und VoiceOver. Reale Funk-/Energieeigenschaften bleiben offen.

## Wünsche an gesperrte Bereiche

- (erledigt 3.11.2026) `xcodegen generate` vor dem regulären Watch-Build ausführen, damit neue Swift-Dateien und beide lproj-Ressourcen im generierten Projekt landen; Einbettung und Ressourcen prüfen. Kein eigener Projektgeneratorlauf durch P5.
- Testintegration: Für reguläre XCTest-Ausführung ein geeignetes Testtarget mit Shared und WatchStore oder einen dauerhaften portablen Test-Harness integrieren; der vorhandene iOS-Testlauf allein deckt die P5-Tests nicht ab.
- Dokumentationsverantwortlicher: Ergebnis und tatsächliche Claude-Build-/UI-Prüfungen in `docs/status.md` übernehmen, diese Übergabe verlinken; Grenze `>=20 Minuten` gegenüber Shared `>20 Minuten` bei künftiger Vereinheitlichung beachten.
- Keine zwingende Änderung an Shared, Weather, Widgets oder WatchWidgets erforderlich. Komplikations-Reloads gehören weiterhin zu P7.
