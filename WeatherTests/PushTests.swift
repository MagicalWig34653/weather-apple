import XCTest
@testable import Weather

// MARK: Fakes

final class FakeSecrets: PushSecretStore, @unchecked Sendable {
    private let lock = NSLock()
    private var identity: PushIdentity?
    func load() -> PushIdentity? { lock.withLock { identity } }
    func save(_ identity: PushIdentity) -> Bool { lock.withLock { self.identity = identity }; return true }
    func delete() { lock.withLock { identity = nil } }
}

final class FakeGateway: PushGateway, @unchecked Sendable {
    private let lock = NSLock()
    private var _calls: [String] = []
    var calls: [String] { lock.withLock { _calls } }
    /// Errors thrown by the next call with this method name (consumed in order).
    private var failures: [String: [PushGatewayError]] = [:]
    private(set) var lastRequests: [PushSubscriptionRequest] = []
    private(set) var lastToken: String?
    private(set) var lastEnvironment: PushEnvironment?
    private(set) var lastIdentity: PushIdentity?

    func fail(_ method: String, with errors: PushGatewayError...) { lock.withLock { failures[method, default: []].append(contentsOf: errors) } }
    private func record(_ name: String, _ identity: PushIdentity) throws {
        let error: PushGatewayError? = lock.withLock {
            _calls.append(name); lastIdentity = identity
            guard var queue = failures[name], !queue.isEmpty else { return nil }
            let first = queue.removeFirst(); failures[name] = queue; return first
        }
        if let error { throw error }
    }

    func putInstallation(_ identity: PushIdentity, token: String, environment: PushEnvironment, locale: String) async throws {
        try record("putInstallation", identity)
        lock.withLock { lastToken = token; lastEnvironment = environment }
    }
    func deleteInstallation(_ identity: PushIdentity) async throws { try record("deleteInstallation", identity) }
    func createSubscription(_ identity: PushIdentity, _ request: PushSubscriptionRequest) async throws -> String {
        try record("createSubscription", identity)
        lock.withLock { lastRequests.append(request) }
        return UUID().uuidString.lowercased()
    }
    func updateSubscription(_ identity: PushIdentity, id: String, _ request: PushSubscriptionRequest) async throws {
        try record("updateSubscription", identity)
        lock.withLock { lastRequests.append(request) }
    }
    func deleteSubscription(_ identity: PushIdentity, id: String) async throws { try record("deleteSubscription", identity) }
    func sendTestNotification(_ identity: PushIdentity) async throws -> String {
        try record("sendTestNotification", identity)
        return "sandbox"
    }
}

final class FakeAuthorizer: PushAuthorizing, @unchecked Sendable {
    private let lock = NSLock()
    private var current: PushAuthorization
    private let grants: Bool
    private(set) var prompts = 0
    init(_ status: PushAuthorization, grants: Bool = true) { current = status; self.grants = grants }
    func status() async -> PushAuthorization { lock.withLock { current } }
    func requestAuthorization() async -> Bool {
        lock.withLock { prompts += 1; if current == .notDetermined { current = grants ? .authorized : .denied } }
        return grants
    }
}

@MainActor final class FakeRegistrar: RemoteNotificationRegistering {
    var registered = 0, unregistered = 0
    func register() { registered += 1 }
    func unregister() { unregistered += 1 }
}

// MARK: Tests

@MainActor
final class PushManagerTests: XCTestCase {
    private var defaults: UserDefaults!
    private let berlin = (lat: 52.52, lon: 13.405)

    override func setUp() {
        defaults = UserDefaults(suiteName: "push-tests-\(UUID().uuidString)")
    }

    private func make(auth: PushAuthorization = .notDetermined, grants: Bool = true, gateway: FakeGateway = FakeGateway(),
                      secrets: FakeSecrets = FakeSecrets()) -> (PushManager, FakeGateway, FakeSecrets, FakeAuthorizer, FakeRegistrar) {
        let authorizer = FakeAuthorizer(auth, grants: grants), registrar = FakeRegistrar()
        let manager = PushManager(gateway: gateway, secrets: secrets, authorizer: authorizer, registrar: registrar,
                                  defaults: defaults, environment: .sandbox, locale: "de")
        return (manager, gateway, secrets, authorizer, registrar)
    }

