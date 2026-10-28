# Integration des budgetierten Timeline-Vorladens

Stand: 28. Oktober 2026, 19:57 Uhr MEZ. Build-/Simulatorverantwortlicher: `integrate_test_prefetch`. Kein Archiv, Commit, Push oder Upload durch diese Aufgabe.

## Ergebnis und tatsächliche Prüfungen

XcodeGen hat `RadarPrefetch.swift` und `RadarPrefetchTests.swift` aufgenommen. Die zentrale Buildnummer ist `6`, Version und ShowerNow-Identität bleiben erhalten. Nach unabhängigem Review und Behebung seiner vier konkreten P2-Befunde wurde der endgültige Quellenstand eingefroren.

- **16 gezielte Prefetchtests erfolgreich**, null Fehler, 0,484 s Testzeit; Exit 0 / `TEST SUCCEEDED` um 19:56:29 Uhr MEZ.
- Anschließend **ein einmaliger vollständiger `WeatherTests`-Logiklauf: 57 Tests, null Fehler, 3,244 s**, Exit 0 / `TEST EXECUTE SUCCEEDED`, Abschluss um 19:56:48 Uhr MEZ. Enthalten sind 33 bestehende DWD-/Maptests, acht Einordnungstests und 16 Prefetchtests. Die gezielten Fälle werden nicht nochmals zur Gesamtzahl addiert.
- Anschließender normaler finaler Simulatorbuild ohne Testhoständerung: Exit 0 / `BUILD SUCCEEDED`. Alle 28 kopierten App-/Test-/Projekt-/Konfigurations-/Ressourcendateien stimmen nach SHA-256 mit dem Arbeitsbaum überein. Keine weitere Quelländerung nach der Testfreigabe.
- Tatsächliches finales Simulatorbundle: beide Namensfelder ShowerNow, Bundle-ID `de.linolaske.showernow`, `0.1.0 (6)`, Gerätefamilie `[1,2]`, drei iPhone- und vier iPad-Orientierungen, Export-Compliance `false`, primäres `AppIcon` vorhanden. SDK: Xcode 27.1 / iOS-Simulator 27.1; Tests auf iPhone 18 Pro mit iOS 27.0.

Die zusätzlichen Regressionen prüfen die konkrete Framewechselreihenfolge mit reserviertem Inflighttransport, die Zuordnung verspäteter promoteter Fehler zur ursprünglichen Reloadrevision und einmalige Responsebytezählung bei zwei Foregroundabnehmern desselben Transports. Der historische Warmcachefall verwendet einen eine Stunde alten Analyseframe bei frischem Timeline-Quelllauf: Er wird tatsächlich vorgewärmt und anschließend vom Foregroundoverlay ohne weiteren Netzstart geladen. Historische Analysezeit und 20-Minuten-Quellfrische bleiben unterschieden.

## Kontrollierter Testhost und Grenzen

Alle Netzwerkfälle verwenden kontrollierte URLProtocol-Antworten. Nur in der wegwerfbaren Testkopie wurde `Weather/App/WeatherApp.swift` durch einen leeren SwiftUI-Einstieg ersetzt, damit der gehostete Appstart keine echten DWD-Anfragen oder Prefetchs nebenher startet. Dies war die einzige Quellenabweichung für beide Testläufe; Radar-, Daten-, Test-, Projekt- und Konfigurationsdateien blieben bytegleich. Für den abschließenden echten Produktionsbuild wurde der ursprüngliche App-Einstieg wiederhergestellt und der vollständige 28-Dateien-Abgleich bestanden. Der Simulator enthält wieder die normale App; sie wurde nicht gestartet.

Ein erster normaler `build-for-testing` war bereits erfolgreich. Ein anschließender Testversuch wurde wegen des danach gemeldeten Telemetriebefunds noch vor dem ersten Testfall gezielt unterbrochen (`TEST INTERRUPTED`, Exit 75); daraus wird kein Testergebnis abgeleitet. Erst der anschließend eingefrorene, korrigierte Stand lieferte die obigen Ergebnisse.

Keine Live-DWD-Bildanfragen, Livelastmatrix, vollständige UI-Wiederholung, physische Geräteprüfung, kalte Latenzmessung, Archivierung oder Veröffentlichung durch diese Aufgabe. Die Budget-/Warmzeitgrenzen aus [Timeline-Prefetch](timeline-prefetch.md) gelten weiter. Die drei Frischeguards einschließlich der erneuten Prüfung nach Budgetwartezeit wurden im unabhängigen Review gelesen; kein separater langer Echtzeit-Wartetest und keine zusätzliche Clockabstraktion eingeführt. Die Ergebnisse begründen weder vollständige Vorwärmung aller Slots noch nahezu sofortiges kaltes Laden oder TestFlight-Installierbarkeit.

Dateien und Build-/Simulatorressourcen sind für den Quellencheckpoint und den getrennten autorisierten Releaseablauf freigegeben. Der Abschlussagent muss den gemeinsamen Status, [Testplan](prefetch-tests.md) und die übrigen Auftragsdokumente auf diese tatsächlichen Ergebnisse aktualisieren.
