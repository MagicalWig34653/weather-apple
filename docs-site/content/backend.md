# Radar-Cache-Backend und Benachrichtigungen

> **Server produktiv, App-Anbindung in Arbeit.** Der Radar-Cache läuft unter `https://showernow.linolaske.de` und ist öffentlich erreichbar. Die App nutzt ihn in der aktuellen Version (Build 8) noch nicht. Die Anbindung für Build 9 ist **in Arbeit**: Die App soll Radarbilder dann zuerst vom Cache laden und bei Fehler oder Daten älter als 20 Minuten auf den DWD zurückfallen. Die Benachrichtigungsdienste bleiben Plan bzw. Entwurf.

Maßgeblich für den Server ist das Schwesterprojekt [weather-backend](https://github.com/MagicalWig34653/weather-backend). Dessen Dokumentation: [magicalwig34653.github.io/weather-backend](https://magicalwig34653.github.io/weather-backend/).

## Zweck

Der DWD-WMS-Dienst ist für eine Zeitleiste mit vielen Einzelbildern langsam und liefert gelegentlich Fehlerantworten. Ein eigener Cache soll jeden Radar-Zeitpunkt einmal vom DWD holen und viele Geräte schonend bedienen. Zugleich ist er die Datenbasis für spätere Benachrichtigungen. Messungen und Empfehlung stehen in [docs/research/backend-radar-cache.md](https://github.com/MagicalWig34653/weather-apple/blob/main/docs/research/backend-radar-cache.md).

## Entschiedene Eckpunkte

- Betrieb auf einem eigenen Docker Swarm mit MariaDB; der Reverse Proxy reicht nur durch, der Cache liegt im Dienst (LRU je Replikat, ETag/304, `immutable`). Zustandslose Replikate, keine Cookies, kein Redis.
- Ein Ganzbild je Zeitpunkt: 1024 × 1311 px, EPSG:3857, DWD-Palette, verlustfreies WebP. Gemessen rund 6 KB bei trockener Lage; bei flächigem Regen sind die Größen nicht gemessen und dürften deutlich größer sein.
- Quellenvermerk „Quelle: Deutscher Wetterdienst“ und Veränderungshinweis bleiben an der Karte sichtbar.

## Vertrag

| Aufruf | Zweck |
|---|---|
| `GET /v1/radar/latest.json` | aktueller Lauf mit Liste der verfügbaren Zeitpunkte |
| `GET /v1/radar/<run>/<slot>.webp` | Bild eines Zeitpunkts (`<run>` = Lauf, `<slot>` = Zeitpunkt) |

Die Form von `latest.json` (Schema 1) steht im Backend-Repository. Vorgesehen ist, dass die App unbekannte Schemaversionen ablehnt und dann auf den DWD zurückfällt. Geplant ist außerdem, `latest.json` beim Aktivwerden und danach etwa jede Minute abzufragen (nur bei sichtbarer App) und die Bilder der Zeitleiste im Hintergrund vorzuladen. Der Cache-Vertrag ist im Backend-Repository dokumentiert; die App-Seite ist noch nicht ausgeliefert.

## Fallback auf den DWD

Vorgesehen für Build 9: Die App nutzt den direkten DWD-Weg bei Fehler, Timeout oder Datenalter über 20 Minuten. Dieser Weg soll DWD-XML-Fehlerantworten (`InvalidDimensionValue`) begrenzt mit Wartezeit wiederholen. Die App soll anzeigen, ob die Radarbilder aus dem ShowerNow-Cache oder direkt vom DWD stammen. Bis Build 9 ausgeliefert ist, gilt für die Radarkarte der direkte DWD-Weg (siehe [Funktionen](funktionen.html)).

## Benachrichtigungsdienst (Entwurf)

Erst nach der nutzbaren App. Automatische Regenwarnungen bei geschlossener App hängen davon ab. Datenschutzrahmen: Registrierung nur mit aktivierter Warnung, möglichst Rasterzellreferenzen statt Koordinaten, keine Ortsnamen, keine Bewegungshistorie. Unterwegs-Warnungen folgen noch später.
