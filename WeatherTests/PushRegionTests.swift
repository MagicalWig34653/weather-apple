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

    func testRegionRemovedDuringFirstUploadDeletesTheLateSubscription() async {
        let (manager, gateway, _) = make()
        await token(manager)
        // A remaining subscription keeps the installation alive, so only an explicit delete cleans up.
        let keep = await manager.addRegion(latitude: 48.14, longitude: 11.58, radiusKm: 10, sharePercent: 25, name: nil)
        XCTAssertNotNil(added(keep))
        gateway.duringCreate = { [manager] in
            gateway.duringCreate = nil
            if let id = await manager.regionsSorted.first(where: { $0.settings.name == "weg" })?.id { await manager.removeRegion(id: id) }
        }
        _ = await manager.addRegion(latitude: berlin.lat, longitude: berlin.lon, radiusKm: 10, sharePercent: 25, name: "weg")
        XCTAssertEqual(manager.regionCount, 1)
        XCTAssertEqual(gateway.createdIDs.count, 2)
        XCTAssertEqual(gateway.deletedIDs, [gateway.createdIDs[1]])
    }

    func testRegionChangedDuringUploadIsUploadedAgain() async throws {
        let (manager, gateway, _) = make()
        await token(manager)
        let r = await manager.addRegion(latitude: berlin.lat, longitude: berlin.lon, radiusKm: 10, sharePercent: 25, name: nil)
        let id = try XCTUnwrap(added(r))
        gateway.duringUpdate = { [manager] in
            gateway.duringUpdate = nil
            await manager.updateRegion(id: id, radiusKm: 25)
        }
        await manager.updateRegion(id: id, radiusKm: 5)
        let latitude = PushGrid.coordinate(of: try XCTUnwrap(manager.region(for: id)).center).latitude
        XCTAssertEqual(gateway.lastRequests.last?.region?.radiusCells, PushGrid.radiusCells(km: 25, latitude: latitude))
        XCTAssertEqual(manager.regionStatus(for: id), .active)
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

/// Wire format against the real backend API (`api.md`, `PushApi.swift`, `PushTests.swift` of commit 34e6416).
final class PushRegionWireTests: XCTestCase {
    private final class Recorder: @unchecked Sendable {
        private let lock = NSLock()
        var requests: [URLRequest] = []
        private var responses: [(Int, String)]
        init(_ responses: [(Int, String)]) { self.responses = responses }
        func next(_ request: URLRequest) -> (Data, HTTPURLResponse) {
            lock.withLock {
                requests.append(request)
                let (code, body) = responses.isEmpty ? (204, "") : responses.removeFirst()
                return (Data(body.utf8), HTTPURLResponse(url: request.url!, statusCode: code, httpVersion: nil, headerFields: nil)!)
            }
        }
    }

    private let identity = PushIdentity(installationID: "11111111-2222-3333-4444-555555555555", secret: String(repeating: "a", count: 43))

    private func gateway(_ recorder: Recorder) -> HTTPPushGateway {
        HTTPPushGateway(baseURL: URL(string: "https://example.test/v1/push/")!, transport: { recorder.next($0) }, sleep: { _ in })
    }

    func testCircleBodyHasExactlyTheBackendFields() throws {
        let request = PushSubscriptionRequest(cell: .init(x: 40, y: 50), threshold: 3, leadMinutes: 20, enabled: true,
                                              region: PushRegionSpec(radiusCells: 14, minSharePercent: 10))
        let body = HTTPPushGateway.body(request)
        XCTAssertEqual(Set(body.keys), ["grid_version", "cell_x", "cell_y", "threshold", "lead_minutes", "enabled", "time_sensitive",
                                        "kind", "radius_cells", "min_share_percent"])
        XCTAssertEqual(body["kind"] as? String, "circle")
        XCTAssertEqual(body["radius_cells"] as? Int, 14)
        XCTAssertEqual(body["min_share_percent"] as? Int, 10)
        // a point never carries region fields (the backend answers 400 invalid_subscription otherwise)
        let point = HTTPPushGateway.body(PushSubscriptionRequest(cell: .init(x: 40, y: 50), threshold: 3, leadMinutes: 20, enabled: true))
        XCTAssertNil(point["kind"]); XCTAssertNil(point["radius_cells"]); XCTAssertNil(point["min_share_percent"])
    }

    func testAllowedValuesMatchBackendRanges() {
        XCTAssertEqual(PushGrid.regionRadiusCellsRange, 3...40)
        XCTAssertEqual(PushGrid.regionSharePercents, [1, 10, 25])
        XCTAssertEqual(PushGrid.defaultRegionSharePercent, 10)
        XCTAssertEqual(PushGrid.maxRegions, 3)
        // api.md: x' = min(floor(x/3)*3+1, 1023), y' analogous (y max 1310)
        for (x, y) in [(0, 0), (41, 52), (1023, 1310), (1022, 1309)] {
            let c = PushGrid.coarseCenter(of: .init(x: x, y: y))
            XCTAssertEqual(c.x, min(x / 3 * 3 + 1, 1023)); XCTAssertEqual(c.y, min(y / 3 * 3 + 1, 1310))
        }
    }

    func testErrorCodesFromBackendBodies() {
        let cases: [(Int, String, PushGatewayError)] = [
            (409, "{\"error\":\"subscription_limit\"}", .subscriptionLimit),
            (409, "{\"error\":\"region_limit\"}", .regionLimit),
            (409, "{\"error\":\"region_capacity\"}", .regionCapacity),
            (409, "{\"error\":\"other\"}", .rejected(409)),
            (400, "{\"error\":\"invalid_subscription\"}", .rejected(400)),
            (400, "{\"error\":\"invalid_id\"}", .rejected(400)),
            (413, "{\"error\":\"too_large\"}", .rejected(413)),
            (401, "{\"error\":\"unauthorized\"}", .unauthorized),
            (404, "{\"error\":\"not_found\"}", .notFound),
            (429, "{\"error\":\"rate_limited\"}", .rateLimited),
            (503, "{\"error\":\"unavailable\"}", .server(503)),
        ]
        for (status, body, expected) in cases {
            XCTAssertEqual(HTTPPushGateway.error(statusCode: status, data: Data(body.utf8)), expected, body)
        }
    }

    func testRegionPostAndPutRoundTripWithBackendResponses() async throws {
        let recorder = Recorder([(201, "{\"id\":\"AAAAAAAA-2222-3333-4444-555555555555\"}"), (204, ""), (409, "{\"error\":\"region_limit\"}")])
        let gw = gateway(recorder)
        let request = PushSubscriptionRequest(cell: .init(x: 41, y: 52), threshold: 3, leadMinutes: 20, enabled: true,
                                              region: PushRegionSpec(radiusCells: 14, minSharePercent: 10))
        let id = try await gw.createSubscription(identity, request)
        XCTAssertEqual(id, "aaaaaaaa-2222-3333-4444-555555555555")
        try await gw.updateSubscription(identity, id: id, request)
        do { _ = try await gw.createSubscription(identity, request); XCTFail("expected region_limit") }
        catch { XCTAssertEqual(error as? PushGatewayError, .regionLimit) }
        let sent = try JSONSerialization.jsonObject(with: XCTUnwrap(recorder.requests[0].httpBody)) as! [String: Any]
        XCTAssertEqual(sent["kind"] as? String, "circle")
        XCTAssertEqual(sent["radius_cells"] as? Int, 14)
        XCTAssertEqual(recorder.requests.map(\.httpMethod), ["POST", "PUT", "POST"])
    }

    func testCapabilitiesFixturesFromStatusEndpoint() async throws {
        for (body, expected) in [("{\"schema\":1,\"push\":true,\"capabilities\":[\"regions\"],\"layers\":[]}", Set(["regions"])),
                                 ("{\"schema\":1,\"push\":false,\"capabilities\":[],\"layers\":[]}", Set<String>()),
                                 ("{\"schema\":1,\"layers\":[]}", Set<String>())] {
            let gw = gateway(Recorder([(200, body)]))
            let capabilities = try await gw.capabilities()
            XCTAssertEqual(capabilities, expected, body)
            XCTAssertEqual(capabilities.contains(PushRegionWire.capability), expected.contains("regions"))
        }
    }

    func testListFixtureIncludesKindAndRegionFields() throws {
        // GET .../subscriptions fixture as described in api.md; the app does not read the list, the fixture pins the field names.
        let json = "[{\"id\":\"a\",\"grid_version\":1,\"cell_x\":40,\"cell_y\":50,\"threshold\":3,\"lead_minutes\":20,\"enabled\":true,\"time_sensitive\":false,\"kind\":\"circle\",\"radius_cells\":14,\"min_share_percent\":10}]"
        let entry = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [[String: Any]]).first
        XCTAssertEqual(entry?[PushRegionWire.kindKey] as? String, PushRegionWire.kindCircle)
        XCTAssertEqual(entry?[PushRegionWire.radiusKey] as? Int, 14)
        XCTAssertEqual(entry?[PushRegionWire.shareKey] as? Int, 10)
    }

    /// The backend sends only `loc-key` + `loc-args` (minutes); the strings must exist in the app in de and en.
    func testPushLocKeysResolveInGermanAndEnglish() throws {
        let payload = "{\"aps\":{\"alert\":{\"loc-args\":[\"10\"],\"loc-key\":\"RAIN_REGION_STARTS_IN\"},\"sound\":\"default\",\"thread-id\":\"x\"},\"minutes\":10,\"region\":true,\"type\":\"rain-start\"}"
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(payload.utf8)) as? [String: Any])
        let alert = try XCTUnwrap((object["aps"] as? [String: Any])?["alert"] as? [String: Any])
        let args = try XCTUnwrap(alert["loc-args"] as? [String])
        let main = Bundle(for: PushManager.self)
        func text(_ key: String, _ language: String) throws -> String {
            let path = try XCTUnwrap(main.path(forResource: language, ofType: "lproj"), "\(language).lproj missing")
            let format = try XCTUnwrap(Bundle(path: path)).localizedString(forKey: key, value: "MISSING", table: nil)
            return String(format: format, arguments: args)
        }
        XCTAssertEqual(alert["loc-key"] as? String, "RAIN_REGION_STARTS_IN")
        XCTAssertEqual(try text("RAIN_REGION_STARTS_IN", "de"), "Regen erreicht deine Region in 10 min")
        XCTAssertEqual(try text("RAIN_REGION_STARTS_IN", "en"), "Rain reaches your area in 10 min")
        XCTAssertEqual(try text("RAIN_STARTS_IN", "de"), "Regen beginnt in 10 min")
        XCTAssertEqual(try text("RAIN_STARTS_IN", "en"), "Rain starts in 10 min")
    }
}
