import XCTest
@testable import Weather

final class WarnSettingsPresentationTests: XCTestCase {
    private typealias P = WarnSettingsPresentation
    private func bundle(_ lang: String) throws -> Bundle {
        try XCTUnwrap(Bundle(path: try XCTUnwrap(Bundle.main.path(forResource: lang, ofType: "lproj"))))
    }

    func testNoRowsWithoutCapability() {
        XCTAssertEqual(P.rows(capability: false, settings: WarnUserSettings(enabled: true)), [])
    }

    func testDisclaimerStandsBeforeMainToggle() {
        let rows = P.rows(capability: true, settings: WarnUserSettings())
        XCTAssertEqual(rows, [.disclaimer, .mainToggle])
    }

    func testEnabledShowsTypesLevelsAndTimeSensitive() {
        var settings = WarnUserSettings(enabled: true)
        settings.types.remove(.frost)
        let rows = P.rows(capability: true, settings: settings)
        XCTAssertEqual(rows, [.disclaimer, .mainToggle, .typeToggle(.severeWeather), .minLevel(.severeWeather),
                              .typeToggle(.frost), .typeToggle(.ice), .minLevel(.ice), .timeSensitive, .timeSensitiveHint])
    }

    func testDefaults() {
        let s = WarnUserSettings()
        XCTAssertEqual([s.level(for: .severeWeather), s.level(for: .frost), s.level(for: .ice)], [3, 1, 2])
        XCTAssertFalse(s.enabled); XCTAssertFalse(s.timeSensitive)
    }

    func testLevelTitlesGermanAndEnglishWithDigit() throws {
        let de = try bundle("de"), en = try bundle("en")
        XCTAssertEqual((1...4).map { P.levelTitle($0, bundle: de) },
                       ["Stufe 1: Wetterwarnung", "Stufe 2: Markante Wetterwarnung", "Stufe 3: Unwetterwarnung", "Stufe 4: Extreme Unwetterwarnung"])
        XCTAssertEqual((1...4).map { P.levelTitle($0, bundle: en) },
                       ["Level 1: Weather warning", "Level 2: Marked weather warning", "Level 3: Severe weather warning", "Level 4: Extreme weather warning"])
    }

    func testDisclaimerAndAccessibilitySentences() throws {
        let de = try bundle("de")
        XCTAssertTrue(P.disclaimer(bundle: de).contains("Kein Ersatz für amtliche Warnkanäle (WarnWetter-App, NINA)"))
        let label = P.accessibilityLabel(.minLevel(.ice), settings: WarnUserSettings(enabled: true), bundle: de)
        XCTAssertEqual(label, "Glätte und Glatteis, Mitteilung ab Stufe 2: Markante Wetterwarnung")
        XCTAssertTrue(P.timeSensitiveHint(bundle: de).contains("Stufe 4"))
    }
}
