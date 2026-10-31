# Radar-Cache-Backend und Benachrichtigungen

> **Server produktiv, App-Anbindung seit Build 9, Historie mit Build 11.** Der Radar-Cache läuft unter `https://showernow.linolaske.de` und ist öffentlich erreichbar. Build 9 lädt Radarbilder zuerst von diesem Cache und fällt bei Fehler oder Daten älter als 20 Minuten auf den DWD zurück. Build 11 nutzt zusätzlich die Zeitpunktliste `history.json`; dafür ist ein Backend ab `sha-e80b6b8` nötig. Am 31. Oktober 2026 (04:59 Uhr MEZ) antwortete `history.json` mit HTTP 404; das spricht dafür, dass der Server den neuen Stand noch nicht hat (nicht abschließend belegt). Build 11 ist hochgeladen und von Apple angenommen; Verarbeitung und Installierbarkeit sind noch nicht bestätigt. Die Benachrichtigungsdienste bleiben Plan bzw. Entwurf.

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
| `GET /v1/radar/history.json` | Historie der Zeitpunkte (ab Build 11); Serverkonfiguration `HISTORY_HOURS`, Standard 48 Stunden, höchstens 72 |

Die Form von `latest.json` (Schema 1) steht im Backend-Repository. Die App lehnt unbekannte Schemaversionen ab und fällt dann auf den DWD zurück.

Die App fragt `latest.json` beim Start und beim Aktivwerden sowie danach alle 60 Sekunden ab, solange sie sichtbar ist (mit ETag; `304` ohne neue Daten). Die Bilder der Zeitleiste werden im Hintergrund vorgeladen. Dafür gelten vier parallele Anfragen und ein Arbeitsspeicher-Cache von höchstens 50 MB; Datensparmodus, Stromsparmodus und inaktive App sperren das Vorladen. Die Historie (`history.json`, ab Build 11) ergänzt die Vergangenheit der Zeitleiste; fehlt sie, bleiben es etwa eine Stunde.

## Fallback auf den DWD

Build 9 nutzt den direkten DWD-Weg bei Fehler, 404, Timeout, ungültigem Manifest oder Daten älter als 20 Minuten. Auf diesem Weg wiederholt die App DWD-XML-Fehlerantworten (`InvalidDimensionValue`) begrenzt mit Wartezeit, bis zu drei Versuche. Liefert der Cache gar keine Bilder, bleibt die App 5 Minuten auf dem DWD-Weg. Die Karte zeigt die Quelle an („ShowerNow-Cache“ bzw. „direkt vom DWD“).

## Öffentliche Seiten

Die Adressen `/datenschutz`, `/marketing` und `/support` antworteten am 31. Oktober 2026 (04:59 Uhr MEZ) mit HTTP 200. Sie sind für Apple als Datenschutz-, Marketing- und Supportadresse vorgesehen; ihr Inhalt wird vor der Einreichung gegengelesen. Details zur Apple-Einreichung: [Apple-Leitfaden](apple-externe-tests.html).

## Benachrichtigungsdienst (Entwurf)

Erst nach der nutzbaren App. Automatische Regenwarnungen bei geschlossener App hängen davon ab. Datenschutzrahmen: Registrierung nur mit aktivierter Warnung, möglichst Rasterzellreferenzen statt Koordinaten, keine Ortsnamen, keine Bewegungshistorie. Unterwegs-Warnungen folgen noch später.
