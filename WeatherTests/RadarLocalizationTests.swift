import XCTest
@testable import Weather

/// L2 (radar screen, timeline, legends): locale-safe formatting and the English strings. The test host runs in German,
/// so English wording is read from `en.lproj` directly; number and time formats take the locale explicitly.
final class RadarLocalizationTests: XCTestCase {
    private let de = Locale(identifier: "de_DE")
    private let us = Locale(identifier: "en_US")
    private let gb = Locale(identifier: "en_GB")

    private func table(_ language: String) throws -> [String: String] {
        let path = try XCTUnwrap(Bundle.main.path(forResource: "Localizable", ofType: "strings", inDirectory: nil, forLocalization: language))
        return try XCTUnwrap(NSDictionary(contentsOfFile: path) as? [String: String])
    }

    func testTemperatureScaleNumberFollowsLocaleAndUsesTypographicMinus() {
        XCTAssertEqual(TemperatureScale.number(-7.5, locale: de), "\u{2212}7,5")
        XCTAssertEqual(TemperatureScale.number(-7.5, locale: us), "\u{2212}7.5")
        XCTAssertEqual(TemperatureScale.number(-7.5, locale: gb), "\u{2212}7.5")
        XCTAssertEqual(TemperatureScale.number(30, locale: us), "30")
        XCTAssertEqual(TemperatureScale.number(-29, locale: de), "\u{2212}29")
        XCTAssertEqual(TemperatureScale.number(0.25, locale: de), "0,25")
    }

    func testRadarLegendNumbersFollowLocale() throws {
        let german = MapLegend.precipitationRadar(locale: de).entries
        let american = MapLegend.precipitationRadar(locale: us).entries
        XCTAssertEqual(german[1].label, "0,1 \u{2013} 0,2")
        XCTAssertEqual(american[1].label, "0.1 \u{2013} 0.2")
        XCTAssertEqual(german[1].spokenLabel, "0,1 bis unter 0,2 Millimeter pro Stunde")
        XCTAssertEqual(german[7].label, "5 \u{2013} 7,5")
        XCTAssertEqual(american[7].label, "5 \u{2013} 7.5")
        XCTAssertEqual(german.last?.label, "ab 150")
        XCTAssertEqual(american.map(\.id), german.map(\.id), "ids do not depend on the locale")
    }

    func testTimelineValueFollowsLocaleForTimeAndDay() throws {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/Berlin"))
        var comps = DateComponents(); comps.year = 2026; comps.month = 11; comps.day = 9; comps.hour = 15; comps.minute = 5
        let date = try XCTUnwrap(cal.date(from: comps))
        let sameDay = date.addingTimeInterval(-3600)
        let german = TimelineAccessibility.value(date: date, isForecast: false, reference: sameDay, calendar: cal, locale: de, caption: "X")
        XCTAssertTrue(german.hasPrefix("15:05"), german)
        let american = TimelineAccessibility.value(date: date, isForecast: false, reference: sameDay, calendar: cal, locale: us, caption: "X")
            .replacingOccurrences(of: "\u{202F}", with: " ")
        XCTAssertTrue(american.hasPrefix("3:05 PM"), american)
        let nextDay = TimelineAccessibility.value(date: date, isForecast: true, reference: date.addingTimeInterval(-86_400), calendar: cal, locale: us, caption: "X")
        XCTAssertTrue(nextDay.contains("Nov"), "names the day for another reference day: \(nextDay)")
        XCTAssertFalse(nextDay.contains("Mo."), nextDay)
    }

    func testSunLabelTimeFollowsLocale() throws {
        let now = Date(timeIntervalSince1970: 1_793_354_400)   // 2026-10-30 11:00 UTC
        let zone = try XCTUnwrap(TimeZone(identifier: "Europe/Berlin"))
        let german = SolarPosition.sunLabel(at: now, latitude: 52.5, longitude: 13.4, timeZone: zone, locale: de)
        let american = SolarPosition.sunLabel(at: now, latitude: 52.5, longitude: 13.4, timeZone: zone, locale: us)
        XCTAssertFalse(german.contains("AM") || german.contains("PM"), german)
        XCTAssertTrue(american.contains("PM") || american.contains("AM"), american)
    }

    func testEnglishWordingOfRadarKeys() throws {
        let en = try table("en"), deTable = try table("de")
        XCTAssertEqual(en["LAYER_RADAR_TITLE"], "Rain radar")
        XCTAssertEqual(en["LAYER_CAPTION_MEASUREMENT"], "Measurement")
        XCTAssertEqual(en["LAYER_CAPTION_FORECAST"], "Forecast")
        XCTAssertEqual(en["RADAR_PAST_WINDOW_ONE"], "1 hour")
        XCTAssertEqual(String(format: try XCTUnwrap(en["RADAR_PAST_WINDOW_MANY"]), 48), "48 hours")
        XCTAssertEqual(String(format: try XCTUnwrap(deTable["RADAR_PAST_WINDOW_MANY"]), 48), "48 Stunden")
        XCTAssertEqual(en["COMMON_DONE"], "Done")
        XCTAssertEqual(deTable["COMMON_DONE"], "Fertig")
        // Reordering placeholders stay numbered.
        XCTAssertEqual(String(format: try XCTUnwrap(en["RADAR_SLOT_LOADING"]), "Radar", "12:05"), "Loading Radar for 12:05 \u{2026}")
        XCTAssertEqual(String(format: try XCTUnwrap(en["TIMELINE_SLIDER_HINT"]), "A", "B").prefix(9), "From A to")
    }

    func testPastWindowLabelGermanSingularAndPlural() {
        // The host runs in German (Simulator de-DE); English comes from the table test above.
        XCTAssertEqual(RadarPastWindow.label(1), "1 Stunde")
        XCTAssertEqual(RadarPastWindow.label(6), "6 Stunden")
    }
}
