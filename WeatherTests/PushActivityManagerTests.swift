import XCTest
@testable import Weather

@MainActor
private final class FakeRainActivities: RainActivityManaging {
    var activitiesEnabled = true
    var ended: [String?] = []
    var fallbackStarts = 0
    func start(eligible: @escaping @MainActor (String) -> Bool,
               startToken: @escaping @MainActor (Data) async -> Void,
               activityToken: @escaping @MainActor (String, Data) async -> Void,
               ended: @escaping @MainActor (String, Data?) async -> Void) {}
    func end(subscriptionID: String?) async { ended.append(subscriptionID) }
    func startFallback(attributes: RainActivityAttributes, state: RainActivityAttributes.ContentState) throws { fallbackStarts += 1 }
}

private actor ActivityTestGateway: PushGateway {
    let base = FakeGateway()
    var startTokens: [String?] = []
    var putTokens: [String] = []
    var deletedTokens: [String] = []
    var reservationDeletes: [String] = []
    var events: [String] = []
    var subscriptionErrors: [PushGatewayError] = []
    var startError: PushGatewayError?
    var failRecovery = false
    func failRecoveryReport() { failRecovery = true }
    func setSubscriptionErrors(_ errors: [PushGatewayError]) { subscriptionErrors = errors }
    func setStartError(_ error: PushGatewayError?) { startError = error }
    func clearEvents() { events = [] }
    private func record(_ request: PushSubscriptionRequest) throws {
        events.append(request.liveActivity == true ? "opt-in" : "ordinary")
        if request.liveActivity == true, !subscriptionErrors.isEmpty {
            let error = subscriptionErrors.removeFirst()
            if failRecovery { startError = .offline }
            throw error
        }
    }
    var nextTokenError: PushGatewayError?
    init(supported: Bool) { base.capabilitySet = supported ? ["live_activity"] : [] }
    func setError(_ error: PushGatewayError) { nextTokenError = error }
    func setSupported(_ supported: Bool) { base.capabilitySet = supported ? ["live_activity"] : [] }
    func capabilities() async throws -> Set<String> { try await base.capabilities() }
    func putInstallation(_ identity: PushIdentity, token: String, environment: PushEnvironment, locale: String) async throws {
        try await base.putInstallation(identity, token: token, environment: environment, locale: locale)
    }
    func deleteInstallation(_ identity: PushIdentity) async throws { try await base.deleteInstallation(identity) }
    func createSubscription(_ identity: PushIdentity, _ request: PushSubscriptionRequest) async throws -> String {
        try record(request)
        return try await base.createSubscription(identity, request)
    }
    func updateSubscription(_ identity: PushIdentity, id: String, _ request: PushSubscriptionRequest) async throws {
        try record(request)
        try await base.updateSubscription(identity, id: id, request)
    }
    func deleteSubscription(_ identity: PushIdentity, id: String) async throws { try await base.deleteSubscription(identity, id: id) }
    func sendTestNotification(_ identity: PushIdentity) async throws -> String { try await base.sendTestNotification(identity) }
    func putLiveActivityStartToken(_ identity: PushIdentity, deviceToken: String, environment: PushEnvironment,
                                   locale: String, startToken: String?) async throws {
        events.append(startToken == nil ? "clear-start" : "start")
        if let startError { throw startError }
        startTokens.append(startToken)
    }
    func putActivityToken(_ identity: PushIdentity, subscriptionID: String, token: String) async throws {
        if let error = nextTokenError { nextTokenError = nil; throw error }
        putTokens.append(token)
    }
    func deleteActivityToken(_ identity: PushIdentity, subscriptionID: String, token: String?) async throws {
        if let token { deletedTokens.append(token) } else { reservationDeletes.append(subscriptionID) }
    }
}

