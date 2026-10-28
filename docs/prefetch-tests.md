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

16 neue Tests liegen in `WeatherTests/RadarPrefetchTests.swift`. Sie prüfen Reihenfolge/Timelinegrenzen, Gerätepolicy, LRU/Bytegrenze/Replacement, Lauf-/Frame-/Zoom-/Coveragekeys, Request-/Bytefenster, Promotion einer laufenden Vorladeanfrage, Abbruch durch andere Nachfrage, tatsächliches Vorwärmen eines historischen −60-Minuten-Nachbarn mit anschließend null zusätzlichen Foreground-Netzstarts, identische Schedulerupdates, echter Framewechsel-Handoff, überholte Refreshfehlerrevision, einmalige Responsebyteabrechnung bei zwei Nachfrage-Subscribern, Inaktivität beziehungsweise nicht erledigten aktuellen Bedarf und endlichen Stop nach einem XML-Dimensionfehler. Netzwerkfälle verwenden ausschließlich kontrollierte URLProtocol-Antworten; die Antwort bleibt bei Promotion bis zur expliziten Testfreigabe angehalten. Kein Test erzeugt Live-WMS-Requests oder lädt eine ganze Timeline gegen den DWD.

Tatsächlich ausgeführt durch den Integrations-/Buildowner: **16 gezielte Tests, null Fehler, 0,484 s**, Exit 0 / `TEST SUCCEEDED` um 19:56:29 Uhr MEZ. Anschließend einmalig die vollständige aktuelle Logiksuite: **57 Tests, null Fehler, 3,244 s**, Exit 0 / `TEST EXECUTE SUCCEEDED` um 19:56:48 Uhr MEZ. Dies umfasst 33 bestehende DWD-/Maptests, acht Einordnungstests und die 16 neuen Prefetchtests; gezielte und Gesamtfälle werden nicht addiert.

Nur die wegwerfbare Testkopie verwendete einen leeren SwiftUI-App-Einstieg anstelle von `Weather/App/WeatherApp.swift`, damit der gehostete Teststart keine echten DWD-Anfragen auslöst. Alle Radar-/Daten-/Test-/Projekt-/Konfigurationsdateien blieben bytegleich. Der anschließend wiederhergestellte unveränderte Produktionsstand kompiliert erfolgreich; alle 28 geprüften Quelldateien stimmen per SHA-256 überein. Ein früher vor Testbeginn unterbrochener Compile liefert kein Testergebnis. [Vollständiger Integrationsnachweis](prefetch-integration.md).


## Ressourcen- und Messgrenzen

Das gewählte Requestbudget von höchstens 120 Vorladeversuchen je 60-Sekunden-Fenster ist eine eigene Schutzregel, kein veröffentlichtes DWD-Kontingent. 32 Tiles × 37 Zeiten bedeuten ohne Wiederverwendung 1.184 Requests. Schon rechnerisch benötigt dies bei gleichmäßiger Budgetausschöpfung rund zehn Minuten; Quieszenz, einzelne Antwortzeiten und Nachfrageunterbrechungen verlängern es. Ein neuer Lauf beziehungsweise ein veränderter Ausschnitt kann deshalb vor dem vollständigen Erwärmen ferner Slots eintreffen. Vorhandene identische Bildkeys bleiben wiederverwendbar. Weder garantierter vollständiger Warmcache noch nahezu sofortiges kaltes Laden wird zugesagt.

Die 50.000.000-Byte-Grenze betrifft ausschließlich zurückbehaltene komprimierte positive Bildpayloads. Decodierte MapKit-Bilder, Eintragsmetadaten und laufende URLSession-Responsepuffer zählen nicht dazu. Die Vorlade-Responsebytegrenze von 8.000.000 je Budgetfenster ist eine Stopgrenze für weitere Requests; die bereits gestartete einzelne Antwort kann sie überschreiten. Sie ist keine harte Netzwerkbyteobergrenze. Der PNG-Validator und seine bestehende Zwei-MiB-Grenze bleiben Bestandteil des Datenvertrags.

Die neuen Tests und die aktuelle Logiksuite sind auf dem eingefrorenen Stand erfolgreich ausgeführt; die Frischeguards nach Budgetwartezeit wurden zusätzlich im unabhängigen Code-Review geprüft, ohne langen Echtzeit-Wartetest oder neue Clockabstraktion. Die Prüfung ersetzt keinen physischen Gerätetest, keine reale Geschwindigkeitsmessung und keine vollständig geometrisch abgegrenzte MapKit-Viewportgarantie.
