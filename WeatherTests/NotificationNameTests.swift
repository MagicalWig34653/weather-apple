import XCTest
@testable import Weather

final class NotificationNameTests: XCTestCase {
    private func localized(_ key: String) -> String? {
        ["RAIN_STARTS_IN": "Regen beginnt in %@ min"][key]
    }

    func testAppendsNameToLocalizedBody() {
        let text = NotificationNameStore.body(original: "Regen beginnt in 10 min", locKey: "RAIN_STARTS_IN", locArgs: ["10"],
                                              name: "Berlin", localized: localized)
        XCTAssertEqual(text, "Regen beginnt in 10 min \u{00B7} Berlin")
    }

    func testBuildsTextFromLocKeyWhenBodyEmpty() {
        let text = NotificationNameStore.body(original: "", locKey: "RAIN_STARTS_IN", locArgs: ["7"], name: " Hamburg ", localized: localized)
        XCTAssertEqual(text, "Regen beginnt in 7 min \u{00B7} Hamburg")
    }

    func testUnchangedWithoutNameOrText() {
        XCTAssertEqual(NotificationNameStore.body(original: "Text", locKey: nil, locArgs: [], name: nil, localized: localized), "Text")
        XCTAssertEqual(NotificationNameStore.body(original: "Text", locKey: nil, locArgs: [], name: "  ", localized: localized), "Text")
        XCTAssertEqual(NotificationNameStore.body(original: "", locKey: "UNKNOWN", locArgs: [], name: "X", localized: localized), "")
    }

    func testCleanShortensAndFlattensName() {
        XCTAssertNil(NotificationNameStore.clean(nil))
        XCTAssertEqual(NotificationNameStore.clean("A\nB"), "A B")
        let long = String(repeating: "x", count: 100)
        XCTAssertEqual(NotificationNameStore.clean(long)?.count, NotificationNameStore.maxNameLength)
    }

    func testMappingPlacesAndRegions() {
        let place = UUID()
        let map = NotificationNameStore.mapping(placeSubscriptions: [place: "s1"], placeNames: [place: "Köln"],
                                                regionSubscriptions: ["s2": "Eifel", "s3": nil, "s4": ""])
        XCTAssertEqual(map, ["s1": "Köln", "s2": "Eifel"])
    }

    func testDefaultsRoundTripAndDelete() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "notification-name-tests"))
        defer { defaults.removePersistentDomain(forName: "notification-name-tests") }
        NotificationNameStore.write(["s1": "Köln"], to: defaults)
        XCTAssertEqual(NotificationNameStore.name(for: "s1", in: defaults), "Köln")
        NotificationNameStore.write([:], to: defaults)
        XCTAssertNil(NotificationNameStore.name(for: "s1", in: defaults))
    }
}