@MainActor
final class PushActivityManagerTests: XCTestCase {
    private func make(supported: Bool = true) async -> (PushManager, ActivityTestGateway, FakeRainActivities, UserDefaults, UUID) {
        let gateway = ActivityTestGateway(supported: supported), activities = FakeRainActivities()
        let defaults = UserDefaults(suiteName: "push-activity-\(UUID().uuidString)")!
        let manager = PushManager(gateway: gateway, secrets: FakeSecrets(), authorizer: FakeAuthorizer(.authorized),
                                  registrar: FakeRegistrar(), defaults: defaults, activityManager: activities)
        let id = UUID()
        await manager.didRegister(deviceToken: Data([1, 2, 3, 4]))
        await manager.enable(placeID: id, latitude: 52.52, longitude: 13.405)
        return (manager, gateway, activities, defaults, id)
    }

    func testOptInWaitsForTokenAndReportsItBeforeSubscriptionPUT() async {
        let (manager, gateway, _, _, id) = await make()
        await gateway.clearEvents()
        await manager.setLiveActivity(placeID: id, enabled: true)
        let before = await gateway.events
        XCTAssertFalse(before.contains("opt-in"))
        XCTAssertEqual(manager.settings(for: id)?.needsUpload, true)
        XCTAssertEqual(manager.liveActivityMessages[id], RainActivityText.waitingForToken.text())
        await manager.receivedStartToken(Data(repeating: 0xAB, count: 32))
        let events = await gateway.events
        XCTAssertEqual(Array(events.suffix(2)), ["start", "opt-in"])
        XCTAssertEqual(manager.settings(for: id)?.needsUpload, false)
        XCTAssertNil(manager.liveActivityMessages[id])
    }

    func testStartTokenMustBeAcknowledgedBeforeOptIn() async {
        let (manager, gateway, _, _, id) = await make()
        await manager.receivedStartToken(Data(repeating: 0xAB, count: 32))
        await gateway.setStartError(.offline)
        await gateway.clearEvents()
        await manager.setLiveActivity(placeID: id, enabled: true)
        let events = await gateway.events
        XCTAssertEqual(events, ["start"])
        XCTAssertEqual(manager.settings(for: id)?.needsUpload, true)
    }

    func testMissingStartTokenRecoveryRetriesOnlyOnce() async {
        for errors in [[PushGatewayError.startTokenRequired], [.startTokenRequired, .startTokenRequired], [.startTokenRequired, .offline]] {
            let (manager, gateway, _, _, id) = await make()
            await manager.receivedStartToken(Data(repeating: 0xAB, count: 32))
            await gateway.setSubscriptionErrors(errors)
            await gateway.clearEvents()
            await manager.setLiveActivity(placeID: id, enabled: true)
            let events = await gateway.events
            XCTAssertEqual(events, ["start", "opt-in", "start", "opt-in"])
            XCTAssertEqual(manager.settings(for: id)?.liveActivity, true)
            XCTAssertEqual(manager.settings(for: id)?.needsUpload, errors.count == 2)
            if errors.count == 2 {
                XCTAssertEqual(manager.liveActivityMessages[id], RainActivityText.waitingForToken.text())
            }
        }
    }

    func testFailedRecoveryReportStaysPendingWithoutSubscriptionRetry() async {
        let (manager, gateway, _, _, id) = await make()
        await manager.receivedStartToken(Data(repeating: 0xAB, count: 32))
        await gateway.setSubscriptionErrors([.startTokenRequired])
        await gateway.failRecoveryReport()
        await gateway.clearEvents()
        await manager.setLiveActivity(placeID: id, enabled: true)
        let events = await gateway.events
        XCTAssertEqual(events, ["start", "opt-in", "start"])
        XCTAssertEqual(manager.settings(for: id)?.needsUpload, true)
        XCTAssertEqual(manager.liveActivityMessages[id], RainActivityText.waitingForToken.text())
    }

