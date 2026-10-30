# Datenquellen und Lizenz

**Quelle: Deutscher Wetterdienst.** Die Daten werden von ShowerNow verändert dargestellt (Ausschnitt, Farbpalette, Zeitleiste, abgeleitete Zusammenfassungen). Diesen Hinweis hält die App an der Karte sichtbar.

## Verwendete Produkte

- **Niederschlagsradar RV (Messung und Vorhersage):** Verzeichnisindex der Radarkomposite zur Wahl des neuesten Laufs, WMS-GetMap für die Kartenebene (EPSG:3857), WMS-GetFeatureInfo für die Punktprognose (25 Zeitpunkte, Referenz bis +120 Minuten).
- Einzelheiten, Einheiten, Sonderwerte und Aktualitätsgrenzen: [DWD-Datenvertrag](datenvertrag.html).

## Lizenz der Daten

Die Nutzung stützt sich auf die offene Datenlizenz des DWD (**GeoNutzV**, kompatibel mit **CC BY 4.0**). Das ist eine begründete Annahme, die mit Quellenvermerk und Veränderungshinweis erfüllt wird; eine schriftliche Bestätigung des DWD zur Spiegelung in einem eigenen Cache steht aus und ist optional.

## Beobachtete Eigenheiten (Messung, kein Vertrag)

- Zeitparameter bei Punktabfragen müssen im Format mit Millisekunden (`.000Z`) gesendet werden; die kürzere Form wurde vom Live-Dienst abgelehnt.
- Etwa jede dritte WMS-GetMap-Antwort lieferte bei einer Messung (30. Oktober 2026) HTTP 200 mit XML-Fehler `InvalidDimensionValue`, auch für veröffentlichte Läufe, und wechselte bei Wiederholung zufällig. Wiederholungen bei XML-Antworten sind daher vorgesehen.
- Das sind Beobachtungen zu einem Zeitpunkt, keine Zusagen des Anbieters.
