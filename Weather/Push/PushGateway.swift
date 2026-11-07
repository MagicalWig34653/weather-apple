import Foundation

/// Push environment as the backend API requires it (`env` in `PUT /v1/push/installations/<uuid>`).
/// Not a product decision: development-signed (Debug) builds get sandbox tokens, TestFlight/App Store production.
enum PushEnvironment: String, Codable, Sendable {
    case sandbox, production
    static var current: PushEnvironment {
        #if DEBUG
        .sandbox
        #else
        .production
        #endif
    }
}

struct PushIdentity: Codable, Equatable, Sendable {
    /// Lowercase UUID.
    let installationID: String
    /// 43 characters base64url, 32 random bytes; only its hash is stored by the server.
    let secret: String

    static func make() -> PushIdentity {
        var bytes = [UInt8](repeating: 0, count: 32)
        if SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) != errSecSuccess {
            for index in bytes.indices { bytes[index] = UInt8.random(in: 0...255) }
        }
        let secret = Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return PushIdentity(installationID: UUID().uuidString.lowercased(), secret: secret)
    }
}

/// Circle region as sent to the server: the (coarse) center is the request cell; no coordinates.
struct PushRegionSpec: Equatable, Sendable {
    let radiusCells: Int
    let minSharePercent: Int
}

/// Wire names of the region extension at one place (checked against backend `api.md` and `PushApi.swift`, commit 34e6416).
enum PushRegionWire {
    static let kindKey = "kind", kindCircle = "circle"
    static let radiusKey = "radius_cells", shareKey = "min_share_percent"
    /// Entry of `capabilities` in `GET /v1/status`.
    static let capability = "regions"
}

struct PushSubscriptionRequest: Equatable, Sendable {
    let cell: PushGrid.Cell
    let threshold: Int
    let leadMinutes: Int
    let enabled: Bool
    /// Backend field `time_sensitive`; PUT replaces all fields, so it is always sent.
    var timeSensitive = false
    /// `nil` = single place (unchanged wire format).
    var region: PushRegionSpec?
    /// nil omits the additive field on servers without the capability (`live_activity`; for regions `live_activity_regions`).
    var liveActivity: Bool?
}

/// Failures of `POST .../test`, derived from the backend `error` code (never from Apple text).
enum PushTestFailure: Equatable, Sendable {
    case environmentNotAllowed
    case apnsUnavailable503
    case badDeviceToken
    case keyRejected
    case apnsUnavailable
    case apnsRejected
    case tokenUnregistered
    case rateLimited(retryAfter: Int?)
    case other(Int)
}

enum PushGatewayError: Error, Equatable, Sendable {
    case offline
    case transport
    case unauthorized
    case notFound
    case subscriptionLimit
    /// 409 `region_capacity`: server-wide region budget exhausted.
    case regionCapacity
    /// 409 `region_limit`: more than 3 regions or more than 8000 cells (sum of the circle areas) for this installation.
    case regionLimit
    case invalidActivityToken
    /// Warning subscriptions: 409 `warn_limit`, 409 `warncell_unknown`, 400 `invalid_warn_subscription`.
    case warnLimit
    case warnCellUnknown
    case invalidWarnSubscription
    case activityNotEligible
    case activityLimit
    case startTokenRequired
    case activityFull
    case rateLimited
    case rejected(Int)
    case server(Int)
    case invalidResponse
    case test(PushTestFailure)
    /// Carrier for the device link routes (see `DeviceLinkGateway`).
    case link(DeviceLinkError)
}

protocol PushGateway: Sendable {
    func putInstallation(_ identity: PushIdentity, token: String, environment: PushEnvironment, locale: String) async throws
    func deleteInstallation(_ identity: PushIdentity) async throws
    func createSubscription(_ identity: PushIdentity, _ request: PushSubscriptionRequest) async throws -> String
    func updateSubscription(_ identity: PushIdentity, id: String, _ request: PushSubscriptionRequest) async throws
    func deleteSubscription(_ identity: PushIdentity, id: String) async throws
    /// `POST installations/<uuid>/test`; returns the environment the server used. No retries (each call counts against 3/h).
    func sendTestNotification(_ identity: PushIdentity) async throws -> String
    /// `GET /v1/status` (no authentication): the `capabilities` strings; empty for servers without that field.
    func capabilities() async throws -> Set<String>
    func putLiveActivityStartToken(_ identity: PushIdentity, deviceToken: String, environment: PushEnvironment,
                                   locale: String, startToken: String?) async throws
    func putActivityToken(_ identity: PushIdentity, subscriptionID: String, token: String) async throws
    func deleteActivityToken(_ identity: PushIdentity, subscriptionID: String, token: String?) async throws
}