    private func deliverToken(_ manager: PushManager) async {
        await manager.didRegister(deviceToken: Data([0xAB, 0xCD, 0x01, 0x02]))
    }

    func testEnableRegistersInstallationAndSubscription() async {
        let (manager, gateway, secrets, authorizer, registrar) = make()
        let id = UUID()
        let ok = await manager.enable(placeID: id, latitude: berlin.lat, longitude: berlin.lon)
        XCTAssertTrue(ok)
        XCTAssertEqual(authorizer.prompts, 1)
        XCTAssertEqual(registrar.registered, 1)
        XCTAssertEqual(gateway.calls, [], "no token yet: nothing sent")
        XCTAssertEqual(manager.status(for: id), .pending)

        await deliverToken(manager)
        XCTAssertEqual(gateway.calls, ["putInstallation", "createSubscription"])
        XCTAssertEqual(gateway.lastToken, "abcd0102")
        XCTAssertEqual(gateway.lastEnvironment, .sandbox)
        XCTAssertEqual(manager.status(for: id), .active)
        let cell = PushGrid.cell(latitude: berlin.lat, longitude: berlin.lon)!
        XCTAssertEqual(gateway.lastRequests, [PushSubscriptionRequest(cell: cell, threshold: 5, leadMinutes: 20, enabled: true)])
        let identity = secrets.load()!
        XCTAssertTrue((32...128).contains(identity.secret.count))
        XCTAssertNotNil(UUID(uuidString: identity.installationID))
    }

    func testTimeSensitiveDefaultsOffAndIsUploadedOnUpdate() async {
        let (manager, gateway, _, _, _) = make()
        let id = UUID()
        _ = await manager.enable(placeID: id, latitude: berlin.lat, longitude: berlin.lon)
        await deliverToken(manager)
        XCTAssertEqual(manager.settings(for: id)?.timeSensitive, false)
        XCTAssertEqual(gateway.lastRequests.last?.timeSensitive, false)
        await manager.update(placeID: id, timeSensitive: true)
        XCTAssertEqual(gateway.lastRequests.last?.timeSensitive, true)
        await manager.update(placeID: id, leadMinutes: 30)
        XCTAssertEqual(gateway.lastRequests.last?.timeSensitive, true, "PUT replaces all fields: keep the flag")
        XCTAssertEqual(manager.status(for: id), .active)
    }

    func testOldPersistedStateWithoutTimeSensitiveStillDecodes() throws {
        let old = #"{"cell":{"x":1,"y":2},"leadMinutes":20,"sensitivity":"moderate","needsUpload":false}"#
        let decoded = try JSONDecoder().decode(PlacePushSettings.self, from: Data(old.utf8))
        XCTAssertFalse(decoded.timeSensitive)
        XCTAssertEqual(decoded.cell, PushGrid.Cell(x: 1, y: 2))
    }

    func testSendTestNeedsAuthorizationAndSucceeds() async {
        let (manager, gateway, _, _, _) = make()
        XCTAssertFalse(manager.canSendTest)
        _ = await manager.enable(placeID: UUID(), latitude: berlin.lat, longitude: berlin.lon)
        XCTAssertFalse(manager.canSendTest, "no token yet")
        await deliverToken(manager)
        XCTAssertTrue(manager.canSendTest)
        await manager.sendTest()
        XCTAssertEqual(manager.testState, .sent)
        XCTAssertEqual(gateway.calls.last, "sendTestNotification")
    }

    func testSendTestShowsGermanMessagePerCode() async {
        let failures: [(PushGatewayError, String)] = [
            (.test(.rateLimited(retryAfter: 3600)), "60 Minuten"),
            (.test(.environmentNotAllowed), "App-Variante"),
            (.test(.apnsUnavailable503), "nicht eingerichtet"),
            (.test(.badDeviceToken), "Gerätetoken"),
            (.test(.keyRejected), "Zugangsschlüssel"),
            (.test(.apnsUnavailable), "Apples Mitteilungsdienst"),
            (.test(.apnsRejected), "abgelehnt"),
            (.notFound, "nicht aktiv"), (.offline, "Internetverbindung"),
        ]
        for (error, fragment) in failures {
            let (manager, gateway, _, _, _) = make()
            _ = await manager.enable(placeID: UUID(), latitude: berlin.lat, longitude: berlin.lon)
            await deliverToken(manager)
            gateway.fail("sendTestNotification", with: error)
            await manager.sendTest()
            guard case .failed(let message) = manager.testState else { XCTFail("\(error)"); continue }
            XCTAssertTrue(message.contains(fragment), "\(error): \(message)")
        }
    }

