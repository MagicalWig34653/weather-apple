import XCTest
@testable import Weather

/// Karte 31A623B9, Frage 9B360945 (beantwortet 27.11.2026): Datenangaben der Warnungstexte und Satelliten-Quellzeile.
final class WarnPrivacyTextTests: XCTestCase {
    private func strings(_ lang: String) throws -> [String: String] {
        let bundlePath = try XCTUnwrap(Bundle.main.path(forResource: lang, ofType: "lproj"), "\(lang).lproj not found in the app bundle")
        let path = try XCTUnwrap(Bundle(path: bundlePath)?.path(forResource: "Localizable", ofType: "strings"), "Localizable.strings (\(lang)) not found")
        return try XCTUnwrap(NSDictionary(contentsOfFile: path) as? [String: String], "Localizable.strings (\(lang)) unreadable")
    }

    func testWarnConfirmMessageNamesDataConsentAndWithdrawal() throws {
        let de = try XCTUnwrap(strings("de")["WARN_CONFIRM_MESSAGE"])
        XCTAssertEqual(de, "Du bekommst Warnungen des Deutschen Wetterdienstes für deine gespeicherten Orte und Regionen. Dafür gehen an den Showers-Server: das Gerätetoken, eine zufällige Installationskennung, die Kennungen der Warngebiete (Kreise), Warnarten, Mindeststufe und die Einstellung für zeitkritische Mitteilungen; keine Koordinaten, keine Ortsnamen, kein Konto. Mit „Einschalten“ willigst du ein. Ausschalten widerruft das jederzeit und löscht die Warndaten auf dem Server. Kein Ersatz für amtliche Warnkanäle (WarnWetter-App, NINA). Danach fragt iOS, ob Showers Mitteilungen senden darf.")
        let en = try XCTUnwrap(strings("en")["WARN_CONFIRM_MESSAGE"])
        XCTAssertEqual(en, "You get warnings from the German Weather Service (DWD) for your saved places and regions. The following is sent to the Showers server: the device token, a random installation ID, the IDs of the warning areas (districts), warning types, minimum level and the time-sensitive setting; no coordinates, no place names, no account. By tapping “Turn on” you consent. Turning it off withdraws consent at any time and deletes the warning data on the server. Not a replacement for official warning channels (WarnWetter app, NINA). iOS then asks whether Showers may send notifications.")
        // The consent wording names the real button of the alert.
        XCTAssertTrue(de.contains("„\(try XCTUnwrap(strings("de")["WARN_CONFIRM_ACTION"]))“"))
        XCTAssertTrue(en.contains("“\(try XCTUnwrap(strings("en")["WARN_CONFIRM_ACTION"]))”"))
    }

    func testWarnFooterListsEverythingTheServerReceives() throws {
        XCTAssertEqual(try strings("de")["WARN_FOOTER"],
                       "Der Server erhält Kennungen der Warngebiete, Warnarten, Mindeststufe, Gerätetoken und Installationskennung; keine Koordinaten, keine Ortsnamen. Namen bleiben auf dem Gerät.")
        XCTAssertEqual(try strings("en")["WARN_FOOTER"],
                       "The server receives warning area IDs, warning types, minimum level, device token and installation ID; no coordinates, no place names. Names stay on the device.")
    }

    func testInfoPrivacyMentionsWarningsAsCoarserLocation() throws {
        let de = try XCTUnwrap(strings("de")["INFO_PRIVACY_1"])
        XCTAssertTrue(de.hasSuffix("Nur wenn du Regenhinweise oder Warnungen einschaltest, geht eine gröbere Ortsangabe an den Radar-Dienst (Regenhinweise: siehe unten; Warnungen: Kennungen der Warngebiete)."))
        let en = try XCTUnwrap(strings("en")["INFO_PRIVACY_1"])
        XCTAssertTrue(en.hasSuffix("Only if you turn on rain alerts or warnings is a coarser location sent to the radar service (rain alerts: see below; warnings: warning area IDs)."))
    }

    /// INFO_PRIVACY_3 („befristet“) bleibt bis zur neuen Datenschutzfassung (Frage 9B360945).
    func testInfoPrivacy3StaysUntilNewPrivacyPage() throws {
        XCTAssertTrue(try XCTUnwrap(strings("de")["INFO_PRIVACY_3"]).contains("befristet protokolliert"))
        XCTAssertTrue(try XCTUnwrap(strings("en")["INFO_PRIVACY_3"]).contains("logs it for a limited time"))
    }
}
