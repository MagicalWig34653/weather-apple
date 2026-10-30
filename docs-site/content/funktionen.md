# Funktionen und Bedienung

Stand: Build 8 (interne Beta). Beschrieben ist, was im Repository umgesetzt und dokumentiert ist; Geräte- und Langzeitprüfungen sind teilweise noch offen (siehe [Roadmap](roadmap.html)).

## Radar und Zeitleiste

- Hauptansicht ist eine Karte (MapKit) mit dem DWD-Niederschlagsradar als transparenter Ebene.
- Die Zeitleiste umfasst die letzten 60 Minuten (Messung) und bis zu zwei Stunden Vorhersage. Messung und Vorhersage sind sichtbar unterschieden, das Datenalter wird angezeigt.
- Play/Pause, „Jetzt“ und ein kompakter, schwebender Zeit-Slider im Liquid-Glass-Stil.
- Der Slider folgt dem Finger unabhängig vom Netz. Eine Statuspille nennt den Zustand des angezeigten Zeitpunkts („lädt“ / „nicht geladen“); ein altes Bild gilt nie als Stand des gewählten Zeitpunkts. Jeder Zeitpunktwechsel gibt eine leichte Haptik.

## Vorladen

Ab Build 8 lädt die App nach dem sichtbaren Frame die übrigen Zeitpunkte des Kartenausschnitts im Hintergrund vor, beginnend beim gewählten Zeitpunkt und abwechselnd nach links und rechts. Der Cache liegt nur im Arbeitsspeicher (höchstens 50.000.000 Byte validierter Bilddaten).

Schutzwerte gegen Überlastung der DWD-Schnittstelle: drei parallele Anfragen, 250 ms Abstand, höchstens 240 Anfragen je 60 Sekunden, Bytestopp 8.000.000 je Fenster, Abbruch nach drei aufeinanderfolgenden Quellfehlern. Datensparmodus, Stromsparmodus und inaktive App sperren das Vorladen; WLAN und Mobilfunk sind sonst erlaubt. Die wahrgenommene Ladezeit ist Nutzerfeedback aus dem Alltagstest, keine Laborstudie; ein kalter Erstabruf hängt von Netz und DWD ab.

## Orte

- Ortssuche und lokal gespeicherte Orte (Umbenennen, Auswählen, Löschen). Ortsnamen bleiben auf dem Gerät.
- Optionaler Standort: die Berechtigung wird erst bei Nutzung angefragt; keine Hintergrundortung.

## Punktprognose

Für den gewählten Ort fragt die App den DWD direkt ab (WMS-Punktabfrage, 25 Fünf-Minuten-Werte bis +120 Minuten ab Referenzzeit) und zeigt den Niederschlagsverlauf, erwarteten Beginn und Ende sowie die Intensität nur im durch die Daten gedeckten Umfang. Fehlende Werte werden nie als „trocken“ ausgegeben. Details: [DWD-Datenvertrag](datenvertrag.html).

## Lokale Einordnung (optional)

Wo verfügbar, wählt Apple Foundation Models auf dem Gerät höchstens zwei belegte Fakten aus; die App zeigt dazu ausschließlich vorbereitete deutsche Sätze. Es entstehen keine zusätzliche Prognose, keine erfundenen Zahlen und keine Warnungen. Die Funktion ist manuell auslösbar; echte Generierung auf einem modellbereiten Gerät ist bisher nicht geprüft.

## Darstellung und Bedienbarkeit

Light/Dark Mode, Dynamic Type und VoiceOver werden berücksichtigt; ein vollständiger Accessibility-Durchgang auf dem Gerät steht noch aus.
