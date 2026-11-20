import Foundation

/// Stand: Gerüst für die Test-zuerst-Phase (Verhalten folgt im nächsten Commit).

/// One run of missing grid times reported by the backend (`history.gaps`): `from` and `to` inclusive.
struct RadarHistoryGap: Equatable, Sendable {
    let from: Date
    let to: Date
    let slots: Int
}

/// The additive `history` block of a manifest (backend PR #4, schema stays 1). Absent or malformed means
/// "unknown": the app then relies on the slots it actually received.
struct RadarHistoryInfo: Equatable, Sendable {
    let hours: Int
    let oldest: Date?
    let expected: Int
    let present: Int
    let complete: Bool
    let gaps: [RadarHistoryGap]
    let gapsTruncated: Bool

    /// Reads the top-level `history` object of a manifest; `nil` for anything that is not a plausible block.
    static func parse(manifestData data: Data) -> RadarHistoryInfo? { nil }
}

/// A hole in the timeline: grid times without an image. `afterIndex` is the index of the slot before the hole
/// (`-1` = the hole lies before the oldest slot).
struct TimelineGap: Equatable, Sendable {
    let afterIndex: Int
    let from: Date
    let to: Date
    let slots: Int
}

struct RadarTimelineGaps: Equatable, Sendable {
    let gaps: [TimelineGap]

    init(dates: [Date], stepMinutes: Int, history: RadarHistoryInfo?) { gaps = [] }

    static let empty = RadarTimelineGaps(dates: [], stepMinutes: 5, history: nil)
    var isEmpty: Bool { gaps.isEmpty }
    /// Holes between two slots (the ones the slider can show as marks).
    var inner: [TimelineGap] { gaps.filter { $0.afterIndex >= 0 } }
    func before(index: Int) -> TimelineGap? { nil }
    func after(index: Int) -> TimelineGap? { nil }
}
