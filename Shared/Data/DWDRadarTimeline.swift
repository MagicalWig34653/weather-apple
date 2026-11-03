import Foundation

/// Direct DWD frame dates without app-only backend metadata.
struct DWDRadarTimeline: Sendable {
    let referenceTime: Date
    let dates: [Date]
}
