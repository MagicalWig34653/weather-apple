import XCTest
@testable import Weather

/// L5: texts of the area Live Activity (shared table `SharedTexts`), push titles for the Notification Service Extension
/// and the shared strings tables in German and English.
final class ExtensionLocalizationTests: XCTestCase {
    private func languageBundle(_ code: String) throws -> Bundle {
        let path = try XCTUnwrap(Bundle.main.path(forResource: code, ofType: "lproj"))
        return try XCTUnwrap(Bundle(path: path))
    }

    private func state(_ phase: RainActivityAttributes.Phase, wet: Int? = nil, peak: Int? = nil, maxClass: Int = 4,
                       radius: Int? = 10) -> RainActivityAttributes.ContentState {
        .init(phase: phase, intensityClass: maxClass, referenceTime: Date(timeIntervalSinceReferenceDate: 0),
              wetSharePercent: wet, peakSharePercent: peak, regionRadiusKm: radius)
    }

    private func p(_ s: RainActivityAttributes.ContentState, _ locale: String, stale: Bool = false) -> RainActivityRegionPresentation {
        RainActivityRegionPresentation(state: s, isStale: stale, localRadiusKm: nil, locale: locale)
    }

    func testSharedTableHasEveryKeyInBothLanguages() throws {
        let keys = ["REGION_ACTIVITY_RADIUS", "REGION_ACTIVITY_SHARE_NOW", "REGION_ACTIVITY_SHARE_PEAK", "REGION_ACTIVITY_SHARE_COMPACT",
                    "REGION_ACTIVITY_INTENSITY", "REGION_ACTIVITY_WORD_VERY_LIGHT", "REGION_ACTIVITY_WORD_LIGHT",
                    "REGION_ACTIVITY_WORD_MODERATE", "REGION_ACTIVITY_WORD_HEAVY", "REGION_ACTIVITY_HEADLINE_STALE",
                    "REGION_ACTIVITY_HEADLINE_STARTS_IN", "REGION_ACTIVITY_HEADLINE_IMMINENT", "REGION_ACTIVITY_HEADLINE_RAINING",
                    "REGION_ACTIVITY_HEADLINE_DRY"]
        for code in ["de", "en"] {
            let bundle = try languageBundle(code)
            for key in keys {
                XCTAssertNotEqual(bundle.localizedString(forKey: key, value: nil, table: "SharedTexts"), key, "\(code) \(key)")
            }
        }
    }

    func testRegionTextsEnglish() {
        let raining = p(state(.raining, wet: 34, peak: 60, maxClass: 9), "en")
        XCTAssertEqual(raining.radiusText, "10 km radius")
        XCTAssertEqual(raining.shareText, "34% of the area wet")
        XCTAssertEqual(raining.compactShareText, "34%")
        XCTAssertEqual(raining.intensityText, "Strongest level 9 (heavy)")
        XCTAssertEqual(raining.title(name: "Garden"), "Garden · 10 km radius")
        XCTAssertEqual(p(state(.startsIn, wet: 0, peak: 34), "en").shareText, "up to 34% of the area wet")
        XCTAssertEqual(p(state(.raining, wet: 1, maxClass: 2), "en").intensityText, "Strongest level 2 (very light)")
        XCTAssertEqual(p(state(.raining, wet: 1, maxClass: 6), "en").intensityText, "Strongest level 6 (moderate)")
    }

    func testRegionHeadlinesEnglish() {
        let r = p(state(.raining, wet: 1), "en")
        XCTAssertEqual(r.headline(phase: .startsIn, isStale: false, hasCountdown: true), "Rain in the area in")
        XCTAssertEqual(r.headline(phase: .startsIn, isStale: false, hasCountdown: false), "Rain in the area imminent")
        XCTAssertEqual(r.headline(phase: .raining, isStale: false, hasCountdown: false), "Raining in the area")
        XCTAssertEqual(r.headline(phase: .dry, isStale: false, hasCountdown: false), "Dry in the area")
        XCTAssertEqual(r.headline(phase: .raining, isStale: true, hasCountdown: false), "Data outdated")
    }

    func testRegionCompactShareGerman() {
        XCTAssertEqual(p(state(.raining, wet: 34), "de").compactShareText, "34 %")
    }

    // MARK: Warning push title (title-loc-args carries the level as a string)

    func testPushTitleResolvesPerLanguageWithStringArgument() throws {
        let expected: [String: [String: String]] = [
            "de": ["severe_weather": "Unwetterhinweis, Stufe 3", "frost": "Frosthinweis, Stufe 3", "ice": "Glättehinweis, Stufe 3"],
            "en": ["severe_weather": "Severe weather notice, level 3", "frost": "Frost notice, level 3",
                   "ice": "Ice and slippery roads notice, level 3"],
        ]
        for (code, kinds) in expected {
            let bundle = try languageBundle(code)
            for (kind, text) in kinds {
                let title = WarningNotificationText.title(kind: kind, severity: 3) { bundle.localizedString(forKey: $0, value: nil, table: nil) }
                XCTAssertEqual(title, text, "\(code) \(kind)")
                // The system substitutes the string argument of title-loc-args the same way.
                let key = try XCTUnwrap(WarningNotificationText.kinds[kind])
                XCTAssertEqual(String(format: bundle.localizedString(forKey: key, value: nil, table: nil), "3"), text)
            }
            XCTAssertNotEqual(WarningNotificationText.body { bundle.localizedString(forKey: $0, value: nil, table: nil) }, "WARN_PUSH_BODY")
        }
    }

    func testPushTitleUsesStringPlaceholder() throws {
        for code in ["de", "en"] {
            let bundle = try languageBundle(code)
            for key in WarningNotificationText.kinds.values {
                let format = bundle.localizedString(forKey: key, value: nil, table: nil)
                XCTAssertTrue(format.contains("%@"), "\(code) \(key)")
                XCTAssertFalse(format.contains("%d"), "\(code) \(key)")
            }
        }
    }

    func testRainPushBodyWithNameInEnglish() throws {
        let bundle = try languageBundle("en")
        let text = NotificationNameStore.body(original: "", locKey: "RAIN_STARTS_IN", locArgs: ["7"], name: "Hamburg") {
            bundle.localizedString(forKey: $0, value: nil, table: nil)
        }
        XCTAssertEqual(text, "Rain starts in 7 min \u{00B7} Hamburg")
    }
}
