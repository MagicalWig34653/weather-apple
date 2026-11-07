import XCTest
@testable import Weather

@MainActor
final class InstallationIDDisplayTests: XCTestCase {
    func testValidatedNormalizesUUIDAndRejectsOthers() {
        XCTAssertEqual(InstallationIDDisplay.validated("3F2504E0-4F89-41D3-9A0C-0305E82C3301"),
                       "3f2504e0-4f89-41d3-9a0c-0305e82c3301")
        XCTAssertNil(InstallationIDDisplay.validated(nil))
        XCTAssertNil(InstallationIDDisplay.validated(""))
        XCTAssertNil(InstallationIDDisplay.validated("not-a-uuid"))
    }

    func testIDIsOnlyVisibleWhenPushIsRegistered() async {
        let secrets = FakeSecrets()
        let identity = PushIdentity.make()
        XCTAssertTrue(secrets.save(identity))
        let defaults = UserDefaults(suiteName: "install-id-\(UUID().uuidString)")!
        let manager = PushManager(gateway: FakeGateway(), secrets: secrets, authorizer: FakeAuthorizer(.authorized, grants: true),
                                  registrar: FakeRegistrar(), defaults: defaults, environment: .sandbox, locale: "de")
        XCTAssertNil(manager.installationID, "no subscription: hidden even if a key exists")
        _ = await manager.enable(placeID: UUID(), latitude: 52.5, longitude: 13.4)
        XCTAssertEqual(manager.installationID, identity.installationID)
        XCTAssertNotEqual(manager.installationID, identity.secret)
        await manager.resetAll()
        XCTAssertNil(manager.installationID)
    }
}
