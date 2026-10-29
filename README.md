# ShowerNow — Apple-App

Native, datensparsame Regen-App mit SwiftUI und MapKit. Produktname: ShowerNow, Bundle-ID: `de.linolaske.showernow`, Team: `J2DU2P47XW`. Technisches Projekt und Swift-Module heißen weiterhin `Weather`.

## Aktueller Stand

Der erste iPhone-Prototyp enthält Radarkarte und Zeitleiste, direkte DWD-Ortsprognose, lokale Orte, Ortssuche und optionalen Standortzugriff bei Nutzung. Es gibt kein eigenes Backend, keine Benutzerkonten und keine Werbung. Datenalter, Messung/Vorhersage sowie fehlende Daten werden unterschieden.

Der Stand ist noch keine vollständige Version 1. Der aktuelle Zielkandidat **`0.1.0 (7)`** lädt nach dem sichtbaren Radarframe schrittweise benachbarte Zeiten im Leerlauf vor. Der RAM-Cache hält höchstens 50.000.000 Byte validierter PNGs; zusätzliche Request-/Bytebudgets und Nachfragepriorität begrenzen optionale Abrufe. WLAN und Mobilfunk sind gemäß Nutzerentscheidung erlaubt, Datensparmodus, Stromsparmodus und inaktive App pausieren Vorladung. Ein warmer identischer Bildkey vermeidet Netzabrufe; vollständige Vorwärmung aller Zeiten und sofortiges kaltes Laden werden nicht garantiert.

Build 6 ist der konservative Zwischenstand mit noch ausgeschlossenen teuren Verbindungen; Apple nahm seinen Upload am 28. Oktober 2026 um 20:01:53 Uhr MEZ an (`PROCESSING`). Build-7-Policytests, Quellencheckpoint und Upload werden getrennt im Arbeitsstatus belegt. Die vollständige Build-6-Logiksuite bestand mit 57 Tests ohne Fehler; diese Zahl wird nicht als neuer Build-7-Gesamtlauf ausgegeben. Die optionale lokale Einordnung bleibt unverändert.
[P0-Befunde und Messgrenzen](docs/performance-regression-build4.md), [Review](docs/reviews/p0-build5.md), [Timeline und Vorschauen](docs/timeline-build5.md), [HIG-Audit von Build 4](docs/reviews/apple-hig-build4.md) und [API-Budgetstrategie](docs/research/near-instant-radar.md) beschreiben Nachweise und Grenzen. Widgets, Watch, angepasste iPad-/Mac-Oberflächen und Push folgen gemäß [Entwicklungsplan](docs/plan.md). Tatsächlich ausgeführte Prüfungen stehen im [Arbeitsstatus](docs/status.md).

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