extension PushGateway {
    func putLiveActivityStartToken(_ identity: PushIdentity, deviceToken: String, environment: PushEnvironment,
                                   locale: String, startToken: String?) async throws { throw PushGatewayError.notFound }
    func putActivityToken(_ identity: PushIdentity, subscriptionID: String, token: String) async throws { throw PushGatewayError.notFound }
    func deleteActivityToken(_ identity: PushIdentity, subscriptionID: String, token: String?) async throws { throw PushGatewayError.notFound }
}

enum PushBackendConfig {
    /// `https://<host>/v1/push/`, derived from the radar base URL (same host, same debug override).
    static func baseURL(radarBaseURL: URL = RadarBackendConfig.baseURL()) -> URL {
        radarBaseURL.deletingLastPathComponent().appendingPathComponent("push/")
    }
}

struct PushServerStatus: Equatable, Sendable {
    let capabilities: Set<String>
    /// End of the operator's pairing window; `nil` = no window (or unparsable).
    let deviceLinkWindowEndsAt: Date?
}

/// URLSession implementation. No cookies, no cache, no credentials store; only the installation secret header.
/// Retry like `RadarRetryPolicy`: at most 3 attempts for 502/503/504, transient `URLError`s and 429
/// (`Retry-After` up to 5 s is honored); never for other 4xx, offline or cancellation.
struct HTTPPushGateway: PushGateway {
    typealias Transport = @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)
    typealias Sleep = @Sendable (TimeInterval) async throws -> Void

    let baseURL: URL
    private let transport: Transport
    private let sleep: Sleep

    init(baseURL: URL = PushBackendConfig.baseURL(), transport: Transport? = nil, sleep: Sleep? = nil) {
        self.baseURL = baseURL
        self.sleep = sleep ?? { try await Task.sleep(for: .seconds($0)) }
        if let transport { self.transport = transport } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.urlCache = nil
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            configuration.httpCookieStorage = nil
            configuration.httpShouldSetCookies = false
            configuration.urlCredentialStorage = nil
            configuration.timeoutIntervalForRequest = 8
            configuration.timeoutIntervalForResource = 20
            configuration.waitsForConnectivity = false
            let session = URLSession(configuration: configuration)
            self.transport = { request in
                let (data, response) = try await session.data(for: request)
                guard let response = response as? HTTPURLResponse else { throw PushGatewayError.invalidResponse }
                return (data, response)
            }
        }
    }

    func putInstallation(_ identity: PushIdentity, token: String, environment: PushEnvironment, locale: String) async throws {
        let body: [String: Any] = ["token": token, "env": environment.rawValue, "locale": locale]
        _ = try await send("PUT", "installations/\(identity.installationID)", identity, body: body, success: [201, 204])
    }

    func putLiveActivityStartToken(_ identity: PushIdentity, deviceToken: String, environment: PushEnvironment,
                                   locale: String, startToken: String?) async throws {
        if let startToken, !PushActivityWire.isValidToken(startToken) { throw PushGatewayError.invalidActivityToken }
        let body: [String: Any] = ["token": deviceToken, "env": environment.rawValue, "locale": locale,
                                   "live_activity_start_token": startToken.map { $0 as Any } ?? NSNull()]
        _ = try await send("PUT", "installations/\(identity.installationID)", identity, body: body, success: [201, 204])
    }

    func putActivityToken(_ identity: PushIdentity, subscriptionID: String, token: String) async throws {
        try await activityTokenRequest("PUT", identity, subscriptionID: subscriptionID, token: token)
    }

    func deleteActivityToken(_ identity: PushIdentity, subscriptionID: String, token: String?) async throws {
        guard UUID(uuidString: subscriptionID) != nil,
              token.map(PushActivityWire.isValidToken) ?? true else { throw PushGatewayError.invalidActivityToken }
        _ = try await send("DELETE", "subscriptions/\(subscriptionID)/activity", identity,
                           body: token.map { ["activity_token": $0] }, success: [204])
    }

    private func activityTokenRequest(_ method: String, _ identity: PushIdentity, subscriptionID: String, token: String) async throws {
        guard UUID(uuidString: subscriptionID) != nil, PushActivityWire.isValidToken(token) else {
            throw PushGatewayError.invalidActivityToken
        }
        _ = try await send(method, "subscriptions/\(subscriptionID)/activity", identity,
                           body: ["activity_token": token], success: [204])
    }

    func deleteInstallation(_ identity: PushIdentity) async throws {
        _ = try await send("DELETE", "installations/\(identity.installationID)", identity, body: nil, success: [204])
    }

    func createSubscription(_ identity: PushIdentity, _ request: PushSubscriptionRequest) async throws -> String {
        let data = try await send("POST", "installations/\(identity.installationID)/subscriptions", identity,
                                  body: Self.body(request), success: [201])
        struct Created: Decodable { let id: String }
        guard let created = try? JSONDecoder().decode(Created.self, from: data),
              UUID(uuidString: created.id) != nil else { throw PushGatewayError.invalidResponse }
        return created.id.lowercased()
    }

    func updateSubscription(_ identity: PushIdentity, id: String, _ request: PushSubscriptionRequest) async throws {
        _ = try await send("PUT", "installations/\(identity.installationID)/subscriptions/\(id)", identity,
                           body: Self.body(request), success: [204])
    }

    func deleteSubscription(_ identity: PushIdentity, id: String) async throws {
        _ = try await send("DELETE", "installations/\(identity.installationID)/subscriptions/\(id)", identity,
                           body: nil, success: [204])
    }

    func capabilities() async throws -> Set<String> { try await serverStatus().capabilities }

    /// `GET /v1/status`: capabilities and the operator pairing window (`device_link_window`, absent or null = no window).
    func serverStatus() async throws -> PushServerStatus {
        guard let url = URL(string: "../status", relativeTo: baseURL)?.absoluteURL else { throw PushGatewayError.invalidResponse }
        var request = URLRequest(url: url)
        request.httpShouldHandleCookies = false
        var attempt = 1
        while true {
            do {
                let (data, response) = try await transport(request)
                if response.statusCode == 200 {
                    struct Window: Decodable { let ends_at: String? }
                    struct Status: Decodable { let capabilities: [String]?; let device_link_window: Window? }
                    guard let status = try? JSONDecoder().decode(Status.self, from: data) else { throw PushGatewayError.invalidResponse }
                    return PushServerStatus(capabilities: Set(status.capabilities ?? []),
                                            deviceLinkWindowEndsAt: DeviceLinkWire.date(status.device_link_window?.ends_at))
                }
                if RadarRetryPolicy.isTransient(statusCode: response.statusCode), attempt < RadarRetryPolicy.maxAttempts {
                    try await sleep(RadarRetryPolicy.delay(afterAttempt: attempt)); attempt += 1; continue
                }
                throw Self.error(statusCode: response.statusCode, data: data)
            } catch let error as URLError {
                if error.code == .cancelled { throw CancellationError() }
                if RadarRetryPolicy.isTransient(error), attempt < RadarRetryPolicy.maxAttempts {
                    try await sleep(RadarRetryPolicy.delay(afterAttempt: attempt)); attempt += 1; continue
                }
                switch error.code {
                case .notConnectedToInternet, .dataNotAllowed, .internationalRoamingOff: throw PushGatewayError.offline
                default: throw PushGatewayError.transport
                }
            }
        }
    }

    func sendTestNotification(_ identity: PushIdentity) async throws -> String {
        let data = try await send("POST", "installations/\(identity.installationID)/test", identity, body: nil,
                                  success: [200], retry: false, mapError: Self.testError)
        struct Sent: Decodable { let sent: Bool; let environment: String? }
        guard let sent = try? JSONDecoder().decode(Sent.self, from: data), sent.sent else { throw PushGatewayError.invalidResponse }
        return sent.environment ?? ""
    }

    static func testError(statusCode: Int, data: Data, retryAfter: Int?) -> PushGatewayError {
        struct Payload: Decodable { let error: String? }
        let code = (try? JSONDecoder().decode(Payload.self, from: data))?.error
        switch (statusCode, code) {
        case (401, _): return .unauthorized
        case (404, _): return .notFound
        case (409, "environment_not_allowed"): return .test(.environmentNotAllowed)
        case (429, "test_rate_limited"): return .test(.rateLimited(retryAfter: retryAfter))
        case (503, "apns_unavailable"): return .test(.apnsUnavailable503)
        case (502, "apns_bad_device_token"): return .test(.badDeviceToken)
        case (502, "apns_key_rejected"): return .test(.keyRejected)
        case (502, "apns_unavailable"): return .test(.apnsUnavailable)
        case (502, "apns_rejected"): return .test(.apnsRejected)
        case (410, "token_unregistered"): return .test(.tokenUnregistered)
        case (429, _): return .test(.rateLimited(retryAfter: retryAfter))
        case (500..., _): return .server(statusCode)
        default: return .test(.other(statusCode))
        }
    }

    static func body(_ request: PushSubscriptionRequest) -> [String: Any] {
        var body: [String: Any] = ["grid_version": PushGrid.version, "cell_x": request.cell.x, "cell_y": request.cell.y,
                                   "threshold": request.threshold, "lead_minutes": request.leadMinutes,
                                   "enabled": request.enabled, "time_sensitive": request.timeSensitive]
        if let region = request.region {
            body[PushRegionWire.kindKey] = PushRegionWire.kindCircle
            body[PushRegionWire.radiusKey] = region.radiusCells
            body[PushRegionWire.shareKey] = region.minSharePercent
        }
        // Regions only carry the field when the server announced `live_activity_regions` (the request is then non-nil).
        if let liveActivity = request.liveActivity { body["live_activity"] = liveActivity }
        return body
    }

    func send(_ method: String, _ path: String, _ identity: PushIdentity, body: [String: Any]?,
                      success: Set<Int>, retry: Bool = true,
                      mapError: (@Sendable (Int, Data, Int?) -> PushGatewayError)? = nil) async throws -> Data {
        guard let url = URL(string: path, relativeTo: baseURL)?.absoluteURL else { throw PushGatewayError.invalidResponse }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(identity.secret, forHTTPHeaderField: "X-Installation-Secret")
        request.httpShouldHandleCookies = false
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        var attempt = 1
        while true {
            do {
                let (data, response) = try await transport(request)
                if success.contains(response.statusCode) { return data }
                // Capacity exhaustion requires a new user opt-in, never transport backoff retries.
                if Self.error(statusCode: response.statusCode, data: data) == .activityFull {
                    throw PushGatewayError.activityFull
                }
                if retry, (response.statusCode == 429 || RadarRetryPolicy.isTransient(statusCode: response.statusCode)),
                   attempt < RadarRetryPolicy.maxAttempts {
                    var delay = RadarRetryPolicy.delay(afterAttempt: attempt)
                    if response.statusCode == 429, let after = response.value(forHTTPHeaderField: "Retry-After").flatMap(Double.init) {
                        delay = max(delay, min(after, 5))
                    }
                    try await sleep(delay)
                    attempt += 1
                    continue
                }
                if let mapError {
                    throw mapError(response.statusCode, data, response.value(forHTTPHeaderField: "Retry-After").flatMap { Int($0) })
                }
                throw Self.error(statusCode: response.statusCode, data: data)
            } catch let error as URLError {
                if error.code == .cancelled { throw CancellationError() }
                if retry, RadarRetryPolicy.isTransient(error), attempt < RadarRetryPolicy.maxAttempts {
                    try await sleep(RadarRetryPolicy.delay(afterAttempt: attempt))
                    attempt += 1
                    continue
                }
                switch error.code {
                case .notConnectedToInternet, .dataNotAllowed, .internationalRoamingOff: throw PushGatewayError.offline
                default: throw PushGatewayError.transport
                }
            }
        }
    }

    static func error(statusCode: Int, data: Data) -> PushGatewayError {
        switch statusCode {
        case 401: return .unauthorized
        case 404: return .notFound
        case 429: return .rateLimited
        case 409:
            struct Payload: Decodable { let error: String? }
            switch (try? JSONDecoder().decode(Payload.self, from: data))?.error {
            case "subscription_limit": return .subscriptionLimit
            case "region_capacity": return .regionCapacity
            case "region_limit": return .regionLimit
            case "warn_limit": return .warnLimit
            case "warncell_unknown": return .warnCellUnknown
            case "activity_not_eligible": return .activityNotEligible
            case "activity_limit": return .activityLimit
            case "start_token_required": return .startTokenRequired
            default: return .rejected(409)
            }
        case 400:
            struct Payload: Decodable { let error: String? }
            switch (try? JSONDecoder().decode(Payload.self, from: data))?.error {
            case "invalid_activity_token": return .invalidActivityToken
            case "invalid_warn_subscription": return .invalidWarnSubscription
            default: return .rejected(400)
            }
        case 401..<500: return .rejected(statusCode)
        case 503:
            struct Payload: Decodable { let error: String? }
            return (try? JSONDecoder().decode(Payload.self, from: data))?.error == "activity_full"
                ? .activityFull : .server(503)
        case 500...: return .server(statusCode)
        default: return .invalidResponse
        }
    }
}
