# Entwickler-Doku

## Bauen und Testen

{{BUILD}}

Ein grüner Simulatorlauf ersetzt keine Gerätetests, keine vollständige Accessibility-/Energieprüfung und keine Release-Abnahme. Weitere Details: [docs/build-and-test.md](https://github.com/MagicalWig34653/weather-apple/blob/main/docs/build-and-test.md).

## TestFlight-Stand

- Build 11 (`0.1.0 (11)`) wurde am 31. Oktober 2026 hochgeladen und von Apple angenommen, ohne Internal-Only-Markierung. Verarbeitung, Installierbarkeit und externe Zuordnung in App Store Connect sind noch nicht bestätigt. Vorgänger ist Build 10 (intern).
- Geprüft für Build 11 im Simulator: volle Logiktests `WeatherTests` (138 Tests, im zweiten Lauf mit gebootetem Simulator 0 Fehler; ein erster Lauf scheiterte vor dem Verbindungsaufbau), normaler Simulatorbuild, eine Sichtprüfung im Hellmodus. Der UI-Test `testNewMapPlaceCanBeSavedRenamedPersistedAndDeleted` ist vorbestehend rot. Nicht geprüft: Gerät, Scrub-Geste, Historie gegen den Live-Server, iPad im Querformat und Dark Mode auf dem iPad.
- Builds 1 bis 10 waren auf interne Tester beschränkt. Build 11 soll externen Gruppen zugeordnet werden können; das ist in App Store Connect noch nicht geprüft.
- Build-, Signing- und TestFlight-Status werden getrennt geführt und nur nach tatsächlicher Prüfung als erledigt gemeldet. Den aktuellen, belegten Stand nennt [docs/status.md](https://github.com/MagicalWig34653/weather-apple/blob/main/docs/status.md).
- Keine Signing-Dateien, Schlüssel oder Tokens im Repository.

## Arbeitsweise

- Das Repository ist die Quelle der Wahrheit; Sitzungen sind wegwerfbar. Entscheidungen stehen in `docs/decisions.md`, der Arbeitsstand in `docs/status.md`.
- Koordinierende Agents delegieren; jede abgegrenzte Aufgabe erhält einen frischen ausführenden Agent, unabhängige Aufgaben mit getrenntem Dateibesitz laufen parallel (höchstens drei). Details: [docs/team.md](https://github.com/MagicalWig34653/weather-apple/blob/main/docs/team.md).
- Kostensparsam arbeiten, keine unaufgeforderte Infrastruktur.

## Diese Seite

Aufbau, lokaler Build und Deployment: [docs/pages.md](https://github.com/MagicalWig34653/weather-apple/blob/main/docs/pages.md).
