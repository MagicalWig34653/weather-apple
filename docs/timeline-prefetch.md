# Budgetiertes Timeline-Vorladen

Stand: 28. Oktober 2026. Implementierung und unabhängiger Code-Review abgeschlossen; endgültige kontrollierte Tests und bytegleicher Produktionsbuild erfolgreich. Keine neuen Builds, Simulatorläufe, GetMap-Requests oder Uploads durch diese Dokumentationsaufgabe.

## Nutzerauftrag und Abnahme

Nach Nutzerfeedback funktioniert der aktuelle Geräteabruf mit ungefähr 100 KB pro Zeitslot. Gewünscht ist unauffälliges Vorladen vom ausgewählten Slot aus abwechselnd nach links und rechts, mit maximal 50 MB Cache. Das ist keine gemessene maximale Slotgröße und kein Nachweis eines DWD-Kontingents. Die frühere Prefetch-Zurückstellung ist für diesen neuen Auftrag ersetzt; der Schutz der DWD-API bleibt verbindlich.

- RAM-Bildcache mit harter Grenze **50.000.000 Byte** gespeicherter validierter PNG-Nutzdaten; Byteanzahl vor Einfügung begrenzen und passende Einträge verdrängen. MapKit, dekodierte Bilder, Metadaten und laufende Responsepuffer zählen nicht zu diesem Bilddatenlimit. Kein Diskcache oder Cache über Appstarts.
- Ausgewählten Frame vollständig bedienen; danach Reihenfolge `selected − 1`, `selected + 1`, `selected − 2`, `selected + 2` usw., mit vorhandenen Nachbarn an Grenzen. Schrittweise über alle geeigneten Slots, soweit Quelle und Budgets dies zulassen, kein blindes 50-MB-Auffüllen.
- Aktuelle Nachfrage priorisieren; bei Scrub, Ort, Zoom und inaktiver Szene überholte Arbeit abbrechen. Abbrüche dürfen keine negativen Tilefehler oder Fehleranzeige des neuen sichtbaren Frames erzeugen. Low Data und Low Power unterbinden optionales Vorladen.
- Zusätzliches Requestbudget, kleine Parallelität, Mindestabstand zwischen Netzstarts und Pause bei Quellproblemen. Diese Werte sind appseitige Schutzentscheidungen, keine von DWD veröffentlichten Nutzerkontingente. Keine periodischen Vorlade-/Refreshschleifen.
- Identität enthält tatsächliche Referenzzeit, Framezeit, Layer-/Darstellungsparameter und Tilekoordinaten/Zoom. Historische Analyseframes behalten ihren eigenen Referenzlauf; aktuelle Zukunftsframes ihren zugehörigen Lauf. Keine Wiederverwendung unter falschem Datenzeitpunkt. Bestehende 20-Minuten-Frische und P0-Fehlerbudgets bleiben erhalten.
- Refreshring nur für sichtbare Nachfrage; keine Prefetch-Fortschrittsfläche. Angezeigte Radar-Gesamtbytes müssen echte abgeschlossene Prefetch-Responsebytes korrekt einschließen; Cachetreffer zählen nicht als Download. Keine erfundenen Prozentwerte.

32 Tiles × 37 ungesehene Slots entsprechen bereits 1.184 GetMap-Requests ohne Retries. Deshalb ist 50 MB allein kein API-Schutz. Das Beispiel ist eine Rechnung, keine neue Lastmessung. Ein warmer Nachbar soll einen echten Cachetreffer ohne zusätzlichen Netzstart ermöglichen; das muss eine kontrollierte Prüfung belegen. Vollständige Vorwärmung und sofortiges kaltes Laden sind keine Garantie.

## Implementierter und unabhängig gelesener Architekturstand

Der Implementierungsauftrag konkretisiert das appseitige Prefetchbudget auf eine Sekunde Leerlauf vor Beginn, höchstens eine spekulative Netzoperation gleichzeitig und mindestens 500 ms zwischen Prefetch-Netzstarts. Zusätzlich sind 120 Prefetchrequests je 60 Sekunden und 8.000.000 empfangene Prefetchbytes je festem 60-Sekunden-Fenster umgesetzt; das Budget bleibt über Frame-/Ort-/Zoomwechsel bestehen. Die Bytezahl ist eine Stopgrenze nach vollständiger Antwort: eine bereits gestartete Antwort kann sie überschreiten. Sie ist keine harte Socket-Transfergrenze. Sichtbare Nachfrage bleibt vom Prefetchbudget unabhängig und unterbricht optionale Arbeit.

