import XCTest
@testable import Weather

final class WarnGatewayTests: XCTestCase {
    private let identity = PushIdentity(installationID: "00000000-0000-0000-0000-000000000001", secret: "test-secret")
    private let sub = "00000000-0000-0000-0000-000000000002"
    private let settings = WarnSubscriptionSettings(
        warncellIDs: ["913073001"], types: Set(WarnKind.allCases), minSeverity: WarnSubscriptionSettings.defaultMinSeverity,
        enabled: true, timeSensitive: false)

    private actor Box {
        var requests: [URLRequest] = []
        var status = 201
        var payload = Data()
        func set(status: Int, payload: String = "") { self.status = status; self.payload = Data(payload.utf8) }
        func send(_ r: URLRequest) -> (Data, HTTPURLResponse) {
            requests.append(r)
            return (payload, HTTPURLResponse(url: r.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
        }
    }

    private func make(_ box: Box) -> HTTPWarnGateway {
        HTTPWarnGateway(push: HTTPPushGateway(baseURL: URL(string: "https://example.invalid/v1/push/")!,
                                              transport: { await box.send($0) }, sleep: { _ in }))
    }

    func testCreateBodyMatchesContractFixture() async throws {
        let box = Box()
        await box.set(status: 201, payload: "{\"id\":\"\(sub)\"}")
        let id = try await make(box).create(identity, settings)
        XCTAssertEqual(id, sub)
        let first = await box.requests.first
        let request = try XCTUnwrap(first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/v1/push/installations/\(identity.installationID)/warn-subscriptions")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Installation-Secret"), "test-secret")
        let fixture = #"{"enabled":true,"min_severity":{"frost":1,"ice":2,"severe_weather":3},"time_sensitive":false,"types":["frost","ice","severe_weather"],"warncell_ids":["913073001"]}"#
        let sent = try JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as! NSDictionary
        let expected = try JSONSerialization.jsonObject(with: Data(fixture.utf8)) as! NSDictionary
        XCTAssertEqual(sent, expected)
        let text = String(decoding: try XCTUnwrap(request.httpBody), as: UTF8.self)
        XCTAssertFalse(text.contains("lat")); XCTAssertFalse(text.contains("name"))
    }

    func testErrorMapping() async throws {
        let cases: [(Int, String, WarnGatewayError)] = [
            (409, #"{"error":"warn_limit"}"#, .limit), (409, #"{"error":"warncell_unknown"}"#, .cellUnknown),
            (400, #"{"error":"invalid_warn_subscription"}"#, .invalid), (401, "", .unauthorized),
            (404, "", .notFound), (503, "", .unavailable)]
        for (status, payload, expected) in cases {
            let box = Box(); await box.set(status: status, payload: payload)
            do { _ = try await make(box).create(identity, settings); XCTFail("no error \(status)") }
            catch { XCTAssertEqual(error as? WarnGatewayError, expected, "status \(status)") }
        }
        let box = Box(); await box.set(status: 429)
        do { try await make(box).update(identity, id: sub, settings); XCTFail() }
        catch { XCTAssertEqual(error as? WarnGatewayError, .rateLimited) }
    }

    func testNetworkErrorIsUnavailable() async {
        let gateway = HTTPWarnGateway(push: HTTPPushGateway(baseURL: URL(string: "https://example.invalid/v1/push/")!,
                                                            transport: { _ in throw URLError(.cannotFindHost) }, sleep: { _ in }))
        do { _ = try await gateway.create(identity, settings); XCTFail() }
        catch { XCTAssertEqual(error as? WarnGatewayError, .unavailable) }
    }

    func testDeleteAndListDecode() async throws {
        let box = Box(); await box.set(status: 204)
        try await make(box).delete(identity, id: sub)
        let first = await box.requests.first
        let request = try XCTUnwrap(first)
        XCTAssertEqual(request.httpMethod, "DELETE")
        await box.set(status: 200, payload: #"[{"id":"\#(sub)","warncell_ids":["913073001"],"types":["frost"],"min_severity":{"frost":2},"enabled":true,"time_sensitive":true}]"#)
        let items = try await make(box).list(identity)
        XCTAssertEqual(items.first?.settings.minSeverity[.frost], 2)
        XCTAssertEqual(items.first?.settings.types, [.frost])
        XCTAssertEqual(items.first?.settings.timeSensitive, true)
    }
}
