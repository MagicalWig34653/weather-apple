import Foundation

/// Failures of the device link routes (contract: backend `api.md`, "Gerätekopplung"), derived from status and `error` code only.
enum DeviceLinkError: Error, Equatable, Sendable {
    case offline, transport
    case unauthorized
    /// 404: `DEVICE_LINK_ENABLED=false` or push off.
    case disabled
    /// 403 `pairing_closed`: the operator has no open pairing window.
    case pairingClosed
    case alreadyLinked
    case linkFull
    case tooLarge
    case invalidRequest
    case rateLimited(retryAfter: Int?)
    case server(Int)
    case invalidResponse
}

struct DeviceLinkCode: Equatable, Sendable {
    let code: String
    let expiresAt: Date
}

struct DeviceLinkStatus: Equatable, Sendable {
    enum State: String, Sendable { case none, codeOpen = "code_open", linked }
    let state: State
    let codeExpiresAt: Date?
    let linkedAt: Date?
    /// `nil` = permanent until revoked.
    let expiresAt: Date?
}

protocol DeviceLinkGateway: Sendable {
    func requestCode(_ identity: PushIdentity) async throws -> DeviceLinkCode
    func status(_ identity: PushIdentity) async throws -> DeviceLinkStatus
    func unlink(_ identity: PushIdentity) async throws
}

enum DeviceLinkWire {
    /// Entry of `capabilities` in `GET /v1/status`.
    static let capability = "device_link"

    static func date(_ string: String?) -> Date? {
        guard let string else { return nil }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        if let date = plain.date(from: string) { return date }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: string)
    }

    static func error(statusCode: Int, data: Data, retryAfter: Int?) -> DeviceLinkError {
        struct Payload: Decodable { let error: String? }
        let code = (try? JSONDecoder().decode(Payload.self, from: data))?.error
        switch (statusCode, code) {
        case (401, _): return .unauthorized
        case (404, _): return .disabled
        case (403, "pairing_closed"): return .pairingClosed
        case (409, "already_linked"): return .alreadyLinked
        case (409, "link_full"): return .linkFull
        case (413, _): return .tooLarge
        case (400, _): return .invalidRequest
        case (429, _): return .rateLimited(retryAfter: retryAfter)
        case (500..., _): return .server(statusCode)
        default: return .invalidResponse
        }
    }
}

extension HTTPPushGateway: DeviceLinkGateway {
    /// No retries: the rate limits count every call and a code must never be requested twice by accident.
    private func linkSend(_ method: String, _ suffix: String, _ identity: PushIdentity, body: [String: Any]?,
                          success: Set<Int>) async throws -> Data {
        do {
            return try await send(method, "installations/\(identity.installationID)/\(suffix)", identity, body: body,
                                  success: success, retry: false,
                                  mapError: { status, data, after in
                                      Self.wrap(DeviceLinkWire.error(statusCode: status, data: data, retryAfter: after))
                                  })
        } catch let error as PushGatewayError {
            switch error {
            case .offline: throw DeviceLinkError.offline
            case .transport: throw DeviceLinkError.transport
            case .link(let inner): throw inner
            default: throw DeviceLinkError.invalidResponse
            }
        }
    }

    private static func wrap(_ error: DeviceLinkError) -> PushGatewayError { .link(error) }

    func requestCode(_ identity: PushIdentity) async throws -> DeviceLinkCode {
        let data = try await linkSend("POST", "link-code", identity, body: [:], success: [201])
        struct Created: Decodable { let code: String; let expires_at: String }
        guard let created = try? JSONDecoder().decode(Created.self, from: data),
              let expires = DeviceLinkWire.date(created.expires_at) else { throw DeviceLinkError.invalidResponse }
        return DeviceLinkCode(code: created.code, expiresAt: expires)
    }

    func status(_ identity: PushIdentity) async throws -> DeviceLinkStatus {
        let data = try await linkSend("GET", "link", identity, body: nil, success: [200])
        struct Payload: Decodable { let state: String; let code_expires_at: String?; let linked_at: String?; let expires_at: String? }
        guard let payload = try? JSONDecoder().decode(Payload.self, from: data),
              let state = DeviceLinkStatus.State(rawValue: payload.state) else { throw DeviceLinkError.invalidResponse }
        return DeviceLinkStatus(state: state, codeExpiresAt: DeviceLinkWire.date(payload.code_expires_at),
                                linkedAt: DeviceLinkWire.date(payload.linked_at), expiresAt: DeviceLinkWire.date(payload.expires_at))
    }

    func unlink(_ identity: PushIdentity) async throws {
        _ = try await linkSend("DELETE", "link", identity, body: nil, success: [204])
    }
}
