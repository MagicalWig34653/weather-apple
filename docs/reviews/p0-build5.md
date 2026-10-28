# Unabhängiges Review des P0-/Timeline-Stands

Stand: 28. Oktober 2026. Geprüft wurde der Arbeitsbaum nach den Radar-/UI-Aufgaben gegen Quellencheckpoint `323564f`. Code ausschließlich gelesen; keine Implementierung, kein Build, keine neue DWD-Probe, kein Upload. Ergebnis: zwei konkrete P2-Befunde vor dem nächsten Release beheben. Kein P1 nachgewiesen. Die kalte Ladezeit ist weiterhin nicht freigegeben.

## P2: Nicht dekodierbares PNG wird als Erfolg gespeichert

`Weather/Data/DWDResponse.swift:37–43` akzeptiert bereits die acht PNG-Signaturbytes. `Weather/Map/RadarMap.swift:354–371` übernimmt solche Daten anschließend in den Memorycache und meldet Erfolg. Damit kann ein abgeschnittenes oder beschädigtes HTTP-200-Bild dauerhaft als Cachetreffer und Abschlusszeichen erscheinen, obwohl MapKit daraus kein Radarbild darstellen kann.

Konkreter Nachweis: Die vorhandenen Tiletests verwenden `Data([137,80,78,71,13,10,26,10,0])` als angeblich erfolgreiches PNG. Eine unabhängig ausgeführte ImageIO-Prüfung derselben neun Bytes ergab `source=true`, aber `decodedImage=false`. Die derzeitige Produktprüfung akzeptiert genau diese Daten. Das ist kein beobachteter DWD-Ausfall und kein Beleg, dass die letzte Coldstartmessung dadurch entstand; es ist ein reproduzierbarer Fehler des neuen Image-Gates.

Empfehlung: Vor Erfolg/Cacheeinfügung tatsächliche Dekodierbarkeit und vernünftige Bildabmessungen prüfen. Die erfolgreichen Fixtures durch ein echtes kleines PNG ersetzen; Signatur ohne Bildinhalt und abgeschnittenes PNG müssen fehlschlagen und dürfen keinen späteren Cachetreffer erzeugen.

## P2: Playback läuft bei vollständig fehlgeschlagenen Frames weiter

`Weather/Views/RadarScreen.swift:98–105` stoppt die Wiedergabe nur bei `runUnavailable > 0`. Bei `succeeded == 0`, `failed > 0`, `pending == 0`, aber `runUnavailable == 0` gilt dagegen `frameFinished == true`; die Animation fordert nach zwei Sekunden den nächsten Frame an. Dies betrifft zum Beispiel Offline-/HTTP-Fehler und ungültige Bildantworten. Ohne einen einzigen gültigen Frame können dadurch weiterhin alle Zeiten durchlaufen und neue Kachelanfragen entstehen.

Nachweis ist der direkte deterministische Zustands-/Kontrollfluss, keine zusätzliche Live-Lastprobe. Das globale Budget von vier **zusätzlichen Dimensionretries** verhindert diese ursprünglichen Requests pro neuem Frame nicht. Empfehlung: Wiedergabe auch bei vollständig fehlgeschlagenem, erledigtem Frame ohne gültige Kachel stoppen; manuelles Erneutversuchen erhalten. Teilweise erfolgreiche Frames und echte Null-Demand-/Idlezustände gesondert behandeln, damit kein neuer Playback-Deadlock entsteht. Einen gezielten Zustandsregressionstest ergänzen.

## Sonstiger geprüfter Vertrag

