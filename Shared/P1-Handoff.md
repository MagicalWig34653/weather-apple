# P1: Shared-Schicht

Stand: 3. November 2026. Implementierung vorhanden, iOS-Builds und Tests inzwischen außerhalb der Beschränkung bestätigt (siehe docs/status.md, P1/P3-P5). P0-Gerüst erhalten; kein Commit/Push. `project.yml` unverändert durch P1, Xcode-Projekt mit `xcodegen generate` neu erzeugt.

## Ergebnis

- DWDClient, DWDRequest, DWDResponse und RainForecast (mit WeatherCoordinate/RainSample/DWDDataError) von Weather/Data nach Shared/Data verschoben. `git mv` scheiterte am schreibgeschützten Git-Index; Dateisystemverschiebungen verwendet.
- RadarTimeline mit RadarManifest bleibt über Weather/Data/DWDRadarTimeline+App.swift in der App; Shared nutzt DWDRadarTimeline und DWDRetryPolicy ohne RadarBackend-Abhängigkeit.
- PlaceStore migriert vorhandene Application-Support-Orte atomar in den App-Group-Container und speichert die letzte Auswahl. Nach erfolgreichem Schreiben/Lesen des Ziels wird die Legacy-Datei entfernt; fehlgeschlagene Bereinigung wird bei weiteren Lade-/Schreibzugriffen wiederholt. Ein datenfreier `.places-migrated`-Marker verhindert erneuten Import bei fehlender Zieldatei und noch vorhandener Quelle. SavedPlace ist geteilt.
- ForecastCache überschreibt eine JSON-Datei je Ort, verwirft ungültige/ältere Läufe und enthält keine Koordinaten oder Abrufhistorie. Dauerhafte, inhaltslose Lockdateien serialisieren Zugriffe zwischen App und Widget. Produktzugriffe prüfen die Mitgliedschaft unter Cache- und PlaceStore-Sperre bis nach dem Schreiben; feste Sperrreihenfolge Cache → PlaceStore. Beim Laden/Schreiben/Prune werden verwaiste UUID-Dateien bereinigt. Der Verzeichnisinitialisierer kann für isolierte Cache-Tests ohne PlaceStore genutzt werden. WeatherStore befüllt den Cache für gespeicherte Orte und entfernt gelöschte Orte; flüchtige Auswahlen bleiben im RAM.
- RainOutlook wertet Prognose und explizite Zeit aus; Summary-Wortlaut und Frischegrenze bleiben erhalten (stale bei mehr als 20 Minuten oder mehr als 60 Sekunden zukünftig). WidgetDeepLink erzeugt/parst showernow://place/<uuid>.

## Schnittstellen für Folgepakete

Alle Typen sind `internal`: Shared ist ein Quellordner mit Zielzugehörigkeit, kein Framework.

```swift
DWDClient.forecast(at: WeatherCoordinate) async throws -> RainForecast
DWDClient.radarRunTimeline(before: Date? = nil) async throws -> DWDRadarTimeline
PlaceStore.init() throws
PlaceStore.init(directory: URL, legacyPlacesURL: URL? = nil, removeLegacy: @Sendable (URL) throws -> Void = …)
PlaceStore.load() throws -> PlaceStore.Snapshot
PlaceStore.save(_ snapshot: PlaceStore.Snapshot) throws
ForecastCache.init() throws
ForecastCache.init(directory: URL, placeStore: PlaceStore? = nil)
ForecastCache.load(for: UUID) throws -> RainForecast?
ForecastCache.save(_ forecast: RainForecast, for: UUID) throws
ForecastCache.remove(for: UUID) throws
ForecastCache.retain(placeIDs: Set<UUID>) throws
RainOutlook.evaluate(_ forecast: RainForecast?, at: Date) -> RainOutlook
WidgetDeepLink.url(for: UUID) -> URL
WidgetDeepLink.placeID(from: URL) -> UUID?
```

`Snapshot`: `places`, `selectedPlaceID`. `SavedPlace`: `id`, `name`, `coordinate`, Codable/Identifiable/Equatable/Sendable. `RainOutlook`: `state` (rainingNow/startsIn/endsIn/dry/stale/noData), `minutes`, `intensity` (none/light/moderate/heavy, Rohwerte 0...3), `missingDataReason`, `summary`.

## Tatsächlich geprüft

