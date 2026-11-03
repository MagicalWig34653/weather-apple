import XCTest
@testable import Weather

final class PushActivityGatewayTests: XCTestCase {
    private let identity = PushIdentity(installationID: "00000000-0000-0000-0000-000000000001", secret: "test-secret")
    private let sub = "00000000-0000-0000-0000-000000000002"
    private let token = String(repeating: "ab", count: 32)

    private actor Recorder {
        var requests: [URLRequest] = []
        func send(_ request: URLRequest) -> (Data, HTTPURLResponse) {
            requests.append(request)
            return (Data(), HTTPURLResponse(url: request.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!)
        }
    }

    func testInstallationOmittedNullAndRotatedToken() async throws {
        let recorder = Recorder()
        let gateway = HTTPPushGateway(baseURL: URL(string: "https://example.invalid/v1/push/")!,
                                      transport: { await recorder.send($0) })
        try await gateway.putInstallation(identity, token: "device", environment: .sandbox, locale: "de")
        try await gateway.putLiveActivityStartToken(identity, deviceToken: "device", environment: .sandbox, locale: "de", startToken: nil)
        try await gateway.putLiveActivityStartToken(identity, deviceToken: "device", environment: .sandbox, locale: "de", startToken: token)
        let requests = await recorder.requests
        let bodies = try requests.map { try JSONSerialization.jsonObject(with: XCTUnwrap($0.httpBody)) as! [String: Any] }
        XCTAssertNil(bodies[0]["live_activity_start_token"])
        XCTAssertTrue(bodies[1]["live_activity_start_token"] is NSNull)
        XCTAssertEqual(bodies[2]["live_activity_start_token"] as? String, token)
        XCTAssertEqual(bodies[2]["token"] as? String, "device")
        XCTAssertTrue(requests.allSatisfy { $0.value(forHTTPHeaderField: "X-Installation-Secret") == "test-secret" })
    }

    func testActivityPutDeleteUseContractPathHeaderAndTokenBody() async throws {
        let recorder = Recorder()
        let gateway = HTTPPushGateway(baseURL: URL(string: "https://example.invalid/v1/push/")!,
                                      transport: { await recorder.send($0) })
        try await gateway.putActivityToken(identity, subscriptionID: sub, token: token)
        try await gateway.deleteActivityToken(identity, subscriptionID: sub, token: token)
        let requests = await recorder.requests
        XCTAssertEqual(requests.map(\.httpMethod), ["PUT", "DELETE"])
        for request in requests {
            XCTAssertEqual(request.url?.path, "/v1/push/subscriptions/\(sub)/activity")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-Installation-Secret"), identity.secret)
            let body = try JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as! [String: String]
            XCTAssertEqual(body, ["activity_token": token])
        }
    }

    func testTokenlessDeleteHasNoBodyAndInvalidDeleteNeverReachesNetwork() async throws {
        let recorder = Recorder()
        let gateway = HTTPPushGateway(baseURL: URL(string: "https://example.invalid/v1/push/")!,
                                      transport: { await recorder.send($0) })
        try await gateway.deleteActivityToken(identity, subscriptionID: sub, token: nil)
        for invalid in ["", "invalid"] {
            do {
                try await gateway.deleteActivityToken(identity, subscriptionID: sub, token: invalid)
                XCTFail("invalid token accepted")
            } catch { XCTAssertEqual(error as? PushGatewayError, .invalidActivityToken) }
        }
        let requests = await recorder.requests
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests.first?.httpMethod, "DELETE")
        XCTAssertEqual(requests.first?.url?.path, "/v1/push/subscriptions/\(sub)/activity")
        XCTAssertNil(requests.first?.httpBody)
        XCTAssertNil(requests.first?.value(forHTTPHeaderField: "Content-Type"))
    }

    func testActivityFullDoesNotRetryHTTP503() async {
        let recorder = Recorder()
        let gateway = HTTPPushGateway(baseURL: URL(string: "https://example.invalid/v1/push/")!, transport: { request in
            _ = await recorder.send(request)
            return (Data(#"{"error":"activity_full"}"#.utf8),
                    HTTPURLResponse(url: request.url!, statusCode: 503, httpVersion: nil, headerFields: nil)!)
        }, sleep: { _ in XCTFail("capacity error must not back off and retry") })
        do {
            try await gateway.putActivityToken(identity, subscriptionID: sub, token: token)
            XCTFail("capacity error accepted")
        } catch { XCTAssertEqual(error as? PushGatewayError, .activityFull) }
        let requests = await recorder.requests
        XCTAssertEqual(requests.count, 1)
    }

    func testOnlyPointSubscriptionsCanSendOptInAndOldRequestsOmitField() {
        var request = PushSubscriptionRequest(cell: .init(x: 1, y: 1), threshold: 2, leadMinutes: 10, enabled: true)
        XCTAssertNil(HTTPPushGateway.body(request)["live_activity"])
        request.liveActivity = true
        XCTAssertEqual(HTTPPushGateway.body(request)["live_activity"] as? Bool, true)
        request.liveActivity = false
        XCTAssertEqual(HTTPPushGateway.body(request)["live_activity"] as? Bool, false)
        request.region = .init(radiusCells: 7, minSharePercent: 10)
        XCTAssertNil(HTTPPushGateway.body(request)["live_activity"])
    }

    func testKnownActivityErrorsAreMapped() {
        for (status, code, expected) in [(400, "invalid_activity_token", PushGatewayError.invalidActivityToken),
                                          (409, "activity_not_eligible", .activityNotEligible), (409, "activity_limit", .activityLimit),
                                          (409, "start_token_required", .startTokenRequired), (503, "activity_full", .activityFull)] {
            XCTAssertEqual(HTTPPushGateway.error(statusCode: status, data: Data("{\"error\":\"\(code)\"}".utf8)), expected)
        }
    }

    func testMalformedTokenIsRejectedWithoutNetworkCall() async {
        let recorder = Recorder()
        let gateway = HTTPPushGateway(baseURL: URL(string: "https://example.invalid/v1/push/")!,
                                      transport: { await recorder.send($0) })
        do {
            try await gateway.putActivityToken(identity, subscriptionID: sub, token: "invalid")
            XCTFail("invalid token accepted")
        } catch { XCTAssertEqual(error as? PushGatewayError, .invalidActivityToken) }
        let requests = await recorder.requests
        XCTAssertTrue(requests.isEmpty)
    }
}