Für Quellfehler ist eine 120-Sekunden-Pause je Referenzlauf vorgesehen, ohne Prefetchretries. Kein periodischer Blindrefresh. Ab Build 7 erlauben normale WLAN- und Mobilfunkverbindungen Vorladung; eine als teuer markierte Verbindung allein sperrt nicht. Low Data, Low Power und inaktive Szene sperren weiterhin. Build 6 schloss teure Verbindungen noch konservativ aus. Historische Frames sollen ihre tatsächliche Analyse-Referenz `min(frameDate, timelineReference)` verwenden; Zukunftsframes bleiben beim Timeline-Referenzlauf. Die 20-Minuten-Frischeguards verwenden den aktuellen Timeline-Quelllauf, nicht die absichtlich ältere Analyse-Referenz historischer Frames. Der fertige Code ist unabhängig gelesen; dies ersetzt noch keinen bestandenen Funktions-/Lastnachweis.

## Netzpräferenz ab Build 7

Verbindliche Nutzerantwort: „WLAN und Mobilfunk, aber nur solange Datensparmodus nicht aktiviert ist“. Der Pfadmonitor und die optionale URLSession erlauben normale Mobilfunk-/Hotspotverbindungen. Die Sitzung erlaubt teure und Mobilfunkverbindungen ausdrücklich, sperrt constrained access und wartet nicht auf passende Connectivity; ein zum Foreground übernommener Transport bleibt dadurch nicht wegen eines ausgeschlossenen normalen Mobilfunkpfads hängen. Datensparmodus, Low Power und inaktive Szene bleiben Stopgründe. Cache-, Request- und Bytebudgets bleiben unverändert. Vier gezielte Policy-/Promotiontests bestanden mit null Fehlern; der enge unabhängige Review hat keine offenen P1/P2. Der Build-7-Produktionscompile wird separat belegt; noch kein Build-7-Upload.

## Primärquellenprüfung

Am 28. Oktober 2026 wurden folgende offizielle Apple-Seiten einschließlich ihrer Markdownfassungen gelesen; der Webreader lieferte zunächst nur JavaScript-Hinweise, die Markdownfassungen wurden gezielt per HTTPS gelesen:

