import XCTest
@testable import Weather

final class WarningNotificationTextTests: XCTestCase {
    private let strings = ["WARN_PUSH_TITLE_FROST": "Frosthinweis, Stufe %@", "WARN_PUSH_TITLE_SEVERE": "Unwetterhinweis, Stufe %@",
                           "WARN_PUSH_TITLE_ICE": "Glättehinweis, Stufe %@", "WARN_PUSH_BODY": "Tippen für Details."]
    private func localized(_ key: String) -> String? { strings[key] }

    func testParseAcceptsWarningPayload() {
        let parsed = WarningNotificationText.parse(userInfo: ["type": "warning", "kind": "frost", "severity": 1])
        XCTAssertEqual(parsed?.kind, "frost")
        XCTAssertEqual(parsed?.severity, 1)
        XCTAssertEqual(WarningNotificationText.parse(userInfo: ["type": "warning", "kind": "ice", "severity": NSNumber(value: 4)])?.severity, 4)
    }

    func testParseRejectsRainAndBrokenPayloads() {
        XCTAssertNil(WarningNotificationText.parse(userInfo: ["aps": ["alert": ["loc-key": "RAIN_STARTS_IN"]]]))
        XCTAssertNil(WarningNotificationText.parse(userInfo: ["type": "rain", "kind": "frost", "severity": 1]))
        XCTAssertNil(WarningNotificationText.parse(userInfo: ["type": "warning", "kind": "heat", "severity": 1]))
        XCTAssertNil(WarningNotificationText.parse(userInfo: ["type": "warning", "kind": "frost", "severity": 0]))
        XCTAssertNil(WarningNotificationText.parse(userInfo: ["type": "warning", "kind": "frost"]))
    }

    func testTitleAndBodyHaveNoOfficialClaimOrSource() throws {
        let title = try XCTUnwrap(WarningNotificationText.title(kind: "severe_weather", severity: 3, localized: localized))
        XCTAssertEqual(title, "Unwetterhinweis, Stufe 3")
        let body = try XCTUnwrap(WarningNotificationText.body(localized: localized))
        for text in [title, body] {
            XCTAssertFalse(text.localizedCaseInsensitiveContains("amtlich"))
            XCTAssertFalse(text.contains("DWD"))
            XCTAssertFalse(text.contains("Quelle"))
        }
    }

    func testMissingStringsGiveNilSoOriginalStays() {
        XCTAssertNil(WarningNotificationText.title(kind: "frost", severity: 1, localized: { _ in nil }))
        XCTAssertNil(WarningNotificationText.title(kind: "frost", severity: 1, localized: { $0 }))
        XCTAssertNil(WarningNotificationText.body(localized: { $0 }))
    }

    func testSubtitleCleansName() {
        XCTAssertEqual(WarningNotificationText.subtitle(name: " Köln\n"), "Köln")
        XCTAssertNil(WarningNotificationText.subtitle(name: nil))
        XCTAssertNil(WarningNotificationText.subtitle(name: "  "))
        XCTAssertEqual(WarningNotificationText.subtitle(name: String(repeating: "x", count: 99))?.count, NotificationNameStore.maxNameLength)
    }

    func testWarnNameLookupViaThreadID() {
        let defaults = UserDefaults(suiteName: "test.warntext.\(UUID().uuidString)")
        NotificationNameStore.writeWarn(["sub-w": "Hamburg"], to: defaults)
        XCTAssertEqual(NotificationNameStore.name(for: "sub-w", in: defaults), "Hamburg")
        XCTAssertNil(NotificationNameStore.name(for: "other", in: defaults))
    }
}
