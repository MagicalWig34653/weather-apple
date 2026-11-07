# Warnungen (Unwetter, Frost, Glatteis) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Projektregel (`docs/team.md`): jedes Paket erhält einen frischen ausführenden Agent, höchstens drei parallel, Hauptagent koordiniert nur. Jeder Agent liest zuerst `docs/status.md`, `docs/decisions.md`, die Spec und den Vertrag (Backend `docs-site/content/api.md`, Abschnitt "Amtliche Warnungen"), meldet `post_progress` mit voller Todolino-Aufgaben-ID und aktualisiert `docs/status.md` seines Repos.

**Goal:** Amtliche DWD-Warnungen (Unwetter allgemein, Frost, Glätte/Glatteis) für gespeicherte Orte und Gebiete als Push und als Liste/Karte in der App, Text unverändert vom DWD mit Quelle.

**Architecture:** Der Backend-Leader `warn` lädt DWD-CAP (Gemeindebasis), speichert aktive Warnungen in MariaDB und liefert sie über `GET /v1/warnings/active` (ohne Ortsangabe, das Gerät filtert lokal). Warn-Abos sind `push_sub`-Zeilen mit `kind = 2` plus `warn_sub*`-Tabellen und nutzen Outbox und APNs-Versand unverändert. Die App ordnet Orte/Gebiete auf dem Gerät per gebündelter Gemeindegeometrie einer WARNCELLID zu; nur diese IDs gehen an den Server.

**Tech Stack:** Swift 6 / Vapor 4 / MySQLKit (Backend, `swift test`), Foundation `XMLParser` (libxml2 ist im Runtime-Image), ZIPFoundation (neu, Task W1.2), SwiftUI/MapKit/XCTest (App, `xcodebuild`), Python 3 (nur Stdlib) für das Geometrie-Skript.

**Spec:** `docs/superpowers/specs/2026-11-07-warnungen-design.md`. **Repos:** App `/Users/linolaske/Development/Xcode/weather` (hier "APP"), Backend `/Users/linolaske/Development/PhpstormProjects/weather` (hier "BE"). Pfade ohne Präfix gelten im jeweils genannten Repo.

## Global Constraints

- Entwicklung ohne Produktiv-Deploy, ohne Serverzugriff, ohne Geheimnisse; Datenschutztext (`docs-site/content/datenschutz.md`) wird nicht live geändert (nur Entwurf W7).
- Umfang v1: Typen `severe_weather` (Gewitter, Sturm, Stark-/Dauerregen, Schnee, Tauwetter), `frost`, `ice`; Hitze/UV/Nebel nicht gespeichert.
- Stufen 1 bis 4 = CAP `Minor`/`Moderate`/`Severe`/`Extreme`. Standard-Mindeststufen Push: `severe_weather` 3, `frost` 1, `ice` 2.
- Push nur für Meldungen mit `sent` höchstens 20 Minuten alt und `expires` in der Zukunft; Entwarnung (Cancel/Ablauf) nie als Push; Update nur bei höherer Stufe, anderem Typ oder Beginn mehr als 1 h früher; Wiederholsperre 60 min je (Abo, Typ), höhere Stufe durchbricht sie.
- Zeitkritisch (`interruption-level: time-sensitive`) nur bei Stufe 4 oder gesetztem Nutzerschalter.
- Server speichert nur Warngebiets-IDs (9 Ziffern), keine Koordinaten, Ortsnamen oder Debuglogs mit Kennungen; Beobachtung nur über feste Zählerlabels.
- Flags standardmäßig aus: `WARN_INGEST_ENABLED`, `WARN_PUSH_ENABLED`; Capabilities `warnings` und `warnings_push` (Definition im Vertrag). App bietet ohne Capability weder Anzeige noch Einstellung an.
- Limits: höchstens 10 Warn-Abos, 64 Warngebiete je Abo, 128 je Installation. Payload gesamt unter 1 900 Bytes, `body` höchstens 900 Bytes (UTF-8).
- Kein Ersatz für amtliche Warnkanäle (WarnWetter, NINA): Hinweis in Einstellungen, vor der Systemabfrage und in der Warnansicht. Quelle "Deutscher Wetterdienst" mit Ausgabezeit.
- Stufe nie nur farbig; VoiceOver, Dynamic Type, Reduce Motion; Oberfläche de/en (`Localizable.strings`).
- Push scharf (`WARN_PUSH_ENABLED=true`) erst nach Antwort des DWD auf die Rückfrage an `CAP@dwd.de` (Nutzeraufgabe) **und** Freigabe des Datenschutztexts.
- Nur tatsächlich ausgeführte Prüfungen als erfolgreich melden; nicht ausgeführte benennen.

## Wellen und Abhängigkeiten

| Welle | Pakete (parallel, getrennter Dateibesitz) | Voraussetzung |
|---|---|---|
| 0 (erledigt) | W0 Vertrag, Entscheidungen, Feed-Befund (BE `b331a6e`, APP Spec/Decisions) | - |
| 1 | **W1** (BE), **W3** (APP, Geometrie), **W7** (APP/BE-Docs Entwurf Datenschutz) | W0 |
| 2 | **W2** (BE), **W4** (APP, Gateway/Einstellungen), **W5** (APP, Ansicht) | W1 für W2; W3 für W4/W5; W4 und W5 teilen kein File, bauen aber nacheinander (ein `xcodebuild`-Verantwortlicher) |
| 3 | **W6** (APP, NSE) | W2 (Payload live), sonst unabhängig; kann in Welle 2 mitlaufen, sobald nur zwei App-Pakete bauen |

Dateibesitz (keine Überschneidung innerhalb einer Welle): W1 `BE Sources/RadarCore/Warn*.swift` (Parser, Modelle, Ingest, Repo-Protokoll `WarnRepo`), `BE migrations/016_warnings.sql`, `BE Sources/RadarCore/{MariaRepo,MemoryRepo}+Warn.swift`, `BE Package.swift`, `BE Dockerfile`; W2 `BE Sources/RadarCore/{WarnEvaluator,WarnPayload,WarnService,WarnApi}.swift`, Änderungen an `PushService.swift`, `PushApi.swift`, `Api.swift`, `Config.swift`, `MariaRepo+Push.swift`, `MemoryRepo+Push.swift`, `Sources/radar/Radar.swift`; W3 `APP Weather/Warnings/Matching/`, `APP tools/warn_geometry.py`, `APP Weather/Resources/WarnGeometry.bin`, `APP WeatherTests/Warn{Geometry,Matcher}Tests.swift`; W4 `APP Weather/Warnings/Subscriptions/`, `APP Weather/Views/WarnSettingsView.swift`, Anbindung in `PlacePushSettingsView.swift`/`InformationSheet.swift` (nur Einhängepunkt); W5 `APP Weather/Warnings/Feed/`, `APP Weather/Views/Warnings*.swift`, `APP Weather/Map/WarnOverlay.swift`; W6 `APP WeatherNotificationService/`, `APP Shared/WarningNotificationText.swift`; W7 `APP docs/datenschutz-warnungen.md`.

Gemeinsame Konstante (W1 definiert, W2 benutzt): `WarnKind`, `WarnAlert`, `WarnRepo` siehe W1.3; App-Seite: `WarnKind` (String-Rohwerte identisch) und `WarnCellID = String` siehe W3/W4.

---

## W1: Backend Ingest, Parser, Speicher (BE)

**Aufwand:** L. **Nach:** W0. **Aufgabe Todolino:** vom Lead anzulegen. **Build/Test:** `cd /Users/linolaske/Development/PhpstormProjects/weather && swift test --filter Warn` (Memory-Repo, ohne DB); MariaDB-Vertragstests nur mit `RADAR_TEST_DB_*` (README).

### Task W1.1: Ereignistabelle belegen (Recherche, Ergebnis ist Code und Doku)

**Files:**
- Create: `BE Sources/RadarCore/WarnEventMap.swift`
- Create: `BE docs/research/warnungen-ereigniscodes.md`
- Test: `BE Tests/RadarCoreTests/WarnEventMapTests.swift`

**Interfaces:**
- Produces: `public enum WarnKind: String, Sendable, CaseIterable, Codable { case severeWeather = "severe_weather"; case frost; case ice }` und `public enum WarnEventMap { public static func kind(ii: Int?, event: String) -> WarnKind? }` (nil = Ereignis in v1 nicht gespeichert).

- [ ] **Step 1: Quelle beschaffen.** DWD-CAP-Profil (v2.1.14) und Implementierungsleitfaden von `https://www.dwd.de/DE/leistungen/opendata/hilfe.html` (Abschnitt Warnungen CAP) lesen; die Tabelle "Warnereignisse" mit `II`-Code, `EVENT`-Name und `GROUP` extrahieren. Bei Layout-/Fontproblemen im PDF zusätzlich mit `curl -s https://opendata.dwd.de/weather/alerts/cap/COMMUNEUNION_EVENT_STAT/` und den Werten aus echten Meldungen gegenprüfen (Verfahren wie in Spec 3.2a: ZIP laden, `eventCode`/`valueName` `II`, `GROUP` und `event` zählen). Eine Quelle, die nicht eindeutig lesbar ist, wird als offen markiert, nicht geraten.
- [ ] **Step 2: Doku schreiben.** `docs/research/warnungen-ereigniscodes.md`: Tabelle `II | event | GROUP | kind (severe_weather/frost/ice/ignoriert) | Quelle/Datum | belegt (Profil / echte Meldung)`. Zuordnung nach Nutzerentscheidung: Gewitter, Sturm/Orkan/Böen, Starkregen/Dauerregen, Schneefall/Schneeverwehung, Tauwetter = `severe_weather`; Frost/Strenger Frost = `frost`; Glätte/Glatteis (inkl. Stufe 1/2 "Glätte" und 3/4 "Glatteis") = `ice`; Hitze, UV, Nebel = ignoriert. Bereits belegt: `II` 22, `event` `FROST`, `GROUP` `FROST` = `frost`.
- [ ] **Step 3: Failing test.**