- Xcode 27.2 (27B52), `xcodegen generate`: erfolgreich.
- `git diff --check`: nach Cache-Korrektur erfolgreich.
- Cache-Regression: separater Dateideskriptor hält die gemeinsame Sperre, zweiter Cache wartet und prüft nach Freigabe den inzwischen publizierten neueren Lauf erneut. 11 Storage-Tests gezielt und anschließend alle 19 Shared-Tests im macOS-Harness grün (`swift test --disable-sandbox --package-path /tmp/weather-p1-shared-harness`, Modulcaches unter /tmp). Native Prozessgrenzen auf iOS/watchOS nicht separat ausgeführt.
- Temporärer macOS-SwiftPM-Harness außerhalb des Repos: unveränderte Shared-Quellen und 19 Shared-Unit-Tests nach Cache-Korrektur ausgeführt, 0 Fehler; die zwei WeatherStore-Integrationstests sind darin nicht enthalten. Kein Package im Repo eingeführt.
- Simulator-Builds ohne Signing versucht: Schemes Weather/WeatherWidgets für generic iOS Simulator sowie WeatherWatch/WeatherWatchWidgets für generic watchOS Simulator mit `CODE_SIGNING_ALLOWED=NO`. Nicht erfolgreich: CoreSimulatorService nicht erreichbar, Icon-Studio-Export für die eingebettete Host-App scheitert; WeatherWatchWidgets-Scheme bietet ohne Simulatorservice kein passendes Ziel an. Separate Target-/SDK-Builds für WeatherWatch, WeatherWidgets, WeatherWatchWidgets scheitern an einem nicht schreibbaren Modulsessionpfad.
- `xcodebuild -project Weather.xcodeproj -scheme Weather -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -destination-timeout 5 -derivedDataPath /tmp/weather-p1-derived -only-testing:WeatherTests -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO test`: versucht; kein verfügbares Gerät, keine iOS-Tests ausgeführt.
- `build-for-testing` auf generic iOS Simulator: Icon-Export blockiert. Ergänzender Versuch mit nur befehlsseitig ausgeschlossenem AppIcon erreicht Compiler und scheitert an gesperrtem `sandbox-exec` für bestehende Swift-Makros (FoundationModels/SwiftUI/Observation). Keine Produktänderungen zur Umgehung.

## Offen und Fortsetzung

Nachgeholt am 3.11.2026: Builds Weather/WeatherWatch und volle Tests (371 Unit, 7 UI) grün; die oben genannten Blockaden betrafen nur die eingeschränkte Umgebung. Nicht geprüft: UI-Tests, Signing/Archiv/Export, Portalressourcen, Geräte/Watch-Laufzeit, Widget-Budgets und Speicher. Keine DWD-Netzwerkabfragen für P1 durchgeführt. docs/status.md und docs/decisions.md wegen des ausdrücklich begrenzten Schreibumfangs nicht durch P1 geändert.


## Review-Befunde 4–6 (3. November 2026)

Alle drei Befunde zuerst am Code bestätigt. Auftrag: keine Teilagenten, kein Commit/Push, keine App-Builds; Änderungen nur in den freigegebenen Quell-/Testverzeichnissen. `docs/status.md` und `docs/decisions.md` deshalb unverändert.

- (4) Migration entfernt die Quelle nach erfolgreichem atomarem Schreiben. Tests decken Bereinigungsfehler, Wiederholung mit neuer Store-Instanz, bereits vorhandenes Ziel und ausbleibenden Re-Import gelöschter Orte auch bei fehlendem Ziel ab. Bestehende Tests für defekte Quelle und fehlgeschlagenes Schreiben bleiben erhalten. WeatherStore benötigt dafür keine Änderung: seine vorhandenen `load`-/`save`-Aufrufe nutzen die korrigierte PlaceStore-Logik.
- (5) ForecastCache prüft die aktuelle Ortsliste nach Erwerb der Cache-Sperre und hält zusätzlich die PlaceStore-Sperre bis nach dem Schreiben. PlaceStore-Schreibzugriffe verwenden dieselbe Ortssperre. Tests decken Warten auf die Cache-Sperre mit zwischenzeitlichem Löschen, Serialisierung der Ortslöschung, Bereinigung beim Laden/Prune und die konkrete Lücke zwischen Loader-Prüfung und Cache-Schreiben ab.
- (6) Die vier bereits in PlaceEntity verwendeten deutschen Schlüssel (`Gespeicherter Ort`, `Regenprognose`, Beschreibung, `Ort`) sind in beiden Widget-Sprachdateien vollständig hinterlegt; englische Werte ergänzt. Schlüssel bleiben im bestehenden Stil konsistent; PlaceEntity selbst benötigt keine Änderung.

Tatsächlich geprüft: isolierter temporärer macOS-SwiftPM-Harness mit kopierten, unveränderten Shared-Quellen sowie WidgetForecastLoader/WidgetTimelineBuilder; 25 Shared-Tests (davon 17 Storage) und separat 14 WidgetLogicTests, jeweils 0 Fehler. Nur die zwei WeatherStore-Integrationstests wurden aus der Harness-Kopie ausgelassen (App-Abhängigkeiten); Repo-Tests unverändert vollständig vorhanden. `plutil -lint` für Widget-de/en erfolgreich; programmatischer Schlüsselvergleich: beide 36 Schlüssel, alle vier AppIntent-Metadaten vorhanden und übersetzt. `git diff --check` erfolgreich.

Nicht geprüft: vollständige WeatherTests-/UI-Suite, App-/Extension-/Watch-Builds, AppIntent-Darstellung zur Laufzeit, Signing, Simulator-/Geräteverhalten und echte App-Group-Prozessgrenzen. Nächster Schritt: Verifikation im uneingeschränkten Xcode-Kontext durch den vom Nutzer genannten Claude-Agent.
