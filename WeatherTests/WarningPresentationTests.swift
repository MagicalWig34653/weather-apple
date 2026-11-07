import XCTest
@testable import Weather

final class WarningPresentationTests: XCTestCase {
    private typealias P = WarningPresentation
    private let berlin = TimeZone(identifier: "Europe/Berlin")!
    private let de = Locale(identifier: "de_DE"), en = Locale(identifier: "en_US")
    private func bundle(_ lang: String) throws -> Bundle {
        try XCTUnwrap(Bundle(path: try XCTUnwrap(Bundle.main.path(forResource: lang, ofType: "lproj"))))
    }
    private func iso(_ s: String) -> Date { ISO8601DateFormatter().date(from: s)! }
    private func plain(_ s: String) -> String { s.replacingOccurrences(of: "\u{202F}", with: " ").replacingOccurrences(of: "\u{00A0}", with: " ") }

    private func sample(severity: Int = 3, kind: WarnKind = .severeWeather) -> ActiveWarning {
        ActiveWarning(id: "x", kind: kind, severity: severity, event: "GEWITTER", sent: iso("2026-11-07T11:31:00Z"),
                      onset: iso("2026-11-07T21:00:00Z"), expires: iso("2026-11-08T08:00:00Z"), headline: "Amtliche WARNUNG vor GEWITTER",
                      text: "t", instruction: "i", lang: "de", warncellIDs: ["1"])
    }

    func testSourceLine() throws {
        let sent = iso("2026-11-07T11:31:00Z"), now = iso("2026-11-07T12:00:00Z")
        XCTAssertEqual(P.sourceLine(sent: sent, now: now, locale: de, timeZone: berlin, bundle: try bundle("de")),
                       "Quelle: Deutscher Wetterdienst, ausgegeben 12:31")
        XCTAssertEqual(plain(P.sourceLine(sent: sent, now: now, locale: en, timeZone: berlin, bundle: try bundle("en"))),
                       "Source: Deutscher Wetterdienst, issued 12:31 PM")
    }

    func testSourceLineOnOtherDayNamesTheDay() throws {
        let line = P.sourceLine(sent: iso("2026-11-06T22:10:00Z"), now: iso("2026-11-07T12:00:00Z"), locale: de, timeZone: berlin, bundle: try bundle("de"))
        XCTAssertEqual(line, "Quelle: Deutscher Wetterdienst, ausgegeben gestern 23:10")
    }

    func testTimeRangeOverMidnight() throws {
        let now = iso("2026-11-07T12:00:00Z")
        let onset = iso("2026-11-07T21:00:00Z"), expires = iso("2026-11-08T08:00:00Z")
        XCTAssertEqual(P.timeRange(onset: onset, expires: expires, now: now, locale: de, timeZone: berlin, bundle: try bundle("de")),
                       "heute 22:00 bis morgen 09:00")
        XCTAssertEqual(plain(P.timeRange(onset: onset, expires: expires, now: now, locale: en, timeZone: berlin, bundle: try bundle("en"))),
                       "today 10:00 PM to tomorrow 9:00 AM")
    }

    func testTimeRangeSameDayShowsEndTimeOnly() throws {
        let r = P.timeRange(onset: iso("2026-11-07T09:00:00Z"), expires: iso("2026-11-07T15:00:00Z"),
                            now: iso("2026-11-07T12:00:00Z"), locale: de, timeZone: berlin, bundle: try bundle("de"))
        XCTAssertEqual(r, "heute 10:00 bis 16:00")
    }

    func testLevelWordsAndKindTitlesGermanEnglish() throws {
        let de = try bundle("de"), en = try bundle("en")
        XCTAssertEqual(P.levelWord(3, bundle: de), "Unwetterwarnung")
        XCTAssertEqual(P.levelWord(4, bundle: en), "Extreme weather warning")
        XCTAssertEqual(P.kindTitle(.frost, bundle: de), "Frost")
        XCTAssertEqual(P.kindTitle(.severeWeather, bundle: en), "Severe weather")
        XCTAssertEqual(P.kindTitle(.ice, bundle: de), "Glätte und Glatteis")
    }

    func testLevelSymbolsDifferPerLevel() {
        XCTAssertEqual((1...4).map(P.levelSymbol), ["exclamationmark.circle", "exclamationmark.triangle",
                                                    "exclamationmark.triangle.fill", "exclamationmark.octagon.fill"])
    }