```swift
import XCTest
@testable import RadarCore

final class WarnEventMapTests: XCTestCase {
    func testFrostIsMappedByCodeAndName() {
        XCTAssertEqual(WarnEventMap.kind(ii: 22, event: "FROST"), .frost)
        XCTAssertEqual(WarnEventMap.kind(ii: nil, event: "FROST"), .frost)
    }
    func testUnknownEventIsIgnored() {
        XCTAssertNil(WarnEventMap.kind(ii: 999, event: "UNBEKANNT"))
    }
    func testEveryDocumentedRowIsCovered() throws {
        // Jede Zeile der Tabelle aus der Doku steht in WarnEventMap.rows; die Zeilenzahl wird hier fest eingetragen.
        XCTAssertEqual(WarnEventMap.rows.count, WarnEventMapTests.documentedRowCount)
    }
    static let documentedRowCount = 0 // Step 5 ersetzt 0 durch die Anzahl der Zeilen der Doku-Tabelle
}
```

- [ ] **Step 4: Run, expect FAIL** (`WarnEventMap` fehlt): `swift test --filter WarnEventMapTests`.
- [ ] **Step 5: Implementierung.** Eine Zeile je Doku-Tabelle:

```swift
import Foundation

public enum WarnKind: String, Sendable, CaseIterable, Codable {
    case severeWeather = "severe_weather"
    case frost
    case ice
}

public enum WarnEventMap {
    public struct Row: Sendable { public let ii: Int; public let event: String; public let kind: WarnKind }
    /// Eine Zeile je Ereignis der DWD-Tabelle (docs/research/warnungen-ereigniscodes.md). Ignorierte Ereignisse (Hitze, UV, Nebel) stehen nicht hier.
    public static let rows: [Row] = [
        Row(ii: 22, event: "FROST", kind: .frost),
        // weitere Zeilen aus Step 1/2, z. B. Row(ii: <Code>, event: "<EVENT>", kind: .severeWeather)
    ]
    private static let byCode: [Int: WarnKind] = Dictionary(rows.map { ($0.ii, $0.kind) }, uniquingKeysWith: { a, _ in a })
    private static let byName: [String: WarnKind] = Dictionary(rows.map { ($0.event, $0.kind) }, uniquingKeysWith: { a, _ in a })
    public static func kind(ii: Int?, event: String) -> WarnKind? {
        if let ii, let kind = byCode[ii] { return kind }
        return byName[event.uppercased()]
    }
}
```

  Der Agent ersetzt den Kommentar in `rows` durch die tatsächlichen Zeilen aus Step 2 und `documentedRowCount` durch deren Anzahl. Ist ein Code für einen Typ nicht belegbar, steht er in `docs/research/...` als "offen" und in `docs/status.md`; der Typ bleibt dann leer (Fail-closed: lieber keine Warnung als eine falsche Zuordnung).
- [ ] **Step 6: Run, expect PASS.** `swift test --filter WarnEventMapTests`.
- [ ] **Step 7: Commit.** `git add Sources/RadarCore/WarnEventMap.swift docs/research/warnungen-ereigniscodes.md Tests/RadarCoreTests/WarnEventMapTests.swift && git commit -m "feat: Ereignistabelle fuer Warnungen"`

### Task W1.2: ZIP-Abhängigkeit und CAP-Parser

**Files:**
- Modify: `BE Package.swift` (Dependency `ZIPFoundation`, in `RadarCore`)
- Create: `BE Sources/RadarCore/WarnModels.swift`, `BE Sources/RadarCore/WarnCAPParser.swift`, `BE Sources/RadarCore/WarnFeedFetcher.swift`
- Test: `BE Tests/RadarCoreTests/WarnCAPParserTests.swift`; Fixture `BE docs/fixtures/warnings/cap-frost-alert.xml` (vorhanden) wird über `Tests/RadarCoreTests/Fixtures/warn-cap-frost.xml` kopiert (Kopie, wie bei den Gerätekopplungs-Fixtures)

**Interfaces:**
- Consumes: `WarnKind`, `WarnEventMap.kind(ii:event:)` (W1.1).
- Produces:

```swift
public enum WarnMsgType: String, Sendable { case alert = "Alert", update = "Update", cancel = "Cancel" }

public struct WarnAlert: Sendable, Equatable {
    public var identifier: String
    public var kind: WarnKind
    public var severity: Int            // 1...4
    public var event: String
    public var msgType: WarnMsgType
    public var references: [String]     // Identifier aus <references> (Format "sender,identifier,sent"), nur der Identifier
    public var sent: Date, onset: Date, expires: Date
    public var headline: String, text: String, instruction: String
    public var lang: String             // "de" | "en"
    public var warncellIDs: [String]    // je 9 Ziffern
}

public struct WarnParseResult: Sendable, Equatable {
    public var alerts: [WarnAlert]
    public var ignoredEvents: [String: Int]   // nicht gespeicherte Ereignisse -> Anzahl
    public var rejected: Int                  // unlesbar/ungültig
}

public enum WarnCAPParser {
    public static func parse(xml: Data) -> WarnParseResult
}
```

- [ ] **Step 1: Failing test** (Fixture aus Spec 3.2a):

```swift
import XCTest
@testable import RadarCore

final class WarnCAPParserTests: XCTestCase {
    private func fixture(_ name: String) throws -> Data {
        try Data(contentsOf: URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/\(name)"))
    }
    func testParsesRealFrostAlert() throws {
        let r = WarnCAPParser.parse(xml: try fixture("warn-cap-frost.xml"))
        XCTAssertEqual(r.alerts.count, 1)
        let a = try XCTUnwrap(r.alerts.first)
        XCTAssertEqual(a.identifier, "2.49.0.0.276.0.DWD.PVW.1794051060000.2509064c-9ae8-40a2-8059-834d43d182b6.DEU")
        XCTAssertEqual(a.kind, .frost); XCTAssertEqual(a.severity, 1); XCTAssertEqual(a.msgType, .alert)
        XCTAssertEqual(a.lang, "de")
        XCTAssertEqual(a.warncellIDs, ["814522510", "814522500"])   // Polygon-Area ohne geocode wird ignoriert
        XCTAssertEqual(a.sent, ISO8601DateFormatter().date(from: "2026-11-07T11:31:00Z"))
        XCTAssertEqual(a.expires, ISO8601DateFormatter().date(from: "2026-11-08T08:00:00Z"))
        XCTAssertEqual(a.headline, "Amtliche WARNUNG vor FROST")
        XCTAssertTrue(a.instruction.hasPrefix("Hinweis auf: mögliche Frostschäden."))
    }
    func testUnknownEventIsCountedNotStored() {
        let xml = Data(WarnCAPParserTests.minimal(event: "HITZE", ii: 1234, severity: "Minor").utf8)
        let r = WarnCAPParser.parse(xml: xml)
        XCTAssertTrue(r.alerts.isEmpty); XCTAssertEqual(r.ignoredEvents["HITZE"], 1)
    }
    func testSeverityMapping() {
        for (s, n) in [("Minor", 1), ("Moderate", 2), ("Severe", 3), ("Extreme", 4)] {
            let r = WarnCAPParser.parse(xml: Data(WarnCAPParserTests.minimal(event: "FROST", ii: 22, severity: s).utf8))
            XCTAssertEqual(r.alerts.first?.severity, n)
        }
        let bad = WarnCAPParser.parse(xml: Data(WarnCAPParserTests.minimal(event: "FROST", ii: 22, severity: "Unknown").utf8))
        XCTAssertTrue(bad.alerts.isEmpty); XCTAssertEqual(bad.rejected, 1)
    }
    func testCancelAndReferences() {
        let xml = WarnCAPParserTests.minimal(event: "FROST", ii: 22, severity: "Minor", msgType: "Cancel",
                                             references: "opendata@dwd.de,OLD.ID.1,2026-11-07T12:31:00+01:00")
        let a = WarnCAPParser.parse(xml: Data(xml.utf8)).alerts.first
        XCTAssertEqual(a?.msgType, .cancel); XCTAssertEqual(a?.references, ["OLD.ID.1"])
    }
    func testBrokenXmlIsRejectedWithoutCrash() {
        let r = WarnCAPParser.parse(xml: Data("<alert><nope".utf8))
        XCTAssertEqual(r.alerts.count, 0); XCTAssertEqual(r.rejected, 1)
    }
    static func minimal(event: String, ii: Int, severity: String, msgType: String = "Alert", references: String? = nil) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?><alert xmlns="urn:oasis:names:tc:emergency:cap:1.2">
        <identifier>T.\(event).1</identifier><sent>2026-11-07T12:31:00+01:00</sent><status>Actual</status><msgType>\(msgType)</msgType>\(references.map { "<references>\($0)</references>" } ?? "")
        <info><language>de-DE</language><event>\(event)</event><severity>\(severity)</severity>
        <eventCode><valueName>II</valueName><value>\(ii)</value></eventCode>
        <onset>2026-11-07T22:00:00+01:00</onset><expires>2026-11-08T09:00:00+01:00</expires>
        <headline>H</headline><description>D</description>
        <area><areaDesc>Stadt X</areaDesc><geocode><valueName>WARNCELLID</valueName><value>814522510</value></geocode></area>
        </info></alert>
        """
    }
}
```

