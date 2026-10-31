# Funktionen und Bedienung

Stand: Build 11 (hochgeladen, Installierbarkeit in TestFlight noch nicht bestätigt). Beschrieben ist, was im Repository umgesetzt und dokumentiert ist; Geräte- und Langzeitprüfungen sind teilweise noch offen (siehe [Roadmap](roadmap.html)).

## Radar und Zeitleiste

- Hauptansicht ist eine Karte (MapKit) mit dem DWD-Niederschlagsradar als transparenter Ebene. Mit Build 9 kommt die Ebene zuerst vom ShowerNow-Cache; bei Fehler oder Daten älter als 20 Minuten lädt die App sie direkt vom DWD. Die Karte zeigt die Quelle („ShowerNow-Cache“ bzw. „direkt vom DWD“). Neue Radarläufe prüft die App alle 60 Sekunden, solange sie sichtbar ist.
- Die Zeitleiste zeigt standardmäßig die letzten 2 Stunden Messung und bis zu zwei Stunden Vorhersage. Die Einstellung „Maximale Vergangenheit“ wählt 1, 2, 6, 12, 24 oder 48 Stunden (Standard: 2 Stunden). Die Zeitpunkte der Vergangenheit kommen aus der Historie des Radar-Cache (`history.json`); fehlt sie, zeigt die App etwa eine Stunde, ebenso auf dem direkten DWD-Weg. Messung und Vorhersage sind sichtbar unterschieden, das Datenalter wird angezeigt. Die Animation umfasst höchstens 3 Stunden Vergangenheit bis zum Ende der Vorhersage.
- Play/Pause, „Jetzt“ und ein kompakter, schwebender Zeit-Slider im Liquid-Glass-Stil.
- Der Slider folgt dem Finger unabhängig vom Netz. Eine Statuspille nennt den Zustand des angezeigten Zeitpunkts („lädt“ / „nicht geladen“); ein altes Bild gilt nie als Stand des gewählten Zeitpunkts. Jeder Zeitpunktwechsel gibt eine leichte Haptik. Zieht man den Finger zusätzlich vertikal vom Slider weg, wird die Bewegung feiner: ab 40, 90 und 150 pt Abstand auf 0,5-, 0,25- und 0,1-fache Schritte (Startwerte, am Gerät noch nicht erprobt).

## Vorladen

Ab Build 8 lädt die App nach dem sichtbaren Frame die übrigen Zeitpunkte des Kartenausschnitts im Hintergrund vor, beginnend beim gewählten Zeitpunkt und abwechselnd nach links und rechts. Der Cache liegt nur im Arbeitsspeicher (höchstens 50.000.000 Byte validierter Bilddaten). Datensparmodus, Stromsparmodus und inaktive App sperren das Vorladen; die sichtbare Nachfrage bleibt erlaubt. WLAN und Mobilfunk sind sonst erlaubt.

Mit Build 9 gilt: Beim Laden aus dem ShowerNow-Cache läuft das Vorladen mit vier parallelen Anfragen über denselben Arbeitsspeicher-Cache. Die Grenzen dieses Wegs sind noch nicht gemessen.

Auf dem DWD-Weg (Fallback) gelten die Schutzwerte gegen Überlastung der DWD-Schnittstelle: drei parallele Anfragen, 250 ms Abstand, höchstens 240 Anfragen je 60 Sekunden, Bytestopp 8.000.000 je Fenster, Abbruch nach drei aufeinanderfolgenden Quellfehlern.

Die wahrgenommene Ladezeit ist Nutzerfeedback aus dem Alltagstest, keine Laborstudie; ein kalter Erstabruf hängt von Netz und Quelle ab.

## Orte

- Ortssuche und lokal gespeicherte Orte (Umbenennen, Auswählen, Löschen). Ortsnamen bleiben auf dem Gerät.
- Optionaler Standort: die Berechtigung wird erst bei Nutzung angefragt; keine Hintergrundortung.

## Punktprognose

Für den gewählten Ort fragt die App den DWD direkt ab (WMS-Punktabfrage, 25 Fünf-Minuten-Werte bis +120 Minuten ab Referenzzeit) und zeigt den Niederschlagsverlauf, erwarteten Beginn und Ende sowie die Intensität nur im durch die Daten gedeckten Umfang. Fehlende Werte werden nie als „trocken“ ausgegeben. Bei Antworten 502, 503 oder 504 und kurzen Netzfehlern wiederholt die App die Anfrage, höchstens dreimal insgesamt. Die Fehlermeldungen unterscheiden die Ursachen. Schlägt eine Aktualisierung fehl, zeigt die App die letzte gültige Prognose des Ortes mit Altersangabe (bis zu 10 Orte). Details: [DWD-Datenvertrag](datenvertrag.html).

## Lokale Einordnung (optional)

Wo verfügbar, wählt Apple Foundation Models auf dem Gerät höchstens zwei belegte Fakten aus; die App zeigt dazu ausschließlich vorbereitete deutsche Sätze. Es entstehen keine zusätzliche Prognose, keine erfundenen Zahlen und keine Warnungen. Die Funktion ist manuell auslösbar; echte Generierung auf einem modellbereiten Gerät ist bisher nicht geprüft.

## Darstellung und Bedienbarkeit

Light/Dark Mode, Dynamic Type und VoiceOver werden berücksichtigt; ein vollständiger Accessibility-Durchgang auf dem Gerät steht noch aus.

## Bekannte Grenzen (Build 11)

- Nicht geprüft: Georeferenz, Rand der Radarabdeckung und Transparenz bei echtem Regen. Im Simulator fiel praktisch kein Regen, ein belastbarer Vergleich mit dem DWD-Bild fehlt daher.
- Auf dem DWD-Weg kann weiterhin das Banner „Einige Radarkacheln fehlen“ erscheinen, wenn der DWD Kachelanfragen fehlerhaft beantwortet.
- Kein Gerätetest. iPad im Querformat und der Dark Mode auf dem iPad sind nicht geprüft.
- Build 11 ist nicht auf dem Gerät geprüft: Scrub-Geste, Einstellung „Maximale Vergangenheit“ und der Fehlerzustand der Ortsprognose (dieser nur per Unit-Test).
- Die Historie ist gegen den Live-Server nicht geprüft: `history.json` antwortete am 31. Oktober 2026 (04:59 Uhr MEZ) mit HTTP 404. Solange sie fehlt, zeigt die App einen Hinweis und etwa eine Stunde Vergangenheit.
