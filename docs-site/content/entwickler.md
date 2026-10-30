# Entwickler-Doku

## Bauen und Testen

{{BUILD}}

Ein grüner Simulatorlauf ersetzt keine Gerätetests, keine vollständige Accessibility-/Energieprüfung und keine Release-Abnahme. Weitere Details: [docs/build-and-test.md](https://github.com/MagicalWig34653/weather-apple/blob/main/docs/build-and-test.md).

## TestFlight-Stand

- Build 9 (`0.1.0 (9)`) wurde am 30. Oktober 2026 hochgeladen und von Apple angenommen. Verarbeitung und Installierbarkeit in TestFlight sind noch nicht bestätigt. Vorgänger ist Build 8.
- Geprüft im Simulator: Logiktests des Projekts (93 Tests, zwei Läufe ohne Fehler), normaler Simulatorbuild, Sichtprüfung von Cache-Weg und DWD-Fallback auf iPhone und iPad im Hochformat. Der UI-Test `testNewMapPlaceCanBeSavedRenamedPersistedAndDeleted` war schon vor Build 9 rot. Kein Gerätetest.
- Die Verteilung ist auf interne Tester beschränkt.
- Build-, Signing- und TestFlight-Status werden getrennt geführt und nur nach tatsächlicher Prüfung als erledigt gemeldet. Den aktuellen, belegten Stand nennt [docs/status.md](https://github.com/MagicalWig34653/weather-apple/blob/main/docs/status.md).
- Keine Signing-Dateien, Schlüssel oder Tokens im Repository.

## Arbeitsweise

- Das Repository ist die Quelle der Wahrheit; Sitzungen sind wegwerfbar. Entscheidungen stehen in `docs/decisions.md`, der Arbeitsstand in `docs/status.md`.
- Koordinierende Agents delegieren; jede abgegrenzte Aufgabe erhält einen frischen ausführenden Agent, unabhängige Aufgaben mit getrenntem Dateibesitz laufen parallel (höchstens drei). Details: [docs/team.md](https://github.com/MagicalWig34653/weather-apple/blob/main/docs/team.md).
- Kostensparsam arbeiten, keine unaufgeforderte Infrastruktur.

## Diese Seite

Aufbau, lokaler Build und Deployment: [docs/pages.md](https://github.com/MagicalWig34653/weather-apple/blob/main/docs/pages.md).
