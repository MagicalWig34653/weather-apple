import Foundation

struct RadarTimeline: Sendable {
    let referenceTime: Date
    let dates: [Date]
    /// Set when the frames come from the radar cache backend; `nil` means direct DWD tiles.
    var backend: RadarManifest?
}

extension DWDClient {
    /// Keeps backend metadata and the app's radar API out of the shared client.
    func radarTimeline(before unavailableReference: Date? = nil) async throws -> RadarTimeline {
        let direct = try await radarRunTimeline(before: unavailableReference)
        return RadarTimeline(referenceTime: direct.referenceTime, dates: direct.dates)
    }
}
