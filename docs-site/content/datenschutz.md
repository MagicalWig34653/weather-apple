# Datenschutz

Datenschutz ist eine Produktanforderung. Aktueller Stand der App (ohne eigenes Backend):

- **Kein Tracking, keine Werbung, keine Analyse-SDKs, keine Benutzerkonten.**
- **Standort nur optional und nur bei Nutzung.** Die Berechtigung wird erst angefragt, wenn du den Standort verwenden willst. Es gibt keine Hintergrundortung und keine Standortverläufe.
- **Ortsnamen und gespeicherte Orte bleiben lokal auf dem Gerät.**
- **Direkte Abfragen beim DWD.** Karte und Punktprognose werden direkt beim Deutschen Wetterdienst abgefragt. Dabei sind – wie bei jeder Netzverbindung – IP-Adresse und der abgefragte Kartenausschnitt bzw. Punkt für den Betreiber des Dienstes sichtbar.
- **Keine identifizierenden Debuglogs.** URLs, Standorte und Fehler-Rohdaten werden nicht geloggt; Zwischenspeicher liegen im Arbeitsspeicher.
- **Lokale KI-Einordnung** läuft ausschließlich auf dem Gerät und erhält keine Koordinaten oder Ortsnamen.

## Geplant (Entwurf, nicht umgesetzt)

Falls später Regenwarnungen bei geschlossener App kommen, gilt: keine Serverregistrierung ohne aktivierte Warnung, möglichst Rasterzellreferenzen statt exakter Koordinaten, keine Ortsnamen und keine Bewegungshistorie. Siehe [Radar-Cache-Backend und Benachrichtigungen](backend.html).

Die rechtlichen Texte der App-Store-Veröffentlichung (Datenschutzerklärung, Privacy-Angaben) sind noch nicht erstellt.