- Initiale Karte wird einmal nicht animiert zentriert; die Centerrevision wird sofort gesetzt. Explizite spätere Ortswechsel bleiben animiert.
- HTTP-200-ServiceException wird vor dem Bildcache erkannt. Dimensionwiederholungen sind pro Anfrage auf eine und zusätzlich pro Referenz-/Refreshidentität über Frames/Overlays auf vier begrenzt; ein echter Vorgängerlauf hat ein separates Budget. Kein Prefetch ergänzt.
- Fallback wechselt die tatsächliche Timeline-/Referenzidentität, kennzeichnet den vorherigen Lauf und ist je Refresh einmalig. Die 20-Minuten-Grenze bleibt bestehen. Die Ortsprognose behält ihren eigenen Referenzlauf.
- Fehler-/Abschlusscallbacks werden anhand Kontext und Sequenz gefiltert. Der neue Viewport startet vor der Kartenbewegung; Null-Demand wird als Idle und nicht als erfundener Cacheerfolg behandelt.
- Refresh bleibt vom langsamen Punktprognoseabschluss getrennt. Die Pille zeigt abgeschlossene Radar-Responsebodybytes einschließlich Fehlerantworten; weder MapKit-Grundkarte noch Punktprognose oder Cachehits werden als Download gezählt. Explizite Cachehits sind Voraussetzung des Cachehinweises. Es wird kein vollständiger sichtbarer Kachelnenner oder Prozentwert behauptet.
- Die belegten UI-Prüfungen zeigen 96 pt unteren Insetbereich, mindestens 44 pt für Play/Jetzt und die geschlossene Maximal-Dynamic-Type-Überlagerung. Die bisherige etwa 243-pt-Baseline ist eine dokumentierte Näherung; der obere Prognosezugang bleibt erhalten.

## Messgrenzen und ausgeführte Prüfung

Die dokumentierten 28 verschiedenen DWD-/Maptests und acht unveränderten KI-Tests, drei gezielten Budget-/XML-Prüfungen sowie vier betroffenen UI-Flows wurden als vorhandene Nachweise abgeglichen, nicht erneut vollständig ausgeführt. Eigene Prüfung: gezielter Code-/Testdiff, Befund-/Messdokumentation und die oben beschriebene lokale ImageIO-Dekodierprobe. Keine neue Geschwindigkeitsmessung.

Der finale Coldstart belegt erstmals sichtbaren Niederschlag im Erfassungsintervall **6,812–7,209 s**. Bei **10,435–10,825 s** waren weitere Anfragen offen; die spätere Sichtung bei **79,044–79,568 s** zeigte Abschluss. Wegen der Erfassungslücke ist Full Settle nur **>10,435 bis ≤79,568 s** eingegrenzt. Dies ist weder eine gemessene 79-Sekunden-Ladezeit noch eine Freigabe für nahezu sofortiges kaltes Radar. Historische schnellere Werte anderer Prüfsnapshots dürfen nicht als finale Garantie verwendet werden. Warmer Refresh mit 32 Memorytreffern und null Download wurde beim ersten AX-Ablesen nach 0,839 s bestätigt; dies ist keine First-Paint-Messung.

Eine kurze Debugger-Sichtung des bereits laufenden Simulatorprozesses konnte die private Swift-Session nicht auflösen. Deshalb liegt **kein verifizierter Vergleich aktiver URLSession-Tasks gegen Tracker.pending** vor. Der Prozess wurde wieder freigegeben; kein Neustart und keine zusätzliche Netzmatrix. Aus der Lücke darf weder ein Tracker-Deadlock noch eine konkrete Provider-/Queueursache abgeleitet werden. Die Zähler umfassen beobachtete MapKit-Anfragen und grenzen sichtbare Tiles gegen mögliche Pufferanforderungen nicht geometrisch ab.

## Übergabe

Frischer Fixauftrag für die beiden P2-Befunde, anschließend nur betroffene Prüfungen. Kein neuer Cache-/Prefetchumfang. Danach die Releaseentscheidung anhand reaktiver Kartenbedienung, ehrlichem Fehler-/Cachefeedback und der ausdrücklich offenen Coldstartgrenze treffen. Der aktuelle Stand verbessert Warnungszuordnung und Bedienfeedback, liefert aber noch keinen belastbaren Nachweis eines zuverlässig schnellen kalten Radaraufbaus. Simulator-/Buildressourcen und Dateien nach diesem Review frei.

