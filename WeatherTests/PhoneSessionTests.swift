import XCTest
@testable import Weather

@MainActor
final class PhoneSessionTests: XCTestCase {
    private func place(_ name: String = "Testort") -> SavedPlace {
        SavedPlace(name: name, coordinate: WeatherCoordinate(latitude: 50, longitude: 10))
    }

    private func decoded(_ context: [String: Any]) throws -> [SavedPlace] {
        try JSONDecoder().decode([SavedPlace].self, from: XCTUnwrap(context["places"] as? Data))
    }

    func testPayloadHasExactlySharedPlaceFieldsAndRoundTrips() async throws {
        let places = [place("Eins"), place("Zwei")]
        let context = try WatchPlacesPayload.context(for: places)
        XCTAssertEqual(Set(context.keys), ["places"])
        XCTAssertEqual(try decoded(context), places)
        let data = try XCTUnwrap(context["places"] as? Data)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        XCTAssertEqual(json.count, 2)
        XCTAssertEqual(Set(json[0].keys), ["id", "name", "coordinate"])
        XCTAssertEqual(json[0]["id"] as? String, places[0].id.uuidString)
        let coordinate = try XCTUnwrap(json[0]["coordinate"] as? [String: Double])
        XCTAssertEqual(coordinate, ["latitude": 50, "longitude": 10])
    }

    func testActivationSendsOnlyLatestList() async throws {
        let transport = FakePhoneTransport()
        let phone = PhoneSession(transport: transport)
        phone.start()
        phone.update(places: [place("Alt")])
        let latest = [place("Neu")]
        phone.update(places: latest)
        XCTAssertEqual(transport.activationCount, 1)
        XCTAssertTrue(transport.contexts.isEmpty)
        transport.activated = true
        transport.onStateChange?()
        XCTAssertEqual(try decoded(XCTUnwrap(transport.contexts.last)), latest)
        XCTAssertEqual(transport.contexts.count, 1)
        XCTAssertFalse(phone.hasPendingUpdate)
    }

    func testUnpairedOrUninstalledWatchDoesNotReceiveContext() async throws {
        for paired in [false, true] {
            let transport = FakePhoneTransport()
            transport.activated = true
            transport.paired = paired
            transport.installed = !paired
            let phone = PhoneSession(transport: transport)
            let places = [place()]
            phone.update(places: places)
            XCTAssertTrue(transport.contexts.isEmpty)
            transport.paired = true
            transport.installed = true
            transport.onStateChange?()
            XCTAssertEqual(try decoded(XCTUnwrap(transport.contexts.last)), places)
        }
    }

    func testDeletionSendsEmptyListToReplaceWatchContents() async throws {
        let transport = FakePhoneTransport()
        transport.activated = true
        let phone = PhoneSession(transport: transport)
        phone.update(places: [place()])
        phone.update(places: [])
        XCTAssertEqual(transport.contexts.count, 2)
        XCTAssertEqual(try decoded(XCTUnwrap(transport.contexts.last)), [])
    }

    func testFailedSendRetriesNewestListOnForeground() async throws {
        let transport = FakePhoneTransport()
        transport.activated = true
        transport.fail = true
        let phone = PhoneSession(transport: transport)
        phone.update(places: [place("Alt")])
        let latest = [place("Neu")]
        phone.update(places: latest)
        XCTAssertTrue(phone.hasPendingUpdate)
        XCTAssertTrue(transport.contexts.isEmpty)
        transport.fail = false
        phone.start()
        XCTAssertEqual(try decoded(XCTUnwrap(transport.contexts.last)), latest)
        XCTAssertFalse(phone.hasPendingUpdate)
    }

    func testWatchSwitchResendsCurrentListWithoutLocalChange() async throws {
        let transport = FakePhoneTransport()
        transport.activated = true
        let phone = PhoneSession(transport: transport)
        let places = [place()]
        phone.update(places: places)
        transport.activated = false
        transport.onStateChange?()
        XCTAssertEqual(transport.contexts.count, 1)
        transport.activated = true
        transport.onStateChange?()
        XCTAssertEqual(transport.contexts.count, 2)
        XCTAssertEqual(try decoded(XCTUnwrap(transport.contexts.last)), places)
    }

    func testUnsupportedSessionAndActivationWithoutSnapshotAreHarmless() async throws {
        let unsupported = PhoneSession(transport: nil)
        unsupported.start()
        unsupported.update(places: [])
        let transport = FakePhoneTransport()
        transport.activated = true
        let phone = PhoneSession(transport: transport)
        phone.start()
        transport.onStateChange?()
        XCTAssertTrue(transport.contexts.isEmpty)
    }
}

@MainActor
private final class FakePhoneTransport: PhoneSessionTransport {
    var activated = false
    var paired = true
    var installed = true
    var fail = false
    var onStateChange: (() -> Void)?
    var activationCount = 0
    var contexts: [[String: Any]] = []
    var canSendContext: Bool { activated && paired && installed }
    func activate() { activationCount += 1 }
    func updateApplicationContext(_ context: [String: Any]) throws {
        if fail { throw URLError(.notConnectedToInternet) }
        contexts.append(context)
    }
}
