# Direkter DWD-Datenvertrag der ersten iPhone-Version

Stand: 28. Oktober 2026. Implementierung: `Weather/Data/`. Kein eigener Server und keine externen Swift-Abhängigkeiten.

## Datenweg

1. Der offizielle RV-Verzeichnisindex wird nach datierten `composite_rv_YYYYMMDD_HHMM.tar`-Einträgen gelesen. Die neueste vorhandene Referenz wird ausgewählt; keine TAR-Datei wird auf dem Gerät geladen. Der langsamere und beim Versuch veraltete WMS-Capabilities-Default wird nicht als aktuell ausgegeben.
2. Zeitparameter werden explizit als UTC mit Millisekunden erzeugt (`YYYY-MM-DDTHH:mm:ss.SSSZ`, z. B. `2026-10-28T15:15:00.000Z`). Im Livevergleich desselben Laufs lieferte `DIM_REFERENCE_TIME` ohne Millisekunden eine XML-Fehlermeldung trotz HTTP200, während `.000Z` erfolgreich war. GetMap-PNG allein beweist keine Punktabfrageverfügbarkeit. Dieser lexikalische Unterschied wird deshalb exakt getestet; kein Verfügbarkeitsfallback wird daraus abgeleitet.
3. Ein expliziter WMS-GetFeatureInfo-Request am Layer `dwd:Niederschlagsradar` fordert genau 25 Zeiten von Referenz bis +120 Minuten an. WMS 1.3.0 und EPSG:4326 verlangen Breite/Länge im BBOX. Ein symmetrisches 3×3-Pixel-Bild mit Abfrage am Mittelpunkt wird verwendet.
4. Genau 25 lückenlose Fünf-Minuten-Schritte und übereinstimmende `REFERENCE_TIME` werden vorausgesetzt. Ein Ersatzlauf, doppelte Zeiten, Lücken, XML-Fehlermeldungen und unbekannte Antwortformate werden abgelehnt.
5. `RV_ANALYSIS` entspricht im abgeglichenen Kontrolllauf einer Fünf-Minuten-Akkumulation. `amountMM` ist diese Menge; `rateMMPerHour` ist deren zwölfmaliger Wert als Intervallmittel, keine unabhängige Momentanmessung.

Primärquellen und realer 25-Werte-Abgleich: [WMS-Befund](research/wms-point-query.md), [Rohdatenbefund](research/dwd-validation.md). Der Produktdatenweg ist damit für den ersten Prototyp begründet; allgemeine Verfügbarkeit und alle NoData-Randfälle sind nicht garantiert.

## Unbekannt, trocken und Aktualität

- Der durch Rohdatenvergleich bestätigte Undetect-Wert `−0.001` wird ausschließlich innerhalb absoluter Toleranz `1e-8` zu null umgerechnet. Andere negative Werte, null, nicht endliche Zahlen und Werte über 100 mm pro fünf Minuten bleiben unbekannt. Die obere Grenze ist eine konservative Plausibilitätsregel, keine DWD-Spezifikation; sie verhindert insbesondere die Interpretation skalierter uint32-NoData-Werte als Starkregen.
- Eine vollständig unbekannte Serie wird abgelehnt. Bei einzelnen unbekannten Werten darf die Zusammenfassung keinen durchgängig trockenen Zeitraum behaupten.
- Vorläufige konservative Produktregel: maximal 20 Minuten alter Datenlauf; eine mehr als 60 Sekunden in der Zukunft liegende Referenz wird ebenfalls abgelehnt. Diese Schwellen sind explizit konfiguriert und getestet, nicht als Anbieterzusage zu verstehen.
- Die Prognose reicht bis Referenz +120 Minuten. Bei einem zehn Minuten alten Lauf verbleiben ungefähr 110 Minuten, nicht automatisch zwei Stunden ab Abruf.
- Die textliche Regenanzeige verwendet vorläufig 0.1 mm/h als messbaren Regen. Das ist eine UI-Schwelle, noch keine Push-Ereignisdefinition.

## Radar und Cache

`radarTimeline()` gibt tatsächlich im Index vorhandene Analyseläufe der letzten 60 Minuten sowie die 25 Vorhersagezeitpunkte des neuesten Laufs zurück. Historische Frames müssen mit ihrer eigenen Referenz abgefragt werden; ab neuester Referenz ist immer deren Referenz zu verwenden.

`DWDRequest.tileURL` konstruiert GetMap-Abfragen für 256-Pixel-Kacheln, EPSG:3857 und WMS 1.1.1 mit x/y-Achsenfolge. Die UI muss die passende Referenz wählen und Datenalter zeigen.

