import XCTest
@testable import Weather

@MainActor
final class WarnManagerTests: XCTestCase {
    private let identity = PushIdentity(installationID: "00000000-0000-0000-0000-000000000001", secret: "s")

    private final class FakeGateway: WarnGateway, @unchecked Sendable {
        var calls: [String] = []
        var created: [WarnSubscriptionSettings] = []
        var updated: [(String, WarnSubscriptionSettings)] = []
        var deleted: [String] = []
        var failCreate: WarnGatewayError?
        var failUpdate: WarnGatewayError?
        var counter = 0
        func create(_ identity: PushIdentity, _ settings: WarnSubscriptionSettings) async throws -> String {
            calls.append("create")
            if let failCreate { throw failCreate }
            counter += 1; created.append(settings)
            return String(format: "00000000-0000-0000-0000-%012d", counter)
        }
        func update(_ identity: PushIdentity, id: String, _ settings: WarnSubscriptionSettings) async throws {
            calls.append("update")
            if let failUpdate { throw failUpdate }
            updated.append((id, settings))
        }
        func delete(_ identity: PushIdentity, id: String) async throws { calls.append("delete"); deleted.append(id) }
        func list(_ identity: PushIdentity) async throws -> [(id: String, settings: WarnSubscriptionSettings)] { calls.append("list"); return [] }
    }

    private final class FakeHost: WarnInstallationHost {
        var identity: PushIdentity?
        var allow = true
        var prepared = 0, synced = 0
        func warningIdentity() -> PushIdentity? { identity }
        func prepareInstallationForWarnings() async -> Bool { prepared += 1; return allow }
        func syncInstallation() async { synced += 1 }
    }

    private struct Env {
        let manager: WarnManager; let gateway: FakeGateway; let host: FakeHost
        let defaults: UserDefaults; let names: UserDefaults
    }

    private func make(push: Bool = true, targets: [WarnTarget] = [], enabled: Bool = true) async throws -> Env {
        let suite = "warn-test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!, names = UserDefaults(suiteName: suite + ".names")!
        let gateway = FakeGateway(), host = FakeHost()
        host.identity = identity
        let geometry = try WarnGeometry.decode(try WarnGeometryTests.sampleData())
        let manager = WarnManager(gateway: gateway, host: host,
                                  capabilities: { push ? ["warnings", "warnings_push"] : ["warnings"] },
                                  matcher: { WarnCellMatcher(geometry: geometry) }, targets: { targets },
                                  defaults: defaults, nameDefaults: names)
        await manager.refreshCapabilities()
        if enabled { await manager.setEnabled(true) }
        return Env(manager: manager, gateway: gateway, host: host, defaults: defaults, names: names)
    }

    private func place(_ n: String, _ lat: Double, _ lon: Double) -> WarnTarget {
        WarnTarget(key: "place:\(n)", name: n, latitude: lat, longitude: lon, radiusKm: nil)
    }

    func testWithoutPushCapabilityNoGatewayCallAndNoFlag() async throws {
        let env = try await make(push: false, targets: [place("A", 51.5, 10.5)])
        XCTAssertFalse(env.manager.capabilityWarningsPush)
        XCTAssertTrue(env.manager.capabilityWarnings)
        await env.manager.reconcile()
        XCTAssertEqual(env.gateway.calls, [])
        XCTAssertEqual(env.host.prepared, 0)
    }

    func testOnePlaceOneSubscriptionWithOneCellAndDefaults() async throws {
        let env = try await make(targets: [place("Erfurt", 51.5, 10.5)])
        XCTAssertEqual(env.gateway.created.count, 1)
        let sub = try XCTUnwrap(env.gateway.created.first)
        XCTAssertEqual(sub.warncellIDs, ["100000001"])
        XCTAssertEqual(sub.minSeverity, [.severeWeather: 3, .frost: 1, .ice: 2])
        XCTAssertEqual(sub.types, Set(WarnKind.allCases))
        XCTAssertFalse(sub.timeSensitive)
    }

    func testPlacesInSameCellShareOneSubscriptionAndNamesStayLocal() async throws {
        let env = try await make(targets: [place("Home", 51.5, 10.5), place("Work", 51.6, 10.6)])
        XCTAssertEqual(env.gateway.created.count, 1)
        let id = "00000000-0000-0000-0000-000000000001"
        XCTAssertEqual(NotificationNameStore.name(for: id, in: env.names), "Home, Work")
    }

    func testRegionGetsAllIntersectingCells() async throws {
        let region = WarnTarget(key: "region:1", name: "R", latitude: 51.5, longitude: 11.0, radiusKm: 30)
        let env = try await make(targets: [region])
        XCTAssertEqual(env.gateway.created.first?.warncellIDs, ["100000001", "100000002"])
    }

    func testPlaceOutsideGermanyGetsNoSubscription() async throws {
        let env = try await make(targets: [place("Paris", 48.85, 2.35)])
        XCTAssertEqual(env.gateway.calls, [])
    }