## Gezielte Korrektur der beiden P2-Befunde

Die PNG-Prüfung verlangt nun vollständige, CRC-validierte PNG-Chunks einschließlich IEND, begrenzte Abmessungen (1–1024 Pixel je Achse) und tatsächliche ImageIO-Dekodierung. Die Response bleibt auf 2 MiB begrenzt. ImageIO allein reichte in einer lokalen Gegenprobe nicht: Sowohl ein auf 45 Bytes abgeschnittenes echtes PNG als auch beschädigte IDAT-Daten ergaben `image != nil` und Source-/Indexstatus `complete`. Deshalb ergänzt ein kleiner längenbegrenzter Chunkdurchlauf die Systemdekodierung; CRC berechnet die Systembibliothek zlib, kein eigener CRC-Algorithmus. Erfolgreiche Fixtures sind jetzt ein vollständiges echtes 1×1-PNG. Abgeschnittene Signatur, unvollständige Chunks und Korruption werden verworfen; ein nachfolgender gültiger Download kann ohne vergifteten Memorycache gelingen.

Playback stoppt jetzt bei `succeeded == 0 && failed > 0 && pending == 0`, unabhängig vom Fehlertyp. Teilweise gültige Frames, echte Idle-/Null-Demandzustände und noch laufende Anfragen werden dadurch nicht als vollständig fehlgeschlagen behandelt. Die manuelle Refreshaktion bleibt unverändert verfügbar.

Tatsächlich ausgeführt: fünf gezielte Tests, **null Fehler**, 1,299 s Testzeit: `testRadarImageRequiresDecodedCompletePNG`, `testFailedFrameStopsPlaybackWithoutBlockingIdleOrValidFrames`, `testInvalidPNGNeverBecomesMemoryCacheHit` sowie beide vorhandenen XML-/Cache-Erholungstests `testPersistentXMLTileErrorIsBoundedAndNextRequestCanRecover` und `testTileHTTP200XMLRetriesOnceAndNeverPoisonsMemoryCache`. Die Tiletests verwenden eigene Refreshrevisionen, damit das absichtlich geteilte globale Retrybudget keine voneinander unabhängigen Tests beeinflusst. Kein abschließender Vollsuitenlauf behauptet; die Testdatei enthält nun 31 DWD-/Maptests. Der gezielte Lauf kompiliert auch die App.

## Neuer P2: MapKit fordert fehlgeschlagene Kacheln automatisch erneut an

Eine ausschließlich temporär instrumentierte isolierte Appkopie verglich einmal sekündlich die echte `URLSession.getAllTasks`-Anzahl der Radar-Tiles mit Tracker-/UIzustand. Nur relative Zeiten und aggregierte Zahlen; keine URLs, Koordinaten oder Standortdaten. Ein erster 20-s-Lauf verlor gepufferte stdout-Ausgabe und liefert keinen Messbeleg. Ein genehmigter einzelner 20-s-Ersatzlauf schrieb ungepuffert; danach wurde beendet. Keine Requestmatrix und keine Gesten, Framewechsel oder manuellen Refreshs während des Laufs.

| Zeit relativ zur jeweiligen Diagnose-Task | echte Tiletasks / Tracker pending | Erfolge / Fehler | Ring / Index / Punkt |
| --- | --- | --- | --- |
| ca. 1–3 s | 32 / 32 | 0 / 0 | lädt / fertig / lädt |
| ca. 5 s | 31 / 31 | 1 / 0 | lädt / fertig / fertig |
| ca. 9–11 s | 4 / 4 | 3 / 25 | lädt / fertig / fertig |
| ca. 12–13 s | 25 / 25 | 6 / 1 | lädt / fertig / fertig |
| ca. 14–15 s | 26 / 26 | 6 / 0 | lädt / fertig / fertig |
| ca. 16–18 s | 24 / 24 | 7 / 1 | lädt / fertig / fertig |

