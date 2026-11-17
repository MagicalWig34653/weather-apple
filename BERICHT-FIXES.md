# Bericht: Apple-Review-Fixes

Stand: 17. November 2026. Alle acht Befunde am Code bestätigt und behoben; 7–8 waren kleine Fixes. Je Befund wurden zuerst Regressionstests geschrieben und danach der Produktionsfix umgesetzt, jeweils in einem eigenen deutschen Commit. Kein Befund verworfen.

**Nicht ausgeführt:** Builds, Tests, Test-Discovery, Lints, Netzaufrufe und Push. Die dokumentierten Befehle sind für den Aufrufer; es wird kein Testerfolg behauptet. Unabhängiges statisches Review ohne konkrete Codebeanstandung; Kompilierung, Harnessausführung und Watch-Oberfläche bleiben ungeprüft.

Alle Befehle ab Repo-Wurzel. App-Tests: XCTest im Target `WeatherTests`, Scheme `Weather`; Xcode und installierter iPhone-18-Pro-Simulator gemäß README erforderlich. Klassen-/Methodenfilter hier benötigen kein `()`, da keine neuen swift-testing-Tests verwendet werden. Für einzelne swift-testing-Tests im App-Target muss `-only-testing` den Namen einschließlich `()` enthalten.

## Befund 1 — bestätigt, behoben

Live-Activity-Countdown: sichere Timerintervalle und Timeline an Ereignis-/Frischegrenzen. Commit: `065b208`.

```sh
xcodebuild -project Weather.xcodeproj -scheme Weather -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -derivedDataPath /tmp/weather-derived CODE_SIGNING_ALLOWED=NO -only-testing:WeatherTests/RainActivityContractTests test
```

## Befund 2 — bestätigt, behoben

Warnabo-Löschaufträge bei fehlender Installationsidentität über Neustarts erhalten. Commit: `9524f79`.

```sh
xcodebuild -project Weather.xcodeproj -scheme Weather -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -derivedDataPath /tmp/weather-derived CODE_SIGNING_ALLOWED=NO -only-testing:WeatherTests/WarnManagerTests test
```

## Befund 3 — bestätigt, behoben

Während einer Push-Synchronisation ergänzte Löschaufträge erhalten. Commit: `52000d4`.

```sh
xcodebuild -project Weather.xcodeproj -scheme Weather -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -derivedDataPath /tmp/weather-derived CODE_SIGNING_ALLOWED=NO -only-testing:WeatherTests/PushDeletionQueueTests test
```

## Befund 4 — bestätigt, behoben

Warnabos installationsgebunden speichern; Altzustände per UPDATE/404-Neuanlage migrieren. Commit: `243c1ca`.

```sh
xcodebuild -project Weather.xcodeproj -scheme Weather -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -derivedDataPath /tmp/weather-derived CODE_SIGNING_ALLOWED=NO -only-testing:WeatherTests/WarnManagerTests test
```

Grenze: Bereits ungültige alte Credentials erlauben keine bestätigte Löschung der Abos des früheren Owners. Die Migration einer gültigen Installation erhält vorhandene IDs und vermeidet Duplikate.

## Befund 5 — bestätigt, behoben

Überholte oder abgebrochene Radarantworten dürfen Store und Manifest-/Historycache nicht überschreiben. Commit: `b6dea02`.

```sh
xcodebuild -project Weather.xcodeproj -scheme Weather -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -derivedDataPath /tmp/weather-derived CODE_SIGNING_ALLOWED=NO -only-testing:WeatherTests/RadarRequestGenerationTests test
```

Der Klassenfilter umfasst alle vier neuen Regressionen: überholtes 200 mit ETag/304, überholtes 404, alter Poll nach manuellem Refresh sowie abgebrochene Antwort ohne Cachemutation.

## Befund 6 — bestätigt, behoben

Tatsächliche ImageIO-Metadaten vor Pixeldekodierung auf Manifestmaße, sichere Ganzzahlen und feste Größenlimits prüfen. Commit: `84894ab`. XCTest im Target `WeatherTests`:

```sh
xcodebuild -project Weather.xcodeproj -scheme Weather -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -derivedDataPath /tmp/weather-derived CODE_SIGNING_ALLOWED=NO \
  -only-testing:WeatherTests/RadarBackendTests/testDecoderValidatesMetadataBeforeAllocatingPixels \
  -only-testing:WeatherTests/RadarBackendTests/testDecoderAcceptsSmallPNGAndRejectsManifestMismatch \
  -only-testing:WeatherTests/RadarBackendTests/testDecoderChecksDimensionsAndRejectsGarbage test
```

## Befund 7 — bestätigt, behoben

Watch-Wiedergabe überspringt bekannte Bildausfälle, wartet auf ladende Nachfolger und stoppt am Ende. Commit: `71a8d53`.

```sh
bash tools/test_watch_radar.sh --filter WatchRadarTests/testPlayback
```

## Befund 8 — bestätigt, behoben

Lokale Frische-/Altersanzeige nominal alle 30 Sekunden während aktiver Watch-Scene aktualisieren, bei Aktivierung sofort; kein zusätzlicher Netzabruf oder Hintergrundtimer. Commit: `a74ce71`.

```sh
bash tools/test_watch_radar.sh --filter WatchRadarTests/testLocalClockTick
```

Für 7–8: XCTest-Klasse `WatchRadarTests` im dependencyfreien temporären SwiftPM-Testtarget `WeatherWatchRadarTests`, erzeugt durch das versionierte Skript; macOS ≥15 und Swift ≥6.0 erforderlich. `WATCH_RADAR_TESTS` aktiviert diese im iOS-App-Target ausgeschlossenen Tests. Paketauflösung ist deaktiviert; Quellen stammen aus dem Checkout. Das Skript wurde nicht ausgeführt.

Details und statisch geprüfte Grenzen: [Übergabe](docs/reviews/apple-review-fixes-uebergabe.md). Vorbereitender Prozesscommit: `e1673e8`; Abschlussdokumentation separat.
