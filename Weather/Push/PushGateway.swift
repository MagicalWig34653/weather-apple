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

struct PushSubscriptionRequest: Equatable, Sendable {
    let cell: PushGrid.Cell
    let threshold: Int
    let leadMinutes: Int
    let enabled: Bool
}

enum PushGatewayError: Error, Equatable, Sendable {
    case offline
    case transport
    case unauthorized
    case notFound
    case subscriptionLimit
    case rateLimited
    case rejected(Int)
    case server(Int)
    case invalidResponse
}

protocol PushGateway: Sendable {
    func putInstallation(_ identity: PushIdentity, token: String, environment: PushEnvironment, locale: String) async throws
    func deleteInstallation(_ identity: PushIdentity) async throws
    func createSubscription(_ identity: PushIdentity, _ request: PushSubscriptionRequest) async throws -> String
    func updateSubscription(_ identity: PushIdentity, id: String, _ request: PushSubscriptionRequest) async throws
    func deleteSubscription(_ identity: PushIdentity, id: String) async throws
}

enum PushBackendConfig {
    /// `https://<host>/v1/push/`, derived from the radar base URL (same host, same debug override).
    static func baseURL(radarBaseURL: URL = RadarBackendConfig.baseURL()) -> URL {
        radarBaseURL.deletingLastPathComponent().appendingPathComponent("push/")
    }
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

    static func body(_ request: PushSubscriptionRequest) -> [String: Any] {
        ["grid_version": PushGrid.version, "cell_x": request.cell.x, "cell_y": request.cell.y,
         "threshold": request.threshold, "lead_minutes": request.leadMinutes, "enabled": request.enabled]
    }

    private func send(_ method: String, _ path: String, _ identity: PushIdentity, body: [String: Any]?,
                      success: Set<Int>) async throws -> Data {
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
                if (response.statusCode == 429 || RadarRetryPolicy.isTransient(statusCode: response.statusCode)),
                   attempt < RadarRetryPolicy.maxAttempts {
                    var delay = RadarRetryPolicy.delay(afterAttempt: attempt)
                    if response.statusCode == 429, let after = response.value(forHTTPHeaderField: "Retry-After").flatMap(Double.init) {
                        delay = max(delay, min(after, 5))
                    }
                    try await sleep(delay)
                    attempt += 1
                    continue
                }
                throw Self.error(statusCode: response.statusCode, data: data)
            } catch let error as URLError {
                if error.code == .cancelled { throw CancellationError() }
                if RadarRetryPolicy.isTransient(error), attempt < RadarRetryPolicy.maxAttempts {
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
            let text = String(data: data.prefix(256), encoding: .utf8) ?? ""
            return text.contains("subscription_limit") ? .subscriptionLimit : .rejected(409)
        case 400..<500: return .rejected(statusCode)
        case 500...: return .server(statusCode)
        default: return .invalidResponse
        }
    }
}