- [ ] **Step 2:** `cp docs/fixtures/warnings/cap-frost-alert.xml Tests/RadarCoreTests/Fixtures/warn-cap-frost.xml`. Run `swift test --filter WarnCAPParserTests`, erwartet FAIL (Typen fehlen).
- [ ] **Step 3: Implementierung** `WarnModels.swift` (Typen oben) und `WarnCAPParser.swift`: `XMLParserDelegate` (unter Linux `import FoundationXML`, unter macOS `Foundation`; `#if canImport(FoundationXML)`), sammelt Elementtext in einem Stack, verwendet `ISO8601DateFormatter` mit `.withInternetDateTime` (Offsets wie `+01:00`), Sprache = `language.prefix(2)` kleingeschrieben, Mapping `Minor/Moderate/Severe/Extreme` -> 1...4, sonst `rejected += 1`. `eventCode` mit `valueName == "II"` -> `Int`. `area` zählt nur, wenn ein `geocode` mit `valueName == "WARNCELLID"` und Wert aus genau 9 Ziffern vorhanden ist. `references`: durch Leerzeichen getrennte Einträge, je Eintrag `split(",")`, mittleres Element = Identifier. Ereignis ohne `WarnEventMap`-Treffer: `ignoredEvents[event, default: 0] += 1`, kein `alert`. `Cancel` darf ohne `onset`/`expires` vorkommen (Fallback `sent`).
- [ ] **Step 4: ZIP-Abruf.** `Package.swift`: `.package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.19")` und `.product(name: "ZIPFoundation", package: "ZIPFoundation")` in `RadarCore`; `Dockerfile`: im Builder-Stage `zlib1g-dev` neben `libwebp-dev`, im Runtime-Stage `zlib1g` neben `libwebp7`. `WarnFeedFetcher`: `public protocol WarnFeedSource: Sendable { func fetch(feed: WarnFeed, lang: String, ifNoneMatch: String?) async throws -> WarnFeedResponse }`, `public enum WarnFeed { case diff, stat }`, `public enum WarnFeedResponse: Sendable { case notModified; case xmlFiles([Data], etag: String?) }`. Implementierung `DWDWarnFeedSource` (AsyncHTTPClient oder die in `DWD.swift` benutzte HTTP-Schicht, URL `https://opendata.dwd.de/weather/alerts/cap/COMMUNEUNION_DWD_{DIFF|STAT}/Z_CAP_C_EDZW_LATEST_PVW_{DIFFERENCE|STATUS}_PREMIUMDWD_COMMUNEUNION_{DE|EN}.zip`, `If-None-Match`, `304` -> `notModified`, ZIP-Größe über 2 MB oder mehr als 5 000 Einträge -> Fehler, nur Dateien mit Endung `.xml`, jede Datei höchstens 4 MB). Test mit einer im Test gebauten ZIP (ZIPFoundation `Archive(accessMode: .create)`) und Fake-HTTP; kein Netz im Test.
- [ ] **Step 5:** `swift test --filter WarnCAPParserTests` PASS; `swift build` ohne neue Warnungen.
- [ ] **Step 6: Commit** `feat: CAP-Parser und Feed-Abruf fuer Warnungen`.

### Task W1.3: Migration 016, WarnRepo (Memory und MariaDB)

**Files:**
- Create: `BE migrations/016_warnings.sql`, `BE Sources/RadarCore/WarnRepo.swift`, `BE Sources/RadarCore/MemoryRepo+Warn.swift`, `BE Sources/RadarCore/MariaRepo+Warn.swift`
- Modify: `BE Sources/RadarCore/Repo.swift` (nur Zusammenfassung: `Repo` erbt zusätzlich `WarnRepo`)
- Test: `BE Tests/RadarCoreTests/WarnRepoTests.swift`

**Interfaces:**
- Consumes: `WarnAlert`, `WarnKind` (W1.1/1.2), `PushKind` (Wert `2` kommt in W2.1 hinzu; hier nur Tabellen).
- Produces:

```swift
public struct WarnStoredAlert: Sendable, Equatable { public var alert: WarnAlert; public var chainID: String; public var status: String /* "active" | "cancelled" */ }

public protocol WarnRepo: Sendable {
    /// Idempotent: speichert/aktualisiert Meldung und Gebiete (de und en getrennt über lang), setzt chainID aus references (erste Meldung der Kette) oder identifier.
    func upsertAlert(_ alert: WarnAlert, now: Date) async throws -> WarnStoredAlert
    /// msgType Cancel: markiert die referenzierten Identifier als cancelled.
    func cancelAlerts(identifiers: [String], now: Date) async throws
    func activeAlerts(now: Date, lang: String) async throws -> [WarnStoredAlert]
    func alert(identifier: String) async throws -> WarnStoredAlert?
    /// Entfernt Meldungen, die seit mehr als `retention` abgelaufen oder aufgehoben sind.
    @discardableResult func purgeWarnings(now: Date, retention: TimeInterval) async throws -> Int
    func setWarnFetchedAt(_ date: Date) async throws
    func warnFetchedAt() async throws -> Date?
}
```

- [ ] **Step 1: Migration** (rückwärtskompatibel, `IF NOT EXISTS`, wie `014`/`015`; Spaltentypen wie in `003_push.sql` prüfen und angleichen):

```sql
CREATE TABLE IF NOT EXISTS warn_alert (
  identifier VARCHAR(160) NOT NULL,
  lang CHAR(2) NOT NULL,
  chain_id VARCHAR(160) NOT NULL,
  kind VARCHAR(16) NOT NULL,
  severity TINYINT NOT NULL,
  event VARCHAR(64) NOT NULL,
  sent DATETIME NOT NULL,
  onset DATETIME NOT NULL,
  expires DATETIME NOT NULL,
  headline VARCHAR(256) NOT NULL,
  body TEXT NOT NULL,
  instruction TEXT NOT NULL,
  status VARCHAR(12) NOT NULL DEFAULT 'active',
  updated_at DATETIME NOT NULL,
  PRIMARY KEY (identifier, lang),
  KEY ix_warn_alert_expires (expires),
  KEY ix_warn_alert_chain (chain_id)
);
CREATE TABLE IF NOT EXISTS warn_alert_cell (
  identifier VARCHAR(160) NOT NULL,
  warncell_id CHAR(9) NOT NULL,
  PRIMARY KEY (identifier, warncell_id),
  KEY ix_warn_cell (warncell_id)
);
CREATE TABLE IF NOT EXISTS warn_sub (
  sub_id CHAR(36) NOT NULL PRIMARY KEY,
  types_mask TINYINT NOT NULL,
  min_sev_weather TINYINT NOT NULL DEFAULT 3,
  min_sev_frost TINYINT NOT NULL DEFAULT 1,
  min_sev_ice TINYINT NOT NULL DEFAULT 2,
  time_sensitive TINYINT NOT NULL DEFAULT 0,
  CONSTRAINT fk_warn_sub FOREIGN KEY (sub_id) REFERENCES push_sub(id) ON DELETE CASCADE
);
CREATE TABLE IF NOT EXISTS warn_sub_cell (
  sub_id CHAR(36) NOT NULL,
  warncell_id CHAR(9) NOT NULL,
  PRIMARY KEY (sub_id, warncell_id),
  KEY ix_warn_sub_cell (warncell_id),
  CONSTRAINT fk_warn_sub_cell FOREIGN KEY (sub_id) REFERENCES push_sub(id) ON DELETE CASCADE
);
CREATE TABLE IF NOT EXISTS warn_sent (
  sub_id CHAR(36) NOT NULL,
  chain_id VARCHAR(160) NOT NULL,
  kind VARCHAR(16) NOT NULL,
  last_severity TINYINT NOT NULL,
  last_onset DATETIME NOT NULL,
  last_sent_at DATETIME NOT NULL,
  PRIMARY KEY (sub_id, chain_id),
  KEY ix_warn_sent_kind (sub_id, kind),
  CONSTRAINT fk_warn_sent FOREIGN KEY (sub_id) REFERENCES push_sub(id) ON DELETE CASCADE
);
CREATE TABLE IF NOT EXISTS warn_state (
  name VARCHAR(32) NOT NULL PRIMARY KEY,
  value_at DATETIME NULL
);
```

  Typ/Länge der `push_sub.id`-Spalte vor dem Anlegen in `003_push.sql` prüfen; die FK-Spalten müssen identisch sein.
- [ ] **Step 2: Failing Repo-Vertragstest** (läuft gegen `MemoryRepo`, optional `MariaRepo` über das vorhandene Muster aus `PushTests.swift`): `upsertAlert` zweimal -> eine Zeile; `chainID` einer Update-Meldung mit `references` auf bekannte ID = chainID der Referenz, unbekannte Referenz = eigener `identifier`; `cancelAlerts` entfernt aus `activeAlerts`; abgelaufene (`expires <= now`) fehlen in `activeAlerts`; `purgeWarnings` löscht abgelaufene/aufgehobene älter als `retention` samt Gebieten; `activeAlerts(lang: "en")` liefert EN-Text, fehlt er, den DE-Text mit `lang == "de"`.
- [ ] **Step 3:** `swift test --filter WarnRepoTests` FAIL. **Step 4:** Memory- und Maria-Implementierung (Muster `MemoryRepo+Push.swift` / `MariaRepo+Push.swift`: gleiche Transaktions- und Fehlerbehandlung, Datumsformat `DATE_FORMAT(..., dateOut)`). **Step 5:** PASS, bei gesetzter Test-DB zusätzlich gegen MariaDB. **Step 6: Commit** `feat: Migration 016 und WarnRepo`.

### Task W1.4: Ingest-Schleife (Leader `warn`)

**Files:**
- Create: `BE Sources/RadarCore/WarnIngestor.swift`
- Test: `BE Tests/RadarCoreTests/WarnIngestorTests.swift`

**Interfaces:**
- Consumes: `WarnFeedSource`, `WarnCAPParser`, `WarnRepo`, `Repo.acquireLeader(name:owner:leaseSeconds:)`.
- Produces:

```swift
public struct WarnIngestResult: Sendable, Equatable {
    public var fetched: Int; public var stored: Int; public var cancelled: Int; public var ignored: Int; public var rejected: Int
    public var newOrChanged: [WarnStoredAlert]   // Eingabe für W2 (Auslöser)
}
public final class WarnIngestor: Sendable {
    public static let leaderName = "warn"
    public init(repo: any Repo, source: any WarnFeedSource, owner: String, stats: any StatsSink, clock: @escaping @Sendable () -> Date = Date.init)
    /// Ein Lauf: DIFF (60 s), STAT alle 15 min oder bei Lücke. Nur der Leader arbeitet; sonst leeres Ergebnis.
    public func tick() async throws -> WarnIngestResult
    public func release() async
}
```

