import XCTest
@testable import Weather

final class PushRegionGridTests: XCTestCase {
    func testCoarseCenterIsMiddleOfThreeByThreeBlock() {
        XCTAssertEqual(PushGrid.coarseCenter(of: .init(x: 783, y: 395)), .init(x: 784, y: 394))
        XCTAssertEqual(PushGrid.coarseCenter(of: .init(x: 0, y: 0)), .init(x: 1, y: 1))
        XCTAssertEqual(PushGrid.coarseCenter(of: .init(x: 785, y: 397)), .init(x: 784, y: 397))
        // all cells of a block map to the same center; edges stay inside the image
        XCTAssertEqual(Set((300...302).flatMap { x in (30...32).map { y in PushGrid.coarseCenter(of: .init(x: x, y: y)) } }).count, 1)
        let corner = PushGrid.coarseCenter(of: .init(x: 1023, y: 1310))
        XCTAssertTrue(corner.x <= 1023 && corner.y <= 1310)
    }

    func testRadiusCellsForPresetsMatchResearchAtGermanLatitudes() {
        // research draft: 5/10/25 km are about 7/14/36 cells at 51 N
        XCTAssertEqual(PushGrid.radiusCells(km: 5, latitude: 51), 7)
        XCTAssertEqual(PushGrid.radiusCells(km: 10, latitude: 51), 14)
        XCTAssertEqual(PushGrid.radiusCells(km: 25, latitude: 51), 36)
        // further north cells are shorter on the ground: more cells
        XCTAssertGreaterThan(PushGrid.radiusCells(km: 10, latitude: 54.5), PushGrid.radiusCells(km: 10, latitude: 47.5))
        for km in PushGrid.regionRadiusPresetsKm {
            for latitude in [47.0, 51.0, 55.0] {
                XCTAssertTrue(PushGrid.regionRadiusCellsRange.contains(PushGrid.radiusCells(km: km, latitude: latitude)))
            }
        }
        XCTAssertEqual(PushGrid.radiusCells(km: 1, latitude: 51), 3, "clamped to the backend minimum")
        XCTAssertEqual(PushGrid.radiusCells(km: 100, latitude: 51), 40, "clamped to the backend maximum")
    }

    func testCellCoordinateRoundTripStaysInsideTheSameCell() throws {
        let cell = try XCTUnwrap(PushGrid.cell(latitude: 52.52, longitude: 13.405))
        let back = PushGrid.coordinate(of: cell)
        XCTAssertEqual(PushGrid.cell(latitude: back.latitude, longitude: back.longitude), cell)
        XCTAssertEqual(back.latitude, 52.52, accuracy: 0.02)
        XCTAssertEqual(back.longitude, 13.405, accuracy: 0.02)
    }
}

@MainActor
final class PushRegionManagerTests: XCTestCase {
    private var defaults: UserDefaults!
    private let berlin = (lat: 52.52, lon: 13.405)

    override func setUp() { defaults = UserDefaults(suiteName: "push-region-tests-\(UUID().uuidString)") }

    private func make(regions: Bool = true, auth: PushAuthorization = .authorized)
        -> (PushManager, FakeGateway, FakeSecrets) {
        let gateway = FakeGateway()
        if regions { gateway.capabilitySet = ["regions"] }
        let secrets = FakeSecrets()
        let manager = PushManager(gateway: gateway, secrets: secrets, authorizer: FakeAuthorizer(auth), registrar: FakeRegistrar(),
                                  defaults: defaults, environment: .sandbox, locale: "de")
        return (manager, gateway, secrets)
    }

    private func token(_ manager: PushManager) async { await manager.didRegister(deviceToken: Data([1, 2, 3, 4])) }

    private func added(_ result: PushManager.RegionAddResult) -> UUID? {
        if case .added(let id) = result { return id }
        return nil
    }