Über diese Beobachtungen blieben Kontext und `requested == 32` gleich. Die Zähler steigen nach bereits gemeldeten Fehlern erneut, während `failed` sinkt: Wiederholte `loadTile`-Aufrufe für dieselben fehlgeschlagenen Keys starten im aktuellen Overlay erneut originale Netzwerkrequests. `RadarLoadTracker.began` setzt `.failed` zurück auf `.pending`; `RadarTileOverlay.loadTile` kennt nach Abschluss weder ein generationsgebundenes Fehlerbudget noch einen Cooldown. Das Budget von vier zusätzlichen Dimensionretries begrenzt diese erneuten Originalrequests nicht. Die automatische Wiederanfrage erklärt ein verlängerbares Pending-/Downloadfenster und zusätzliche Last; sie ist ein konkret zu korrigierender P2, kein Nachweis einer bestimmten Serverursache.

Es gab keinen beobachteten Zustand `0 echte Tiletasks + pending > 0`. Bei bereits beendeter Punktprognose blieb der Ring wegen tatsächlich vorhandener Tiletasks aktiv: keine falsche Punktkopplung nachgewiesen. `URLSessionTask.State.running` beweist keinen aktiven Sockettransfer; bei vier Verbindungen pro Host können Tasks auf Verbindungen warten. Die 8-/12-s-Einzeltaskgrenzen sind kein Gesamtsettle-Versprechen für 32 angeforderte Tiles. Sichtbare Tiles gegenüber MapKit-Pufferbedarf wurden nicht geometrisch getrennt. Kein neuer First-Paint-/Full-Settle-Geschwindigkeitsclaim.

Nächster frischer eng begrenzter Fix: fehlgeschlagene Keys pro Frame-/Viewport-/Refreshgeneration vor automatischen unbegrenzten Wiederanfragen schützen (Cooldown oder kleines Budget), manuelles Erneutversuchen muss eine neue Generation freigeben. Negative Antworten weiterhin nicht im Bildcache speichern. Keine neue Queuearchitektur oder Prefetchfunktion. Die zwei ursprünglichen P2 sind korrigiert; der neue Requestschleifenbefund bleibt vor der Freigabe offen.

## Begrenzung automatischer Wiederanfragen fehlgeschlagener Tiles

Der zusätzliche P2 ist korrigiert: Ein endgültiger Tilefehler bleibt je vollständigem Run-/Frame-/Tile-Key und expliziter Reloadrevision in einem begrenzten flüchtigen Fehlerregister. Automatische MapKit-Wiederanfragen bekommen denselben Fehler ohne neuen Netzabruf; auch ein neuer Viewport reaktiviert ihn nicht. Der Tracker setzt einen bereits fehlgeschlagenen Key dadurch nicht erneut auf `pending`. Ein manueller Refresh mit neuer Revision sowie ein tatsächlich anderer Lauf-/Frame-/Tile-Key erlauben wieder einen Abruf. Cancellation/obsolete Abbrüche werden nicht registriert. Negative Antworten bleiben aus dem Bildcache ausgeschlossen; das zusätzliche Dimensionretrybudget von maximal vier je Lauf/Refresh bleibt bestehen.

Das Register umfasst höchstens 4096 Einträge, also mehr als drei vollständige rechnerische 32-Tile-/37-Frame-Durchläufe, und entfernt Einträge nach 20 Minuten. Es persistiert und protokolliert keine URLs. Die Begrenzung ist eine Schutzmaßnahme gegen automatische Wiederanfragen, keine zusätzliche Vorladung oder Standortgeschichte. Bei sehr großer Kartennutzung kann die feste Kapazitätsgrenze ältere Einträge verdrängen; für den reproduzierten unveränderten 32-Tile-Ausschnitt wird kein Fehler verdrängt.