- [ ] **Step 1: Failing Tests** mit `FakeWarnFeedSource` (Skript aus Antworten): Nicht-Leader tut nichts; DIFF mit Alert wird gespeichert und in `newOrChanged` gemeldet; zweiter Lauf mit `.notModified` ändert nichts; identische Meldung aus STAT nach DIFF ist kein zweites `newOrChanged`; `Cancel` setzt die referenzierte Meldung auf `cancelled`; Fehler der Quelle erhöht Backoff (60 s, 120 s, 300 s) und lässt `warnFetchedAt` unverändert; nach erfolgreichem Lauf steht `warnFetchedAt` auf `now`; STAT-Lauf wird nach 15 min und bei fehlendem DIFF-Zeitstempel (Lücke über 90 s) sofort ausgelöst.
- [ ] **Step 2:** FAIL. **Step 3:** Implementierung (Zustand: `etagDiff`, `etagStat`, `lastStatAt`, `failures` in einer `Mutex`/Actor-Struktur wie in `PushService`). DE immer, EN nur wenn `repo` mindestens eine Installation mit `locale = en` kennt (neue Methode **nicht** nötig: EN immer laden, weil die Dateien klein sind). **Step 4:** PASS. **Step 5: Commit** `feat: Warn-Ingest mit Leader-Lease`.

**W1 Abschluss:** `swift test` komplett (ohne DB), `docs/status.md` (BE) fortschreiben, Push auf `main`. Nicht deployt; Flag `WARN_INGEST_ENABLED` wird erst in W2.4 gelesen.

---

## W2: Backend Auslöser, API, Versand (BE)

**Aufwand:** M-L. **Nach:** W1 (Modelle, `WarnRepo`, `WarnIngestor`). **Test:** `swift test` (Memory), MariaDB-Vertragstests mit `RADAR_TEST_DB_*`.

### Task W2.1: Warn-Abos im Push-Bestand (kind 2) und Repo-Methoden

**Files:**
- Modify: `BE Sources/RadarCore/PushModels.swift` (`PushKind.warning = 2`), `BE Sources/RadarCore/MariaRepo+Push.swift` (`evaluationSubscriptions`, Zähler), `BE Sources/RadarCore/MemoryRepo+Push.swift` (gleich), `BE Sources/RadarCore/Repo.swift` (Protokoll `WarnSubRepo`)
- Create: `BE Sources/RadarCore/WarnSubRepo+Maria.swift`, `BE Sources/RadarCore/WarnSubRepo+Memory.swift`
- Test: `BE Tests/RadarCoreTests/WarnSubRepoTests.swift`, Ergänzung in `PushTests.swift`

**Interfaces:**
- Produces:

```swift
public struct WarnSubscriptionInput: Sendable, Equatable {
    public var warncellIDs: [String]; public var types: Set<WarnKind>; public var minSeverity: [WarnKind: Int]
    public var enabled: Bool; public var timeSensitive: Bool
}
public struct WarnSubscription: Sendable, Equatable {
    public var id: String; public var installationID: String; public var input: WarnSubscriptionInput
}
public struct WarnSentRecord: Sendable, Equatable {
    public var chainID: String; public var kind: WarnKind; public var lastSeverity: Int; public var lastOnset: Date; public var lastSentAt: Date
}
public enum WarnAddResult: Sendable, Equatable { case added, limit /* 409 warn_limit */, unknownCell(String) /* 409 warncell_unknown */ }
public protocol WarnSubRepo: Sendable {
    func addWarnSubscription(installationID: String, id: String, _ input: WarnSubscriptionInput, now: Date) async throws -> WarnAddResult
    func updateWarnSubscription(installationID: String, id: String, _ input: WarnSubscriptionInput) async throws -> Bool
    func deleteWarnSubscription(installationID: String, id: String) async throws -> Bool
    func warnSubscriptions(installationID: String) async throws -> [WarnSubscription]
    /// Aktive Warn-Abos, die mindestens eines der Gebiete enthalten (Index warn_sub_cell.warncell_id).
    func warnSubscriptions(matching warncellIDs: [String]) async throws -> [WarnSubscription]
    func warnSent(subID: String) async throws -> [WarnSentRecord]
    func recordWarnSent(subID: String, _ record: WarnSentRecord) async throws
}
```

- [ ] **Step 1: Failing Tests.** (a) Ein Warn-Abo wird als `push_sub`-Zeile `kind = 2`, `cell_x = 0`, `cell_y = 0`, `threshold = 1`, `lead_min = 10`, `grid_version = 1` gespeichert. (b) **`evaluationSubscriptions` liefert kein `kind = 2`** und `subscriptions(installationID:)` (Regenliste) listet es nicht; das 10er-Limit und die Regionenzähler ignorieren es. (c) 11. Warn-Abo -> `.limit`; 65 Warngebiete im Body sind schon API-Fehler (W2.3); 129. Gebiet der Installation -> `.limit`. (d) `unknownCell`: Prüfung gegen die bekannte Gemeindeliste (siehe Step 3). (e) Löschen der Installation löscht Abo, `warn_sub*`, `warn_sent` (Cascade bzw. Memory-Entsprechung). (f) `warnSubscriptions(matching:)` findet nur aktivierte Abos mit Schnittmenge.
- [ ] **Step 2:** FAIL. **Step 3: Implementierung.** Bekannte Gemeindeliste: Tabelle `warn_cell_known(warncell_id CHAR(9) PRIMARY KEY)` wird vom Ingest befüllt (jede in einer Meldung gesehene ID, `INSERT IGNORE`); beim Seed einer leeren Tabelle ist die Prüfung abgeschaltet (alle IDs akzeptiert), solange `warn_cell_known` leer ist, damit Abos vor der ersten Meldung nicht scheitern. Tabelle in `016_warnings.sql` (W1.3) als zusätzlicher Block nachtragen, falls W1 schon gemergt ist: neue Datei `017_warn_cell_known.sql`. Genaue Ausgangsliste: `https://www.dwd.de/DE/leistungen/opendata/help/warnungen/warnungen_gemeinden_csv.html` (CSV `WARNCELLID;NAME;...`, 11 828 Zeilen am 7.11.2026) wird einmalig per `tools/seed_warncells.sh` in die Tabelle geladen (Skript im Task anlegen, nicht automatisch ausführen).
- [ ] **Step 4:** Alle `PushKind`-Switches kompilieren lassen (`swift build`), Warnabos aus `PushDiagnosis`/Dashboard-Zählern ausschließen (`grep -n "kind" Sources/RadarCore/Dashboard*.swift Sources/RadarCore/Insights*.swift`; jede Zählung nach Regen-Abos filtert `kind IN (0,1)`). **Step 5:** PASS. **Step 6: Commit** `feat: Warn-Abos als push_sub kind 2`.

### Task W2.2: WarnEvaluator und Payload (rein, ohne I/O)

**Files:**
- Create: `BE Sources/RadarCore/WarnEvaluator.swift`, `BE Sources/RadarCore/WarnPayload.swift`
- Test: `BE Tests/RadarCoreTests/WarnEvaluatorTests.swift`, `BE Tests/RadarCoreTests/WarnPayloadTests.swift`

**Interfaces:**
- Consumes: `WarnAlert`, `WarnSubscription`, `WarnSentRecord`, `WarnKind`.
- Produces:

```swift
public enum WarnSuppression: String, Sendable { case cancel, expired, stale, noMatch, typeOff, belowThreshold, noChange, locked, disabled }
public enum WarnDecision: Sendable, Equatable { case send, suppress(WarnSuppression) }

public enum WarnEvaluator {
    public static let maxAge: TimeInterval = PushEvaluator.maxRunAge      // 20 min
    public static let repeatLock: TimeInterval = PushEvaluator.repeatLock // 60 min
    public static let earlierOnset: TimeInterval = 3600
    public static let defaultMinSeverity: [WarnKind: Int] = [.severeWeather: 3, .frost: 1, .ice: 2]
    /// chain: letzter Versand dieser Kette an dieses Abo; lastOfKind: letzter Versand (beliebige Kette) desselben Typs an dieses Abo.
    public static func decide(sub: WarnSubscription, alert: WarnAlert, chain: WarnSentRecord?, lastOfKind: WarnSentRecord?, now: Date) -> WarnDecision
}

public enum WarnPayload {
    public static let maxBodyBytes = 900
    public static let maxPayloadBytes = 1900
    public static func make(alert: WarnAlert, subID: String, timeSensitive: Bool) -> String?   // nil, wenn Gesamtgröße nicht einhaltbar
    public static func dedupeKey(subID: String, identifier: String) -> String   // sha256 hex, 64 Zeichen
    public static func collapseID(subID: String, kind: WarnKind) -> String      // "<sub>:<kind>", höchstens 64 Bytes
    public static func truncate(_ text: String, maxBytes: Int) -> String        // an Zeichengrenze, "…" bei Kürzung
}
```

- [ ] **Step 1: Failing Tabellentests** (`now = 2026-11-07T12:40:00Z`, Alert `sent = 12:31:00Z`, `expires = now + 8h`, `onset = now + 9h`; Abo Gebiete `["814522510"]`, Typen alle, Standardstufen):

