# Radar-Cache-Backend und Benachrichtigungen

> **Plan bzw. Entwurf.** Das Backend ist entschieden und in Arbeit, aber **nicht als produktiv bestätigt**. Die App nutzt es noch nicht (Anbindung als eigener Auftrag, Build 9 geplant). Maßgeblich ist das Schwesterprojekt [weather-backend](https://github.com/MagicalWig34653/weather-backend).

## Zweck

Der DWD-WMS-Dienst ist für eine Zeitleiste mit vielen Einzelbildern langsam und liefert gelegentlich Fehlerantworten. Ein eigener Cache soll jeden Radar-Zeitpunkt einmal vom DWD holen und viele Geräte schonend bedienen. Zugleich ist er die Datenbasis für spätere Benachrichtigungen. Messungen und Empfehlung stehen in [docs/research/backend-radar-cache.md](https://github.com/MagicalWig34653/weather-apple/blob/main/docs/research/backend-radar-cache.md).

## Entschiedene Eckpunkte

- Betrieb auf einem vorhandenen Docker Swarm mit MariaDB; der Reverse Proxy reicht nur durch, der Cache liegt im Dienst (LRU je Replikat, ETag/304, `immutable`). Zustandslose Replikate, keine Cookies, kein Redis.
- Ein Ganzbild je Zeitpunkt: 1024 × 1311 px, EPSG:3857, DWD-Palette, verlustfreies WebP.
- Quellenvermerk „Quelle: Deutscher Wetterdienst“ und Veränderungshinweis bleiben an der Karte sichtbar.

## Vertrag (Entwurf)

| Aufruf | Zweck |
|---|---|
| `GET /v1/radar/latest.json` | aktueller Lauf mit Liste der verfügbaren Zeitpunkte |
| `GET /v1/radar/<run>/<slot>.webp` | Bild eines Zeitpunkts (`<run>` = Lauf, `<slot>` = Zeitpunkt) |

Die genaue Form von `latest.json` steht im Backend-Repository und kann sich bis zur Anbindung ändern.

## Fallback auf den DWD

Die App behält den direkten DWD-Weg und nutzt ihn bei Fehler, Timeout oder Datenalter über 20 Minuten. Auch dieser Weg soll XML-Fehlerantworten wiederholen (Prüfung in Build 9 offen).

## Benachrichtigungsdienst (Entwurf)

Erst nach der nutzbaren App. Automatische Regenwarnungen bei geschlossener App hängen davon ab. Datenschutzrahmen: Registrierung nur mit aktivierter Warnung, möglichst Rasterzellreferenzen statt Koordinaten, keine Ortsnamen, keine Bewegungshistorie. Unterwegs-Warnungen folgen noch später.