Gezielt ausgeführt: sechs Tests, **null Fehler**, 1,562 s Testzeit: `testFailedTileRepeatsStaySettledAcrossViewportsAndRefreshReleasesNetwork`, `testFailedTileRegistrySeparatesKeysAndDoesNotStampCancellation`, `testRadarStateSuccessfulRetryClearsFailureAndObsoleteCancellationIsNotError`, `testPersistentXMLTileErrorIsBoundedAndNextRequestCanRecover`, `testInvalidPNGNeverBecomesMemoryCacheHit`, `testUnavailableRunRetryBudgetIsSharedAndBoundedAcrossFrames`. Acht automatische Wiederanfragen desselben fehlgeschlagenen Tiles einschließlich Viewportwechsel erzeugten exakt zwei URLProtocol-Netzabrufe insgesamt (Original plus erlaubter Dimensionretry), nicht acht Originalabrufe. Danach blieb ein Fehler und null Pending erhalten; expliziter Refresh konnte mit einer echten PNG-Antwort erfolgreich erneut laden. Die Erholungstests verlangen jetzt ausdrücklich eine neue Refreshrevision statt impliziter automatischer Wiederholung. Zwei neue Tests; kein vollständiger Suitenlauf behauptet.

Ein einziger begrenzter 20-s-Coldstart mit temporärer aggregierter Instrumentierung bestätigte: echte Tiletasks und Tracker-Pending sanken gemeinsam von 30 (ca. 1 s) über 17 (ca. 4 s) und vier (ca. 7 s) auf null (ca. 8 s). Angefordert waren 32 unterschiedliche Tiles; bei ca. 8 s waren 32 erfolgreich und null fehlgeschlagen, ab ca. 9 s blieb der UI-Ring bis Laufende aus. Die Punktprognose war bei ca. 4 s fertig, während der Ring wegen echter Tiletasks weiterlief. Die Fehlerklassen Timeout/Transport, HTTP, Dimension-XML und PNG-Integrität waren in diesem einzelnen Lauf sämtlich null; deshalb ist dies kein Live-Ausfall-/Recoverybeleg. Der deterministische Ausfallbeleg stammt aus den obigen Tests. Die relative Zeit startet beim temporären Diagnosetimer, nicht bei `simctl launch`; kein First-Paint- oder nahezu-sofortiger Coldstartclaim. Sichtbare Tiles und mögliche MapKit-Puffertiles sind weiterhin nicht geometrisch getrennt.

Der temporäre Konstruktionszähler erfasste 34 Taskobjekte für 32 Keys, darunter anschließend coalesced und vor Start abgebrochene Duplikate; daraus darf **keine Zahl von 34 tatsächlichen Netzstarts** abgeleitet werden. Es wurden keine URLs, Koordinaten oder Payloads protokolliert. Instrumentierung wurde aus der isolierten Kopie entfernt; der normale Appbuild wurde erfolgreich kompiliert und wieder installiert (App beendet). Keine neue Matrix, keine Prefetch-/Diskcachefunktion, kein Upload und keine pauschale kalte Geschwindigkeitsfreigabe. Nächster Schritt: frischer enger Review dieses Retry-/Fehlerzustandsdiffs.

Der Reprotest wurde abschließend um Neuerstellung desselben Overlays innerhalb derselben Revision ergänzt: auch dadurch bleibt der Fehler ohne neuen Netzabruf erhalten. Genau dieser eine betroffene Test nochmals erfolgreich, null Fehler, 0,530 s. Die Testdatei enthält jetzt 33 DWD-/Maptestmethoden; dies ist keine Behauptung eines neuen 33-Test-Gesamtlaufs. Abschließende scoped Diffprüfung ohne Befund. Dateien und Simulator-/Buildressourcen sind freigegeben; keine weiteren Änderungen oder Tests geplant.