    func testRestoredPendingOptInReportsTokenBeforeSubscriptionPOST() async throws {
        let gateway = ActivityTestGateway(supported: true)
        let defaults = UserDefaults(suiteName: "push-activity-\(UUID().uuidString)")!
        let id = UUID()
        var state = PushState()
        var settings = PlacePushSettings(cell: .init(x: 1, y: 1))
        settings.liveActivity = true
        settings.liveActivityDirty = true
        state.places[id] = settings
        defaults.set(try JSONEncoder().encode(state), forKey: PushManager.stateKey)
        let manager = PushManager(gateway: gateway, secrets: FakeSecrets(), authorizer: FakeAuthorizer(.authorized),
                                  registrar: FakeRegistrar(), defaults: defaults, activityManager: FakeRainActivities())
        await manager.didRegister(deviceToken: Data([1, 2, 3, 4]))
        await manager.refreshLiveActivitySupport()
        await gateway.clearEvents()
        await gateway.setSubscriptionErrors([.startTokenRequired])
        await manager.receivedStartToken(Data(repeating: 0xAB, count: 32))
        let events = await gateway.events
        let calls = await gateway.base.calls
        XCTAssertEqual(events, ["start", "opt-in", "start", "opt-in"])
        XCTAssertTrue(calls.contains("createSubscription"))
        XCTAssertFalse(calls.contains("updateSubscription"))
        XCTAssertNotNil(manager.settings(for: id)?.subscriptionID)
        XCTAssertEqual(manager.settings(for: id)?.needsUpload, false)
    }

    func testActivityFullDisablesOptInWithoutAutomaticReactivation() async {
        let (manager, gateway, _, _, id) = await make()
        await manager.receivedStartToken(Data(repeating: 0xAB, count: 32))
        await gateway.setSubscriptionErrors([.activityFull])
        await gateway.clearEvents()
        await manager.setLiveActivity(placeID: id, enabled: true)
        await manager.sync()
        let events = await gateway.events
        XCTAssertEqual(events.filter { $0 == "opt-in" }.count, 1)
        XCTAssertEqual(manager.settings(for: id)?.liveActivity, false)
        XCTAssertEqual(manager.settings(for: id)?.needsUpload, false)
        XCTAssertEqual(manager.liveActivityMessages[id], RainActivityText.full.text())
        XCTAssertNotEqual(RainActivityText.full.text(locale: "de"), RainActivityText.full.text(locale: "en"))
    }

    func testActivityTokenCapacityErrorAlsoDisablesOptIn() async throws {
        let (manager, gateway, activities, _, id) = await make()
        await manager.receivedStartToken(Data(repeating: 0xAB, count: 32))
        await manager.setLiveActivity(placeID: id, enabled: true)
        let sub = try XCTUnwrap(manager.settings(for: id)?.subscriptionID)
        await gateway.setError(.activityFull)
        await manager.receivedActivityToken(subscriptionID: sub, data: Data(repeating: 0xAB, count: 32))
        await manager.sync()
        let tokens = await gateway.putTokens
        XCTAssertTrue(tokens.isEmpty)
        XCTAssertEqual(manager.settings(for: id)?.liveActivity, false)
        XCTAssertEqual(manager.liveActivityMessages[id], RainActivityText.full.text())
        XCTAssertTrue(activities.ended.contains(sub))
    }

    func testTokenlessEndAndOptOutReleaseReservationImmediately() async throws {
        let (manager, gateway, _, _, id) = await make()
        await manager.setLiveActivity(placeID: id, enabled: true)
        let sub = try XCTUnwrap(manager.settings(for: id)?.subscriptionID)
        await manager.activityEnded(subscriptionID: sub, data: nil)
        await manager.setLiveActivity(placeID: id, enabled: false)
        let deletes = await gateway.reservationDeletes
        XCTAssertEqual(deletes, [sub, sub])
    }

