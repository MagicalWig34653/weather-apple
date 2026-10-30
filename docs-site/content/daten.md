# Datenquellen und Lizenz

**Quelle: Deutscher Wetterdienst.** Die Daten werden von ShowerNow verändert dargestellt (Ausschnitt, Farbpalette, Zeitleiste, abgeleitete Zusammenfassungen). Diesen Hinweis hält die App an der Karte sichtbar.

## Verwendete Produkte

- **Niederschlagsradar RV (Messung und Vorhersage):** Verzeichnisindex der Radarkomposite zur Wahl des neuesten Laufs, WMS-GetMap für die Kartenebene (EPSG:3857, heute und als Fallback), WMS-GetFeatureInfo für die Punktprognose (25 Zeitpunkte, Referenz bis +120 Minuten).
- Einzelheiten, Einheiten, Sonderwerte und Aktualitätsgrenzen: [DWD-Datenvertrag](datenvertrag.html).

## ShowerNow-Radar-Cache (Build 9, in Arbeit)

Der eigene Cache speichert pro Zeitpunkt ein Ganzbild für Deutschland (1024 × 1311 px, EPSG:3857, DWD-Farbpalette, verlustfreies WebP). Es ist eine abgeleitete Darstellung der DWD-Radardaten, keine Kopie der Originaldatei. Quellenvermerk „Quelle: Deutscher Wetterdienst“ und der Veränderungshinweis bleiben an der Karte sichtbar. Der endgültige Wortlaut des Veränderungshinweises ist noch nicht festgelegt. Details: [Radar-Cache-Backend](backend.html).

## Lizenz der Daten

Die Nutzung stützt sich auf die offene Datenlizenz des DWD (**GeoNutzV**, kompatibel mit **CC BY 4.0**). Das ist eine begründete Annahme, die mit Quellenvermerk und Veränderungshinweis erfüllt wird. Sie gilt auch für die Zwischenspeicherung im Radar-Cache. Eine schriftliche Bestätigung des DWD zur Spiegelung in einem eigenen Cache und zu Abruftakt und Lastgrenzen steht aus und ist optional.

## Beobachtete Eigenheiten (Messung, kein Vertrag)

- Zeitparameter bei Punktabfragen müssen im Format mit Millisekunden (`.000Z`) gesendet werden; die kürzere Form wurde vom Live-Dienst abgelehnt.
- Etwa jede dritte WMS-GetMap-Antwort lieferte bei einer Messung (30. Oktober 2026) HTTP 200 mit XML-Fehler `InvalidDimensionValue`, auch für veröffentlichte Läufe, und wechselte bei Wiederholung zufällig. Wiederholungen bei XML-Antworten sind daher vorgesehen.
- Das sind Beobachtungen zu einem Zeitpunkt, keine Zusagen des Anbieters.
