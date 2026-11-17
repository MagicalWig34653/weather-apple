# Apple-Review: Befund 5

Status: **bestätigt und behoben, Ausführung offen**.

## Codebefund und Änderung

`WeatherStore.pollRadar()` prüfte nach der Manifestantwort nur `isRadarLoading`. Eine inzwischen vollständig beendete manuelle Aktualisierung war damit unsichtbar. `RadarBackendClient.latest()` konnte zugleich seinen Manifest-/ETag-Cache mit einer überholten Antwort überschreiben oder durch ein verspätetes 404 leeren.

Zuerst vier deterministische XCTest-Regressionen in der bereits eingebundenen Datei `WeatherTests/RadarPollScheduleTests.swift` ergänzt (`RadarRequestGenerationTests`):

- Älteres 200 nach neuerem 200 darf Manifest und ETag nicht zurücksetzen; anschließendes 304 liefert den neuen Lauf.
- Verspätetes 404 darf den neuen Clientcache nicht löschen.
- Alter Poll nach vollständig beendetem manuellem Refresh darf den neuen Store-Lauf nicht ersetzen.
- Abgebrochener Request darf den Clientcache nicht füllen.

Danach minimale Requestgenerationen in `Weather/Models/WeatherStore.swift` und `Weather/Data/RadarBackend.swift` ergänzt. Store-Radaroperationen teilen eine Generation; Guards erfassen auch History-Abfragen, deren Zustandsänderungen, direkte Fallbacks und Neukomposition. Forecast-Generationen bleiben unabhängig. Client-Manifest und Historycache akzeptieren nach ihrem Transport-await nur noch die aktuelle, nicht abgebrochene Anfrage. Fehlerantworten werden vor einer Cacheänderung ebenfalls auf Überholung geprüft; Transportfehler verändern keinen Cache.

## Prüfung und nächste Schritte

Nur eigene Änderungen statisch gelesen (`git diff`, gezielte Quelldateien). **Keine Builds, Tests, Test-Discovery, Lints oder Netzaufrufe ausgeführt; kein Push.** Kompilierbarkeit und tatsächliches Laufzeitverhalten sind daher nicht bestätigt. Die Ausführungsprüfung übernimmt der Aufrufer.

Exakter Regressionstestbefehl (XCTest-Klassenfilter, deshalb ohne `()`):

```sh
xcodebuild -project Weather.xcodeproj -scheme Weather -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -derivedDataPath /tmp/weather-derived CODE_SIGNING_ALLOWED=NO -only-testing:WeatherTests/RadarRequestGenerationTests test
```

Für breitere Abnahme zusätzlich die bestehenden RadarBackendTests und RadarPollScheduleTests ausführen. Keine Projektdatei geändert, da die Testquelldatei bereits im WeatherTests-Target enthalten ist.