    func testUnregisteredTokenTriggersReRegistration() async {
        let (manager, gateway, _, _, _) = make()
        let id = UUID()
        _ = await manager.enable(placeID: id, latitude: berlin.lat, longitude: berlin.lon)
        await deliverToken(manager)
        gateway.fail("sendTestNotification", with: .test(.tokenUnregistered))
        await manager.sendTest()
        XCTAssertEqual(Array(gateway.calls.suffix(3)), ["sendTestNotification", "putInstallation", "createSubscription"])
        XCTAssertEqual(manager.status(for: id), .active)
    }

    func testDeviceTokenAndSecretAreNeverPersistedInDefaults() async {
        let (manager, _, secrets, _, _) = make()
        _ = await manager.enable(placeID: UUID(), latitude: berlin.lat, longitude: berlin.lon)
        await deliverToken(manager)
        let stored = String(data: defaults.data(forKey: PushManager.stateKey)!, encoding: .utf8)!
        XCTAssertFalse(stored.contains("abcd0102"))
        XCTAssertFalse(stored.contains(secrets.load()!.secret))
        XCTAssertFalse(stored.contains("52.5"))
        XCTAssertFalse(stored.contains("13.4"))
    }

    func testDeniedPromptKeepsOptOutAndReportsSettingsHint() async {
        let (manager, gateway, _, authorizer, registrar) = make(grants: false)
        let id = UUID()
        let ok = await manager.enable(placeID: id, latitude: berlin.lat, longitude: berlin.lon)
        XCTAssertFalse(ok)
        XCTAssertEqual(authorizer.prompts, 1)
        XCTAssertEqual(manager.authorization, .denied)
        XCTAssertNil(manager.settings(for: id))
        XCTAssertNotNil(manager.messages[id])
        XCTAssertEqual(registrar.registered, 0)
        XCTAssertEqual(gateway.calls, [])
    }

    func testAlreadyDeniedDoesNotPromptAgain() async {
        let (manager, _, _, authorizer, _) = make(auth: .denied)
        let ok = await manager.enable(placeID: UUID(), latitude: berlin.lat, longitude: berlin.lon)
        XCTAssertFalse(ok)
        XCTAssertEqual(authorizer.prompts, 0)
    }

    func testPlaceOutsideRadarIsRejectedWithoutPrompt() async {
        let (manager, _, _, authorizer, _) = make()
        let id = UUID()
        let ok = await manager.enable(placeID: id, latitude: 40.4, longitude: -3.7)
        XCTAssertFalse(ok)
        XCTAssertEqual(authorizer.prompts, 0)
        XCTAssertNotNil(manager.messages[id])
    }

    func testUpdateSendsPutWithNewValues() async {
        let (manager, gateway, _, _, _) = make()
        let id = UUID()
        _ = await manager.enable(placeID: id, latitude: berlin.lat, longitude: berlin.lon)
        await deliverToken(manager)
        await manager.update(placeID: id, leadMinutes: 30, sensitivity: .heavy)
        XCTAssertEqual(gateway.calls.suffix(2), ["putInstallation", "updateSubscription"])
        XCTAssertEqual(gateway.lastRequests.last?.leadMinutes, 30)
        XCTAssertEqual(gateway.lastRequests.last?.threshold, 8)
        XCTAssertEqual(manager.status(for: id), .active)
    }

    func testUpdateOfUnknownSubscriptionRecreatesIt() async {
        let (manager, gateway, _, _, _) = make()
        let id = UUID()
        _ = await manager.enable(placeID: id, latitude: berlin.lat, longitude: berlin.lon)
        await deliverToken(manager)
        gateway.fail("updateSubscription", with: .notFound)
        await manager.update(placeID: id, leadMinutes: 10)
        XCTAssertEqual(gateway.calls.suffix(2), ["updateSubscription", "createSubscription"])
        XCTAssertEqual(manager.status(for: id), .active)
    }

