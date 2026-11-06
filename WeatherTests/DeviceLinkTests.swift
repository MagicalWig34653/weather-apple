import XCTest
@testable import Weather

// MARK: Fixtures (copies of backend docs/fixtures/app, contract frozen 6.11.2026)

enum LinkFixture {
    static func data(_ name: String) -> Data {
        let url = Bundle(for: DeviceLinkGatewayTests.self).url(forResource: name, withExtension: "json", subdirectory: "Fixtures/deviceLink")
        return try! Data(contentsOf: url!)
    }
}

// MARK: HTTP gateway against fixtures

final class DeviceLinkGatewayTests: XCTestCase {
    private let identity = PushIdentity(installationID: "11111111-1111-1111-1111-111111111111", secret: "s3cret")

    private final class Recorder: @unchecked Sendable {
        let lock = NSLock(); var requests: [URLRequest] = []
    }

    private func gateway(_ status: Int, _ fixture: String?, headers: [String: String] = [:], recorder: Recorder = Recorder()) -> (HTTPPushGateway, Recorder) {
        let gateway = HTTPPushGateway(baseURL: URL(string: "https://example.test/v1/push/")!, transport: { request in
            recorder.lock.withLock { recorder.requests.append(request) }
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: headers)!
            return (fixture.map(LinkFixture.data) ?? Data(), response)
        }, sleep: { _ in })
        return (gateway, recorder)
    }

    func testRequestCodeSendsJWSAndSecretAndParsesCode() async throws {
        let (gateway, recorder) = gateway(201, "link-code.201")
        let code = try await gateway.requestCode(identity, appTransaction: "JWS-VALUE")
        XCTAssertEqual(code.code, "7KQ2-M9XD")
        XCTAssertEqual(code.expiresAt, DeviceLinkWire.date("2026-11-06T09:25:00Z"))
        let request = try XCTUnwrap(recorder.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/v1/push/installations/\(identity.installationID)/link-code")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Installation-Secret"), "s3cret")
        let body = try JSONSerialization.jsonObject(with: try XCTUnwrap(request.httpBody)) as? [String: String]
        XCTAssertEqual(body, ["app_transaction": "JWS-VALUE"])
    }

    func testRequestCodeErrorsFromFixtures() async {
        let cases: [(Int, String, [String: String], DeviceLinkError)] = [
            (400, "link-code.400-invalid_request", [:], .invalidRequest),
            (401, "link-code.401-unauthorized", [:], .unauthorized),
            (403, "link-code.403-not_testflight", [:], .notTestFlight),
            (404, "link.404-disabled", [:], .disabled),
            (409, "link-code.409-already_linked", [:], .alreadyLinked),
            (409, "link-code.409-link_full", [:], .linkFull),
            (413, "link-code.413-too_large", [:], .tooLarge),
            (429, "link-code.429-rate_limited", ["Retry-After": "30"], .rateLimited(retryAfter: 30)),
            (429, "link-code.429-link_code_rate_limited", [:], .rateLimited(retryAfter: nil)),
            (503, "link-code.401-unauthorized", [:], .server(503)),
        ]
        for (status, fixture, headers, expected) in cases {
            let (gateway, recorder) = gateway(status, fixture, headers: headers)
            do { _ = try await gateway.requestCode(identity, appTransaction: "x"); XCTFail("\(status)") }
            catch { XCTAssertEqual(error as? DeviceLinkError, expected, "\(status) \(fixture)") }
            XCTAssertEqual(recorder.requests.count, 1, "no retries for \(status)")
        }
    }

    func testStatusFixtures() async throws {
        let none = try await gateway(200, "link.none").0.status(identity)
        XCTAssertEqual(none, DeviceLinkStatus(state: .none, codeExpiresAt: nil, linkedAt: nil, expiresAt: nil))
        let open = try await gateway(200, "link.code_open").0.status(identity)
        XCTAssertEqual(open.state, .codeOpen)
        XCTAssertEqual(open.codeExpiresAt, DeviceLinkWire.date("2026-11-06T09:25:00Z"))
        let linked = try await gateway(200, "link.linked").0.status(identity)
        XCTAssertEqual(linked.state, .linked)
        XCTAssertNil(linked.expiresAt, "expires_at null means permanent")
        let ttl = try await gateway(200, "link.linked-with-ttl").0.status(identity)
        XCTAssertEqual(ttl.expiresAt, DeviceLinkWire.date("2026-12-06T09:18:30Z"))
    }

    func testStatusUnknownStateIsInvalid() async {
        let (gateway, _) = gateway(200, "link-code.201")
        do { _ = try await gateway.status(identity); XCTFail() } catch { XCTAssertEqual(error as? DeviceLinkError, .invalidResponse) }
    }

    func testUnlinkIs204AndDisabledIs404() async throws {
        let (ok, recorder) = gateway(204, nil)
        try await ok.unlink(identity)
        XCTAssertEqual(recorder.requests.first?.httpMethod, "DELETE")
        XCTAssertEqual(recorder.requests.first?.url?.path, "/v1/push/installations/\(identity.installationID)/link")
        do { try await gateway(404, "link.404-disabled").0.unlink(identity); XCTFail() }
        catch { XCTAssertEqual(error as? DeviceLinkError, .disabled) }
    }

    func testOfflineMapsToOffline() async {
        let gateway = HTTPPushGateway(baseURL: URL(string: "https://example.test/v1/push/")!,
                                      transport: { _ in throw URLError(.notConnectedToInternet) }, sleep: { _ in })
        do { _ = try await gateway.status(identity); XCTFail() } catch { XCTAssertEqual(error as? DeviceLinkError, .offline) }
    }
}