    func testAddRegionSendsCoarseCenterRadiusAndShare() async throws {
        let (manager, gateway, _) = make()
        await token(manager)
        let r_id = await manager.addRegion(latitude: berlin.lat, longitude: berlin.lon, radiusKm: 10, sharePercent: 25, name: "  Garten ")
        let id = try XCTUnwrap(added(r_id))
        XCTAssertEqual(gateway.calls, ["capabilities", "putInstallation", "createSubscription"])
        let request = try XCTUnwrap(gateway.lastRequests.last)
        let fine = try XCTUnwrap(PushGrid.cell(latitude: berlin.lat, longitude: berlin.lon))
        XCTAssertEqual(request.cell, PushGrid.coarseCenter(of: fine))
        XCTAssertEqual(request.region, PushRegionSpec(radiusCells: PushGrid.radiusCells(km: 10, latitude: berlin.lat), minSharePercent: 25))
        XCTAssertEqual(manager.region(for: id)?.name, "Garten")
        XCTAssertEqual(manager.regionStatus(for: id), .active)
        XCTAssertEqual(manager.enabledCount, 1)
    }

    func testNoCapabilityMeansNoRegionRequestAndNoCoordinateState() async {
        let (manager, gateway, _) = make(regions: false)
        await token(manager)
        let result = await manager.addRegion(latitude: berlin.lat, longitude: berlin.lon, radiusKm: 5, sharePercent: 10, name: nil)
        XCTAssertEqual(result, .failed("Der Server unterstützt noch keine Regionen."))
        XCTAssertEqual(manager.regionSupport, .unsupported)
        XCTAssertEqual(manager.regionCount, 0)
        XCTAssertFalse(gateway.calls.contains("createSubscription"))
        XCTAssertFalse(gateway.calls.contains("putInstallation"))
    }

    func testUnknownCapabilityDoesNotUploadAndRecoversLater() async throws {
        let (manager, gateway, _) = make()
        gateway.fail("capabilities", with: .offline)
        let first = await manager.addRegion(latitude: berlin.lat, longitude: berlin.lon, radiusKm: 5, sharePercent: 10, name: nil)
        guard case .failed = first else { return XCTFail() }
        XCTAssertEqual(manager.regionSupport, .unknown)
        XCTAssertEqual(manager.regionCount, 0)
        await manager.refreshRegionSupport()
        XCTAssertEqual(manager.regionSupport, .supported)
    }

    func testExistingRegionIsNotUploadedWhenServerLosesTheCapability() async throws {
        let (manager, gateway, _) = make()
        await token(manager)
        let r_id = await manager.addRegion(latitude: berlin.lat, longitude: berlin.lon, radiusKm: 5, sharePercent: 10, name: nil)
        let id = try XCTUnwrap(added(r_id))
        gateway.capabilitySet = []
        await manager.start()   // app start re-checks the capability while regions exist
        XCTAssertEqual(manager.regionSupport, .unsupported)
        await manager.updateRegion(id: id, radiusKm: 25)
        XCTAssertEqual(gateway.calls.filter { $0 == "updateSubscription" }.count, 0)
        XCTAssertEqual(manager.messages[id], "Der Server unterstützt noch keine Regionen.")
        XCTAssertEqual(manager.regionStatus(for: id), .pending)
    }

    func testAtMostThreeRegionsAndTenSubscriptionsTotal() async throws {
        let (manager, _, _) = make()
        await token(manager)
        for _ in 0..<3 {
            let r = await manager.addRegion(latitude: berlin.lat, longitude: berlin.lon, radiusKm: 5, sharePercent: 10, name: nil)
        XCTAssertNotNil(added(r))
        }
        XCTAssertFalse(manager.canAddRegion)
        let fourth = await manager.addRegion(latitude: berlin.lat, longitude: berlin.lon, radiusKm: 5, sharePercent: 10, name: nil)
        XCTAssertEqual(fourth, .failed("Höchstens 3 Regionen sind möglich."))
        XCTAssertEqual(manager.regionCount, 3)

        // places and regions share the limit of 10
        defaults = UserDefaults(suiteName: "push-region-tests-\(UUID().uuidString)")
        let (mixed, _, _) = make()
        await token(mixed)
        for _ in 0..<8 { _ = await mixed.enable(placeID: UUID(), latitude: berlin.lat, longitude: berlin.lon) }
        let r1 = await mixed.addRegion(latitude: berlin.lat, longitude: berlin.lon, radiusKm: 5, sharePercent: 10, name: nil)
        XCTAssertNotNil(added(r1), "\(r1)")
        let r2 = await mixed.addRegion(latitude: berlin.lat, longitude: berlin.lon, radiusKm: 5, sharePercent: 10, name: nil)
        XCTAssertNotNil(added(r2))
        XCTAssertFalse(mixed.canAddRegion)
        let eleventh = await mixed.addRegion(latitude: berlin.lat, longitude: berlin.lon, radiusKm: 5, sharePercent: 10, name: nil)
        guard case .failed = eleventh else { return XCTFail() }
    }