    func testOptOutOfOneOfTwoPlacesDeletesOnlySubscription() async {
        let (manager, gateway, secrets, _, _) = make()
        let a = UUID(), b = UUID()
        _ = await manager.enable(placeID: a, latitude: berlin.lat, longitude: berlin.lon)
        _ = await manager.enable(placeID: b, latitude: 48.14, longitude: 11.58)
        await deliverToken(manager)
        await manager.disable(placeID: a)
        XCTAssertEqual(gateway.calls.last, "deleteSubscription")
        XCTAssertFalse(gateway.calls.contains("deleteInstallation"))
        XCTAssertNil(manager.settings(for: a))
        XCTAssertNotNil(secrets.load())
    }

    func testLastOptOutDeletesInstallationAndKeychain() async {
        let (manager, gateway, secrets, _, registrar) = make()
        let id = UUID()
        _ = await manager.enable(placeID: id, latitude: berlin.lat, longitude: berlin.lon)
        await deliverToken(manager)
        await manager.disable(placeID: id)
        XCTAssertEqual(gateway.calls.last, "deleteInstallation")
        XCTAssertNil(secrets.load())
        XCTAssertEqual(registrar.unregistered, 1)
        XCTAssertFalse(manager.isAnyEnabled)
        XCTAssertEqual(manager.summary, "Mitteilungen: aus")
    }

    func testPlaceRemovalDeletesSubscription() async {
        let (manager, gateway, _, _, _) = make()
        let a = UUID(), b = UUID()
        _ = await manager.enable(placeID: a, latitude: berlin.lat, longitude: berlin.lon)
        _ = await manager.enable(placeID: b, latitude: 48.14, longitude: 11.58)
        await deliverToken(manager)
        await manager.placesRemoved([a])
        XCTAssertEqual(gateway.calls.last, "deleteSubscription")
        XCTAssertEqual(manager.enabledCount, 1)
    }

    func testResetAllDeletesInstallation() async {
        let (manager, gateway, secrets, _, _) = make()
        _ = await manager.enable(placeID: UUID(), latitude: berlin.lat, longitude: berlin.lon)
        await deliverToken(manager)
        await manager.resetAll()
        XCTAssertEqual(gateway.calls.last, "deleteInstallation")
        XCTAssertNil(secrets.load())
        XCTAssertEqual(manager.enabledCount, 0)
    }

    func testFailedInstallationDeleteIsRetriedLater() async {
        let (manager, gateway, secrets, _, _) = make()
        let id = UUID()
        _ = await manager.enable(placeID: id, latitude: berlin.lat, longitude: berlin.lon)
        await deliverToken(manager)
        gateway.fail("deleteInstallation", with: .offline)
        await manager.disable(placeID: id)
        XCTAssertNotNil(secrets.load(), "secret is kept until the server confirmed the deletion")
        XCTAssertTrue(manager.state.pendingInstallationDelete)
        await manager.sync()
        XCTAssertNil(secrets.load())
        XCTAssertFalse(manager.state.pendingInstallationDelete)
    }

    func testFailedSubscriptionDeleteIsRetriedLater() async {
        let (manager, gateway, _, _, _) = make()
        let a = UUID(), b = UUID()
        _ = await manager.enable(placeID: a, latitude: berlin.lat, longitude: berlin.lon)
        _ = await manager.enable(placeID: b, latitude: 48.14, longitude: 11.58)
        await deliverToken(manager)
        gateway.fail("deleteSubscription", with: .server(503))
        await manager.disable(placeID: a)
        XCTAssertEqual(manager.state.pendingSubscriptionDeletes.count, 1)
        await manager.sync()
        XCTAssertEqual(manager.state.pendingSubscriptionDeletes.count, 0)
    }

    func testOfflineKeepsOptInPendingWithMessageAndRetries() async {
        let (manager, gateway, _, _, _) = make()
        let id = UUID()
        _ = await manager.enable(placeID: id, latitude: berlin.lat, longitude: berlin.lon)
        gateway.fail("putInstallation", with: .offline)
        await deliverToken(manager)
        XCTAssertEqual(manager.status(for: id), .pending)
        XCTAssertNotNil(manager.messages[id])
        await manager.sync()
        XCTAssertEqual(manager.status(for: id), .active)
        XCTAssertNil(manager.messages[id])
    }

