# Build und Prüfung des iPhone-Prototyps

Stand: 28. Oktober 2026. Für aktuelle Freigaben und Ergebnisse zuerst `status.md` lesen.

## Voraussetzungen und reproduzierbare Befehle

Xcode 27.1 mit iOS-27-Simulator, Swift 6 und XcodeGen 2.46.0. Alle Befehle beginnen im Repository-Verzeichnis. Nach Änderungen an `project.yml`:

```sh
xcodegen generate
```

Ein reiner Simulator-Build benötigt keine Apple-Zugangsdaten:

```sh
xcodebuild -project Weather.xcodeproj -scheme Weather \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/weather-derived CODE_SIGNING_ALLOWED=NO build
```

Vollständige gezielte Suite:

```sh
xcodebuild -project Weather.xcodeproj -scheme Weather \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  -derivedDataPath /tmp/weather-derived CODE_SIGNING_ALLOWED=NO test
```

Nur die betroffene UI-Suite nach Änderungen an einem UI-Test erneut ausführen:

```sh
xcodebuild -project Weather.xcodeproj -scheme Weather \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  -derivedDataPath /tmp/weather-derived CODE_SIGNING_ALLOWED=NO \
  -only-testing:WeatherUITests/WeatherSmokeTests test
```

Vorhandene Simulatornamen gegebenenfalls anpassen. Keine Logs oder xcresult-Bundles mit lokalen Dateipfaden ins öffentliche Repo übernehmen.

## Inhalt der Prüfungen

- Datentests verwenden eine archivierte DWD-Fixture und injizierte Transport-/Uhrfunktionen. Sie prüfen Einheiten, spezielle Werte, fehlende Daten, Datenalter, fremde Läufe, Zeitlücken, Achsenfolge, explizite UTC-Zeitstempel und speicherseitigen Cache.
- Die UI-Smokes prüfen Datenquellen-/Datenschutz-Navigation sowie den lokalen Ortsablauf. Die UI nutzt reale Kartendienste; die Tests benötigen weder erfolgreiche Live-Prognosen noch Standortfreigabe. Eigene zufällig benannte Testorte werden gezielt entfernt; vorhandene Nutzerorte dürfen nicht pauschal gelöscht werden.
- Ein begrenzter Live-Datentest am öffentlichen Beispielpunkt Berlin bestätigte nach dem Millisekundenfix einen HTTP-200-JSON-Response mit 25 Samples. Das ist keine Verfügbarkeits- oder Energieverbrauchsstudie.

## Lokaler Xcode-Hinweis

Beim Integrationslauf wartete Xcode vor dem Build in `NSFileCoordinator` beim Lesen des Projektpakets. Das Projekt war per `plutil` syntaktisch gültig. Eine neue temporäre Kopie der relativen Projekt-/Source-Dateien umging die lokale Dateikoordination; Build und Tests liefen dort an. Es wurden keine globalen Dienste geändert und keine privaten lokalen Konfigurationsdateien kopiert. Dies ist ein lokaler Tooling-Befund, kein erforderlicher Bestandteil der Projektarchitektur.

## Noch keine Release-Abnahme

Ein grüner Simulatorlauf ersetzt weder Tests auf dem physischen iPhone noch eine vollständige Accessibility-/Energieprüfung. Die erste interne TestFlight-Veröffentlichung benötigt zusätzlich eine bestätigte explizite Bundle-ID, den vom Nutzer angelegten App-Store-Connect-Datensatz, App-Icon und einen erfolgreich validierten Release-Stand. Signing und Registrierung werden getrennt in `signing.md` dokumentiert.