// MARK: Manager

final class FakeLinkGateway: DeviceLinkGateway, @unchecked Sendable {
    private let lock = NSLock()
    private var _calls: [String] = []
    var calls: [String] { lock.withLock { _calls } }
    var lastAttestation: String?
    var codeResult: Result<DeviceLinkCode, DeviceLinkError> = .success(DeviceLinkCode(code: "7KQ2-M9XD", expiresAt: Date(timeIntervalSince1970: 1_000_600)))
    var statuses: [Result<DeviceLinkStatus, DeviceLinkError>] = []
    var unlinkResult: Result<Void, DeviceLinkError> = .success(())

    func requestCode(_ identity: PushIdentity, appTransaction: String) async throws -> DeviceLinkCode {
        lock.withLock { _calls.append("code"); lastAttestation = appTransaction }
        return try codeResult.get()
    }
    func status(_ identity: PushIdentity) async throws -> DeviceLinkStatus {
        let next: Result<DeviceLinkStatus, DeviceLinkError> = lock.withLock {
            _calls.append("status")
            return statuses.count > 1 ? statuses.removeFirst() : (statuses.first ?? .success(.init(state: .none, codeExpiresAt: nil, linkedAt: nil, expiresAt: nil)))
        }
        return try next.get()
    }
    func unlink(_ identity: PushIdentity) async throws {
        lock.withLock { _calls.append("unlink") }
        try unlinkResult.get()
    }
}