    func testRemovedPlaceDeletesSubscriptionAndName() async throws {
        let env = try await make(targets: [place("A", 51.5, 10.5)])
        env.manager.targets = { [] }
        await env.manager.reconcile()
        XCTAssertEqual(env.gateway.deleted.count, 1)
        XCTAssertNil(NotificationNameStore.name(for: "00000000-0000-0000-0000-000000000001", in: env.names))
        XCTAssertEqual(env.manager.subscriptionCount, 0)
    }

    func testSettingChangeUpdatesAndUnchangedDoesNothing() async throws {
        let env = try await make(targets: [place("A", 51.5, 10.5)])
        await env.manager.reconcile()
        XCTAssertEqual(env.gateway.calls, ["create"])
        await env.manager.setMinSeverity(.frost, level: 2)
        await env.manager.setTimeSensitive(true)
        XCTAssertEqual(env.gateway.updated.count, 2)
        XCTAssertEqual(env.gateway.updated.last?.1.minSeverity[.frost], 2)
        XCTAssertEqual(env.gateway.updated.last?.1.timeSensitive, true)
        await env.manager.setType(.ice, on: false)
        XCTAssertEqual(env.gateway.updated.last?.1.types, [.severeWeather, .frost])
        XCTAssertNil(env.gateway.updated.last?.1.minSeverity[.ice])
    }

    func testLimitAndGeometryOutdatedStatesWithoutCrash() async throws {
        let env = try await make(enabled: false)
        env.manager.targets = { [self.place("A", 51.5, 10.5)] }
        env.gateway.failCreate = .limit
        await env.manager.setEnabled(true)
        XCTAssertEqual(env.manager.notice, .limitReached)
        env.gateway.failCreate = .cellUnknown
        await env.manager.reconcile()
        XCTAssertEqual(env.manager.notice, .geometryOutdated)
        XCTAssertEqual(WarnSettingsPresentation.noticeText(.geometryOutdated, bundle: try bundle("de")),
                       "Warngebiete veraltet, bitte App aktualisieren.")
        env.gateway.failCreate = nil
        await env.manager.reconcile()
        XCTAssertNil(env.manager.notice)
        XCTAssertEqual(env.manager.subscriptionCount, 1)
    }

    func testOfflineKeepsStateForRetry() async throws {
        let env = try await make(enabled: false)
        env.manager.targets = { [self.place("A", 51.5, 10.5)] }
        env.gateway.failCreate = .unavailable
        await env.manager.setEnabled(true)
        XCTAssertEqual(env.manager.notice, .offline)
        XCTAssertEqual(env.manager.subscriptionCount, 0)
    }

    func testUpdateNotFoundRecreates() async throws {
        let env = try await make(targets: [place("A", 51.5, 10.5)])
        env.gateway.failUpdate = .notFound
        await env.manager.setTimeSensitive(true)
        XCTAssertEqual(env.gateway.created.count, 2)
    }

    func testDisableDeletesSubscriptionsAndSyncsInstallation() async throws {
        let env = try await make(targets: [place("A", 51.5, 10.5)])
        await env.manager.setEnabled(false)
        XCTAssertEqual(env.gateway.deleted.count, 1)
        XCTAssertEqual(env.host.synced, 1)
        XCTAssertFalse(env.manager.isActive)
    }

    func testDeniedPermissionKeepsSwitchOff() async throws {
        let env = try await make(enabled: false)
        env.host.allow = false
        await env.manager.setEnabled(true)
        XCTAssertFalse(env.manager.settings.enabled)
        XCTAssertEqual(env.manager.notice, .notificationsDenied)
    }

    func testNoIdentityNoCallsUntilInstallationReady() async throws {
        let env = try await make(targets: [place("A", 51.5, 10.5)], enabled: false)
        env.host.identity = nil
        await env.manager.setEnabled(true)
        XCTAssertEqual(env.gateway.calls, [])
        env.host.identity = identity
        await env.manager.reconcile()
        XCTAssertEqual(env.gateway.calls, ["create"])
    }

    func testSettingsPersist() async throws {
        let env = try await make(targets: [])
        await env.manager.setMinSeverity(.ice, level: 4)
        let again = WarnManager(gateway: env.gateway, host: env.host, capabilities: { [] }, matcher: { nil }, defaults: env.defaults)
        XCTAssertEqual(again.settings.level(for: .ice), 4)
        XCTAssertTrue(again.settings.enabled)
    }

    func testWarnNamesDoNotOverwriteRainNames() {
        let defaults = UserDefaults(suiteName: "warn-names-\(UUID().uuidString)")!
        NotificationNameStore.write(["rain-sub": "Regenort"], to: defaults)
        NotificationNameStore.writeWarn(["warn-sub": "Warnort"], to: defaults)
        NotificationNameStore.write(["rain-sub": "Neu"], to: defaults)
        XCTAssertEqual(NotificationNameStore.name(for: "warn-sub", in: defaults), "Warnort")
        XCTAssertEqual(NotificationNameStore.name(for: "rain-sub", in: defaults), "Neu")
    }

    private func bundle(_ lang: String) throws -> Bundle {
        let path = try XCTUnwrap(Bundle.main.path(forResource: lang, ofType: "lproj"))
        return try XCTUnwrap(Bundle(path: path))
    }
}
