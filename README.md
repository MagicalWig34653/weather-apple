# Showers — Apple-App

Native, datensparsame Regen-App mit SwiftUI und MapKit. Produktname: Showers, Bundle-ID: `de.linolaske.showernow`, Team: `J2DU2P47XW`. Technisches Projekt und Swift-Module heißen weiterhin `Weather`.

## Aktueller Stand

Die App enthält Radarkarte (Backend-Cache zuerst, DWD-Fallback) mit Zeitleiste, Zusatzebenen (Luftdruck, Blitze, Wolken, Sonne), direkte DWD-Ortsprognose, lokale Orte, Ortssuche, optionalen Standortzugriff bei Nutzung sowie optionale Regenmeldungen je Ort per Push (eigene Server-Komponente im Schwesterrepo, standardmäßig aus) und Regionen (Umkreis). Es gibt keine Benutzerkonten und keine Werbung. Datenalter, Messung/Vorhersage sowie fehlende Daten werden unterschieden.

Der Stand ist noch keine vollständige Version 1. Der letzte hochgeladene Build ist **`0.1.0 (12)`** (31. Oktober 2026, TestFlight-Verarbeitung nicht geprüft); `main` enthält weitere, noch nicht gebaute Änderungen. Der RAM-Cache hält höchstens 50.000.000 Byte validierter PNGs; Budgets und Nachfragepriorität begrenzen optionale Abrufe, Datensparmodus, Stromsparmodus und inaktive App pausieren Vorladung. Widgets, Watch und angepasste iPad-/Mac-Oberflächen folgen gemäß [Entwicklungsplan](docs/plan.md). Builds, Prüfungen und offene Punkte: [Arbeitsstatus](docs/status.md); ältere Nachweise: [P0-Befunde](docs/performance-regression-build4.md), [Review](docs/reviews/p0-build5.md), [Timeline und Vorschauen](docs/timeline-build5.md), [HIG-Audit](docs/reviews/apple-hig-build4.md), [API-Budgetstrategie](docs/research/near-instant-radar.md).

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

Lokalisierung (de/en): `tools/check_l10n.sh` prueft Schluessel- und Platzhalterparitaet je Bundle und meldet hartcodierte deutsche Texte in Swift-Quellen. Ohne Argument verbietet es nur Treffer ueber `tools/l10n_baseline.txt` hinaus; `--baseline` schreibt die Ausgangslage neu, `--strict` ignoriert sie (Ziel am Ende der Lokalisierung), `--list` zeigt alle Treffer. Ausnahmen: `tools/l10n_allow.txt`. Texte, die mehrere Targets teilen (Live Activity), stehen in der Tabelle `Shared/Resources/*.lproj/SharedTexts.strings`. Seit Abschluss von L6 ist die Baseline leer: `tools/check_l10n.sh` (ohne Argument) entspricht `--strict` und muss vor jedem Commit mit Text- oder Oberflaechenaenderung Exit 0 liefern (bewusst keine Build-Phase). Layout-Pruefung mit doppelter Textlaenge/RTL: UI-Tests `PseudoLocalizationTests`. Englische Screenshots: `tools/screenshots.sh <iphone-pro|iphone-max|ipad> en` (siehe `docs/appstore-screenshots.md`). Braucht nur Bash und Python 3.

## Dokumentation

- [Arbeitsstand und nächste Schritte](docs/status.md)
- [Uploadbefund](docs/testflight-upload.md) und [interne iPhone-Testanleitung](docs/internal-testing.md)
- [Entwicklungsplan](docs/plan.md)
- [Aktuelle Entscheidungen](docs/decisions.md)
- [DWD-Datenvertrag und Grenzen](docs/data-contract.md)
- [Ursprüngliches Konzept](docs/concept-v2.md)
- [GitHub-Pages-Dokumentation](docs/pages.md) (Aufbau, lokaler Build, Deployment)
- [Anweisungen für Agents](AGENTS.md), [Claude Code](CLAUDE.md)

Die private lokale Zuordnung zum Schwesterrepository steht optional in der ignorierten `LOCAL_WORKSPACE.md`; die öffentliche Vorlage enthält keine persönlichen Pfade. Schwesterrepository: [weather-backend](https://github.com/MagicalWig34653/weather-backend).

## Lizenz

Open Source unter AGPLv3 ist vorgesehen. Die endgültige Lizenzfreigabe und die Vereinbarkeit mit der vorgesehenen App-Store-Veröffentlichung stehen noch aus. Derzeit ist keine Lizenz erteilt; insbesondere bedeutet ein öffentliches Repository allein keine Nutzungserlaubnis.
