# Prüfung des Timeline-Vorladens

Stand: 28. Oktober 2026. Unabhängiger QA-Auftrag zum neu freigegebenen Vorladen benachbarter Radarzeiten. Frühere Prefetch-Nichtziele beschreiben Build 5; der aktuelle Nutzerauftrag erlaubt ein begrenztes Vorladen ausschließlich in der geöffneten App. Kein Diskcache, Backendumbau oder DWD-Lasttest.

## Abnahmekriterien

- Gewählter Frame und beobachteter aktueller Kartenbedarf haben Vorrang; Nachbarn folgen abwechselnd links/rechts, an Timelinegrenzen nur auf der vorhandenen Seite.
- Der RAM-Bildcache hält höchstens 50.000.000 komprimierte PNG-Bytes, entfernt zuletzt am längsten ungenutzte Bilder und akzeptiert nur zuvor vollständig validierte Wetter-PNGs. Die Grenze ist kein Ziel für zusätzliche Downloads.
- Identische warme Bildkeys vermeiden Netzabrufe. Referenzlauf, tatsächlicher Frame und Tilekoordinaten bleiben im Key; historische Analysezeiten behalten ihren eigenen Lauf.
- Ein neuer Ausschnitt, Zoom, Zeitpunkt oder Nachfragebedarf bricht überholtes Vorladen ab. Cancellation erzeugt keinen gespeicherten Fehler. Prefetch darf keine sichtbaren Pending-/Fehlerzähler verändern.
- Inaktive App, Low Data und Low Power unterbinden neue Vorladeabrufe. Requestanzahl, Parallelität und Wiederholungen werden zusätzlich zum Bytebudget begrenzt.
- Quellenfehler führen zum endlichen Stop/Cooldown; keine blinden automatischen Wiederholungen. Das bestehende zusätzliche Dimensionretrybudget und explizite manuelle Erholung bleiben erhalten.

## Testaufbau und Grenzen

Der Build-6-Stand enthielt 16 neue Tests in `WeatherTests/RadarPrefetchTests.swift`. Sie prüfen Reihenfolge/Timelinegrenzen, Gerätepolicy, LRU/Bytegrenze/Replacement, Lauf-/Frame-/Zoom-/Coveragekeys, Request-/Bytefenster, Promotion einer laufenden Vorladeanfrage, Abbruch durch andere Nachfrage, tatsächliches Vorwärmen eines historischen −60-Minuten-Nachbarn mit anschließend null zusätzlichen Foreground-Netzstarts, identische Schedulerupdates, echter Framewechsel-Handoff, überholte Refreshfehlerrevision, einmalige Responsebyteabrechnung bei zwei Nachfrage-Subscribern, Inaktivität beziehungsweise nicht erledigten aktuellen Bedarf und endlichen Stop nach einem XML-Dimensionfehler. Netzwerkfälle verwenden ausschließlich kontrollierte URLProtocol-Antworten; die Antwort bleibt bei Promotion bis zur expliziten Testfreigabe angehalten. Kein Test erzeugt Live-WMS-Requests oder lädt eine ganze Timeline gegen den DWD.

Tatsächlich ausgeführt durch den Integrations-/Buildowner: **16 gezielte Tests, null Fehler, 0,484 s**, Exit 0 / `TEST SUCCEEDED` um 19:56:29 Uhr MEZ. Anschließend einmalig die vollständige aktuelle Logiksuite: **57 Tests, null Fehler, 3,244 s**, Exit 0 / `TEST EXECUTE SUCCEEDED` um 19:56:48 Uhr MEZ. Dies umfasst 33 bestehende DWD-/Maptests, acht Einordnungstests und die 16 neuen Prefetchtests; gezielte und Gesamtfälle werden nicht addiert.

Nur die wegwerfbare Testkopie verwendete einen leeren SwiftUI-App-Einstieg anstelle von `Weather/App/WeatherApp.swift`, damit der gehostete Teststart keine echten DWD-Anfragen auslöst. Alle Radar-/Daten-/Test-/Projekt-/Konfigurationsdateien blieben bytegleich. Der anschließend wiederhergestellte unveränderte Produktionsstand kompiliert erfolgreich; alle 28 geprüften Quelldateien stimmen per SHA-256 überein. Ein früher vor Testbeginn unterbrochener Compile liefert kein Testergebnis. [Vollständiger Integrationsnachweis](prefetch-integration.md).


## Ressourcen- und Messgrenzen

Das gewählte Requestbudget von höchstens 120 Vorladeversuchen je 60-Sekunden-Fenster ist eine eigene Schutzregel, kein veröffentlichtes DWD-Kontingent. 32 Tiles × 37 Zeiten bedeuten ohne Wiederverwendung 1.184 Requests. Schon rechnerisch benötigt dies bei gleichmäßiger Budgetausschöpfung rund zehn Minuten; Quieszenz, einzelne Antwortzeiten und Nachfrageunterbrechungen verlängern es. Ein neuer Lauf beziehungsweise ein veränderter Ausschnitt kann deshalb vor dem vollständigen Erwärmen ferner Slots eintreffen. Vorhandene identische Bildkeys bleiben wiederverwendbar. Weder garantierter vollständiger Warmcache noch nahezu sofortiges kaltes Laden wird zugesagt.

