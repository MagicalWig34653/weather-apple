# ShowerNow — Apple-App

Native, datensparsame Regen-App mit SwiftUI und MapKit. Produktname: ShowerNow, Bundle-ID: `de.linolaske.showernow`, Team: `J2DU2P47XW`. Technisches Projekt und Swift-Module heißen weiterhin `Weather`.

## Aktueller Stand

Der erste iPhone-Prototyp enthält Radarkarte und Zeitleiste, direkte DWD-Ortsprognose, lokale Orte, Ortssuche und optionalen Standortzugriff bei Nutzung. Es gibt kein eigenes Backend, keine Benutzerkonten und keine Werbung. Datenalter, Messung/Vorhersage sowie fehlende Daten werden unterschieden.

Der Stand ist noch keine vollständige Version 1. Aktueller Kandidat ist ShowerNow `0.1.0 (3)` mit neuer Bundle-ID. Der Nutzer hat die Umstellung seines App-Store-Connect-Eintrags auf die neue Bundle-ID bestätigt. Der geprüfte Quellencheckpoint `2e500fc` ist veröffentlicht; genau ein Upload wurde am 28. Oktober 2026 um 17:51:38 Uhr MEZ erfolgreich angenommen. Letzter Serverstand: `PROCESSING`; abgeschlossene Verarbeitung und interne TestFlight-Verfügbarkeit sind noch nicht bestätigt. Historisch wurde Build `0.1.0 (2)` unter `de.linolaske.weather` zum Upload angenommen (`PROCESSING`); zusätzlich meldet der Nutzer einen Namenskonflikt mit Weather. Daraus folgt kein nutzbarer TestFlight-Build. Widgets, Watch, angepasste iPad-/Mac-Oberflächen und Push folgen gemäß [Entwicklungsplan](docs/plan.md). Tatsächlich ausgeführte Prüfungen und offene Punkte stehen im [Arbeitsstatus](docs/status.md).

## Projekt öffnen und prüfen

Voraussetzungen: Xcode 27.1 mit iOS-Simulator und XcodeGen 2.46.0. Die Deployment-Mindestversion ist iOS 27.0. Die folgenden Befehle werden im Repository-Verzeichnis ausgeführt:

```sh
xcodegen generate
open Weather.xcodeproj
```

Das generierte Xcode-Projekt ist eingecheckt; nach Änderungen an `project.yml` erneut generieren. Simulator-Build ohne Signing:

```sh
xcodebuild -project Weather.xcodeproj -scheme Weather \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/weather-derived CODE_SIGNING_ALLOWED=NO build
```

Unit- und UI-Tests auf einem installierten iPhone-18-Pro-Simulator:

```sh
xcodebuild -project Weather.xcodeproj -scheme Weather \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  -derivedDataPath /tmp/weather-derived CODE_SIGNING_ALLOWED=NO test
```

Bei anderem Simulator dessen vorhandenen Namen einsetzen. UI-Tests legen nur eigene zufällig benannte Testorte an und entfernen diese gezielt. Signierte Gerätebuilds und Bundle-ID-Registrierung sind im [Signing-Status](docs/signing.md) getrennt dokumentiert. Keine Signing-Dateien oder lokalen Pfade committen.

## Dokumentation

- [Arbeitsstand und nächste Schritte](docs/status.md)
- [Uploadbefund](docs/testflight-upload.md) und [interne iPhone-Testanleitung](docs/internal-testing.md)
- [Entwicklungsplan](docs/plan.md)
- [Aktuelle Entscheidungen](docs/decisions.md)
- [DWD-Datenvertrag und Grenzen](docs/data-contract.md)
- [Ursprüngliches Konzept](docs/concept-v2.md)
- [Anweisungen für Agents](AGENTS.md), [Claude Code](CLAUDE.md)

Die private lokale Zuordnung zum Schwesterrepository steht optional in der ignorierten `LOCAL_WORKSPACE.md`; die öffentliche Vorlage enthält keine persönlichen Pfade. Schwesterrepository: [weather-backend](https://github.com/MagicalWig34653/weather-backend).

## Lizenz

Open Source unter AGPLv3 ist vorgesehen. Die endgültige Lizenzfreigabe und die Vereinbarkeit mit der vorgesehenen App-Store-Veröffentlichung stehen noch aus. Derzeit ist keine Lizenz erteilt; insbesondere bedeutet ein öffentliches Repository allein keine Nutzungserlaubnis.