```swift
func testFreshMatchingAlertIsSent() { XCTAssertEqual(decide(), .send) }
func testCancelNeverSends() { XCTAssertEqual(decide(msg: .cancel), .suppress(.cancel)) }
func testExpired() { XCTAssertEqual(decide(expires: now), .suppress(.expired)) }
func testStaleOver20Minutes() { XCTAssertEqual(decide(sent: now.addingTimeInterval(-1201)), .suppress(.stale)) }
func testExactly20MinutesIsFresh() { XCTAssertEqual(decide(sent: now.addingTimeInterval(-1200)), .send) }
func testNoCellOverlap() { XCTAssertEqual(decide(cells: ["999999999"]), .suppress(.noMatch)) }
func testTypeDisabled() { XCTAssertEqual(decide(types: [.ice]), .suppress(.typeOff)) }
func testBelowThresholdSevereWeatherLevel2() { XCTAssertEqual(decide(kind: .severeWeather, severity: 2), .suppress(.belowThreshold)) }
func testSevereWeatherLevel3Sent() { XCTAssertEqual(decide(kind: .severeWeather, severity: 3), .send) }
func testIceLevel1Suppressed_Level2Sent() { /* ice 1 -> belowThreshold, ice 2 -> send */ }
func testUpdateSameLevelSuppressed() { XCTAssertEqual(decide(chain: rec(sev: 1, onset: alertOnset)), .suppress(.noChange)) }
func testUpdateHigherLevelSent() { XCTAssertEqual(decide(severity: 2, chain: rec(sev: 1, onset: alertOnset)), .send) }
func testUpdateOnsetMoreThanOneHourEarlierSent() { XCTAssertEqual(decide(chain: rec(sev: 1, onset: alertOnset.addingTimeInterval(3601))), .send) }
func testUpdateOnsetExactlyOneHourEarlierSuppressed() { XCTAssertEqual(decide(chain: rec(sev: 1, onset: alertOnset.addingTimeInterval(3600))), .suppress(.noChange)) }
func testLockWithinSixtyMinutesSameOrLowerLevel() { XCTAssertEqual(decide(lastOfKind: rec(sev: 1, sentAgo: 600)), .suppress(.locked)) }
func testHigherLevelBreaksLock() { XCTAssertEqual(decide(severity: 2, lastOfKind: rec(sev: 1, sentAgo: 600)), .send) }
func testLockExpiresAfterSixtyMinutes() { XCTAssertEqual(decide(lastOfKind: rec(sev: 1, sentAgo: 3600)), .send) }
func testDisabledSubscription() { XCTAssertEqual(decide(enabled: false), .suppress(.disabled)) }
```

  Der Agent baut die Hilfsfunktion `decide(...)` mit Standardwerten im Testfile und schreibt alle 17 Tests aus (keine Auslassungen, `rec(sev:onset:sentAgo:)` erzeugt `WarnSentRecord`). Reihenfolge der Prüfungen in `decide`: `disabled`, `cancel`, `expired`, `stale`, `noMatch`, `typeOff`, `belowThreshold`, Kettenprüfung (`noChange`), Sperre (`locked`), sonst `send`.
- [ ] **Step 2:** `swift test --filter WarnEvaluatorTests` FAIL. **Step 3: Implementierung:**

```swift
public enum WarnEvaluator {
    // Konstanten wie oben
    public static func decide(sub: WarnSubscription, alert: WarnAlert, chain: WarnSentRecord?, lastOfKind: WarnSentRecord?, now: Date) -> WarnDecision {
        let input = sub.input
        guard input.enabled else { return .suppress(.disabled) }
        if alert.msgType == .cancel { return .suppress(.cancel) }
        if alert.expires <= now { return .suppress(.expired) }
        if now.timeIntervalSince(alert.sent) > maxAge { return .suppress(.stale) }
        guard !Set(input.warncellIDs).isDisjoint(with: alert.warncellIDs) else { return .suppress(.noMatch) }
        guard input.types.contains(alert.kind) else { return .suppress(.typeOff) }
        let minimum = input.minSeverity[alert.kind] ?? defaultMinSeverity[alert.kind] ?? 1
        guard alert.severity >= minimum else { return .suppress(.belowThreshold) }
        if let chain {
            let higher = alert.severity > chain.lastSeverity
            let otherKind = alert.kind != chain.kind
            let earlier = chain.lastOnset.timeIntervalSince(alert.onset) > earlierOnset
            if !(higher || otherKind || earlier) { return .suppress(.noChange) }
        }
        if let last = lastOfKind, now.timeIntervalSince(last.lastSentAt) < repeatLock, alert.severity <= last.lastSeverity {
            return .suppress(.locked)
        }
        return .send
    }
}
```

  `WarnPayload.make` baut ein `[String: Any]` -> JSON (`JSONSerialization`, `sortedKeys`): `aps` {`alert` {`title` = headline (auf 120 Bytes gekürzt), `body` = `truncate(text, 900 - 16) + "\nQuelle: DWD"`}, `sound` "default", `thread-id` = subID, `mutable-content` 1, optional `interruption-level` "time-sensitive" bei `timeSensitive || severity == 4`}, plus `type` "warning", `kind`, `severity`, `sent` (ISO UTC), `warning_id`. Gesamtgröße über `maxPayloadBytes` -> Body weiter kürzen, bis es passt; sonst `nil`. Payload-Tests: UTF-8-Grenzen (Umlaute, Emoji), Länge je Eingabe, `time-sensitive` nur bei Stufe 4/Schalter, `dedupeKey` 64 Hex-Zeichen und stabil, `collapseID` höchstens 64 Bytes.
- [ ] **Step 4:** PASS. **Step 5: Commit** `feat: WarnEvaluator und Payload`.

### Task W2.3: WarnService (Auslöser), API-Routen, Capabilities, Flags

**Files:**
- Create: `BE Sources/RadarCore/WarnService.swift`, `BE Sources/RadarCore/WarnApi.swift`
- Modify: `BE Sources/RadarCore/Config.swift` (`warn.ingestEnabled`, `warn.pushEnabled` aus `WARN_INGEST_ENABLED`, `WARN_PUSH_ENABLED`, Standard `false`; Eintrag in `ConfigRegistry.swift` wie die bestehenden Flags), `BE Sources/RadarCore/Api.swift` (Capabilities, Route `GET /v1/warnings/active`), `BE Sources/RadarCore/PushApi.swift` (Warn-Abo-Routen, Delegation an `WarnApi`), `BE Sources/radar/Radar.swift` (Schleife `runWarnLoop` neben `runPushLoop`)
- Test: `BE Tests/RadarCoreTests/WarnServiceTests.swift`, `BE Tests/RadarCoreTests/WarnApiTests.swift`

**Interfaces:**
- Consumes: alles aus W1/W2.1/W2.2, `PushRepo.commitEvaluation`-Muster (hier neue Methode siehe unten), `NewOutboxItem(subID:dedupeKey:collapseID:payloadJSON:expiresAt:)`, `ApnsSender` unverändert.
- Produces:

```swift
public final class WarnService: Sendable {
    public init(config: Config, repo: any Repo, stats: any StatsSink, clock: @escaping @Sendable () -> Date = Date.init)
    /// Nimmt das Ergebnis eines Ingest-Laufs: für jede neue/geänderte Meldung passende Abos finden, decide() aufrufen,
    /// Outbox-Einträge schreiben und warn_sent aktualisieren. Gibt die Zahl der eingereihten Pushes zurück.
    public func trigger(_ changed: [WarnStoredAlert]) async throws -> Int
}
```

  Neue Repo-Methode in `WarnSubRepo`: `func commitWarnSend(items: [(sub: String, record: WarnSentRecord, outbox: NewOutboxItem)], now: Date) async throws -> Int` (atomar: `INSERT IGNORE` Outbox über `dedupe_key`, `warn_sent` nur bei tatsächlich neuer Zeile); Implementierungen in `WarnSubRepo+Maria/Memory`.
- [ ] **Step 1: Failing Tests (Service):** Fake-Repo mit zwei Abos (eins trifft, eins nicht) -> genau ein Outbox-Eintrag mit `payload.type == "warning"`; zweiter `trigger` mit derselben Meldung -> kein zweiter Eintrag (Dedupe); Update höherer Stufe -> neuer Eintrag mit gleicher `collapseID`; Update gleicher Stufe -> keiner; Meldung älter als 20 min -> keiner; `WARN_PUSH_ENABLED=false` -> `trigger` gibt 0 zurück und schreibt nichts; Outbox `expiresAt = min(alert.expires, now + 6 h)`.
- [ ] **Step 2: Failing Tests (API):** `GET /v1/warnings/active` ohne Flag `404 {"error":"not_found"}`, mit Flag `200` und Struktur wie `docs/fixtures/warnings/active.200.json` (Vergleich der Schlüssel; `Accept-Language: en` liefert EN-Text); ohne Abgleich (`warnFetchedAt == nil`) `503 warnings_unavailable`; `Cache-Control: public, max-age=30`; Warn-Abo POST/GET/PUT/DELETE: Auth `401` einheitlich, Body-Validierung (`warncell_ids` 9 Ziffern, 1 bis 64, keine Duplikate; `types` nicht leer; `min_severity` 1 bis 4; Typfehler -> `400 invalid_warn_subscription`; zu groß `413 too_large`), `409 warn_limit`, `409 warncell_unknown`, Pfade mit `WARN_PUSH_ENABLED=false` -> `404`; **Rückwärtskompatibilität:** alle bestehenden Push-API-Tests laufen unverändert; `GET .../subscriptions` enthält keine Warn-Abos. `GET /v1/status`: `capabilities` enthält `warnings` genau bei `WARN_INGEST_ENABLED` (auch bei `PUSH_ENABLED=false`) und `warnings_push` genau bei den drei Flags.
- [ ] **Step 3:** FAIL. **Step 4: Implementierung.** `trigger`: pro Meldung `repo.warnSubscriptions(matching: alert.warncellIDs)`; je Abo `warnSent(subID:)` laden, `chain` = Eintrag mit `chainID == stored.chainID`, `lastOfKind` = jüngster Eintrag gleichen Typs; `WarnEvaluator.decide`; bei `.send` Payload (`nil` -> Zähler `warn_payload_too_large` erhöhen, kein Push); Zähler über feste Labels (`warn_sent`, `warn_suppressed_<reason>`, kein Abo-/Gebietsbezug) im bestehenden `StatsSink`/`PushObserver`-Muster. `Radar.swift`: `runWarnLoop` startet `WarnIngestor` und `WarnService` nur bei `config.warn.ingestEnabled` (Leader-Lease `warn`, Schleife alle 60 s, wie `runPushLoop` aufgebaut; bei Cancel `trigger` nicht aufrufen), ruft `repo.purgeWarnings(now:retention: 86400)` einmal pro Stunde. Versand läuft weiter über `PushService.dispatch` (läuft nur bei `PUSH_ENABLED`); Warn-Outbox-Einträge werden von `dueOutbox` wie die Regeneinträge geholt, **keine** Änderung am Versand. Antwort-JSON von `/v1/warnings/active` mit `JSONSerialization` bauen, ISO-Zeiten über `TimeUtil.toISO`.
- [ ] **Step 5:** PASS (`swift test --filter Warn`), danach vollständiger `swift test`; **Step 6: Commit** `feat: Warn-Auslöser, API und Capabilities (Flags aus)`.