    func testServerErrorsAndRateLimitGiveMessages() async {
        for error in [PushGatewayError.server(500), .rateLimited, .notFound, .rejected(400)] {
            let (manager, gateway, _, _, _) = make()
            let id = UUID()
            _ = await manager.enable(placeID: id, latitude: berlin.lat, longitude: berlin.lon)
            gateway.fail("putInstallation", with: error)
            await deliverToken(manager)
            XCTAssertNotNil(manager.messages[id], "\(error)")
            XCTAssertEqual(manager.status(for: id), .pending)
        }
    }

    func testSubscriptionLimitRemovesTheOptIn() async {
        let (manager, gateway, _, _, _) = make()
        let id = UUID()
        _ = await manager.enable(placeID: id, latitude: berlin.lat, longitude: berlin.lon)
        gateway.fail("createSubscription", with: .subscriptionLimit)
        await deliverToken(manager)
        XCTAssertNil(manager.settings(for: id))
        XCTAssertNotNil(manager.messages[id])
    }

    func testUnauthorizedRotatesIdentityAndRecreatesSubscriptions() async {
        let (manager, gateway, secrets, _, _) = make()
        let id = UUID()
        _ = await manager.enable(placeID: id, latitude: berlin.lat, longitude: berlin.lon)
        await deliverToken(manager)
        let old = secrets.load()!
        gateway.fail("putInstallation", with: .unauthorized)
        await manager.update(placeID: id, leadMinutes: 10)
        XCTAssertNotEqual(secrets.load()?.installationID, old.installationID)
        XCTAssertEqual(manager.status(for: id), .active)
        XCTAssertEqual(gateway.calls.suffix(3), ["putInstallation", "putInstallation", "createSubscription"])
    }

    func testLeftoverIdentityWithoutPlacesIsCleanedUp() async {
        let secrets = FakeSecrets()
        _ = secrets.save(PushIdentity.make())   // e.g. keychain survived an app reinstall
        let (manager, gateway, _, _, _) = make(auth: .authorized, secrets: secrets)
        await manager.start()
        XCTAssertEqual(gateway.calls, ["deleteInstallation"])
        XCTAssertNil(secrets.load())
    }

    func testStateSurvivesRestartWithoutToken() async {
        let (manager, _, _, _, _) = make()
        let id = UUID()
        _ = await manager.enable(placeID: id, latitude: berlin.lat, longitude: berlin.lon)
        await deliverToken(manager)
        let (again, gateway, _, _, registrar) = make(auth: .authorized)
        XCTAssertEqual(again.settings(for: id)?.leadMinutes, 20)
        await again.start()
        XCTAssertEqual(registrar.registered, 1, "fresh token requested on every start")
        XCTAssertEqual(gateway.calls, [], "waits for the token, none cached")
    }

    func testSubscriptionLimitLocallyEnforced() async {
        let (manager, _, _, _, _) = make(auth: .authorized)
        for _ in 0..<PushManager.maxSubscriptions { _ = await manager.enable(placeID: UUID(), latitude: berlin.lat, longitude: berlin.lon) }
        let extra = UUID()
        let ok = await manager.enable(placeID: extra, latitude: berlin.lat, longitude: berlin.lon)
        XCTAssertFalse(ok)
        XCTAssertNotNil(manager.messages[extra])
    }
}

// MARK: Grid

final class PushGridTests: XCTestCase {
    private func mercator(_ lat: Double, _ lon: Double) -> (Double, Double) {
        let r = 6_378_137.0
        return (r * lon * .pi / 180, r * log(tan(.pi / 4 + lat * .pi / 360)))
    }

    func testCellMatchesBackendFormula() throws {
        for (lat, lon) in [(52.52, 13.405), (48.137, 11.575), (53.55, 9.99), (47.7, 7.6)] {
            let (x, y) = mercator(lat, lon)
            let b = PushGrid.bbox
            let expectedX = Int(floor((x - b[0]) / (b[2] - b[0]) * 1024))
            let expectedY = Int(floor((b[3] - y) / (b[3] - b[1]) * 1311))
            let cell = try XCTUnwrap(PushGrid.cell(latitude: lat, longitude: lon))
            XCTAssertEqual(cell, PushGrid.Cell(x: expectedX, y: expectedY))
            XCTAssertTrue((0..<1024).contains(cell.x) && (0..<1311).contains(cell.y))
        }
    }

