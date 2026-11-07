import Foundation

/// Warning types, raw values identical to the backend `kind` strings.
enum WarnKind: String, Codable, CaseIterable, Sendable {
    case severeWeather = "severe_weather", frost, ice
}

/// One server subscription (wire level). Only warning-cell IDs, no coordinates, no names.
struct WarnSubscriptionSettings: Codable, Equatable, Sendable {
    var warncellIDs: [WarnCellID]
    var types: Set<WarnKind>
    var minSeverity: [WarnKind: Int]
    var enabled: Bool
    var timeSensitive: Bool

    static let defaultMinSeverity: [WarnKind: Int] = [.severeWeather: 3, .frost: 1, .ice: 2]
}

/// Global user choice (types, minimum level per type, time-sensitive switch); no locations.
struct WarnUserSettings: Codable, Equatable, Sendable {
    var enabled = false
    var types: Set<WarnKind> = Set(WarnKind.allCases)
    var minSeverity = WarnSubscriptionSettings.defaultMinSeverity
    var timeSensitive = false

    func level(for kind: WarnKind) -> Int { minSeverity[kind] ?? WarnSubscriptionSettings.defaultMinSeverity[kind] ?? 3 }
}

enum WarnGatewayError: Error, Equatable, Sendable {
    case unauthorized, limit, cellUnknown, invalid, rateLimited, unavailable, notFound
}

protocol WarnGateway: Sendable {
    func create(_ identity: PushIdentity, _ settings: WarnSubscriptionSettings) async throws -> String
    func update(_ identity: PushIdentity, id: String, _ settings: WarnSubscriptionSettings) async throws
    func delete(_ identity: PushIdentity, id: String) async throws
    func list(_ identity: PushIdentity) async throws -> [(id: String, settings: WarnSubscriptionSettings)]
}
