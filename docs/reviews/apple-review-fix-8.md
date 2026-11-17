# Apple-Review: Befund 8

**Bestätigt.** `WatchRadarView` rief die vorhandene Frischeprüfung weder periodisch noch bei erneuter Aktivierung auf. Nach abgeschlossenem Laden konnte `.ready` über die 20-Minuten-Grenze bestehen bleiben; die Altersanzeige aktualisierte sich ebenfalls nur bei sonstiger View-Auswertung.

Zuerst zwei XCTest-Regressionen mit verstellbarer, synchronisierter Uhr in `WatchRadarTests.swift` geschrieben: vollständig geladene Daten bleiben unmittelbar vor der Grenze frisch und werden am Grenzzeitpunkt veraltet; ein Aktivierungstick nach einer Pause verwendet die aktuelle Uhr. Beide prüfen, dass der lokale Tick keine weiteren Requests auslöst. Danach `localClockTick()` als gemeinsamen Zeitpunkt für Frischeprüfung und Altersanzeige ergänzt. Der View tickt nur bei aktiver Scene alle 30 Sekunden und gleicht bei erneuter Aktivierung sofort ab. Bestehendes Laden beim Wiederöffnen bleibt separat.

Dateien: `WeatherWatch/Radar/WatchRadarView.swift`, `WeatherWatch/Radar/WatchRadarStore.swift`, `WeatherTests/WatchRadarTests.swift` und diese Übergabe. Der Harness aus Befund 7 bleibt unverändert.

Exakter Testbefehl ab Repo-Wurzel (macOS ≥15, Swift ≥6.0):

```sh
bash tools/test_watch_radar.sh --filter WatchRadarTests/testLocalClockTick
```

XCTest im dependencyfreien temporären SwiftPM-Paket; kein App-Target-Filter und kein swift-testing. Tatsächlich ausgeführt: statisches Lesen und eigene Diffsichtung. Nicht ausgeführt: Builds, Tests, Harness, Test-Discovery, Lints, Netzaufrufe oder Push. Die Aktualisierung erfolgt nominal alle 30 Sekunden während aktiver Scene und bei Aktivierung sofort, ohne Echtzeitgarantie; Kompilierung, Tests und Watch-Scene-Verhalten muss der Aufrufer prüfen. Nächster Schritt: serieller Befundcommit und unabhängiges statisches Abschlussreview.
