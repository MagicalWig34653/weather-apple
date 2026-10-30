# Datenschutz

Datenschutz ist eine Produktanforderung. Stand: Build 9 (hochgeladen, Installierbarkeit noch nicht bestätigt). Gegenüber Build 8 ändert sich der Weg der Radarbilder; das ist unten gekennzeichnet.

- **Kein Tracking, keine Werbung, keine Analyse-SDKs, keine Benutzerkonten.**
- **Standort nur optional und nur bei Nutzung.** Die Berechtigung wird erst angefragt, wenn du den Standort verwenden willst. Es gibt keine Hintergrundortung und keine Standortverläufe.
- **Ortsnamen und gespeicherte Orte bleiben lokal auf dem Gerät.**
- **Radarbilder vom ShowerNow-Cache (ab Build 9).** Die App lädt Radarbilder für ganz Deutschland vom ShowerNow-Radar-Server, ohne Ortsangabe, ohne Cookies und ohne Kennung. Der Server sieht nur den Abruf eines Ganzbilds (technisch die IP-Adresse), keinen Ort und keine Standortverläufe. Laut Backend-Dokumentation gibt es keine Zugriffsprotokolle mit IP-Adressen.
- **Radarbilder direkt beim DWD (Build 8 und Fallback).** Bei Fehlern oder Daten älter als 20 Minuten lädt die App die Radarbilder direkt beim Deutschen Wetterdienst. Dieser sieht dabei den abgefragten Kartenausschnitt und – wie bei jeder Verbindung – die IP-Adresse.
- **Punktprognose direkt beim DWD.** Dabei sind – wie bei jeder Netzverbindung – IP-Adresse und der abgefragte Punkt für den Betreiber des Dienstes sichtbar. Dieser Weg bleibt vorerst unverändert.
- **Keine identifizierenden Debuglogs.** URLs, Standorte und Fehler-Rohdaten werden nicht geloggt; Zwischenspeicher liegen im Arbeitsspeicher.
- **Lokale KI-Einordnung** läuft ausschließlich auf dem Gerät und erhält keine Koordinaten oder Ortsnamen.

## Geplant (Entwurf, nicht umgesetzt)

Falls später Regenwarnungen bei geschlossener App kommen, gilt: keine Serverregistrierung ohne aktivierte Warnung, möglichst Rasterzellreferenzen statt exakter Koordinaten, keine Ortsnamen und keine Bewegungshistorie. Siehe [Radar-Cache-Backend und Benachrichtigungen](backend.html).

Die rechtlichen Texte der App-Store-Veröffentlichung (Datenschutzerklärung, Privacy-Angaben) sind noch nicht erstellt.
