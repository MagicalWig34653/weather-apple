# Interner iPhone-Test von ShowerNow

Aktueller Kandidat: ShowerNow `0.1.0 (5)` / `de.linolaske.showernow`, nach unabhängig geprüftem P0-Fix. Build 4 wurde vom Nutzer verwendet und als langsam/unvollständig kritisiert. Build 5 begrenzt automatische Fehlversuche, erhält gültige Bilder beim Refresh und zeigt Radar-Ladestatus/Cacheergebnis. Archiv/Upload werden getrennt dokumentiert; noch keine neue interne Verfügbarkeit behauptet. Keine Tester-/Rechteänderungen.

Nach tatsächlicher Verfügbarkeit von Build 5 gezielt prüfen:

- Kaltstart bis zum ersten sichtbaren Radar und bis zum Ende des Ladeindikators beobachten; Netz/DWD können variieren. Kein Instant-Versprechen.
- Warmen Refresh antippen: sofortige Rückmeldung, bei Cachetreffern Abschlusszeichen/Cachehinweis, sonst tatsächliche Radarbytes; Karte bleibt bedienbar. Punktprognose darf Radarfeedback nicht blockieren.
- Zoomen, verschieben und Frames wechseln: keine Warnung aus alten Anfragen, kein endloser Wiederholungsring. Nach Fehler explizit erneut versuchen; ein Vorgängerlauf muss als solcher erkennbar bleiben.
- Schmale Timeline unten, Play/Jetzt/Slider und Details bei Light/Dark sowie maximaler Schrift prüfen; keine überlagerten Zeitangaben.
- Lokale Einordnung nur bei Interesse auf tatsächlich modellbereitem Gerät prüfen. Sie ist unverändert und keine zusätzliche Wettervorhersage; reale Generierung bleibt bisher ungeprüft.

Auf dem physischen iPhone prüfen:

- Name ShowerNow und Radar-Icon auf dem Homescreen.
- Radar/Zeitleiste, Messung und Vorhersage sowie Play/Pause.
- Ort wählen, speichern, umbenennen, nach Neustart auswählen und löschen.
- Quellen und Datenschutz öffnen; optionalen Standort nur bei Nutzung freigeben.
- Netzfehler/Retry, fehlende oder veraltete Daten und Verhalten bei Regen.

Beobachtungen mit Version/Build und kurzem Ablauf melden; keine privaten Orte oder Koordinaten öffentlich dokumentieren. Widgets, Watch und automatische Warnungen sind noch nicht enthalten. Interne Tester benötigen ASC-Zugriff auf die App; keine Einladungen ohne gesonderten Auftrag.