    func testKnownBerlinCell() throws {
        // Arithmetic check: X = 1_492_139 m -> (X-612257)/1124327*1024 = 801.3; Y = 6_894_699 m -> (7381298-Y)/1439224*1311 = 443.2.
        let cell = try XCTUnwrap(PushGrid.cell(latitude: 52.52, longitude: 13.405))
        XCTAssertEqual(cell, PushGrid.Cell(x: 801, y: 443))
    }

    func testOutsideAndInvalidReturnNil() {
        XCTAssertNil(PushGrid.cell(latitude: 40, longitude: -3))
        XCTAssertNil(PushGrid.cell(latitude: 60, longitude: 10))
        XCTAssertNil(PushGrid.cell(latitude: .nan, longitude: 10))
        XCTAssertNil(PushGrid.cell(latitude: 52, longitude: 25))
    }

    func testCornersStayInsideTheGrid() throws {
        // Just inside the south-west and north-east corner of the bbox.
        let r = 6_378_137.0
        func wgs(_ x: Double, _ y: Double) -> (Double, Double) { ((2 * atan(exp(y / r)) - .pi / 2) * 180 / .pi, x / r * 180 / .pi) }
        let b = PushGrid.bbox
        let sw = wgs(b[0] + 1, b[1] + 1), ne = wgs(b[2] - 1, b[3] - 1)
        XCTAssertEqual(PushGrid.cell(latitude: sw.0, longitude: sw.1), PushGrid.Cell(x: 0, y: 1310))
        XCTAssertEqual(PushGrid.cell(latitude: ne.0, longitude: ne.1), PushGrid.Cell(x: 1023, y: 0))
    }

    func testSensitivityThresholdsMatchLegendLowerBounds() {
        let entries = MapLegend.precipitationRadar.entries   // entry 0 = "no data", entry n = class n
        XCTAssertEqual(entries[PushSensitivity.light.threshold].id, "0.4")
        XCTAssertEqual(entries[PushSensitivity.moderate.threshold].id, "2")
        XCTAssertEqual(entries[PushSensitivity.heavy.threshold].id, "7.5")
        XCTAssertEqual(PushLead.options, [10, 20, 30])
    }
}

// MARK: HTTP gateway

final class HTTPPushGatewayTests: XCTestCase {
    private final class Recorder: @unchecked Sendable {
        private let lock = NSLock()
        var requests: [URLRequest] = []
        var sleeps: [TimeInterval] = []
        private var responses: [Result<(Int, String, [String: String]), Error>]
        init(_ responses: [Result<(Int, String, [String: String]), Error>]) { self.responses = responses }
        func next(_ request: URLRequest) throws -> (Data, HTTPURLResponse) {
            try lock.withLock {
                requests.append(request)
                let item = responses.isEmpty ? .success((204, "", [:])) : responses.removeFirst()
                switch item {
                case .failure(let error): throw error
                case .success(let (code, body, headers)):
                    return (Data(body.utf8), HTTPURLResponse(url: request.url!, statusCode: code, httpVersion: nil, headerFields: headers)!)
                }
            }
        }
    }

    private let identity = PushIdentity(installationID: "11111111-2222-3333-4444-555555555555", secret: String(repeating: "a", count: 43))
    private let request = PushSubscriptionRequest(cell: .init(x: 783, y: 395), threshold: 5, leadMinutes: 20, enabled: true)

    private func gateway(_ recorder: Recorder) -> HTTPPushGateway {
        HTTPPushGateway(baseURL: URL(string: "https://example.test/v1/push/")!,
                        transport: { try recorder.next($0) }, sleep: { recorder.sleeps.append($0) })
    }

