# Apple-Review: Befund 7

**Bestätigt.** `WatchRadarView.play()` wartete nach jedem Tick unverändert auf denselben Nachfolger, auch wenn `slotFailures` dessen dauerhaften Ausfall bereits festhielt.

Zuerst zwei XCTest-Regressionen in `WatchRadarTests.swift` geschrieben: geladener Nachfolger/Ende sowie bekannte Lücken und Fehler überspringen, auf einen noch ladenden Nachfolger warten. Danach minimale reine Entscheidung `WatchRadarSlots.playbackStep` ergänzt und im View verwendet. Die Auswahl springt über bekannte Ausfälle; am Ende endet die Wiedergabe.

Dateien: `WeatherWatch/Radar/WatchRadarStore.swift`, `WeatherWatch/Radar/WatchRadarView.swift`, `WeatherTests/WatchRadarTests.swift`, `tools/test_watch_radar.sh` und diese Übergabe. Das kleine versionierte Skript rekonstruiert das bereits im Testheader beschriebene temporäre SwiftPM-Paket einschließlich Softwaredecoder; keine Produkt-Package-Struktur. Der Test importiert ImageIO für seine bestehenden Decoder-Vergleiche ausdrücklich.

Exakter Testbefehl ab Repo-Wurzel (macOS ≥15, Swift ≥6.0):

```sh
bash tools/test_watch_radar.sh --filter WatchRadarTests/testPlayback
```

Das dependencyfreie Paket setzt `WATCH_RADAR_TESTS`; die iOS-App führt diese Watchtests bewusst nicht aus. Das Skript deaktiviert automatische Paketauflösung und räumt sein temporäres Verzeichnis auf. Alle Quellen stammen aus dem Checkout.

Tatsächlich ausgeführt: nur statisches Lesen und eigene Diffsichtung. Nicht ausgeführt: Skript, Builds, Tests, Discovery, Lints, Netzaufrufe und Push. Kompilierung, Testausführung und Watch-Oberfläche muss der Aufrufer prüfen. Nächster Schritt: serieller Befundcommit, danach separater Worker für Befund 8.
