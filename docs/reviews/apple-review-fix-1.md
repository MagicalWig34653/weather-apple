# Review-Befund 1: Live-Activity-Countdown

**Bestätigt (17.11.2026).** Beide Timer in `RainLiveActivity.swift` erzeugten `Date.now...target`, obwohl die Präsentation den Zieltermin mit einem früheren Timelinezeitpunkt prüft. Nach Überschreiten des Termins konnte daraus ein ungültiger `ClosedRange` entstehen. Die explizite Timeline enthielt außerdem keinen Ereignistermin.

Zuerst wurden drei XCTest-Regressionstests in der bereits eingebundenen `RainActivityContractTests.swift` ergänzt: gültiger Countdown vor/am/nach Termin; Timeline für Beginn/Ende am Ereignis- und Frischetermin; fehlende Ereignisse und doppelte Termine. Danach wurde der reine Foundation-Helfer `RainActivityTiming` in der bereits eingebundenen `Shared/RainActivityAttributes.swift` ergänzt und von beiden Timern sowie der Timeline verwendet. Das Intervall beginnt spätestens am Zieltermin, die Timeline enthält zukünftige Ereignis-/Frischetermine sortiert und ohne Duplikate.

Geändert: `Shared/RainActivityAttributes.swift`, `WeatherWidgets/LiveActivity/RainLiveActivity.swift`, `WeatherTests/RainActivityContractTests.swift`, diese Übergabe. Kein Projektgenerator nötig; alle Swift-Dateien sind bereits im eingecheckten Projekt eingebunden.

Tatsächlich geprüft: gezielte statische Codelektüre, `git diff`, `git status --short`. Keine Builds, Tests, Discovery, Lints, Netzaufrufe oder Push ausgeführt; insbesondere keine Aussage über erfolgreiches Kompilieren oder Laufzeitverhalten. L10n-Lint gemäß ausdrücklichem Prüfverbot nicht ausgeführt.

Späterer exakter Testbefehl (XCTest-Klassenfilter, daher ohne `()`):

```sh
xcodebuild -project Weather.xcodeproj -scheme Weather -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -derivedDataPath /tmp/weather-derived CODE_SIGNING_ALLOWED=NO -only-testing:WeatherTests/RainActivityContractTests test
```

Nächster Schritt: statisches unabhängiges Review, Befundcommit und Ausführungsprüfung durch den Aufrufer.