    func testRequestFormats() async throws {
        let recorder = Recorder([.success((201, "", [:])), .success((201, "{\"id\":\"AAAAAAAA-2222-3333-4444-555555555555\"}", [:])), .success((204, "", [:])), .success((204, "", [:])), .success((204, "", [:]))])
        let gw = gateway(recorder)
        try await gw.putInstallation(identity, token: "abcd", environment: .production, locale: "de")
        let id = try await gw.createSubscription(identity, request)
        XCTAssertEqual(id, "aaaaaaaa-2222-3333-4444-555555555555")
        try await gw.updateSubscription(identity, id: id, request)
        try await gw.deleteSubscription(identity, id: id)
        try await gw.deleteInstallation(identity)

        let r = recorder.requests
        XCTAssertEqual(r.map(\.httpMethod), ["PUT", "POST", "PUT", "DELETE", "DELETE"])
        XCTAssertEqual(r[0].url?.absoluteString, "https://example.test/v1/push/installations/\(identity.installationID)")
        XCTAssertEqual(r[1].url?.path, "/v1/push/installations/\(identity.installationID)/subscriptions")
        XCTAssertEqual(r[2].url?.lastPathComponent, id)
        for item in r {
            XCTAssertEqual(item.value(forHTTPHeaderField: "X-Installation-Secret"), identity.secret)
            XCTAssertFalse(item.httpShouldHandleCookies)
        }
        XCTAssertEqual(String(data: r[0].httpBody!, encoding: .utf8), "{\"env\":\"production\",\"locale\":\"de\",\"token\":\"abcd\"}")
        let body = try JSONSerialization.jsonObject(with: r[1].httpBody!) as! [String: Int]
        XCTAssertEqual(body, ["grid_version": 1, "cell_x": 783, "cell_y": 395, "threshold": 5, "lead_minutes": 20, "enabled": 1, "time_sensitive": 0])
        XCTAssertNil(r[3].httpBody)
        XCTAssertLessThan(r[1].httpBody!.count, 2048)
    }

    func testTimeSensitiveIsAlwaysSentAsBooleanInPutAndPost() async throws {
        let recorder = Recorder([.success((204, "", [:])), .success((204, "", [:]))])
        let gw = gateway(recorder)
        let on = PushSubscriptionRequest(cell: .init(x: 1, y: 2), threshold: 5, leadMinutes: 20, enabled: true, timeSensitive: true)
        try await gw.updateSubscription(identity, id: "aaaaaaaa-2222-3333-4444-555555555555", on)
        try await gw.updateSubscription(identity, id: "aaaaaaaa-2222-3333-4444-555555555555", request)
        let texts = recorder.requests.map { String(data: $0.httpBody!, encoding: .utf8)! }
        XCTAssertTrue(texts[0].contains("\"time_sensitive\":true"), texts[0])
        XCTAssertTrue(texts[1].contains("\"time_sensitive\":false"), texts[1])
        XCTAssertEqual(recorder.requests.map(\.httpMethod), ["PUT", "PUT"])
    }

    func testTestNotificationRequestAndSuccess() async throws {
        let recorder = Recorder([.success((200, "{\"sent\":true,\"environment\":\"sandbox\"}", [:]))])
        let env = try await gateway(recorder).sendTestNotification(identity)
        XCTAssertEqual(env, "sandbox")
        let r = recorder.requests[0]
        XCTAssertEqual(r.httpMethod, "POST")
        XCTAssertEqual(r.url?.path, "/v1/push/installations/\(identity.installationID)/test")
        XCTAssertNil(r.httpBody)
        XCTAssertEqual(r.value(forHTTPHeaderField: "X-Installation-Secret"), identity.secret)
    }

    func testTestNotificationMapsEveryErrorCodeWithoutRetry() async {
        let cases: [(Int, String, [String: String], PushGatewayError)] = [
            (409, "{\"error\":\"environment_not_allowed\"}", [:], .test(.environmentNotAllowed)),
            (503, "{\"error\":\"apns_unavailable\"}", [:], .test(.apnsUnavailable503)),
            (502, "{\"error\":\"apns_bad_device_token\",\"reason\":\"BadDeviceToken\"}", [:], .test(.badDeviceToken)),
            (502, "{\"error\":\"apns_key_rejected\"}", [:], .test(.keyRejected)),
            (502, "{\"error\":\"apns_unavailable\"}", [:], .test(.apnsUnavailable)),
            (502, "{\"error\":\"apns_rejected\"}", [:], .test(.apnsRejected)),
            (410, "{\"error\":\"token_unregistered\"}", [:], .test(.tokenUnregistered)),
            (429, "{\"error\":\"test_rate_limited\"}", ["Retry-After": "3600"], .test(.rateLimited(retryAfter: 3600))),
            (404, "", [:], .notFound), (401, "{\"error\":\"unauthorized\"}", [:], .unauthorized),
        ]
        for (code, body, headers, expected) in cases {
            let recorder = Recorder([.success((code, body, headers))])
            do { _ = try await gateway(recorder).sendTestNotification(identity); XCTFail("\(code)") }
            catch { XCTAssertEqual(error as? PushGatewayError, expected, "\(code) \(body)") }
            XCTAssertEqual(recorder.requests.count, 1, "\(code): a test must never be retried")
            XCTAssertTrue(recorder.sleeps.isEmpty)
        }
    }