### Task W2.4: Dokumentation und Übergabe

- [ ] `docs-site/content/api.md` gegen die Implementierung abgleichen (Abweichungen im Vertrag korrigieren und in `docs/status.md` benennen); `docs-site/content/betrieb.md`: Flags `WARN_INGEST_ENABLED`, `WARN_PUSH_ENABLED`, Reihenfolge Rollout (Migration 016/017 vor Deploy, Ingest an, Push zuletzt); `docs/status.md` (BE) mit Prüfungen aktualisieren; `docs/fixtures/warnings/` bleibt die Vertragsquelle für die App. **Kein Deploy.** Commit und Push auf `main`.

---

## W3: App Gemeindegeometrie und Zuordnung (APP)

**Aufwand:** M. **Nach:** W0. **Build/Test:** nach `README.md`, z. B. `xcodebuild -project Weather.xcodeproj -scheme Weather -destination 'platform=iOS Simulator,name=iPhone 18 Pro' CODE_SIGNING_ALLOWED=NO test -only-testing:WeatherTests/WarnMatcherTests`; vorher `xcodegen generate`, wenn neue Ordner nicht im Projekt erscheinen.

### Task W3.1: Quelle und Lizenz der Gemeinde-Geometrie klären (Gate)

**Files:** Create: `APP docs/research/warngebiete-geometrie.md`

- [ ] **Step 1:** DWD-Warngebiete (Gemeinden) als Shapefile/GeoJSON suchen und prüfen: Startseite `https://www.dwd.de/DE/leistungen/opendata/help/warnungen/` bzw. "Warngebiete" in `https://www.dwd.de/DE/leistungen/opendata/hilfe.html`; Dateiname, Stand, Koordinatensystem, Größe, Lizenz (BKG/GeoBasis-DE, Hinweis "Daten modifiziert" wie im CAP-`LICENSE`-Feld), Weitergabe in einer App zulässig. Ergebnis in die Doku (Quelle, Datum, Lizenztext wörtlich, Größe, Spalten, ob `WARNCELLID` enthalten).
- [ ] **Step 2 (Gate):** Ist die Quelle nicht abrufbar oder die Lizenz die Bündelung nicht erlaubt, stoppt W3 hier, trägt den Befund in `docs/status.md` ein und stellt dem Lead eine Todolino-Frage (Alternativen: Gemeinde-Mittelpunkte aus `cells.csv`-Liste plus nächste Gemeinde, gröber; Landkreis-Ebene `DISTRICT_*`). Ohne Gate-Freigabe keine Datei unter `Weather/Resources/` anlegen. **Step 3:** Commit `docs: Quelle Warngebiete-Geometrie`.

### Task W3.2: Aufbereitungsskript und Binärformat

**Files:** Create: `APP tools/warn_geometry.py`, `APP Weather/Resources/WarnGeometry.bin` (Ergebnis), `APP WeatherTests/Fixtures/warn/warn_geometry_sample.bin` (Test-Beispiel, erzeugt vom Skript aus einem 3-Gemeinden-Beispiel)

**Format `WGEO1` (little endian):** `magic "WGEO1"` (5 Byte), `UInt32 cellCount`; je Gemeinde: `UInt32 warncellID` (9 Ziffern passen in UInt32), `Int32 minLatE5, minLonE5, maxLatE5, maxLonE5` (Grad mal 1e5, gerundet), `UInt16 ringCount`; je Ring: `UInt32 pointCount`, danach `pointCount` mal (`Int32 latE5`, `Int32 lonE5`). Löcher sind eigene Ringe mit negativem Vorzeichen nicht nötig: Ringe gelten per Even-Odd-Regel. Koordinaten WGS84.

- [ ] **Step 1:** Skript (nur Python-Stdlib: `struct`, `sys`, `argparse`) liest `.shp`/`.dbf` (Typ Polygon = 5; DBF-Feld mit der 9-stelligen WARNCELLID wird in W3.1 benannt und als `--id-field` übergeben), vereinfacht jeden Ring mit Douglas-Peucker (Toleranz `--tolerance-m`, Standard 150 m, Ring bleibt mit mindestens 4 Punkten erhalten), schreibt `WGEO1`. Aufruf: `python3 -I tools/warn_geometry.py --shp <pfad>/gemeinden.shp --id-field <feld> --tolerance-m 150 --out Weather/Resources/WarnGeometry.bin`. Ausgabe auf stdout: Zahl Gemeinden, Dateigröße. Sollgröße unter 8 MB; sonst Toleranz erhöhen und in der Doku vermerken.
- [ ] **Step 2:** Test-Beispiel: `python3 -I tools/warn_geometry.py --self-test-sample WeatherTests/Fixtures/warn/warn_geometry_sample.bin` schreibt drei Quadrate (IDs `100000001`, `100000002`, `100000003`; `100000002` mit Loch-Ring), `--self-test-sample` ist im Skript implementiert. **Step 3:** Commit `feat: Skript Warngeometrie`, Binärdatei separat committen (`feat: gebuendelte Warngeometrie`) mit Größe im Commit-Text.

### Task W3.3: Leser und Punkt-in-Polygon (TDD)

**Files:** Create: `APP Weather/Warnings/Matching/WarnGeometry.swift`, `APP Weather/Warnings/Matching/WarnCellMatcher.swift`; Test: `APP WeatherTests/WarnGeometryTests.swift`, `APP WeatherTests/WarnMatcherTests.swift`

**Interfaces:**
- Produces:

```swift
typealias WarnCellID = String   // 9 Ziffern

struct WarnGeometry: Sendable {
    struct Cell: Sendable { let id: WarnCellID; let minLat, minLon, maxLat, maxLon: Double; let rings: [[(lat: Double, lon: Double)]] }
    let cells: [Cell]
    static func decode(_ data: Data) throws -> WarnGeometry          // wirft WarnGeometryError.badFormat
    static func bundled(in bundle: Bundle = .main) throws -> WarnGeometry
}
enum WarnGeometryError: Error, Equatable { case badFormat, missingResource }

struct WarnCellMatcher: Sendable {
    init(geometry: WarnGeometry)
    /// Gemeinde, die den Punkt enthält (nil außerhalb Deutschlands); bei Randpunkten die kleinste ID (deterministisch).
    func cell(containing lat: Double, lon: Double) -> WarnCellID?
    /// Alle Gemeinden, die den Kreis schneiden (Mittelpunkt, Radius in km), sortiert, höchstens `limit` (Standard 64; bei Überschreitung die nächsten 64 zum Mittelpunkt).
    func cells(intersectingCircleLat lat: Double, lon: Double, radiusKm: Double, limit: Int) -> [WarnCellID]
}
```

- [ ] **Step 1: Failing Tests** gegen das Beispiel (`warn_geometry_sample.bin` im Testbundle): `decode` liest 3 Zellen; kaputtes Magic/abgeschnittene Daten -> `.badFormat`; Punkt in Quadrat 1 -> `100000001`; Punkt im Loch von `100000002` -> nil; Punkt außerhalb -> nil; Randpunkt (genau auf der gemeinsamen Kante zweier Quadrate) -> kleinere ID; Kreis, der nur Quadrat 1 trifft; Kreis über zwei Quadrate -> beide; Kreis mit Radius 0,1 km mitten in Quadrat 3 -> nur diese; `limit: 1` bei zwei Treffern -> der zum Mittelpunkt nähere. Die Bounding-Box-Vorauswahl wird mitgetestet (Zelle weit weg, nicht geprüft: Zähler `matcher.testStats.polygonTests` bleibt klein).
- [ ] **Step 2:** FAIL. **Step 3: Implementierung:** `decode` mit `Data`-Cursor (`withUnsafeBytes`/`loadUnaligned`), Even-Odd-Strahlverfahren in lat/lon (kleine Flächen, Genauigkeit reicht), Kreis-Schnitt: Zelle trifft, wenn (a) ein Kreispunkt (Mittelpunkt oder 16 Punkte auf dem Rand) in der Zelle liegt oder (b) ein Zellenringpunkt im Kreis liegt oder (c) eine Ringkante den Kreis schneidet (Abstand Punkt-Strecke in lokaler Näherung `dx = Δlon·cos(lat)·111,32`, `dy = Δlat·111,32` km). **Step 4:** PASS. **Step 5:** Test mit der echten gebündelten Datei: ein Test, der `WarnGeometry.bundled()` lädt und prüft `cells.count > 11_000` und dass ein Punkt in Berlin (52,52 / 13,40) in genau eine Zelle fällt (nur wenn die Datei aus W3.2 existiert). **Step 6: Commit** `feat: Warngebiet-Zuordnung auf dem Geraet`.

---

## W4: App Gateway, Abo-Verwaltung, Einstellungen (APP)

**Aufwand:** M. **Nach:** W0 (Vertrag), W3 (`WarnCellMatcher`, `WarnCellID`). **Nicht vor W2 testbar gegen echtes Backend**, aber gegen Fixtures vollständig testbar.

### Task W4.1: Modelle und Gateway

**Files:** Create: `APP Weather/Warnings/Subscriptions/WarnModels.swift`, `APP Weather/Warnings/Subscriptions/WarnGateway.swift`; Test: `APP WeatherTests/WarnGatewayTests.swift`; Fixtures: `APP WeatherTests/Fixtures/warn/warn-subscription.request.json`, `active.200.json` (Kopien aus BE `docs/fixtures/warnings/`)

**Interfaces:**
- Consumes: Muster und Authentifizierung aus `Weather/Push/PushGateway.swift` und `PushKeychain.swift` (Installations-ID und Secret) — vor dem Schreiben lesen und denselben Transport (`URLSession`-Injektion) benutzen.
- Produces:

```swift
enum WarnKind: String, Codable, CaseIterable, Sendable { case severeWeather = "severe_weather", frost, ice }

struct WarnSubscriptionSettings: Codable, Equatable, Sendable {
    var warncellIDs: [WarnCellID]
    var types: Set<WarnKind>
    var minSeverity: [WarnKind: Int]     // 1...4
    var enabled: Bool
    var timeSensitive: Bool
    static let defaultMinSeverity: [WarnKind: Int] = [.severeWeather: 3, .frost: 1, .ice: 2]
}

enum WarnGatewayError: Error, Equatable { case unauthorized, limit, cellUnknown, invalid, rateLimited, unavailable, notFound }

protocol WarnGateway: Sendable {
    func create(_ settings: WarnSubscriptionSettings) async throws -> String        // Abo-ID
    func update(id: String, _ settings: WarnSubscriptionSettings) async throws
    func delete(id: String) async throws
    func list() async throws -> [(id: String, settings: WarnSubscriptionSettings)]
}
final class URLSessionWarnGateway: WarnGateway { init(baseURL: URL, installation: PushInstallationCredentials, session: URLSession) }
```

  (`PushInstallationCredentials` ist der bestehende oder in der Datei benannte Typ aus `PushGateway.swift`; der Agent verwendet den vorhandenen Typnamen.)
- [ ] **Step 1: Failing Tests** mit `URLProtocol`-Mock: Request-Body für `create` ist JSON-identisch zu `warn-subscription.request.json` (Schlüssel sortiert, `min_severity` als Objekt, `types` sortiert); `409 warn_limit` -> `.limit`, `409 warncell_unknown` -> `.cellUnknown`, `400 invalid_warn_subscription` -> `.invalid`, `401` -> `.unauthorized`, `429` -> `.rateLimited`, `404` -> `.notFound`, Netzwerkfehler -> `.unavailable`; Header `X-Installation-Secret` gesetzt; kein Koordinatenfeld im Body. **Step 2:** FAIL. **Step 3:** Implementierung. **Step 4:** PASS. **Step 5: Commit** `feat: WarnGateway`.

### Task W4.2: Abo-Manager (je Ort/Gebiet) und lokaler Namensspeicher

**Files:** Create: `APP Weather/Warnings/Subscriptions/WarnManager.swift`; Modify: `APP Shared/NotificationNameStore.swift` nur falls die Zuordnung Abo-ID -> Name hier nicht ausreicht (vor Änderung lesen, Tests `NotificationNameTests` müssen grün bleiben); Test: `APP WeatherTests/WarnManagerTests.swift`

**Interfaces:**
- Consumes: `WarnGateway`, `WarnCellMatcher`, `PlaceStore` (`Shared/PlaceStore.swift`, Orte), bestehende Gebietsdaten (`Weather/Views/RegionViews.swift`, Kreis: Mittelpunkt und Radius), `NotificationNameStore`.
- Produces:

```swift
@MainActor final class WarnManager: ObservableObject {
    @Published private(set) var capabilityWarnings: Bool     // "warnings" in /v1/status
    @Published private(set) var capabilityWarningsPush: Bool // "warnings_push"
    @Published var settings: WarnUserSettings                // global: types, minSeverity, timeSensitive, enabled (UserDefaults, keine Koordinaten)
    func refreshCapabilities() async
    /// Gleicht Server-Abos mit gespeicherten Orten/Gebieten ab: legt fehlende an, aktualisiert geänderte, löscht verwaiste. Nur bei capabilityWarningsPush und enabled.
    func reconcile() async
}
struct WarnUserSettings: Codable, Equatable { var enabled = false; var types: Set<WarnKind> = Set(WarnKind.allCases); var minSeverity = WarnSubscriptionSettings.defaultMinSeverity; var timeSensitive = false }
```

- [ ] **Step 1: Failing Tests** (Fake-Gateway, Fake-Matcher): ohne Capability `warnings_push` kein Gateway-Aufruf und `capabilityWarningsPush == false`; ein Ort -> ein Abo mit genau einer WARNCELLID; ein Gebiet -> Abo mit allen geschnittenen Gemeinden (höchstens 64); Ort ohne Zuordnung (außerhalb Deutschlands) -> kein Abo; Ort gelöscht -> Abo gelöscht; Einstellungsänderung -> `update`; `.limit` -> Fehlerzustand `limitReached` ohne Absturz; `.cellUnknown` -> Zustand `geometryOutdated` (Text "Warngebiete veraltet, bitte App aktualisieren"); Name verlässt das Gerät nie (Gateway-Mock prüft, dass der Body keinen Namen enthält); Abo-ID -> Name wird im `NotificationNameStore` abgelegt und beim Löschen entfernt. **Step 2:** FAIL. **Step 3:** Implementierung (Abo-IDs lokal in einer Zuordnung `placeID/regionID -> subID` in der App-Group-`UserDefaults`, wie `NotificationNameStore.mapping`). **Step 4:** PASS. **Step 5: Commit** `feat: WarnManager`.

### Task W4.3: Einstellungen "Warnungen"

**Files:** Create: `APP Weather/Views/WarnSettingsView.swift`; Modify (nur Einhängepunkt, eine Zeile je Datei): `APP Weather/Views/InformationSheet.swift` oder `APP Weather/Views/PlacesSheet.swift` (Stelle der bestehenden Mitteilungs-Einstellungen im Code suchen: `grep -n "Regenhinweise\|PUSH_" Weather/Views/*.swift`); Strings: `APP Weather/Resources/de.lproj/Localizable.strings`, `en.lproj` (Schlüssel `WARN_*`); Tests: `APP WeatherTests/WarnSettingsPresentationTests.swift`, UI-Test in `WeatherUITests` (Datei dort ergänzen, Name `WarnSettingsUITests.swift`)

**Interfaces:** `WarnSettingsView(manager: WarnManager)`; Presentation-Logik rein in `WarnSettingsPresentation` (`static func sections(capability: Bool, settings: WarnUserSettings) -> [Row]`, `static func levelTitle(_ level: Int) -> String`, deutsch/englisch über `NSLocalizedString`).

- [ ] **Step 1: Failing Tests:** Bereich ist ohne `warnings_push` nicht vorhanden (UI-Test mit Launch-Argument `-UITestWarnCapabilities none|push` und Fake-Status); Stufentexte: 1 "Wetterwarnung", 2 "Markante Wetterwarnung", 3 "Unwetterwarnung", 4 "Extreme Unwetterwarnung" (en: "Weather warning", "Marked weather warning", "Severe weather warning", "Extreme weather warning") und stets mit Ziffer "Stufe N" / "Level N"; Standardwerte 3/1/2; Zeitkritisch-Schalter erklärt "Nur bei Stufe 4 immer, sonst nur wenn eingeschaltet"; Hinweistext "Kein Ersatz für amtliche Warnkanäle (WarnWetter-App, NINA)" ist sichtbar, bevor der Schalter die Systemabfrage auslöst (Reihenfolge im Presenter-Test: Hinweis-Row steht vor dem Haupt-Schalter oder die Abfrage folgt erst nach Bestätigung). VoiceOver-Labels je Zeile als ein Satz. **Step 2:** FAIL. **Step 3:** Implementierung. **Step 4:** `xcodebuild ... test` für diese Tests PASS; Screenshot normal und AccessibilityXXXL nach Muster aus `docs/status.md` Abschnitt Build 26 prüfen (nur ansehen, nicht committen). **Step 5: Commit** `feat: Einstellungen Warnungen`.

---

## W5: App Warnansicht Liste und Karte (APP)

**Aufwand:** M-L. **Nach:** W0, W3. Dateien getrennt von W4; gebaut wird nicht gleichzeitig mit W4 (ein `xcodebuild`-Verantwortlicher pro Welle).

### Task W5.1: Abruf und Filter (rein)

**Files:** Create: `APP Weather/Warnings/Feed/WarnFeed.swift`, `APP Weather/Warnings/Feed/WarnFeedStore.swift`; Test: `APP WeatherTests/WarnFeedTests.swift`; Fixture `APP WeatherTests/Fixtures/warn/active.200.json`

**Interfaces:**
- Produces:

```swift
struct ActiveWarning: Codable, Equatable, Identifiable, Sendable {
    let id: String; let kind: WarnKind; let severity: Int; let event: String
    let sent: Date; let onset: Date; let expires: Date
    let headline: String; let text: String; let instruction: String; let lang: String; let warncellIDs: [WarnCellID]
}
struct ActiveWarningsResponse: Decodable, Sendable { let fetchedAt: Date; let warnings: [ActiveWarning] }   // JSON snake_case, ISO 8601

enum WarnFilter {
    static func relevant(_ all: [ActiveWarning], cells: Set<WarnCellID>, now: Date) -> [ActiveWarning]   // Schnittmenge, nicht abgelaufen, sortiert: Stufe absteigend, dann onset
    static func staleness(fetchedAt: Date, now: Date) -> Staleness   // .fresh (<= 30 min), .stale (> 30 min)
}
@MainActor final class WarnFeedStore: ObservableObject {
    @Published private(set) var warnings: [ActiveWarning]; @Published private(set) var fetchedAt: Date?; @Published private(set) var state: State // .idle,.loading,.loaded,.failed(cachedAt)
    func refresh() async   // GET /v1/warnings/active mit Accept-Language, Cache in Application Support (nur öffentliche Daten), Fehler -> letzter Stand
}
```

- [ ] **Step 1: Failing Tests:** Dekodierung der Fixture (`snake_case`, ISO-Daten mit `Z`); `relevant` filtert nach Zellen und Ablauf, Reihenfolge Stufe 4 vor 3; `staleness` Grenze exakt 30 min = fresh, darüber stale; `refresh` bei Netzfehler behält Liste und setzt `.failed(cachedAt:)`; kein Aufruf ohne Capability `warnings` (Store bekommt `isEnabled`-Closure); Request enthält keinen Ort und keine Installations-Kennung (Mock prüft Header/Query leer außer `Accept-Language`). **Step 2:** FAIL. **Step 3:** Implementierung. **Step 4:** PASS. **Step 5: Commit** `feat: Warn-Feed der App`.

### Task W5.2: Liste, Detail, Karte

