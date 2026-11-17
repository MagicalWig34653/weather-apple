# Apple-Review: Befund 3

**Bestätigt und behoben:** `PushManager.runSync()` ersetzte die während eines DELETE-Awaits veränderbare Löschwarteschlange durch den Rest eines älteren Snapshots. Ein zweiter Regions-Opt-out konnte dadurch seine Serverlöschung verlieren.

Zuerst wurden in der bereits im App-Testtarget eingebundenen `WeatherTests/PushRegionTests.swift` zwei XCTest-Regressionen (`PushDeletionQueueTests`) geschrieben. Ein privater Actor hält das erste DELETE per Continuation an; währenddessen wird Region B neben A entfernt, Region C bleibt aktiv. Beide Serverlöschungen werden geprüft. Der Fehlerfall prüft zusätzlich die persistierte Warteschlange und einen späteren erfolgreichen Wiederholungsversuch.

Anschließend minimaler Fix in `Weather/Push/PushManager.swift`: Nur erfolgreich gelöschte beziehungsweise mit 404 bestätigte IDs werden aus der aktuellen Warteschlange entfernt. Fehlgeschlagene und währenddessen neu ergänzte Aufträge bleiben erhalten.

Statisch gelesen: betroffene Synchronisationspfade, vorhandene Gateway-Fakes und Target-Einbindung im eingecheckten Projekt; eigener Diff gesichtet. Keine Builds, Tests, Test-Discovery, Lints, Netzaufrufe oder Push ausgeführt (Nutzerauftrag). Commitzuordnung ergänzt der Abschlussbericht.

Ausführung durch den Aufrufer:

```sh
xcodebuild -project Weather.xcodeproj -scheme Weather \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  -derivedDataPath /tmp/weather-derived CODE_SIGNING_ALLOWED=NO \
  -only-testing:WeatherTests/PushDeletionQueueTests test
```

Nächster Schritt: unabhängiges statisches Review und später die oben genannte Ausführungsprüfung durch den Aufrufer.
