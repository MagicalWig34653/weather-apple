# Interner iPhone-Test von ShowerNow

Aktueller Stand: ShowerNow `0.1.0 (3)` / `de.linolaske.showernow` funktioniert laut Nutzer intern über TestFlight. Der damalige Uploadabschluss und Serverzustand sind im [Uploadbefund](testflight-upload.md) dokumentiert. Build `0.1.0 (4)` ist als neuer Verbesserungskandidat integriert und im Simulator kompiliert; Review, signierte Archivprüfung und Upload stehen noch aus. Keine neue interne Verfügbarkeit für Build 4 behauptet. Agents haben keine Tester, Rollen, Gruppen oder Einladungen verändert.

Die folgenden zusätzlichen Alltagstests nach tatsächlicher Verfügbarkeit von Build 4 durchführen:

- Beim Laden prüfen, ob Radar schon sichtbar wird, während die Ortsprognose noch lädt; wiederholte Orts-/Zeitwechsel und manuellen Refresh beobachten.
- Kompakte schwebende Bedienung bei Light/Dark und großer Schrift prüfen; Jetzt, Play/Pause und Details müssen erreichbar bleiben.
- In Details die Einordnung prüfen. Bei nur einem belegten Fakt bleibt der Standardtext ohne Modellrequest. Sonst manuell lokal einordnen; bei ungeeignetem Gerät, deaktiviertem Apple Intelligence oder nicht bereitem Modell bleibt die Standard-Einordnung erhalten. Echte Modellgeneration ist bislang nicht auf bereiter Hardware belegt. Keine zusätzliche Vorhersage oder amtliche Warnung daraus ableiten.

Auf dem physischen iPhone prüfen:

- Name ShowerNow und Radar-Icon auf dem Homescreen.
- Radar/Zeitleiste, Messung und Vorhersage sowie Play/Pause.
- Ort wählen, speichern, umbenennen, nach Neustart auswählen und löschen.
- Quellen und Datenschutz öffnen; optionalen Standort nur bei Nutzung freigeben.
- Netzfehler/Retry, fehlende oder veraltete Daten und Verhalten bei Regen.

Beobachtungen mit Version/Build und kurzem Ablauf melden; keine privaten Orte oder Koordinaten öffentlich dokumentieren. Widgets, Watch und automatische Warnungen sind noch nicht enthalten. Interne Tester benötigen ASC-Zugriff auf die App; keine Einladungen ohne gesonderten Auftrag.