**Files:** Create: `APP Weather/Views/WarningsListView.swift`, `APP Weather/Views/WarningDetailView.swift`, `APP Weather/Map/WarnOverlay.swift`, `APP Weather/Warnings/Feed/WarningPresentation.swift`; Strings `WARN_*` in `Localizable.strings` de/en; Test: `APP WeatherTests/WarningPresentationTests.swift`, UI-Test `WeatherUITests/WarningsUITests.swift`; Einhängepunkt: Zugang aus der Hauptansicht nur bei Capability `warnings` (Stelle in `Weather/Views/RadarScreen.swift` oder `PlacesSheet.swift` wählen und in der Statusdoku nennen)

**Interfaces:** `WarningPresentation.levelWord(_:)` (Texte wie W4.3), `levelSymbol(_:)` (SF Symbols `exclamationmark.circle`, `exclamationmark.triangle`, `exclamationmark.triangle.fill`, `exclamationmark.octagon.fill`), `kindTitle(_:)` ("Unwetter", "Frost", "Glätte/Glatteis"; en "Severe weather", "Frost", "Ice/Black ice"), `timeRange(onset:expires:locale:timeZone:)`, `sourceLine(sent:locale:timeZone:)` -> "Quelle: Deutscher Wetterdienst, ausgegeben 12:31", `accessibilityLabel(for:)` ein Satz, `staleNotice(staleness:)` -> "Warnungen eventuell nicht aktuell" ab > 30 min; `WarnOverlay` zeichnet die `MKPolygon`s der Gemeinden betroffener Warnungen aus `WarnGeometry` (Farbe plus Strichmuster je Stufe; Stufe nie nur Farbe).

- [ ] **Step 1: Failing Tests** (Presentation, reine Funktionen, feste Locale/Zeitzone `Europe/Berlin`): Wortlaut je Stufe/Typ de/en; `sourceLine` mit `sent = 2026-11-07T11:31:00Z` -> "Quelle: Deutscher Wetterdienst, ausgegeben 12:31"; Zeitraumtext über Mitternacht ("heute 22:00 bis morgen 09:00" / en "today 10:00 PM to tomorrow 9:00 AM"); Accessibility-Satz enthält Typ, Stufenwort mit Ziffer, Zeitraum, Quelle; Hinweistext "Kein Ersatz für amtliche Warnkanäle" immer vorhanden; Filterschalter "Meine Orte" / "Alle" (Standard Meine Orte, bei leerer Ortsliste "Alle"). UI-Test: Liste zeigt Warnung aus Fixture (Launch-Argument `-UITestWarnings fixture`), Detail zeigt DWD-Text und Anweisung unverändert (String-Gleichheit), Offline zeigt letzten Stand mit Alter; AccessibilityXXXL ohne abgeschnittene Bedienelemente. **Step 2:** FAIL. **Step 3:** Implementierung (Karte: MapKit-Overlays im Stil von `Weather/Map/RadarMap.swift`, Liste ist die Alternative bei VoiceOver und bei Reduce Motion ohne Animation). **Step 4:** Tests PASS, Screenshots normal/XXXL ansehen. **Step 5: Commit** `feat: Warnansicht Liste und Karte`.

---

## W6: Benachrichtigungstext (NSE) (APP)

**Aufwand:** S. **Nach:** W0. Eigene Dateien; bei gleichzeitigem Bau mit W3/W5 nicht parallel `xcodebuild`.

**Files:** Create: `APP Shared/WarningNotificationText.swift`; Modify: `APP WeatherNotificationService/NotificationService.swift`; Test: `APP WeatherTests/WarningNotificationTextTests.swift` (Muster `NotificationNameTests.swift`)

**Interfaces:**
- Produces:

```swift
enum WarningNotificationText {
    /// Ersetzt die Schlusszeile "Quelle: DWD" des Server-Bodys durch "Quelle: DWD, ausgegeben HH:mm" (Gerätezeitzone); ohne gültiges sent bleibt der Body unverändert.
    static func body(original: String, sentISO: String?, timeZone: TimeZone, locale: Locale) -> String
    /// Ortsname für die Unterzeile (subtitle); nil/leer -> nil. Nutzt NotificationNameStore.clean.
    static func subtitle(name: String?) -> String?
}
```

- [ ] **Step 1: Failing Tests:** `body(original: "Leichter Frost.\nQuelle: DWD", sentISO: "2026-11-07T11:31:00Z", timeZone: Europe/Berlin, locale: de)` == "Leichter Frost.\nQuelle: DWD, ausgegeben 12:31"; ohne `sent`, mit kaputtem ISO oder ohne Schlusszeile bleibt der Text unverändert; Locale en: `"Source: DWD, issued 12:31"` (de: `"Quelle: DWD, ausgegeben 12:31"`; 24-Stunden-Format `HH:mm` in beiden Sprachen); der Server schreibt immer die deutsche Schlusszeile `Quelle: DWD`, die Extension erkennt sie und ersetzt sie sprachabhängig; `subtitle` kürzt auf `NotificationNameStore.maxNameLength` und flacht Zeilenumbrüche ab. **Step 2:** FAIL. **Step 3:** Implementierung; in `NotificationService.didReceive`: ist `content.userInfo["type"] as? String == "warning"`, `content.subtitle` mit dem Namen aus dem `NotificationNameStore` (Schlüssel `threadIdentifier`) setzen und `content.body` mit `WarningNotificationText.body` ersetzen, **kein** " · Name"-Anhängen an den DWD-Text; sonst der bisherige Pfad unverändert (Regressionstest `NotificationNameTests` bleibt grün). Fehler oder Zeitablauf: Originaltext (`serviceExtensionTimeWillExpire` unverändert). **Step 4:** PASS inklusive `NotificationNameTests`; Extension baut (`xcodebuild -scheme Weather build CODE_SIGNING_ALLOWED=NO`). **Step 5: Commit** `feat: NSE-Text fuer Warnungen`.
- [ ] Hinweis: Echte Zustellung (Push mit `mutable-content`, Subtitle sichtbar) ist nur auf dem Gerät mit einem Warn-Push prüfbar, also erst nach Freigabe von `WARN_PUSH_ENABLED`; in `docs/status.md` als nicht geprüft eintragen.

---

## W7: Entwurf Datenschutztext und App-Privacy (APP, freigabepflichtig)

**Aufwand:** S. **Nach:** W0. **Nicht live ändern.**

**Files:** Create: `APP docs/datenschutz-warnungen.md` (Muster: Backend `docs/datenschutz-gebiets-live-activity.md`, vorher lesen); danach vom Lead ins Backend-Repo `docs-site/content/datenschutz.md` übernommen **erst nach Freigabe**.

- [ ] **Step 1:** Entwurf mit: Zweck (Unwetter-/Frost-/Glatteiswarnungen), neue Daten (Warngebiets-IDs je Abo, Typen, Mindeststufen, Zeitkritisch-Schalter; Gemeindekennung ist gröber oder ähnlich genau wie die Rasterzelle; Kombination mit Regen-Abo derselben Installation benannt), Zuordnung Ort -> Gemeinde nur auf dem Gerät, öffentliche Abfrage `GET /v1/warnings/active` ohne Ortsangabe, Speicherdauer und Löschung (Cascade bei Installation löschen, Abo löschen, 60 Tage Inaktivität), Quelle DWD (Lizenz-/Quellenhinweis wörtlich aus Fixture: "© GeoBasis-DE / BKG 2021 (Daten modifiziert)" für die Gebietsdaten, DWD-Nutzungsbedingungen aus der Antwort auf die CAP-Rückfrage), kein Ersatz für amtliche Warnkanäle. **Step 2:** Abschnitt "App-Privacy (App Store Connect)": Kategorien voraussichtlich unverändert (Device ID, Coarse Location; Zweck App Functionality; nicht mit Identität verknüpft, kein Tracking), Begründung und Abgleich mit dem bestehenden Eintrag aus `docs/` (Datei per `grep -rn "App Privacy" docs` finden). **Step 3:** Offene Punkte für den Nutzer (Freigabe, Antwort DWD) als Todolino-Frage an der Aufgabe, Text <= 2 Zeilen mit Optionen. **Step 4: Commit** `docs: Entwurf Datenschutz Warnungen`.

---

## Spec-Abdeckung (Selbstreview)

| Spec | Paket |
|---|---|
| 3.2 Ingest, Parser, Typzuordnung | W1.1, W1.2, W1.4 |
| 3.3 Speicher/Migration, `kind = 2`, Pflichtfilter im Regenauswerter, Limits | W1.3, W2.1 |
| 3.4 Auslöser, Frische, Update, Sperre, Dedupe | W2.2, W2.3 |
| 3.5 API, Payload, Capabilities | W0 (erledigt), W2.3 |
| 3.6 Zuordnung, Einstellungen, Ansicht, NSE, Barrierefreiheit | W3, W4, W5, W6 |
| 4 Ausfall/Alter | W1.4 (Backoff, `fetched_at`), W5.1 (Staleness 30 min) |
| 5 Datenschutz | W7 (Entwurf), Global Constraints |
| 6 Tests | jeweils Test-Schritte je Task |
| 7 Rollout (Flags, Reihenfolge) | W2.4, Global Constraints |
| 3.7 Teil 2/3 Schnittstellen | nicht Teil dieses Plans (nur Wiederverwendbarkeit: `warn_sub*`, `warn_sent`, `WarnEvaluator`, `WarnPayload`) |

Bekannte Abweichungen von der Spec: (1) Warn-Abo-Routen unter `/v1/push/installations/<uuid>/warn-subscriptions` (Spec nannte `/v1/installations/...`); (2) Ortsname bei Warn-Pushes als `subtitle` statt " · Name" im Body (W6), damit der DWD-Text unverändert bleibt; (3) neue Abhängigkeit ZIPFoundation (W1.2); (4) Tabelle `warn_cell_known` zur Prüfung von `409 warncell_unknown` (W2.1). Offene Datenpunkte, die die Pakete selbst belegen: Ereigniscodes außer `FROST` (W1.1), Quelle/Lizenz der Geometrie (W3.1, Gate).