    func testAccessibilityLabelHasTypeLevelDigitRangeSource() throws {
        let label = P.accessibilityLabel(for: sample(), now: iso("2026-11-07T12:00:00Z"), locale: de, timeZone: berlin, bundle: try bundle("de"))
        for part in ["Unwetter", "Stufe 3", "heute 22:00 bis morgen 09:00", "Amtliche WARNUNG vor GEWITTER",
                     "Quelle: Deutscher Wetterdienst, ausgegeben 12:31"] {
            XCTAssertTrue(label.contains(part), "\(part) missing in \(label)")
        }
    }

    func testStaleNoticeOnlyWhenStale() throws {
        XCTAssertNil(P.staleNotice(.fresh, bundle: try bundle("de")))
        XCTAssertEqual(P.staleNotice(.stale, bundle: try bundle("de")), "Warnungen eventuell nicht aktuell")
        XCTAssertEqual(P.staleNotice(.stale, bundle: try bundle("en")), "Warnings may not be up to date")
    }

    func testDisclaimerAlwaysAvailable() throws {
        XCTAssertEqual(P.disclaimer(bundle: try bundle("de")), "Kein Ersatz für amtliche Warnkanäle (WarnWetter-App, NINA).")
        XCTAssertTrue(P.disclaimer(bundle: try bundle("en")).contains("NINA"))
    }

    func testDefaultScope() {
        XCTAssertEqual(WarnScope.defaultScope(hasPlaces: true), .mine)
        XCTAssertEqual(WarnScope.defaultScope(hasPlaces: false), .all)
    }

    func testContentStatesAreHonest() {
        func c(_ scope: WarnScope = .mine, data: Bool = true, loading: Bool = false, places: Bool = true, cells: Bool = true, count: Int = 0) -> P.Content {
            P.content(scope: scope, hasData: data, isLoading: loading, hasPlaces: places, hasAnyCells: cells, count: count)
        }
        XCTAssertEqual(c(data: false, loading: true), .loading)
        XCTAssertEqual(c(data: false), .unavailable)          // never "no warnings" without data
        XCTAssertEqual(c(places: false), .noPlaces)
        XCTAssertEqual(c(cells: false), .noCells)
        XCTAssertEqual(c(.all, places: false, count: 0), .empty)
        XCTAssertEqual(c(count: 2), .list)
    }

    func testLanguageHint() throws {
        XCTAssertNil(P.languageHint(warningLang: "de", appLang: "de"))
        XCTAssertEqual(P.languageHint(warningLang: "de", appLang: "en", bundle: try bundle("en")), "Official text only available in German.")
        XCTAssertEqual(P.languageHint(warningLang: "en", appLang: "de", bundle: try bundle("de")), "Amtlicher Text nur auf Englisch verfügbar.")
    }

    func testButtonValue() throws {
        let b = try bundle("de")
        XCTAssertEqual(P.buttonValue(P.summary(of: []), stale: false, bundle: b), "Keine aktiven Warnungen für deine Orte")
        XCTAssertEqual(P.buttonValue(P.summary(of: [sample(), sample(severity: 4)]), stale: true, bundle: b),
                       "2 aktive Warnungen für deine Orte, höchste Stufe 4. Warnungen eventuell nicht aktuell")
    }

    func testOverlayModelMaxSeverityPerCell() {
        var a = sample(severity: 2), b = sample(severity: 4)
        a = ActiveWarning(id: "a", kind: a.kind, severity: 2, event: "", sent: a.sent, onset: a.onset, expires: a.expires, headline: "", text: "", instruction: "", lang: "de", warncellIDs: ["1", "2"])
        b = ActiveWarning(id: "b", kind: b.kind, severity: 4, event: "", sent: b.sent, onset: b.onset, expires: b.expires, headline: "", text: "", instruction: "", lang: "de", warncellIDs: ["2"])
        XCTAssertEqual(WarnOverlayModel.maxSeverityByCell([a, b]), ["1": 2, "2": 4])
    }

    func testShapesTreatNestedRingAsHole() {
        let outer: [WarnGeometry.Point] = [(0, 0), (0, 10), (10, 10), (10, 0)]
        let hole: [WarnGeometry.Point] = [(4, 4), (4, 6), (6, 6), (6, 4)]
        let island: [WarnGeometry.Point] = [(4.5, 4.5), (4.5, 5.5), (5.5, 5.5), (5.5, 4.5)]
        let cell = WarnGeometry.Cell(id: "1", minLat: 0, minLon: 0, maxLat: 10, maxLon: 10, rings: [hole, outer, island])
        let shapes = WarnOverlayModel.shapes(of: cell)
        XCTAssertEqual(shapes.count, 2)   // outer (with one hole) and the island inside the hole
        XCTAssertEqual(shapes.map { $0.holes.count }.sorted(), [0, 1])
    }
}
