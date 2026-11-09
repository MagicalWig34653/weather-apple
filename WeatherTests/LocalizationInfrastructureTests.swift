import XCTest
@testable import Weather

/// L1: one language source, fallback configuration, locale-safe formatting, NSE string resolution.
@MainActor
final class LocalizationInfrastructureTests: XCTestCase {
    // MARK: AppLanguage

    func testAppLanguageMapsToDeOrEn() {
        XCTAssertEqual(AppLanguage.code(preferredLocalizations: ["de"]), "de")
        XCTAssertEqual(AppLanguage.code(preferredLocalizations: ["de-AT"]), "de")
        XCTAssertEqual(AppLanguage.code(preferredLocalizations: ["en"]), "en")
        XCTAssertEqual(AppLanguage.code(preferredLocalizations: ["fr"]), "en")
        XCTAssertEqual(AppLanguage.code(preferredLocalizations: []), "en")
    }

    func testAllReportersUseTheSameLanguage() {
        XCTAssertEqual(PushManager.currentLocale(), AppLanguage.code)
        XCTAssertEqual(WarnFeedStore.appLanguage(), AppLanguage.code)
        XCTAssertTrue(AppLanguage.supported.contains(AppLanguage.code))
    }

    // MARK: Info.plist configuration (E2)

    func testPlistDeclaresGermanAndEnglishWithEnglishFallback() {
        XCTAssertEqual(Bundle.main.developmentLocalization, "en")
        let declared = Bundle.main.object(forInfoDictionaryKey: "CFBundleLocalizations") as? [String]
        XCTAssertEqual(Set(declared ?? []), ["de", "en"])
    }

    func testFrenchFallsBackToEnglish() {
        let result = Bundle.preferredLocalizations(from: ["de", "en"], forPreferences: ["fr-FR", "es"])
        XCTAssertEqual(result.first, "en")
    }

    // MARK: Strings resolution (as the notification service does through the host bundle)

    private func languageBundle(_ code: String) throws -> Bundle {
        let path = try XCTUnwrap(Bundle.main.path(forResource: code, ofType: "lproj"))
        return try XCTUnwrap(Bundle(path: path))
    }

    func testHostBundleResolvesNotificationTextsInBothLanguages() throws {
        for key in ["WARN_PUSH_TITLE_SEVERE", "WARN_PUSH_TITLE_FROST", "WARN_PUSH_TITLE_ICE", "WARN_PUSH_BODY", "RAIN_STARTS_IN", "RAIN_REGION_STARTS_IN"] {
            let en = try languageBundle("en").localizedString(forKey: key, value: nil, table: nil)
            let de = try languageBundle("de").localizedString(forKey: key, value: nil, table: nil)
            XCTAssertNotEqual(en, key, key)
            XCTAssertNotEqual(de, key, key)
            XCTAssertNotEqual(en, de, key)
        }
        let title = WarningNotificationText.title(kind: "frost", severity: 2) {
            try? self.languageBundle("en").localizedString(forKey: $0, value: nil, table: nil)
        }
        XCTAssertEqual(title?.contains("2"), true)
        XCTAssertFalse(title?.contains("hinweis") ?? true)
    }

    func testLocationPermissionTextExistsInBothLanguages() throws {
        for code in ["de", "en"] {
            let bundle = try languageBundle(code)
            let text = bundle.localizedString(forKey: "NSLocationWhenInUseUsageDescription", value: nil, table: "InfoPlist")
            XCTAssertNotEqual(text, "NSLocationWhenInUseUsageDescription", code)
        }
        let en = try languageBundle("en").localizedString(forKey: "NSLocationWhenInUseUsageDescription", value: nil, table: "InfoPlist")
        XCTAssertTrue(en.contains("German Weather Service"))
    }

    // MARK: LocaleFormat

    private let de = Locale(identifier: "de_DE"), us = Locale(identifier: "en_US"), gb = Locale(identifier: "en_GB")

    func testDecimalFollowsLocaleSeparator() {
        XCTAssertEqual(LocaleFormat.decimal(7.5, locale: de), "7,5")
        XCTAssertEqual(LocaleFormat.decimal(7.5, locale: us), "7.5")
        XCTAssertEqual(LocaleFormat.decimal(12, locale: us), "12")
        XCTAssertEqual(LocaleFormat.decimal(0.25, maxFractionDigits: 2, locale: de), "0,25")
        XCTAssertEqual(LocaleFormat.decimal(2, minFractionDigits: 1, locale: us), "2.0")
    }

    func testTypographicMinus() {
        XCTAssertEqual(LocaleFormat.decimal(-3.5, useTypographicMinus: true, locale: us), "\u{2212}3.5")
        XCTAssertEqual(LocaleFormat.decimal(-3.5, useTypographicMinus: true, locale: de), "\u{2212}3,5")
    }

    func testIntegerAndQuantity() {
        XCTAssertEqual(LocaleFormat.integer(1234, locale: us), "1234")
        XCTAssertEqual(LocaleFormat.quantity(7.5, unit: "mm/h", locale: de), "7,5\u{00A0}mm/h")
        XCTAssertEqual(LocaleFormat.quantity(7.5, unit: "mm/h", locale: us), "7.5\u{00A0}mm/h")
    }

    func testTimeUses24hOr12hByLocale() throws {
        let zone = try XCTUnwrap(TimeZone(identifier: "Europe/Berlin"))
        var comps = DateComponents(); comps.year = 2026; comps.month = 11; comps.day = 9; comps.hour = 15; comps.minute = 5
        var cal = Calendar(identifier: .gregorian); cal.timeZone = zone
        let date = try XCTUnwrap(cal.date(from: comps))
        XCTAssertEqual(LocaleFormat.time(date, timeZone: zone, locale: de), "15:05")
        XCTAssertEqual(LocaleFormat.time(date, timeZone: zone, locale: gb), "15:05")
        let american = LocaleFormat.time(date, timeZone: zone, locale: us).replacingOccurrences(of: "\u{202F}", with: " ")
        XCTAssertEqual(american, "3:05 PM")
    }
}