- [NSCache.totalCostLimit](https://developer.apple.com/documentation/foundation/nscache/totalcostlimit): Apple garantiert keine harte Grenze oder Verdrängungsreihenfolge. Ein auf 50 MB gesetztes `NSCache`-Kostenlimit allein erfüllt deshalb den Auftrag nicht; die App muss die gespeicherten PNG-Bytes selbst begrenzen.
- [URLSessionConfiguration.allowsConstrainedNetworkAccess](https://developer.apple.com/documentation/foundation/urlsessionconfiguration/allowsconstrainednetworkaccess): steuert Zugriff bei Low Data Mode. Apple empfiehlt, optionalen Netzwerkbedarf bis zu einer geeigneten Verbindung aufzuschieben. Das unterstützt getrennte Regeln für ausdrückliche Nutzeranfrage und Vorladung. Ob auf Konfiguration oder Request umgesetzt wird, muss zum gemeinsamen Deduplizierungs-/Prioritätsmodell passen; nutzerinitiierte Nachfrage nicht versehentlich global sperren.
- [URLSessionTask.cancel()](https://developer.apple.com/documentation/foundation/urlsessiontask/cancel()): Abbruch wird sofort markiert, aber Delegate-Mitteilungen können noch folgen. Daher alte Generationen unabhängig vom tatsächlichen Transportabschluss filtern; Cancellation nicht als Providerfehler behandeln.
- [ProcessInfo.isLowPowerModeEnabled](https://developer.apple.com/documentation/foundation/processinfo/islowpowermodeenabled): aktuellen Zustand abfragen und bei `NSProcessInfoPowerStateDidChange` erneut prüfen. Optionales Vorladen reduzieren beziehungsweise stoppen; beim Start nicht allein auf eine spätere Notification vertrauen.

Die bereits geprüfte [DWD-Anleitung zur WMS-Einbindung](https://www.dwd.de/DE/wetter/warnungen_aktuell/objekt_einbindung/einbindung_karten_geodienste.pdf?__blob=publicationFile&v=14) empfiehlt regelmäßige Auffrischungen nicht unter fünf Minuten. Das betrifft Refresh, kein explizites Tile-/Timeline-Kontingent. Der erneute Webabruf dieser PDF wurde mit HTTP 403 abgewiesen; die bestehende Quellenbewertung aus [near-instant-radar.md](research/near-instant-radar.md) wurde deshalb nicht als neu verifizierter PDF-Inhalt ausgegeben. Keine zusätzlichen DWD-Bildanfragen, kein WMTS-Recheck und keine Lastprobe für diesen Auftrag.

## Übergabe und noch offene Nachweise

Produktionscode und ursprüngliche QA sind fertig und freigegeben. Der [frische unabhängige Review](reviews/prefetch-build6.md) hat vier konkrete P2-Grenzen gefunden, nach Korrektur erneut gelesen und keine offenen P1/P2 im geprüften Diff. Der Integrations-/Buildowner hat 16 kontrollierte neue Tests und anschließend einmalig die vollständige aktuelle Logiksuite mit 57 Tests, jeweils null Fehlern, ausgeführt; Quellencheckpoint-/Dokumentationsowner prüft anschließend Diff, Privacy, Links, Ignore und Index. Root und technischer Lead koordinieren. Keine 37-Slot-DWD-Matrix.

32 beobachtete Tiles × 37 Slots würden ohne Cachewiederverwendung 1.184 Requests bedeuten und bei 120/min ungefähr zehn Minuten Budgetzeit benötigen. Quieszenz, Antwortzeiten und Nachfrage verlängern diese Rechnung. Neue Fünf-Minuten-Läufe können ferne Slots vor vollständiger Erwärmung neu verankern; keine vollständige Warmcachegarantie. Die Coverage enthält mögliche MapKit-Puffertiles und ist keine exakt vermessene sichtbare Fläche. Identische ältere positive Bildkeys bleiben innerhalb des RAM-Budgets wiederverwendbar.

16 gezielte Tests (0,484 s) und der vollständige einmalige Logiklauf mit 57 Tests (3,244 s) sind erfolgreich. Der abschließende normale Produktionsbuild ist erfolgreich und alle 28 geprüften Dateien sind bytegleich. Die isolierte Testhost-Abweichung und die Grenzen der Prüfung stehen im Integrationsnachweis. Offen sind der geprüfte Quellencheckpoint und der Build-6-Upload. [Integration](prefetch-integration.md) und [Tests](prefetch-tests.md) halten geplante und ausgeführte Prüfungen getrennt. Apple-Serverannahme (`PROCESSING`) bleibt von interner Installierbarkeit getrennt.

## Build 8: vollständige Timeline vorladen (30. Oktober 2026)

Nutzerfeedback zu Build 7: Die Zeitleiste wird nicht komplett vorgeladen; erst nach dem Durchgehen jedes Slots ist das Scrubben flüssig. Ziel: kurz nach Ort-/Lauf-Laden ist die gesamte Timeline (ca. 37 Slots) des sichtbaren Ausschnitts warm.

Ursachen (Build 7, Code `RadarPrefetch.swift`/`RadarMap.swift`):

1. Die Koordinatenmenge kam aus `overlay.observedPaths`, also nur aus MapKit-Anfragen des gerade sichtbaren Slots. Sie wurde zwar je Slot wiederverwendet, hing aber an einem einzelnen Overlay: jeder Frame-/Viewportwechsel leert sie (`beginViewport`), bis MapKit neu angefragt hat. Der Scheduler lief erst nach Ruhe und stoppte bei jedem Neuanker.
2. Durchsatz: eine Netzoperation, 500 ms Abstand plus Antwortzeit (ca. 0,3 bis 1 s) ergibt höchstens etwa 1 bis 1,5 Requests/s. Bei 32 Tiles mal 37 Slots = 1.184 Requests sind das 13 bis 20 Minuten, länger als eine typische Sitzung ohne Interaktion. Jede Interaktion bricht ab und beginnt nach 1 s Ruhe neu (bereits warme Keys werden übersprungen, der Fortschritt bleibt, aber nur bei unverändertem Ausschnitt).
3. Eine einzige Fehlerantwort beendete den gesamten Lauf für 120 s, auch bei einem einzelnen defekten Tile.
4. Budgets (120 Requests, 8 MB je 60 s) hätten 1.184 Requests erst nach etwa zehn Minuten erlaubt, 8 MB bei ca. 100 KB je Slot-Tile-Gruppe ebenfalls knapp.

Umsetzung: `RadarPrefetchPolicy.plan` bildet slot-major (abwechselnd links/rechts vom gewählten Slot) die Koordinaten des sichtbaren Ausschnitts auf alle Slots ab (gleiche z/x/y, andere Zeit). Drei Worker teilen sich den Plan. Nicht verändert: 50-MB-RAM-Cap, kein Diskcache, Abbruch bei Ort-/Zoom-/Framewechsel und Nachfrage, Sperre bei Datensparmodus, Low Power und inaktiver App, Quellfehlerpause (120 s je Referenzlauf), Frischeguard.

Neue Werte (ersetzen die Build-6/7-Vorsichtswerte): 3 parallele Requests (vorher 1), 250 ms Abstand je Worker (vorher 500 ms), 240 Requests je festem 60-s-Fenster (vorher 120), Quellfehlerstopp nach 3 aufeinanderfolgenden Fehlern; einzelne fehlerhafte Tiles werden übersprungen und nicht erneut angefragt. Das Bytefenster bleibt bei 8.000.000 empfangenen Bytes je 60 s (Stopgrenze), weil die gemessenen Tilegrößen es nicht erfordern.

Tilegröße (gemessen): Zwei einzelne Testabrufe am 30. Oktober 2026 gegen den im Code genutzten Dienst (Zoom 8, Standardzeit) lieferten 1.189 und 2.178 Bytes bei 0,18 und 0,24 s Antwortzeit. Der frühere Simulatorbeleg in [near-instant-radar.md](research/near-instant-radar.md) nennt 32 Tiles mit rund 137 KB, also etwa 4,3 KB je Tile. Die Tilegröße hängt vom Niederschlagsinhalt ab; ein Spektrum von etwa 1 bis 4 KB ist belegt, Ausreißer sind nicht ausgeschlossen. Die frühere Schätzung 3 bis 4 KB wurde damit bestätigt beziehungsweise nach unten erweitert.

Rechnung (Annahmen gekennzeichnet): Geschätzt ca. 0,25 s Abstand plus gemessene ca. 0,2 s Antwort je Request, also etwa 2 Requests/s je Worker; mit 3 Workern rechnerisch etwa 6/s, begrenzt durch das Fenster auf 240/min = 4/s. 32 Tiles mal 37 Slots = 1.184 Requests, davon höchstens 32 bereits durch die sichtbare Nachfrage warm: etwa 1.152/4 = 288 s, also knapp 5 Minuten (5 Fenster). Bei 12 bis 20 Tiles (kleiner Ausschnitt) 444 bis 740 Requests, also 2 bis 3 Minuten. Datenmenge: 1.184 Tiles mal 1 bis 4,3 KB = 1,2 bis 5,1 MB insgesamt; höchstens 240 mal 4,3 KB = rund 1 MB je Minute, weit unter der 8-MB-Stopgrenze. Der 50-MB-RAM-Cap wird damit nicht erreicht. Das ist Rechnung auf Basis weniger Messpunkte, keine Lastmessung und keine Garantie.

Lastbewertung: höchstens 4 Requests/s je aktivem Nutzer über wenige Minuten, einmalig je Ort/Zoom, ohne Retries, mit Abbruch bei Fehlern und Sperre bei Datensparmodus. Das ist deutlich über Build 7, aber begrenzt; die Werte sind appseitige Schutzwerte, kein DWD-Kontingent. Bei Hinweisen auf Drosselung sind Parallelität und Budget konservativer zu setzen.

## Build 9: Backendweg (30. Oktober 2026)

Liefert der Radar-Cache einen frischen Lauf, ersetzt ein einziges `RadarImageOverlay` (eigener `MKOverlay`/`MKOverlayRenderer`, Ganzbild in die EPSG:3857-bbox gezeichnet, nur der benötigte Bildausschnitt je Kachel, Interpolation `medium`, Alpha 0,72 wie beim DWD-Weg) die DWD-Tile-Overlays. Der Slotwechsel setzt nur die angezeigte Bild-URL und zeichnet neu; das Overlay wird nicht ersetzt. Ein neuer Lauf erzeugt ein neues Overlay und verwirft nicht mehr gelistete Bilder aus dem Cache.

- Manifest: `RadarManifest` (Validierung: Schema 1, Pflichtfelder, bbox, Zeiten sortiert, Referenz-Slot vorhanden, Pfade nur `<run>/<slot>.webp`). Slotzahl variabel (bis zu 12 frühere Analysen plus 25), nie hartkodiert.
- Vorladen: `BackendRadarLoader.prefetch` lädt alle Slots in der Reihenfolge `RadarPrefetchPolicy.order` (selected, -1, +1, ...) mit 4 parallelen Requests (je Bild etwa 6 KB, gesamt etwa 150-300 KB). Komprimierte Bilder im bestehenden 50-MB-`TileMemoryCache`, höchstens 8 dekodierte Bilder zugleich; Fehler eines Bildes haben 5 s Abkühlung, kein Sturm.
- Der DWD-`RadarPrefetcher` wird auf dem Backendweg nicht aktualisiert und bricht laufende Arbeit ab; beide Wege laufen nie zugleich.
- Aktualisierung: `WeatherStore.pollRadar` (alle 60 s, aktiv); ein neuer Lauf behält den gewählten Zeitpunkt (`RadarTimelineSelection`), „Jetzt“ folgt der neuen Referenz.

### Retry-Budgets (DWD-Direktweg, Nachbesserung Build 9)

Die 240 Requests/min gelten nur für den Prefetch (jeder Versuch inklusive Retry verbraucht das Fenster). Retries der sichtbaren Nachfrage haben einen eigenen Deckel: 160 je (Referenzzeit, Reload-Revision), höchstens 2 Retries je Kachel. Der erste Build-9-Wert 48 ist ersetzt: bei etwa 1/3 `InvalidDimensionValue` und 32 sichtbaren Kacheln fallen rund 14 Retries je neu angezeigtem Frame an, 48 reichten für etwa 3 Frames (Rechnung, keine Lastmessung). Der Prefetch-Worker prüft nach dem Backoff-Sleep erneut Cache, Fehlerstand und Abbruch und fragt nicht erneut an, wenn die Nachfrage die Kachel inzwischen geladen hat.

## Build-11-Kandidat: bis zu 48 h Vergangenheit (30. Oktober 2026)

Timeline bis etwa 576 + 27 Slots (rund 600). Unverändert: Reihenfolge `RadarPrefetchPolicy.order` (abwechselnd links/rechts vom gewählten Slot), 4 parallele Requests, 50-MB-RAM-Cache für komprimierte Bilder, höchstens 8 dekodierte Bilder (ca. 5 MB je Bild, also ca. 40 MB), Sperre bei Datensparmodus (damit kein Vorladen weit entfernter Slots), Low Power und inaktiver App. Der Cache ist über Läufe/Loader hinweg geteilt; unveränderte Slot-URLs werden nicht erneut geladen, ein neuer Lauf lädt nur neue Slots.

Neu: **Vorlade-Obergrenze 40.000.000 Byte** (`RadarBackendPolicy.prefetchCacheCeiling`, 80 % des Caches). Begründung: Der Cache verdrängt den am längsten ungenutzten Eintrag; beim Vorladen von außen nach innen wären das gerade die zuerst geladenen, nächsten Slots. Mit der Obergrenze hört das Vorladen auf, bevor Verdrängung beginnt (die nächsten Slots bleiben, entfernte werden ggf. erst bei Bedarf geladen), und der Platz für sichtbare Nachfrage bleibt frei. Zahlen: bei der dokumentierten Bildgröße von ca. 6 KB (Annahme, nicht für Historie gemessen) sind 600 Bilder ca. 3,6 MB, weit unter der Obergrenze; pessimistisch 100 KB je Bild wären 60 MB, dann stoppt das Vorladen bei ca. 400 Bildern. Request-Zahl: einmalig bis ca. 600 Requests bei 4 parallel (kein Fenster-Rate-Limit im Backendweg; Lastgrenze beim eigenen Server). Tests: `RadarHistoryTests` (Reihenfolge bei 603 Slots, Cache-Harte-Grenze mit 603 x 100 KB, Obergrenze stoppt Vorladen und behält die nächsten Slots). Nicht gemessen: echte Bildgrößen der Historie, Speicherverbrauch auf dem Gerät, Wiedergabe über 48 h (Animation läuft weiter alle Slots durch).