@MainActor
final class DeviceLinkManagerTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_000_000)
    private var defaults: UserDefaults!
    private var gateway: FakeLinkGateway!
    private var secrets: FakeSecrets!

    override func setUp() {
        defaults = UserDefaults(suiteName: "devicelink.\(UUID().uuidString)")
        gateway = FakeLinkGateway()
        secrets = FakeSecrets()
        _ = secrets.save(PushIdentity(installationID: "11111111-1111-1111-1111-111111111111", secret: "s"))
    }

    private func manager(environment: String? = "Sandbox", verified: Bool = true, capabilities: Set<String> = ["regions", "device_link"],
                         capabilityError: Bool = false, now: Date? = nil) -> DeviceLinkManager {
        let detector = BuildChannelDetector(
            source: ClosureEvidenceSource {
                guard let environment else { throw URLError(.notConnectedToInternet) }
                return AppTransactionEvidence(isVerified: verified, environment: environment, jws: "JWS")
            }, isDebugBuild: false, hasSandboxReceipt: { true }, timeout: .milliseconds(300))
        let start = now ?? t0
        return DeviceLinkManager(detector: detector, gateway: gateway, secrets: secrets,
                                 capabilities: { if capabilityError { throw URLError(.timedOut) }; return capabilities },
                                 defaults: defaults, now: { start }, sleep: { _ in })
    }

    func testAppStoreShowsNothingAndMakesNoLinkCalls() async {
        let m = manager(environment: "Production")
        await m.refresh()
        XCTAssertEqual(m.phase, .hidden); XCTAssertFalse(m.isAvailable)
        await m.setEnabled(true)
        XCTAssertEqual(m.phase, .hidden)
        XCTAssertEqual(gateway.calls, [])
    }

    func testUnverifiedOfflineAndCapabilityMissingAreHidden() async {
        for m in [manager(verified: false), manager(environment: nil), manager(capabilities: ["regions"]), manager(capabilityError: true)] {
            await m.refresh()
            XCTAssertEqual(m.phase, .hidden)
        }
        XCTAssertEqual(gateway.calls, [])
    }

    func testTestFlightWithCapabilityOffersSwitchAndShowsCode() async {
        let m = manager()
        await m.refresh()
        XCTAssertEqual(m.phase, .off)
        await m.setEnabled(true)
        XCTAssertEqual(m.phase, .codeOpen(code: "7KQ2-M9XD", expiresAt: Date(timeIntervalSince1970: 1_000_600)))
        XCTAssertEqual(gateway.lastAttestation, "JWS")
        XCTAssertTrue(m.mayBeLinked)
    }

    func testExistingLinkShownAsLinkedOnRefresh() async {
        gateway.statuses = [.success(.init(state: .linked, codeExpiresAt: nil, linkedAt: t0, expiresAt: nil))]
        let m = manager()
        await m.refresh()
        XCTAssertEqual(m.phase, .linked(since: t0, expiresAt: nil))
    }

    func testSwitchToAppStoreDeletesExistingLinkOnce() async {
        defaults.set(true, forKey: DeviceLinkManager.markerKey)
        let m = manager(environment: "Production")
        await m.refresh()
        XCTAssertEqual(gateway.calls, ["unlink"])
        XCTAssertEqual(m.phase, .hidden)
        XCTAssertFalse(m.mayBeLinked)
        await m.refresh()
        XCTAssertEqual(gateway.calls, ["unlink"], "no further link calls after cleanup")
    }

    func testUnclearChannelDoesNotDeleteButStaysHidden() async {
        defaults.set(true, forKey: DeviceLinkManager.markerKey)
        let m = manager(environment: nil)
        await m.refresh()
        XCTAssertEqual(gateway.calls, [])
        XCTAssertEqual(m.phase, .hidden)
        XCTAssertTrue(m.mayBeLinked)
    }

    func testFailedCleanupKeepsMarkerForNextStart() async {
        defaults.set(true, forKey: DeviceLinkManager.markerKey)
        gateway.unlinkResult = .failure(.offline)
        let m = manager(environment: "Production")
        await m.refresh()
        XCTAssertTrue(m.mayBeLinked)
    }

    func testRequestErrors() async {
        let cases: [(DeviceLinkError, DeviceLinkPhase, DeviceLinkNotice?)] = [
            (.notTestFlight, .hidden, nil),
            (.disabled, .hidden, nil),
            (.linkFull, .off, .linkFull),
            (.rateLimited(retryAfter: 60), .off, .rateLimited(retryAfter: 60)),
            (.unauthorized, .off, .needsPush),
            (.offline, .off, .offline),
            (.server(500), .off, .failed),
            (.tooLarge, .off, .failed),
        ]
        for (error, phase, notice) in cases {
            gateway.codeResult = .failure(error)
            let m = manager()
            await m.refresh()
            await m.setEnabled(true)
            XCTAssertEqual(m.phase, phase, "\(error)")
            XCTAssertEqual(m.notice, notice, "\(error)")
        }
    }

    func testAlreadyLinkedLoadsStatus() async {
        gateway.codeResult = .failure(.alreadyLinked)
        let m = manager()
        await m.refresh()
        gateway.statuses = [.success(.init(state: .linked, codeExpiresAt: nil, linkedAt: t0, expiresAt: nil))]
        await m.setEnabled(true)
        XCTAssertEqual(m.phase, .linked(since: t0, expiresAt: nil))
    }

    func testWithoutInstallationNeedsPushAndMakesNoRequest() async {
        secrets.delete()
        let m = manager()
        await m.refresh()
        XCTAssertEqual(m.phase, .off)
        await m.setEnabled(true)
        XCTAssertEqual(m.notice, .needsPush)
        XCTAssertEqual(gateway.calls, [])
    }

    func testRevokeDeletesAndTurnsOff() async {
        gateway.statuses = [.success(.init(state: .linked, codeExpiresAt: nil, linkedAt: t0, expiresAt: nil))]
        defaults.set(true, forKey: DeviceLinkManager.markerKey)
        let m = manager()
        await m.refresh()
        await m.setEnabled(false)
        XCTAssertEqual(gateway.calls.last, "unlink")
        XCTAssertEqual(m.phase, .off)
        XCTAssertFalse(m.mayBeLinked)
    }

    func testRevokeFailureKeepsLinked() async {
        gateway.statuses = [.success(.init(state: .linked, codeExpiresAt: nil, linkedAt: t0, expiresAt: nil))]
        gateway.unlinkResult = .failure(.offline)
        let m = manager()
        await m.refresh()
        await m.setEnabled(false)
        XCTAssertEqual(m.phase, .linked(since: t0, expiresAt: nil))
        XCTAssertEqual(m.notice, .offline)
    }

    func testPollingTurnsCodeIntoLinked() async {
        let m = manager()
        await m.refresh()
        await m.setEnabled(true)
        gateway.statuses = [.success(.init(state: .codeOpen, codeExpiresAt: nil, linkedAt: nil, expiresAt: nil)),
                            .success(.init(state: .linked, codeExpiresAt: nil, linkedAt: t0, expiresAt: nil))]
        await m.runPolling()
        XCTAssertEqual(m.phase, .linked(since: t0, expiresAt: nil))
        XCTAssertEqual(gateway.calls.filter { $0 == "status" }.count, 3, "one refresh and two polls")
    }

    func testPollingStopsAtTenMinutes() async {
        gateway.statuses = [.success(.init(state: .codeOpen, codeExpiresAt: nil, linkedAt: nil, expiresAt: nil))]
        let m = manager()
        await m.refresh() // a code open on the server without a local code is not shown (a new code replaces it)
        XCTAssertEqual(m.phase, .off)
        gateway.codeResult = .success(DeviceLinkCode(code: "AAAA-BBBB", expiresAt: t0.addingTimeInterval(3600)))
        await m.setEnabled(true)
        await m.runPolling()
        XCTAssertEqual(m.phase, .off)
        XCTAssertEqual(m.notice, .codeExpired)
        XCTAssertEqual(gateway.calls.filter { $0 == "status" }.count, 1 + 200, "3 s steps for 10 minutes")
    }

    func testExpiredCodeResetsToOff() async {
        let m = manager()
        await m.refresh()
        await m.setEnabled(true)
        m.expireIfNeeded(now: Date(timeIntervalSince1970: 1_000_601))
        XCTAssertEqual(m.phase, .off)
        XCTAssertEqual(m.notice, .codeExpired)
    }
}