## Abschließender unabhängiger Review der gezielten Korrekturen

Ein frischer Reviewer hat ausschließlich die effektiven PNG-/Playback-/Fehlerregisterkorrekturen und zugehörigen Tests lesend geprüft. **Keine offenen P1-/P2-Befunde in diesem begrenzten Diff; Abnahme für die Build-5-Integration und den anschließenden internen Releaseablauf.** Die anfänglichen Befunde und Zwischenmessungen oben bleiben als Historie erhalten und beschreiben nicht den nun korrigierten Zustand.

- PNG: vollständige, längenbegrenzte Chunks mit System-zlib-CRC und abschließendem IEND werden vor ImageIO-Dekodierung geprüft. Zwei-MiB-Eingabegrenze und maximal 1024 Pixel je Achse begrenzen den Prüfaufwand. Die echten PNG-/Abbruch-/Korruptionsfixtures passen zum korrigierten Vertrag; verworfene Bilder gelangen nicht in den Memorycache.
- Playback: der gemeinsame Zustandsausdruck stoppt vollständig fehlgeschlagene erledigte Frames ohne Erfolg unabhängig von der Fehlerklasse. Idle, Cancellation, laufende Requests und teilweise gültige Frames bleiben getrennt.
- Automatische Wiederanfragen: das gemeinsame flüchtige Fehlerregister verwendet vollständigen Tile-Key plus explizite Reloadrevision. Viewport-/Overlayneuerstellung erneuert diesen Schlüssel nicht. Wiederholte Fehler bleiben im Tracker erledigt, ohne wieder auf Pending gesetzt zu werden. Neue manuelle Refreshrevisionen dürfen erneut laden; Cancellation wird nicht registriert. Das bestehende zusätzliche Dimensionbudget von vier je Lauf/Refresh bleibt erhalten. Kapazitäts-/Altersgrenzen sind dokumentiert, kein Diskcache oder Prefetch hinzugefügt.
- Die kontrollierte Reproduktion prüft acht Wiederanfragen einschließlich Viewport- und Overlaywechsel, exakt zwei Transportabrufe und anschließende manuelle Erholung. Die dokumentierten sechs betroffenen Tests sowie der um Overlayneuerstellung ergänzte Einzeltest sind gezielte vorhandene Nachweise, keine zusätzlichen neuen Fälle und kein vollständiger 33-Test-Lauf. Auch die früheren fünf PNG-/Playbackprüfungen werden nicht doppelt als neue Testfälle gezählt.

Eigene Prüfung: gezielte Code-/Testlektüre und Abgleich der vorhandenen Ergebnis-/Messdokumentation; keine neuen Builds, Tests, Liveanfragen oder Simulatoraktionen. Im Produktcode keine temporären P0TASK-/P0RING-Logs, privaten absoluten Pfade oder Debugausgaben gefunden. Die sicheren öffentlichen UI-/HIG-Belege und der geschlossene Maximal-Dynamic-Type-Befund bleiben über [Timelineprüfung](../timeline-build5.md) und [Build-4-HIG-Audit](apple-hig-build4.md) nachvollziehbar.

Freigabegrenze: der eine spätere 20-s-Lauf zeigt endliches angefordertes Tile-Settling und ausgeschalteten Ring, aber keine garantierte kalte Geschwindigkeit oder Live-Ausfallwiederherstellung. Frühere lange Erfassungslücken werden dadurch nicht zu exakten Ladezeiten. Physischer iPhone-Alltagstest, wechselnde DWD-Verfügbarkeit und die Trennung sichtbarer Tiles von MapKit-Puffertiles bleiben offene Grenzen. Diese Grenzen verhindern keine interne Testversion der konkret begrenzten Fehler-/Lastkorrekturen; keine Aussage „alles instant“ oder „DWD behoben“. Dateien und Ressourcen sind für Integration freigegeben.
