# Apple-Review: Befund 4

Bestätigt: `WarnManager.State` enthielt keine Installationszuordnung; unveränderte Fingerprints verhinderten nach einer neuen Installation die Neuanlage der Warnabos.

Zuerst drei XCTest-Regressionen in `WarnManagerTests.swift` ergänzt: identische Einstellungen nach I1→I2 einschließlich persistierter Bindung und Neustart; rückwärtskompatibler Altzustand ohne Bindung mit fehlgeschlagenem UPDATE und Retry ohne doppeltes CREATE; Alt-ID mit 404 wird neu angelegt. Danach minimaler Fix in `WarnManager.swift`: optionale `installationID` im Zustand, veraltete Referenzen bei bekanntem Wechsel verwerfen. Bei Altzuständen werden Fingerprints einmal invalidiert, damit bestehende IDs per UPDATE bestätigt werden; Fehler bleiben retryfähig, 404 nutzt die vorhandene Neuanlage.

Grenze: Die bestehende Push-Rotation folgt auf 401 wegen eines unbekannten/falschen Secrets (`PushManager.runSync`). Neue Credentials können die Abos des alten Owners nicht löschen; der Fix behauptet keine bestätigte Bereinigung einer bereits unzugänglichen alten Installation. Er sendet keine alten IDs unter dem neuen Owner. Die Migration einer noch gültigen Installation behält die IDs und vermeidet dadurch zusätzliche verwaiste Abos. Keine Backend-Änderung oder neue Speicherung von Secrets.

Dateien: `Weather/Warnings/Subscriptions/WarnManager.swift`, `WeatherTests/WarnManagerTests.swift` und diese Übergabe. Pflichtdokumentation, Review, Gateway und Rotationspfad statisch gelesen, Diff gesichtet. Keine Builds, Tests, Discovery, Lints oder Netzaufrufe ausgeführt; kein Push. Testausführung und Erfolg bleiben offen und liegen beim Aufrufer.

Exakter Testbefehl (XCTest-Klassenfilter):

```sh
xcodebuild -project Weather.xcodeproj -scheme Weather -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -derivedDataPath /tmp/weather-derived CODE_SIGNING_ALLOWED=NO -only-testing:WeatherTests/WarnManagerTests test
```

Nächster Schritt: autorisierter separater Befundcommit, anschließend unabhängiges statisches Abschlussreview und Prüfung durch den Aufrufer.
