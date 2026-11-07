import Foundation

/// One official DWD warning as the backend delivers it (`GET /v1/warnings/active`). Texts are shown unchanged.
struct ActiveWarning: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let kind: WarnKind
    let severity: Int
    let event: String
    let sent: Date
    let onset: Date
    let expires: Date
    let headline: String
    let text: String
    let instruction: String
    let lang: String
    let warncellIDs: [WarnCellID]

    enum CodingKeys: String, CodingKey {
        case id, kind, severity, event, sent, onset, expires, headline, text, instruction, lang
        case warncellIDs = "warncell_ids"
    }
}

struct ActiveWarningsResponse: Codable, Equatable, Sendable {
    let fetchedAt: Date
    let warnings: [ActiveWarning]

    enum CodingKeys: String, CodingKey { case fetchedAt = "fetched_at", warnings }

    static func decode(_ data: Data) throws -> ActiveWarningsResponse {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let string = try decoder.singleValueContainer().decode(String.self)
            let plain = ISO8601DateFormatter()
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = plain.date(from: string) ?? fractional.date(from: string) { return date }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "bad date \(string)"))
        }
        return try decoder.decode(ActiveWarningsResponse.self, from: data)
    }
}

enum Staleness: Equatable, Sendable { case fresh, stale }

enum WarnFilter {
    /// Older than this the data counts as possibly outdated (the server polls the DWD feed every few minutes).
    static let staleAfter: TimeInterval = 30 * 60

    /// Not expired, sorted: level descending, then onset, then id.
    static func active(_ all: [ActiveWarning], now: Date) -> [ActiveWarning] {
        all.filter { $0.expires > now }.sorted {
            ($0.severity, $1.onset.timeIntervalSince1970, $1.id) > ($1.severity, $0.onset.timeIntervalSince1970, $0.id)
        }
    }

    /// Intersection with the device's own warning cells, not expired, sorted.
    static func relevant(_ all: [ActiveWarning], cells: Set<WarnCellID>, now: Date) -> [ActiveWarning] {
        active(all, now: now).filter { !cells.isDisjoint(with: $0.warncellIDs) }
    }

    /// Exactly 30 minutes still counts as fresh.
    static func staleness(fetchedAt: Date, now: Date) -> Staleness {
        now.timeIntervalSince(fetchedAt) <= staleAfter ? .fresh : .stale
    }
}

/// A saved place or region with the warning cells it lies in (computed on the device; never sent anywhere).
struct WarnPlaceCells: Equatable, Sendable {
    let name: String?
    let cells: Set<WarnCellID>
}
