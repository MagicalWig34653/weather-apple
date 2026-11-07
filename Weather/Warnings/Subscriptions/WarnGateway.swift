import Foundation

/// Warning subscription routes (`/v1/push/installations/<uuid>/warn-subscriptions`) on top of the push transport
/// (same retry policy, header, no cookies).
struct HTTPWarnGateway: WarnGateway {
    private let push: HTTPPushGateway

    init(push: HTTPPushGateway = HTTPPushGateway()) { self.push = push }

    static func body(_ settings: WarnSubscriptionSettings) -> [String: Any] {
        let types = settings.types.map(\.rawValue).sorted()
        let severity = Dictionary(uniqueKeysWithValues: settings.types.map {
            ($0.rawValue, settings.minSeverity[$0] ?? WarnSubscriptionSettings.defaultMinSeverity[$0] ?? 3)
        })
        return ["warncell_ids": settings.warncellIDs, "types": types, "min_severity": severity,
                "enabled": settings.enabled, "time_sensitive": settings.timeSensitive]
    }

    func create(_ identity: PushIdentity, _ settings: WarnSubscriptionSettings) async throws -> String {
        let data = try await call("POST", identity, "", Self.body(settings), [201])
        struct Created: Decodable { let id: String }
        guard let created = try? JSONDecoder().decode(Created.self, from: data),
              UUID(uuidString: created.id) != nil else { throw WarnGatewayError.unavailable }
        return created.id.lowercased()
    }

    func update(_ identity: PushIdentity, id: String, _ settings: WarnSubscriptionSettings) async throws {
        guard UUID(uuidString: id) != nil else { throw WarnGatewayError.notFound }
        _ = try await call("PUT", identity, "/\(id)", Self.body(settings), [204])
    }

    func delete(_ identity: PushIdentity, id: String) async throws {
        guard UUID(uuidString: id) != nil else { throw WarnGatewayError.notFound }
        _ = try await call("DELETE", identity, "/\(id)", nil, [204])
    }

    func list(_ identity: PushIdentity) async throws -> [(id: String, settings: WarnSubscriptionSettings)] {
        let data = try await call("GET", identity, "", nil, [200])
        struct Item: Decodable {
            let id: String; let warncell_ids: [String]; let types: [String]
            let min_severity: [String: Int]?; let enabled: Bool?; let time_sensitive: Bool?
        }
        let items: [Item]
        if let direct = try? JSONDecoder().decode([Item].self, from: data) { items = direct }
        else if let wrapped = try? JSONDecoder().decode([String: [Item]].self, from: data), let first = wrapped.values.first { items = first }
        else { throw WarnGatewayError.unavailable }
        return items.map { item in
            let types = Set(item.types.compactMap(WarnKind.init(rawValue:)))
            var severity: [WarnKind: Int] = [:]
            for (key, value) in item.min_severity ?? [:] { if let kind = WarnKind(rawValue: key) { severity[kind] = value } }
            return (item.id.lowercased(), WarnSubscriptionSettings(
                warncellIDs: item.warncell_ids, types: types, minSeverity: severity,
                enabled: item.enabled ?? true, timeSensitive: item.time_sensitive ?? false))
        }
    }

    private func call(_ method: String, _ identity: PushIdentity, _ suffix: String, _ body: [String: Any]?,
                      _ success: Set<Int>) async throws -> Data {
        do {
            return try await push.send(method, "installations/\(identity.installationID)/warn-subscriptions\(suffix)", identity,
                                       body: body, success: success)
        } catch let error as PushGatewayError {
            throw Self.map(error)
        }
    }

    static func map(_ error: PushGatewayError) -> WarnGatewayError {
        switch error {
        case .unauthorized: .unauthorized
        case .notFound: .notFound
        case .warnLimit: .limit
        case .warnCellUnknown: .cellUnknown
        case .invalidWarnSubscription, .rejected(400): .invalid
        case .rateLimited: .rateLimited
        default: .unavailable
        }
    }
}
