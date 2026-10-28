# Gezieltes Nachladen und Caching

Stand: 28. Oktober 2026. Nutzerfeedback nach funktionierendem internem TestFlight-Build: Nachladen wirkt langsam. Die folgenden Befunde trennen nachgewiesene Request-/Ablaufkosten von noch nicht gemessener Geschwindigkeit auf dem iPhone.

## Befunde und Änderung

- `WeatherStore.refresh()` wartete vorher auf Punktprognose und Radarindex zusammen, bevor es eines der Ergebnisse veröffentlichte. Deshalb konnte eine langsame Punktantwort den Beginn des Radarladens verzögern. Beide Ergebnisse werden nun unabhängig übernommen; dieselbe Orts-/Requestgeneration und Cancellationprüfung schützt weiterhin vor verspäteten Antworten.
- Der Index wurde bereits für fünf Minuten im Speicher gehalten und für parallele Verbraucher zusammengeführt. Dieselbe Wiederverwendung fehlte für gleichzeitig angefragte Punktprognosen. Diese werden nun anhand Koordinate **und explizitem Datenlauf** zusammengeführt. Der Abbruch eines Verbrauchers beendet nicht die gemeinsame Anfrage anderer Verbraucher; der abgebrochene Verbraucher erhält kein Ergebnis.
- Der Punktcache bleibt auf 20 Einträge und fünf Minuten begrenzt. Ein neuer Eintrag verdrängt den ältesten statt den gesamten Cache zu leeren. Vor Wiederverwendung wird der aktuelle Indexlauf geprüft; veraltete Prognosen bleiben ausgeschlossen.
- Radar-PNGs blieben bereits im begrenzten 48-MiB-Speichercache. Zusätzliche gleichzeitige MapKit-Anfragen derselben Kachel werden jetzt innerhalb eines Overlays zusammengeführt. Beim Entfernen eines Overlays werden alle wartenden Verbraucher einmalig abgebrochen. Fehler werden nicht gecacht, der nächste Overlay-/Refreshversuch darf erneut laden.
- Die Kachelidentität enthält weiterhin Zoom/Ausschnitt, Framezeit und Referenzlauf in der vollständigen Wetterbild-URL. Historische Messframes und Vorhersage desselben Zeitpunkts aus verschiedenen Läufen werden nicht vermischt. Bei Ortswechsel bleibt derselbe Wetterbildcache für überlappende Kartenflächen nutzbar; Orts-Punktanfragen werden separat behandelt.

Es gibt bewusst keinen zusätzlichen Diskcache und kein pauschales Vorladen der Animationsframes. Dafür fehlt bisher ein belegter Vorteil gegenüber zusätzlichem Speicher-/Netzaufwand. Anfragen mit exakten Punktkoordinaten und Karten-/URLverläufe werden nicht auf Disk persistiert oder protokolliert. Gespeicherte Orte bleiben die ausdrückliche lokale Nutzerfunktion.

## Begrenzte Vorher-/Nachherprüfung

Ein isolierter Swift-6-CLI-Probe verwendete die bestehende archivierte WMS-Fixture, eine feste Uhr und einen injizierten Transport mit 100 ms künstlich verzögerter Punktantwort. Zwei parallele Aufrufe derselben Punktprognose lieferten jeweils 25 Samples:

| Quellenstand | Indexabrufe | Punktabrufe |
| --- | ---: | ---: |
| bisheriger veröffentlichter Stand | 1 | 2 |
| neuer Datenclient | 1 | 1 |

Beide Probeprogramme wurden kompiliert und liefen erfolgreich. Das belegt einen vermiedenen Abruf bei diesem überlappenden Aufrufmuster, keine pauschale Ladezeit-, Akku- oder DWD-Verfügbarkeitsverbesserung. Kein Live-DWD-Abruf war dafür erforderlich. Swift-Syntaxprüfung der geänderten Daten-, Map-, Store- und Testdateien sowie direkte Swift-6-Typprüfung des App-Datenkerns einschließlich Map/Store gegen das iOS-27-Simulator-SDK erfolgreich. Eine separate XCTest-Typprüfung ohne vollständige Xcode-Testumgebung konnte das XCTest-Swift-Overlay nicht auflösen; maßgeblich ist deshalb der anschließende erfolgreiche echte XCTestlauf.

Der UI-/Simulator-Owner führte den integrierten Snapshot auf iPhone 18 Pro mit iOS 27/SDK 27.1 aus: **18 Datentests erfolgreich, null Fehler**; zusammen mit acht KI-Tests **26 Tests erfolgreich**, Testausführungszeit 0,369 Sekunden. Das ist keine App-Ladezeitmessung. Sechs neue Datentests decken ab:

- Zwei parallele Punktverbraucher teilen einen Abruf; ein abgebrochener Verbraucher vergiftet weder den zweiten noch den Cache.
- Der Fake-Transport hält die Punktantwort per Continuation zurück: Die Timeline muss schon vorhanden sein, während die Punktprognose fehlt und der Ladevorgang läuft. Erst danach wird die Punktantwort freigegeben. Damit ist die frühere gemeinsame Veröffentlichung als Regression prüfbar, ohne Live-DWD-Timing.
- Ein abgebrochener Refresh übernimmt keine verzögerte Punktantwort; ein folgender Refresh kann wieder erfolgreich laden.
- Cacheablauf löst neue Index-/Punktabrufe aus; alte Daten werden weiterhin zurückgewiesen.
- Zwei gleiche Tile-Anfragen erhalten bei Overlay-Abbruch genau je einen Cancellation-Callback; späte Antwort und wiederholter Abbruch liefern keine zweiten Callbacks.
- Eine abgeschlossene Tile-Anfrage verteilt ihren Fehler an beide Verbraucher; fremde Request-ID wird ignoriert und ein neues Overlay darf erneut versuchen.

Keine Simulator-/Buildressource wurde parallel verwendet. Die Registry-Tests prüfen kontrollierte Completion-/Abbruchreihenfolgen, keine exhaustive Thread-Stressprüfung. Standort-/Refreshgenerationen werden weiterhin vor jeder unabhängigen Veröffentlichung geprüft; reale schnelle Orts-/Zeitwechsel und Kachelfehler bleiben Gegenstand der integrierten UI-/Alltagsprüfung.

## Grenzen und nächster Schritt

Keine Messung auf physischem iPhone und keine neue Live-Latenz-/Speicherstudie. Der bisherige Kachelcache hilft erst nach erfolgreichen Antworten; erstmalige oder zuvor abgebrochene Animationsframes benötigen weiterhin Netzabrufe. Schnelle Zeitwechsel brechen überholte Requests weiterhin ab, statt alle Vorhersageframes im Hintergrund zu laden. Nächster Schritt: unabhängiges Integrationsreview des kombinierten UI-/Datenstands; anschließend Alltagsbeobachtung beim Nutzer ohne private Standortlogs.