    func testRegionCapacityErrorIsExplainedAndRegionIsNotKept() async {
        let (manager, gateway, _) = make()
        await token(manager)
        gateway.fail("createSubscription", with: .regionCapacity)
        let result = await manager.addRegion(latitude: berlin.lat, longitude: berlin.lon, radiusKm: 25, sharePercent: 10, name: nil)
        XCTAssertEqual(result, .failed(PushManager.regionCapacityMessage))
        XCTAssertEqual(manager.regionCount, 0)
        XCTAssertEqual(manager.regionNotice, PushManager.regionCapacityMessage)
    }

    func testOutsideRadarAreaAndDeniedPermissionAreRejected() async {
        let (manager, gateway, _) = make()
        let outside = await manager.addRegion(latitude: 40, longitude: 0, radiusKm: 5, sharePercent: 10, name: nil)
        XCTAssertEqual(outside, .failed("Dieser Mittelpunkt liegt außerhalb des Radargebiets."))
        let (denied, _, _) = make(auth: .denied)
        let result = await denied.addRegion(latitude: berlin.lat, longitude: berlin.lon, radiusKm: 5, sharePercent: 10, name: nil)
        guard case .failed = result else { return XCTFail() }
        XCTAssertEqual(denied.regionCount, 0)
        XCTAssertFalse(gateway.calls.contains("createSubscription"))
    }

    func testUpdateRenameIsLocalOnlyAndOtherChangesPut() async throws {
        let (manager, gateway, _) = make()
        await token(manager)
        let r_id = await manager.addRegion(latitude: berlin.lat, longitude: berlin.lon, radiusKm: 5, sharePercent: 10, name: nil)
        let id = try XCTUnwrap(added(r_id))
        await manager.updateRegion(id: id, name: "Neu")
        XCTAssertEqual(gateway.calls.filter { $0 == "updateSubscription" }.count, 0, "name never goes to the server")
        XCTAssertEqual(manager.region(for: id)?.name, "Neu")
        await manager.updateRegion(id: id, radiusKm: 25, sharePercent: 1, leadMinutes: 30, timeSensitive: true)
        let request = try XCTUnwrap(gateway.lastRequests.last)
        XCTAssertEqual(request.region?.minSharePercent, 1)
        XCTAssertEqual(Double(request.region?.radiusCells ?? 0), Double(PushGrid.radiusCells(km: 25, latitude: berlin.lat)), accuracy: 2)
        XCTAssertEqual(request.leadMinutes, 30)
        XCTAssertTrue(request.timeSensitive)
        await manager.updateRegion(id: id, radiusKm: 7)
        XCTAssertEqual(manager.region(for: id)?.radiusKm, 25, "only presets are accepted")
    }