    func testCapabilityAbsentNeverSendsLiveActivityFieldsOrTokens() async throws {
        let (manager, gateway, activities, _, id) = await make(supported: false)
        await manager.setLiveActivity(placeID: id, enabled: true)
        await manager.receivedStartToken(Data(repeating: 0xAB, count: 32))
        XCTAssertEqual(manager.settings(for: id)?.liveActivity, false)
        let tokens = await gateway.startTokens
        let requests = await gateway.base.lastRequests
        XCTAssertTrue(tokens.isEmpty)
        XCTAssertTrue(requests.allSatisfy { $0.liveActivity == nil })
        XCTAssertEqual(activities.fallbackStarts, 0)
    }

    func testRotationRetryAndOldEndDoNotDeleteNewToken() async throws {
        let (manager, gateway, activities, defaults, id) = await make()
        await manager.setLiveActivity(placeID: id, enabled: true)
        let sub = try XCTUnwrap(manager.settings(for: id)?.subscriptionID)
        let old = Data(repeating: 0xAB, count: 32), new = Data(repeating: 0xCD, count: 32)
        await manager.receivedStartToken(old)
        await manager.receivedStartToken(new)
        await gateway.setError(.offline)
        await manager.receivedActivityToken(subscriptionID: sub, data: old)
        await manager.sync()
        await manager.receivedActivityToken(subscriptionID: sub, data: new)
        await manager.activityEnded(subscriptionID: sub, data: old)
        await manager.activityEnded(subscriptionID: sub, data: nil)
        await manager.sync()
        let startTokens = await gateway.startTokens
        let putTokens = await gateway.putTokens
        let deleted = await gateway.deletedTokens
        XCTAssertEqual(startTokens.last!, PushActivityWire.hex(new))
        XCTAssertEqual(putTokens.last, PushActivityWire.hex(new))
        XCTAssertTrue(putTokens.contains(PushActivityWire.hex(old)), "offline upload retried")
        XCTAssertEqual(deleted.last, PushActivityWire.hex(old))
        XCTAssertFalse(deleted.contains(PushActivityWire.hex(new)), "unidentified late end cannot delete a replacement")
        let saved = String(data: try XCTUnwrap(defaults.data(forKey: PushManager.stateKey)), encoding: .utf8)!
        XCTAssertFalse(saved.contains(PushActivityWire.hex(old)))
        XCTAssertFalse(saved.contains(PushActivityWire.hex(new)))
        XCTAssertEqual(activities.fallbackStarts, 0, "token handling never starts a local activity")
    }

    func testOptOutEndsActivityDeletesTokenAndClearsStartToken() async throws {
        let (manager, gateway, activities, _, id) = await make()
        await manager.setLiveActivity(placeID: id, enabled: true)
        let sub = try XCTUnwrap(manager.settings(for: id)?.subscriptionID)
        let token = Data(repeating: 0xAB, count: 32)
        await manager.receivedStartToken(token)
        await manager.receivedActivityToken(subscriptionID: sub, data: token)
        await manager.setLiveActivity(placeID: id, enabled: false)
        XCTAssertTrue(activities.ended.contains(sub))
        XCTAssertEqual(manager.settings(for: id)?.liveActivity, false)
        let deleted = await gateway.deletedTokens, start = await gateway.startTokens
        XCTAssertTrue(deleted.contains(PushActivityWire.hex(token)))
        XCTAssertNil(start.last!)
    }

    func testOptOutWithoutCapabilityPersistsUntilSupportReturns() async throws {
        let (manager, gateway, activities, defaults, id) = await make()
        await manager.setLiveActivity(placeID: id, enabled: true)
        await gateway.setSupported(false)
        await manager.refreshLiveActivitySupport()
        await manager.setLiveActivity(placeID: id, enabled: false)
        let state = try JSONDecoder().decode(PushState.self, from: XCTUnwrap(defaults.data(forKey: PushManager.stateKey)))
        XCTAssertEqual(state.places[id]?.liveActivity, false)
        XCTAssertEqual(state.places[id]?.liveActivityDirty, true)
        XCTAssertEqual(state.places[id]?.needsUpload, true)
        XCTAssertFalse(activities.ended.isEmpty)
        await gateway.setSupported(true)
        await manager.start()
        XCTAssertEqual(manager.settings(for: id)?.needsUpload, false)
    }