Der Client verwendet eine ephemeral URLSession ohne URLCache und mit 20 Sekunden Request-/30 Sekunden Ressourcenlimit. Keine URL-, Standort- oder Fehler-Rohdaten werden geloggt. Index und bis zu 20 Ortsprognosen bleiben ausschließlich im Speicher, jeweils höchstens fünf Minuten. Gleichzeitige Indexanfragen werden zusammengeführt. Eine persistente lokale Prognosekopie kann die UI separat speichern und muss ihr Alter anzeigen.

Der Client wiederholt Index- und Punktabruf höchstens zweimal (3 Requests) bei `InvalidDimensionValue`, HTTP 502/503/504 und transienten `URLError`; Inhaltsfehler werden als eigene `DWDDataError`-Fälle gemeldet (siehe `decisions.md`). `WeatherStore` hält je Ort (höchstens 10) die zuletzt gültige Punktprognose nur im Speicher und zeigt sie bei Fehlern mit Alter; die 20-Minuten-Grenze gilt unverändert.

Die unterstützte Koordinatenhülle ist vorläufig 45–56.5°N und 0–20°E; sie ist keine Garantie tatsächlicher Radar-Abdeckung. Fehlende Daten bleiben auch innerhalb dieser Hülle unbekannt.

## Prüfungen und offene Grenzen

`WeatherTests/DWDDataTests.swift` prüft die reale WMS-Fixture, Einheitenumrechnung, Sentinelwerte, null, fremde/alte/zukünftige Läufe, Zeitlücken, Projektion/Achsenfolge sowie Request-Zusammenführung und Cache. Fixture enthält einen öffentlichen Wetterpunkt, keine Nutzerposition.

Offen bleiben allgemeine Zellgrenzen-/NoData-Verifikation, Quellenänderungen, Ausfallverhalten im Alltag und iPhone-Energieverbrauch. Die Tests sind offline und ersetzen keine regelmäßig begrenzte Live-Prüfung. Build-/Testausführung dokumentiert die koordinierende Instanz im Arbeitsstatus.

## Radar-Cache-Backend (Build 9)

Quelle `RadarBackendConfig.productionBaseURL` (`https://showernow.linolaske.de/v1/radar/`). `GET latest.json` (Schema 1: `run`, `reference_time`, `generated_at`, `step_minutes`, `image` mit `format` `image/webp`, `width`, `height`, `projection` `EPSG:3857`, `bbox`, `slots[]` mit `time`, `kind` `analysis|forecast`, `path`, `attribution`, `modification_notice`; ETag, `max-age=30`; 404 solange nichts veröffentlicht ist) und `GET <run>/<slot>.webp` (ein Ganzbild für Deutschland, unveränderlich, ETag/304). Keine Ortsangabe, keine Cookies. Die App validiert strikt (siehe `RadarManifest.parse`), lehnt unbekannte Schemaversionen ab und nutzt Daten nur bis 20 Minuten Alter; sonst DWD-Direktweg. Fixture einer echten Antwort: `WeatherTests/Fixtures/radar-latest.json`. Attribution und Veränderungshinweis aus dem Manifest werden in der App angezeigt. Die Punktprognose bleibt direkt beim DWD.

## `history.json` (Build-11-Kandidat, neu, additiv)

`GET /v1/radar/history.json` (ETag, `Cache-Control: public, max-age=60`). Schema 1: `run`, `generated_at`, `step_minutes`, `history_hours` (Serverkonfiguration, kann unter 48 liegen), `image` (identisch zu `latest.json`), `slots` (`time`, `kind` = nur `analysis`, `path` relativ zu `/v1/radar/`), `attribution`, `modification_notice`. Slots aufsteigend, 5-Minuten-Raster, Lücken erlaubt. `path` ist für die App opak (Bild unter `/v1/radar/<path>`, nicht aus `time` rekonstruieren).

App-Validierung (`RadarHistory.parse`): bekanntes Schema 1, Run-ID-Format, `generated_at` nicht in der Zukunft, `step_minutes` 1..60, `history_hours` 1..168, Bild wie bei `latest.json`, 1..1000 Slots, nur `analysis`, streng aufsteigend ohne Duplikate, Slot nicht nach `generated_at`, `path` nur 1 bis 4 einfache Segmente mit `.webp` (kein Schema, keine Traversal, keine Query), Host/Pfadpräfix wie Radar-Basis. Alles andere gilt als ungültig und führt zum Fallback auf die Vergangenheit aus `latest.json`. Die Historie wird nur genutzt, wenn Bildgröße und bbox zu `latest.json` passen; Historien-Slots nach der Referenzzeit werden verworfen. **Gegen das Live-Backend ungetestet** (Stand der Entwicklung: noch nicht deployt); Fixture `WeatherTests/Fixtures/radar-history.json` ist synthetisch.