    func testDeleteRegionDeletesSubscriptionAndLastOneTheInstallation() async throws {
        let (manager, gateway, secrets) = make()
        await token(manager)
        let r_id = await manager.addRegion(latitude: berlin.lat, longitude: berlin.lon, radiusKm: 5, sharePercent: 10, name: nil)
        let id = try XCTUnwrap(added(r_id))
        await manager.removeRegion(id: id)
        XCTAssertEqual(gateway.calls.last, "deleteInstallation", "the last opt-out removes the installation (cascade)")
        XCTAssertNil(secrets.load())
        XCTAssertEqual(manager.regionCount, 0)

        // with another region left only the subscription is deleted
        defaults = UserDefaults(suiteName: "push-region-tests-\(UUID().uuidString)")
        let (two, gateway2, secrets2) = make()
        await token(two)
        let first = await two.addRegion(latitude: berlin.lat, longitude: berlin.lon, radiusKm: 5, sharePercent: 10, name: nil)
        let second = await two.addRegion(latitude: berlin.lat, longitude: berlin.lon, radiusKm: 10, sharePercent: 10, name: nil)
        await two.removeRegion(id: try XCTUnwrap(added(first)))
        XCTAssertEqual(gateway2.calls.last, "deleteSubscription")
        XCTAssertNotNil(secrets2.load())
        XCTAssertNotNil(two.region(for: try XCTUnwrap(added(second))))
        XCTAssertEqual(two.regionCount, 1)
    }

    func testResetAllRemovesRegionsToo() async throws {
        let (manager, gateway, secrets) = make()
        await token(manager)
        _ = await manager.enable(placeID: UUID(), latitude: berlin.lat, longitude: berlin.lon)
        _ = await manager.addRegion(latitude: berlin.lat, longitude: berlin.lon, radiusKm: 5, sharePercent: 10, name: nil)
        await manager.resetAll()
        XCTAssertEqual(manager.enabledCount, 0)
        XCTAssertTrue(gateway.calls.contains("deleteInstallation"))
        XCTAssertNil(secrets.load())
    }

    func testRegionsPersistWithoutCoordinatesAndSurviveRestart() async throws {
        let (manager, _, _) = make()
        await token(manager)
        let r_id = await manager.addRegion(latitude: berlin.lat, longitude: berlin.lon, radiusKm: 10, sharePercent: 10, name: "Heim")
        let id = try XCTUnwrap(added(r_id))
        let raw = try XCTUnwrap(defaults.data(forKey: PushManager.stateKey))
        let text = String(decoding: raw, as: UTF8.self)
        XCTAssertFalse(text.contains("52.5"), "no coordinates in persisted state")
        XCTAssertFalse(text.contains("13.4"))
        let (restarted, _, _) = (PushManager(gateway: FakeGateway(), secrets: FakeSecrets(), authorizer: FakeAuthorizer(.authorized),
                                             registrar: FakeRegistrar(), defaults: defaults, environment: .sandbox, locale: "de"), 0, 0)
        XCTAssertEqual(restarted.region(for: id)?.name, "Heim")
        XCTAssertEqual(restarted.region(for: id)?.radiusKm, 10)
    }

    func testStateFromBeforeRegionsMigratesAndKeepsPlaceSubscriptions() throws {
        struct Legacy: Codable {
            var places: [UUID: PlacePushSettings]
            var pendingSubscriptionDeletes: [String]
            var pendingInstallationDelete: Bool
        }
        let place = UUID()
        let legacy = Legacy(places: [place: PlacePushSettings(cell: .init(x: 5, y: 6), sensitivity: .light, subscriptionID: "abc", needsUpload: false)],
                            pendingSubscriptionDeletes: ["x"], pendingInstallationDelete: false)
        let data = try JSONEncoder().encode(legacy)
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("regions"))
        defaults.set(data, forKey: PushManager.stateKey)
        let manager = PushManager(gateway: FakeGateway(), secrets: FakeSecrets(), authorizer: FakeAuthorizer(.authorized),
                                  registrar: FakeRegistrar(), defaults: defaults, environment: .sandbox, locale: "de")
        XCTAssertEqual(manager.state.regions, [:])
        XCTAssertEqual(manager.settings(for: place)?.subscriptionID, "abc")
        XCTAssertEqual(manager.settings(for: place)?.sensitivity, .light)
        XCTAssertEqual(manager.state.pendingSubscriptionDeletes, ["x"])
        XCTAssertEqual(manager.status(for: place), .active)
        XCTAssertEqual(manager.regionCount, 0)
    }
}