    func testConflictEndsActivityAndKeepsOrdinarySubscription() async throws {
        for error in [PushGatewayError.activityLimit, .activityNotEligible] {
            let (manager, gateway, activities, _, id) = await make()
            await manager.setLiveActivity(placeID: id, enabled: true)
            let sub = try XCTUnwrap(manager.settings(for: id)?.subscriptionID)
            await gateway.setError(error)
            await manager.receivedActivityToken(subscriptionID: sub, data: Data(repeating: 0xAB, count: 32))
            XCTAssertTrue(activities.ended.contains(sub))
            XCTAssertNotNil(manager.messages[id])
            XCTAssertNotNil(manager.settings(for: id))
        }
    }

    func testPlaceRemovalAndResetEndLocalActivities() async throws {
        let (manager, _, activities, _, id) = await make()
        await manager.setLiveActivity(placeID: id, enabled: true)
        let sub = try XCTUnwrap(manager.settings(for: id)?.subscriptionID)
        await manager.disable(placeID: id)
        XCTAssertTrue(activities.ended.contains(sub))
        await manager.resetAll()
        XCTAssertTrue(activities.ended.contains(where: { $0 == nil }))
    }

    func testOlderSettingsDefaultToOptOut() throws {
        var settings = PlacePushSettings(cell: .init(x: 1, y: 1))
        settings.needsUpload = false
        var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(settings)) as! [String: Any]
        object["liveActivity"] = nil; object["liveActivityDirty"] = nil
        let restored = try JSONDecoder().decode(PlacePushSettings.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertFalse(restored.liveActivity)
        XCTAssertFalse(restored.liveActivityDirty)
        XCTAssertFalse(restored.needsUpload)
    }

    func testFallbackRequiresExplicitActionAndOptIn() async throws {
        let (manager, _, activities, _, id) = await make()
        let content = RainActivityAttributes.ContentState(phase: .raining, intensityClass: 2, referenceTime: Date())
        XCTAssertThrowsError(try manager.startLiveActivityFallback(placeID: id, displayName: "Test", content: content))
        await manager.receivedStartToken(Data(repeating: 0xAB, count: 32))
        await manager.setLiveActivity(placeID: id, enabled: true)
        XCTAssertEqual(activities.fallbackStarts, 0)
        try manager.startLiveActivityFallback(placeID: id, displayName: "Test", content: content)
        XCTAssertEqual(activities.fallbackStarts, 1)
    }

    func testLateTokenAfterOptOutIsDeletedAndNeverRegistered() async throws {
        let (manager, gateway, activities, _, id) = await make()
        await manager.setLiveActivity(placeID: id, enabled: true)
        let sub = try XCTUnwrap(manager.settings(for: id)?.subscriptionID)
        await manager.setLiveActivity(placeID: id, enabled: false)
        let token = Data(repeating: 0xAB, count: 32)
        await manager.receivedActivityToken(subscriptionID: sub, data: token)
        let registered = await gateway.putTokens, deleted = await gateway.deletedTokens
        XCTAssertTrue(registered.isEmpty)
        XCTAssertTrue(deleted.contains(PushActivityWire.hex(token)))
        XCTAssertTrue(activities.ended.contains(sub))
    }

    func testSystemDenialPreventsOptIn() async {
        let (manager, _, activities, _, id) = await make()
        activities.activitiesEnabled = false
        await manager.setLiveActivity(placeID: id, enabled: true)
        XCTAssertEqual(manager.settings(for: id)?.liveActivity, false)
    }
}