Die 50.000.000-Byte-Grenze betrifft ausschließlich zurückbehaltene komprimierte positive Bildpayloads. Decodierte MapKit-Bilder, Eintragsmetadaten und laufende URLSession-Responsepuffer zählen nicht dazu. Die Vorlade-Responsebytegrenze von 8.000.000 je Budgetfenster ist eine Stopgrenze für weitere Requests; die bereits gestartete einzelne Antwort kann sie überschreiten. Sie ist keine harte Netzwerkbyteobergrenze. Der PNG-Validator und seine bestehende Zwei-MiB-Grenze bleiben Bestandteil des Datenvertrags.

Die neuen Tests und die aktuelle Logiksuite sind auf dem eingefrorenen Stand erfolgreich ausgeführt; die Frischeguards nach Budgetwartezeit wurden zusätzlich im unabhängigen Code-Review geprüft, ohne langen Echtzeit-Wartetest oder neue Clockabstraktion. Die Prüfung ersetzt keinen physischen Gerätetest, keine reale Geschwindigkeitsmessung und keine vollständig geometrisch abgegrenzte MapKit-Viewportgarantie.

## Eng begrenzte Netzpolicyprüfung für Build 7

Gemäß Nutzerentscheidung erlaubt normales WLAN ebenso wie Mobilfunk Vorladung; Datensparmodus blockiert beide, Stromsparmodus und inaktive App bleiben Stopgründe. Ein bisheriger Policytest wurde in zwei Matrixfälle geteilt; die Datei enthält nun 17 Testmethoden. Gezielt ausgeführt wurden am 28. Oktober 2026 um **20:03:41 Uhr MEZ vier Tests, null Fehler, 0,083 s**, Exit 0 / `TEST SUCCEEDED`: beide Netzpolicyfälle sowie Promotion nach spekulativem Abbruch und echter Framewechsel-Handoff. Die Matrix prüft normale und als teuer markierte Verbindungen jeweils mit/ohne constrained access sowie Inaktivität/Low Power. Es wurde keine neue vollständige 58-Test-Logiksuite behauptet oder ausgeführt.

Nur der wegwerfbare Testhost verwendete wieder eine leere SwiftUI-Szene; sämtliche Radar-/Daten-/Testquellen blieben bytegleich. Kein physischer Mobilfunk-/Low-Data-Gerätetest und keine Live-DWD-Anfrage. Die tatsächlichen URLSessionflags und der gemeinsame Pfadpolicyhelper wurden unabhängig im [Build-7-Review](reviews/mobile-policy-build7.md) ohne offene P1/P2 geprüft.

## Build 8 (30. Oktober 2026)

Neue Logiktests in `WeatherTests/RadarPrefetchTests.swift`: Plan über alle Slots mit Koordinaten für unbesuchte Slots und Reihenfolge links/rechts; Standardbudget (240 je Fenster) und Parallelität 3; höchstens drei gleichzeitige Transporte und Abbruch aller Worker; einzelner Tilefehler wird übersprungen, drei Fehler in Folge beenden den Lauf. Wartepunkte pollen mit großzügigem Zeitlimit statt kurzer fester Timeouts. Der frühere Test zum Quellfehler (ein Fehler stoppt) ist durch den Drei-Fehler-Test ersetzt. Ergebnisse siehe Abschnitt Ausführung unten. Keine Live-DWD-Anfragen.

Ausführung am 30. Oktober 2026 (iPhone-18-Pro-Simulator): Klasse `RadarPrefetchTests` mit 20 Tests dreimal hintereinander ohne Fehler (0,9 bis 1,1 s). Ein erster Lauf der vollen Suite scheiterte an einer Reihenfolgeabhängigkeit: der geteilte `RadarNetworkPriority.shared` (Demand-Zähler anderer Tests) hielt den Prefetch an; gelöst durch eine injizierbare Priorität je `RadarPrefetcher` (Tests nutzen eine eigene Instanz) und Zustands-Reset in `setUp`/`tearDown`, nicht durch längere Timeouts. Danach zweimal die volle `WeatherTests`-Suite: **63 Tests, null Fehler** (3,8 s und 3,6 s), `TEST SUCCEEDED`. Normaler Simulatorbuild (`generic/platform=iOS Simulator`): `BUILD SUCCEEDED`. Keine Live-DWD-Anfrage durch Tests. Nicht geprüft: Sichtprüfung im Simulator, Gerät, Verhalten unter echter DWD-Last.
