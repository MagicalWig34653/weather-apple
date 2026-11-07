import Foundation

/// P2 wire helpers; token bytes never enter UserDefaults, files or logs.
enum PushActivityWire {
    static let capability = "live_activity"
    /// `GET /v1/status`: Live Activities for region subscriptions. Without it `live_activity: true` on a region would get a 400.
    static let regionCapability = "live_activity_regions"

    static func hex(_ data: Data) -> String { data.map { String(format: "%02x", $0) }.joined() }

    static func isValidToken(_ value: String) -> Bool {
        (32...200).contains(value.utf8.count) && value.utf8.count.isMultiple(of: 2)
            && value.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
    }
}