    func testTestNotificationOfflineIsNotRetried() async {
        let recorder = Recorder([.failure(URLError(.timedOut))])
        do { _ = try await gateway(recorder).sendTestNotification(identity); XCTFail() }
        catch { XCTAssertEqual(error as? PushGatewayError, .transport) }
        XCTAssertEqual(recorder.requests.count, 1)
    }

    func testRetriesTransientFailuresThenSucceeds() async throws {
        let recorder = Recorder([.success((503, "", [:])), .failure(URLError(.timedOut)), .success((204, "", [:]))])
        try await gateway(recorder).deleteInstallation(identity)
        XCTAssertEqual(recorder.requests.count, 3)
        XCTAssertEqual(recorder.sleeps.count, 2)
    }

    func testGivesUpAfterMaxAttempts() async {
        let recorder = Recorder([.success((502, "", [:])), .success((502, "", [:])), .success((502, "", [:])), .success((204, "", [:]))])
        do { try await gateway(recorder).deleteInstallation(identity); XCTFail() }
        catch { XCTAssertEqual(error as? PushGatewayError, .server(502)) }
        XCTAssertEqual(recorder.requests.count, RadarRetryPolicy.maxAttempts)
    }

    func testRateLimitIsRetriedHonoringRetryAfterAndThenReported() async {
        let recorder = Recorder([.success((429, "", ["Retry-After": "2"])), .success((429, "", [:])), .success((429, "", [:]))])
        do { try await gateway(recorder).deleteInstallation(identity); XCTFail() }
        catch { XCTAssertEqual(error as? PushGatewayError, .rateLimited) }
        XCTAssertEqual(recorder.requests.count, 3)
        XCTAssertGreaterThanOrEqual(recorder.sleeps.first ?? 0, 2)
    }

    func testClientErrorsAreNotRetried() async {
        let cases: [(Int, String, PushGatewayError)] = [
            (401, "{\"error\":\"unauthorized\"}", .unauthorized), (404, "", .notFound),
            (409, "{\"error\":\"subscription_limit\"}", .subscriptionLimit), (409, "{\"error\":\"x\"}", .rejected(409)),
            (400, "", .rejected(400)), (413, "", .rejected(413)),
        ]
        for (code, body, expected) in cases {
            let recorder = Recorder([.success((code, body, [:]))])
            do { try await gateway(recorder).deleteInstallation(identity); XCTFail() }
            catch { XCTAssertEqual(error as? PushGatewayError, expected, "\(code)") }
            XCTAssertEqual(recorder.requests.count, 1)
        }
    }

    func testOfflineIsNotRetried() async {
        let recorder = Recorder([.failure(URLError(.notConnectedToInternet))])
        do { try await gateway(recorder).deleteInstallation(identity); XCTFail() }
        catch { XCTAssertEqual(error as? PushGatewayError, .offline) }
        XCTAssertEqual(recorder.requests.count, 1)
    }

    func testIdentityFormatMatchesBackendRules() {
        let identity = PushIdentity.make()
        XCTAssertNotNil(UUID(uuidString: identity.installationID))
        XCTAssertEqual(identity.installationID, identity.installationID.lowercased())
        XCTAssertTrue((32...128).contains(identity.secret.count))
        XCTAssertTrue(identity.secret.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") })
        XCTAssertNotEqual(identity.secret, PushIdentity.make().secret)
    }

    func testBaseURLDerivedFromRadarURL() {
        XCTAssertEqual(PushBackendConfig.baseURL(radarBaseURL: URL(string: "https://showernow.linolaske.de/v1/radar/")!).absoluteString,
                       "https://showernow.linolaske.de/v1/push/")
    }
}
