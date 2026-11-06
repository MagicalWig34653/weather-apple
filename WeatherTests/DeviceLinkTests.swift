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

    func testRequestCodeSendsEmptyBodyAndSecretAndParsesCode() async throws {
        let (gateway, recorder) = gateway(201, "link-code.201")
        let code = try await gateway.requestCode(identity)
        XCTAssertEqual(code.code, "7KQ2-M9XD")
        XCTAssertEqual(code.expiresAt, DeviceLinkWire.date("2026-11-06T09:25:00Z"))
        let request = try XCTUnwrap(recorder.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/v1/push/installations/\(identity.installationID)/link-code")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Installation-Secret"), "s3cret")
        XCTAssertEqual(String(data: try XCTUnwrap(request.httpBody), encoding: .utf8), "{}")
        XCTAssertEqual(LinkFixture.data("link-code.request"), Data("{}\n".utf8))
    }

    func testRequestCodeErrorsFromFixtures() async {
        let cases: [(Int, String, [String: String], DeviceLinkError)] = [
            (400, "link-code.400-invalid_request", [:], .invalidRequest),
            (401, "link-code.401-unauthorized", [:], .unauthorized),
            (403, "link-code.403-pairing_closed", [:], .pairingClosed),
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
            do { _ = try await gateway.requestCode(identity); XCTFail("\(status)") }
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

    func testServerStatusParsesWindowAndCapabilities() async throws {
        let open = try await gateway(200, "status.device_link_window").0.serverStatus()
        XCTAssertTrue(open.capabilities.contains("device_link"))
        XCTAssertEqual(open.deviceLinkWindowEndsAt, DeviceLinkWire.date("2026-11-06T09:20:00Z"))
        let none = try await gateway(200, "status.device_link").0.serverStatus()
        XCTAssertNil(none.deviceLinkWindowEndsAt, "no device_link_window field = no window")
        let null = HTTPPushGateway(baseURL: URL(string: "https://example.test/v1/push/")!, transport: { request in
            (Data(#"{"capabilities":["device_link"],"device_link_window":null}"#.utf8),
             HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }, sleep: { _ in })
        let status = try await null.serverStatus()
        XCTAssertNil(status.deviceLinkWindowEndsAt)
        XCTAssertEqual(status.capabilities, ["device_link"])
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
    var codeResult: Result<DeviceLinkCode, DeviceLinkError> = .success(DeviceLinkCode(code: "7KQ2-M9XD", expiresAt: Date(timeIntervalSince1970: 1_000_600)))
    var statuses: [Result<DeviceLinkStatus, DeviceLinkError>] = []
    var unlinkResult: Result<Void, DeviceLinkError> = .success(())

    func requestCode(_ identity: PushIdentity) async throws -> DeviceLinkCode {
        lock.withLock { _calls.append("code") }
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

/// Mutable server and clock for the manager tests.
final class FakeServer: @unchecked Sendable {
    private let lock = NSLock()
    private var _status: Result<PushServerStatus, URLError> = .success(.init(capabilities: ["regions", "device_link"], deviceLinkWindowEndsAt: nil))
    private var _now = Date(timeIntervalSince1970: 1_000_000)
    private var _requests = 0
    var status: Result<PushServerStatus, URLError> { get { lock.withLock { _status } } set { lock.withLock { _status = newValue } } }
    var now: Date { get { lock.withLock { _now } } set { lock.withLock { _now = newValue } } }
    var requests: Int { lock.withLock { _requests } }
    func fetch() throws -> PushServerStatus { lock.withLock { _requests += 1 }; return try status.get() }
    func window(endsIn seconds: TimeInterval?, capabilities: Set<String> = ["regions", "device_link"]) {
        status = .success(.init(capabilities: capabilities, deviceLinkWindowEndsAt: seconds.map { now.addingTimeInterval($0) }))
    }
}

@MainActor
final class DeviceLinkManagerTests: XCTestCase {
    private var gateway: FakeLinkGateway!
    private var secrets: FakeSecrets!
    private var server: FakeServer!

    override func setUp() {
        gateway = FakeLinkGateway()
        secrets = FakeSecrets()
        server = FakeServer()
        _ = secrets.save(PushIdentity(installationID: "11111111-1111-1111-1111-111111111111", secret: "s"))
    }

    private func manager(sleepStep: TimeInterval = 0) -> DeviceLinkManager {
        let server = self.server!
        return DeviceLinkManager(gateway: gateway, secrets: secrets, serverStatus: { try server.fetch() },
                                 now: { server.now }, sleep: { _ in server.now = server.now.addingTimeInterval(sleepStep) })
    }

    private func linked() -> Result<DeviceLinkStatus, DeviceLinkError> {
        .success(.init(state: .linked, codeExpiresAt: nil, linkedAt: server.now, expiresAt: nil))
    }

    // Visibility rule

    func testNoWindowAndNotLinkedIsHidden() async {
        let m = manager()
        await m.refresh()
        XCTAssertEqual(m.phase, .hidden); XCTAssertFalse(m.isAvailable)
        XCTAssertEqual(gateway.calls, ["status"], "only the link status is read; never a code")
    }

    func testOpenWindowOffersSwitch() async {
        server.window(endsIn: 300)
        let m = manager()
        await m.refresh()
        XCTAssertEqual(m.phase, .off)
        XCTAssertEqual(m.windowEndsAt, server.now.addingTimeInterval(300))
    }

    func testExpiredWindowIsHidden() async {
        server.window(endsIn: -1)
        let m = manager()
        await m.refresh()
        XCTAssertEqual(m.phase, .hidden)
    }

    func testLinkedDeviceIsShownWithoutWindow() async {
        gateway.statuses = [linked()]
        let m = manager()
        await m.refresh()
        XCTAssertEqual(m.phase, .linked(since: server.now, expiresAt: nil))
    }

    func testServerFeatureOffIsHiddenEvenWithWindowOrLink() async {
        server.window(endsIn: 300, capabilities: ["regions"])
        gateway.statuses = [linked()]
        let m = manager()
        await m.refresh()
        XCTAssertEqual(m.phase, .hidden)
        XCTAssertEqual(gateway.calls, [])
    }

    func testOfflineKeepsHiddenAndKeepsLastKnown() async {
        server.status = .failure(URLError(.notConnectedToInternet))
        let m = manager()
        await m.refresh()
        XCTAssertEqual(m.phase, .hidden, "fail closed")
        server.window(endsIn: 300)
        await m.refresh()
        XCTAssertEqual(m.phase, .off)
        server.status = .failure(URLError(.timedOut))
        await m.refresh()
        XCTAssertEqual(m.phase, .off, "an error does not undo the last known state")
    }

    func testWindowCannotOutliveItsEndWhileOffline() async {
        server.window(endsIn: 60)
        let m = manager()
        await m.refresh()
        server.status = .failure(URLError(.notConnectedToInternet))
        server.now = server.now.addingTimeInterval(61)
        await m.refresh()
        XCTAssertEqual(m.phase, .hidden)
    }

    func testWithoutInstallationNoLinkCallAndNeedsPush() async {
        secrets.delete()
        server.window(endsIn: 300)
        let m = manager()
        await m.refresh()
        XCTAssertEqual(m.phase, .off)
        await m.setEnabled(true)
        XCTAssertEqual(m.notice, .needsPush)
        XCTAssertEqual(gateway.calls, [])
    }

    func testConcurrentRefreshesShareOneRequest() async {
        server.window(endsIn: 300)
        let m = manager()
        async let a: Void = m.refresh()
        async let b: Void = m.refresh()
        _ = await (a, b)
        XCTAssertEqual(server.requests, 1)
    }

    // Window polling

    func testWindowPollingAsksEvery15sUntilEnd() async {
        server.window(endsIn: 60)
        let m = manager(sleepStep: 15)
        await m.refresh()
        let before = server.requests
        await m.runWindowPolling()
        XCTAssertEqual(server.requests - before, 4, "15, 30, 45, 60 s")
        XCTAssertEqual(m.phase, .hidden, "window over")
    }

    func testNoPollingWithoutWindow() async {
        let m = manager(sleepStep: 15)
        await m.refresh()
        let before = server.requests
        await m.runWindowPolling()
        XCTAssertEqual(server.requests, before)
    }

    func testPollingEndsWhenServerClosesWindowEarly() async {
        server.window(endsIn: 600)
        let m = manager(sleepStep: 15)
        await m.refresh()
        server.window(endsIn: nil)
        await m.runWindowPolling()
        XCTAssertEqual(m.phase, .hidden)
        XCTAssertEqual(server.requests, 2)
    }

    // Switch

    func testSwitchOnShowsCode() async {
        server.window(endsIn: 300)
        let m = manager()
        await m.refresh()
        await m.setEnabled(true)
        XCTAssertEqual(m.phase, .codeOpen(code: "7KQ2-M9XD", expiresAt: Date(timeIntervalSince1970: 1_000_600)))
        XCTAssertEqual(gateway.calls.last, "code")
    }

    func testCodeStaysAfterWindowEndsAndNoNewCodeIsOffered() async {
        server.window(endsIn: 300)
        let m = manager()
        await m.refresh()
        await m.setEnabled(true)
        server.window(endsIn: nil)
        await m.refresh()
        XCTAssertEqual(m.phase, .codeOpen(code: "7KQ2-M9XD", expiresAt: Date(timeIntervalSince1970: 1_000_600)))
        m.expireIfNeeded(now: Date(timeIntervalSince1970: 1_000_601))
        XCTAssertEqual(m.phase, .hidden, "after the code expired and without a window there is nothing to offer")
    }

    func testRequestErrors() async {
        let cases: [(DeviceLinkError, DeviceLinkPhase, DeviceLinkNotice?)] = [
            (.pairingClosed, .off, .pairingClosed),
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
            server.window(endsIn: 300)
            let m = manager()
            await m.refresh()
            await m.setEnabled(true)
            XCTAssertEqual(m.phase, phase, "\(error)")
            XCTAssertEqual(m.notice, notice, "\(error)")
        }
    }

    func testPairingClosedEndsWindowLocally() async {
        gateway.codeResult = .failure(.pairingClosed)
        server.window(endsIn: 300)
        let m = manager()
        await m.refresh()
        await m.setEnabled(true)
        XCTAssertNil(m.windowEndsAt)
        server.window(endsIn: nil)
        await m.refresh()
        XCTAssertEqual(m.phase, .hidden)
    }

    func testAlreadyLinkedLoadsStatus() async {
        gateway.codeResult = .failure(.alreadyLinked)
        server.window(endsIn: 300)
        let m = manager()
        await m.refresh()
        gateway.statuses = [linked()]
        await m.setEnabled(true)
        XCTAssertEqual(m.phase, .linked(since: server.now, expiresAt: nil))
    }

    func testRevokeDeletesAndHidesWithoutWindow() async {
        gateway.statuses = [linked()]
        let m = manager()
        await m.refresh()
        await m.setEnabled(false)
        XCTAssertEqual(gateway.calls.last, "unlink")
        XCTAssertEqual(m.phase, .hidden)
    }

    func testRevokeWithOpenWindowGoesToOff() async {
        gateway.statuses = [linked()]
        server.window(endsIn: 300)
        let m = manager()
        await m.refresh()
        await m.setEnabled(false)
        XCTAssertEqual(m.phase, .off)
    }

    func testRevokeFailureKeepsLinked() async {
        gateway.statuses = [linked()]
        gateway.unlinkResult = .failure(.offline)
        let m = manager()
        await m.refresh()
        await m.setEnabled(false)
        XCTAssertEqual(m.phase, .linked(since: server.now, expiresAt: nil))
        XCTAssertEqual(m.notice, .offline)
    }

    func testLinkStatusErrorKeepsLinked() async {
        gateway.statuses = [linked()]
        let m = manager()
        await m.refresh()
        gateway.statuses = [.failure(.offline)]
        await m.refresh()
        XCTAssertEqual(m.phase, .linked(since: server.now, expiresAt: nil))
    }

    func testLinkDisabled404Hides() async {
        gateway.statuses = [.failure(.disabled)]
        server.window(endsIn: 300)
        let m = manager()
        await m.refresh()
        XCTAssertEqual(m.phase, .hidden)
    }

    func testPollingTurnsCodeIntoLinked() async {
        server.window(endsIn: 3000)
        let m = manager()
        await m.refresh()
        await m.setEnabled(true)
        gateway.statuses = [.success(.init(state: .codeOpen, codeExpiresAt: nil, linkedAt: nil, expiresAt: nil)), linked()]
        await m.runPolling()
        XCTAssertEqual(m.phase, .linked(since: server.now, expiresAt: nil))
        XCTAssertEqual(gateway.calls.filter { $0 == "status" }.count, 3, "one refresh and two polls")
    }

    func testPollingStopsAtTenMinutes() async {
        gateway.statuses = [.success(.init(state: .codeOpen, codeExpiresAt: nil, linkedAt: nil, expiresAt: nil))]
        server.window(endsIn: 100_000)
        let m = manager()
        await m.refresh()
        XCTAssertEqual(m.phase, .off)
        gateway.codeResult = .success(DeviceLinkCode(code: "AAAA-BBBB", expiresAt: server.now.addingTimeInterval(3600)))
        await m.setEnabled(true)
        await m.runPolling()
        XCTAssertEqual(m.phase, .off)
        XCTAssertEqual(m.notice, .codeExpired)
        XCTAssertEqual(gateway.calls.filter { $0 == "status" }.count, 1 + 200, "3 s steps for 10 minutes")
    }

    func testExpiredCodeResetsToOffWithWindow() async {
        server.window(endsIn: 3000)
        let m = manager()
        await m.refresh()
        await m.setEnabled(true)
        m.expireIfNeeded(now: Date(timeIntervalSince1970: 1_000_601))
        XCTAssertEqual(m.phase, .off)
        XCTAssertEqual(m.notice, .codeExpired)
    }
}
