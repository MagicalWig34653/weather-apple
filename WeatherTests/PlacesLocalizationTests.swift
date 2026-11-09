import XCTest
@testable import Weather

/// L3: places, regions, push texts and info sheet in both languages.
final class PlacesLocalizationTests: XCTestCase {
    private func bundle(_ code: String) throws -> Bundle {
        let path = try XCTUnwrap(Bundle.main.path(forResource: code, ofType: "lproj"))
        return try XCTUnwrap(Bundle(path: path))
    }
    private func string(_ key: String, _ code: String) throws -> String {
        try bundle(code).localizedString(forKey: key, value: "MISSING", table: nil)
    }

    func testRainActivityTextsDifferByLanguage() {
        for text in [RainActivityText.explanation, .unavailable, .privacy, .regionExplanation, .regionPrivacy, .limit, .notEligible, .waitingForToken, .full, .retry] {
            XCTAssertNotEqual(text.text(locale: "de"), text.text(locale: "en"))
        }
        XCTAssertTrue(RainActivityText.limit.text(locale: "en").hasPrefix("Only one"))
    }

    func testPluralisedRateLimitMessage() throws {
        let one = try string("PUSH_TEST_RATE_LIMITED_MINUTE", "en"), many = try string("PUSH_TEST_RATE_LIMITED_MINUTES", "en")
        XCTAssertTrue(String(format: one, 1).hasSuffix("about 1 minute."))
        XCTAssertTrue(String(format: many, 5).hasSuffix("about 5 minutes."))
    }

    func testRegionAndLimitFormats() throws {
        XCTAssertEqual(String(format: try string("REGION_DETAIL", "en"), 10, 25), "10 km radius · from 25% of the area")
        XCTAssertEqual(String(format: try string("REGION_DETAIL", "de"), 10, 25), "Umkreis 10 km · ab 25 % der Fläche")
        XCTAssertEqual(String(format: try string("PLACES_REGION_LIMIT", "en"), 3, 10), "At most 3 regions (at most 10 alerts in total).")
        XCTAssertEqual(String(format: try string("PUSH_PLACE_CONFIRM_MESSAGE", "en"), "Berlin").prefix(40), "Showers notifies you when it is about to")
    }

    func testAllL3KeysExistInBothLanguages() throws {
        for key in ["PLACES_TITLE", "REGION_EXPLANATION", "PUSH_TEST_KEY_REJECTED", "INFO_PRIVACY_6", "SITE_UNREACHABLE", "PUSH_MSG_KEYCHAIN"] {
            XCTAssertNotEqual(try string(key, "de"), "MISSING", key)
            XCTAssertNotEqual(try string(key, "en"), "MISSING", key)
        }
    }
}
