# Datenschutz

Datenschutz ist eine Produktanforderung. Stand: Build 8, Abweichungen durch die geplante Radar-Cache-Anbindung (Build 9, in Arbeit) sind gekennzeichnet.

- **Kein Tracking, keine Werbung, keine Analyse-SDKs, keine Benutzerkonten.**
- **Standort nur optional und nur bei Nutzung.** Die Berechtigung wird erst angefragt, wenn du den Standort verwenden willst. Es gibt keine Hintergrundortung und keine Standortverläufe.
- **Ortsnamen und gespeicherte Orte bleiben lokal auf dem Gerät.**
- **Radarbilder heute direkt beim DWD (Build 8).** Der Deutsche Wetterdienst sieht dabei den abgefragten Kartenausschnitt und – wie bei jeder Verbindung – die IP-Adresse.
- **Radarbilder vom ShowerNow-Cache (Build 9, in Arbeit).** Die App soll dann Radarbilder für ganz Deutschland vom ShowerNow-Radar-Server laden, ohne Ortsangabe, ohne Cookies und ohne Kennung. Der Server sieht nur den Abruf eines Ganzbilds (technisch die IP-Adresse), keinen Ort und keine Standortverläufe. Laut Backend-Dokumentation gibt es keine Zugriffsprotokolle mit IP-Adressen. Bei Fehlern oder Daten älter als 20 Minuten soll die App die Radarbilder direkt beim Deutschen Wetterdienst laden.
- **Punktprognose direkt beim DWD.** Dabei sind – wie bei jeder Netzverbindung – IP-Adresse und der abgefragte Punkt für den Betreiber des Dienstes sichtbar. Dieser Weg bleibt vorerst unverändert.
- **Keine identifizierenden Debuglogs.** URLs, Standorte und Fehler-Rohdaten werden nicht geloggt; Zwischenspeicher liegen im Arbeitsspeicher.
- **Lokale KI-Einordnung** läuft ausschließlich auf dem Gerät und erhält keine Koordinaten oder Ortsnamen.

## Geplant (Entwurf, nicht umgesetzt)

Falls später Regenwarnungen bei geschlossener App kommen, gilt: keine Serverregistrierung ohne aktivierte Warnung, möglichst Rasterzellreferenzen statt exakter Koordinaten, keine Ortsnamen und keine Bewegungshistorie. Siehe [Radar-Cache-Backend und Benachrichtigungen](backend.html).

Die rechtlichen Texte der App-Store-Veröffentlichung (Datenschutzerklärung, Privacy-Angaben) sind noch nicht erstellt.
