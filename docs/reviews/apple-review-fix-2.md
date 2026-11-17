# Apple-Review: Befund 2

Bestätigt: `WarnManager.run()` verwarf beim Ausschalten ohne bestätigte Hostidentität die gespeicherten Warnabo-IDs. Eine nur verzögerte Registrierung ist kein Nachweis der Serverlöschung.

Zuerst ergänzt: `WarnManagerTests.testDisableWithoutIdentityKeepsPendingDeletionAcrossRestart` (fehlende Identität, persistierte Löschabsicht, Neustart, fehlgeschlagener DELETE, erfolgreicher Retry) und `testPendingDeletionCompletesWhenServerAlreadyRemovedSubscription` (404). Danach minimaler Fix: IDs bleiben beim fehlenden Host erhalten; lokale Anzeigenamen werden weiterhin entfernt. Die bestehende Löschlogik entfernt Referenzen nur nach Erfolg oder 404.

Dateien: `Weather/Warnings/Subscriptions/WarnManager.swift`, `WeatherTests/WarnManagerTests.swift` und diese Übergabe.

Statisch gelesen: Pflichtdokumentation, Review und betroffene Quellen; Diff gesichtet. Keine Builds, Tests, Discovery, Lints oder Netzaufrufe ausgeführt; kein Push. Testerfolg ist nicht behauptet. Nächster Schritt: autorisierter Befundcommit, danach Ausführung durch den Aufrufer.

Exakter Testbefehl (XCTest-Klassenfilter):

```sh
xcodebuild -project Weather.xcodeproj -scheme Weather -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -derivedDataPath /tmp/weather-derived CODE_SIGNING_ALLOWED=NO -only-testing:WeatherTests/WarnManagerTests test
```
