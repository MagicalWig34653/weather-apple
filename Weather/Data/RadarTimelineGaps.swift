import CoreFoundation
import Foundation

/// One run of missing grid times reported by the backend (`history.gaps`): `from` and `to` inclusive.
struct RadarHistoryGap: Equatable, Sendable {
    let from: Date
    let to: Date
    let slots: Int
}

/// The additive `history` block of a manifest (backend PR #4, schema stays 1): the reported duration (48 or 72 hours),
/// the oldest slot that exists, how many grid times are expected and present, and the holes. Absent or malformed means
/// "unknown": the app then relies on the slots it actually received (no guessing, no invented values).
struct RadarHistoryInfo: Equatable, Sendable {
    let hours: Int
    let oldest: Date?
    let expected: Int
    let present: Int
    let complete: Bool
    let gaps: [RadarHistoryGap]
    /// The backend lists at most 100 holes; more are cut off (`gaps_truncated`).
    let gapsTruncated: Bool

    static let maximumHours = 168
    static let maximumGaps = 200

    /// Reads the top-level `history` object of a manifest; `nil` for anything that is not a plausible block.
    static func parse(manifestData data: Data) -> RadarHistoryInfo? {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let block = root["history"] as? [String: Any] else { return nil }
        return parse(block: block)
    }

    static func parse(block: [String: Any]) -> RadarHistoryInfo? {
        guard let hours = integer(block["hours"]), (1...maximumHours).contains(hours),
              let expected = integer(block["expected"]), (0...100_000).contains(expected),
              let present = integer(block["present"]), (0...expected).contains(present),
              let complete = boolean(block["complete"]) else { return nil }
        var oldest: Date?
        switch block["oldest"] {
        case nil, is NSNull: oldest = nil
        case let text as String:
            guard let date = DWDRequest.date(text) else { return nil }
            oldest = date
        default: return nil
        }
        var gaps: [RadarHistoryGap] = []
        switch block["gaps"] {
        case nil: break
        case let list as [Any]:
            guard list.count <= maximumGaps else { return nil }
            for item in list {
                guard let entry = item as? [String: Any],
                      let fromText = entry["from"] as? String, let from = DWDRequest.date(fromText),
                      let toText = entry["to"] as? String, let to = DWDRequest.date(toText),
                      let slots = integer(entry["slots"]), (1...100_000).contains(slots), from <= to else { return nil }
                if let last = gaps.last, from <= last.to { return nil }
                gaps.append(RadarHistoryGap(from: from, to: to, slots: slots))
            }
        default: return nil
        }
        return RadarHistoryInfo(hours: hours, oldest: oldest, expected: expected, present: present, complete: complete,
                                gaps: gaps, gapsTruncated: boolean(block["gaps_truncated"]) ?? false)
    }

    /// JSON numbers only (a text or a boolean is not a count).
    private static func integer(_ value: Any?) -> Int? {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
        return Int(exactly: number.doubleValue)
    }

    private static func boolean(_ value: Any?) -> Bool? {
        guard let number = value as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID() else { return nil }
        return number.boolValue
    }
}

/// A hole in the timeline: grid times without an image, `from` and `to` inclusive. `afterIndex` is the index of the
/// slot before the hole (`-1`: the hole lies before the oldest slot, i.e. the source does not reach back that far).
struct TimelineGap: Equatable, Sendable {
    let afterIndex: Int
    let from: Date
    let to: Date
    let slots: Int
}

/// Holes of a timeline. Holes between two slots come from the slots themselves (what the slider really offers);
/// the part before the oldest slot comes from the backend's `history` block. Nothing is interpolated or filled.
struct RadarTimelineGaps: Equatable, Sendable {
    let gaps: [TimelineGap]

    /// A spacing larger than this many steps counts as a hole (tolerates small jitter of slot times).
    static let tolerance = 1.5

    init(dates: [Date], stepMinutes: Int, history: RadarHistoryInfo?, windowStart: Date? = nil) {
        let step = Double(max(stepMinutes, 1)) * 60
        var result: [TimelineGap] = []
        // The source reaches back less far than the window: only when the oldest slot shown IS the oldest that exists
        // (a shorter user choice hides the shortfall, so it is not claimed).
        if let history, let oldest = history.oldest, let first = dates.first, abs(first.timeIntervalSince(oldest)) < 1,
           let lead = history.gaps.first(where: { abs($0.to.addingTimeInterval(step).timeIntervalSince(oldest)) < 1 }) {
            // Only the part inside the chosen past counts: 48 h chosen, 72 h reported by the server -> from 48 h back.
            if let windowStart, windowStart > lead.from {
                let slots = Int((lead.to.timeIntervalSince(windowStart) / step).rounded()) + 1
                if slots >= 1 { result.append(TimelineGap(afterIndex: -1, from: windowStart, to: lead.to, slots: slots)) }
            } else {
                result.append(TimelineGap(afterIndex: -1, from: lead.from, to: lead.to, slots: lead.slots))
            }
        }
        if dates.count > 1 {
            for index in 0..<(dates.count - 1) {
                let delta = dates[index + 1].timeIntervalSince(dates[index])
                guard delta > step * Self.tolerance else { continue }
                result.append(TimelineGap(afterIndex: index, from: dates[index].addingTimeInterval(step),
                                          to: dates[index + 1].addingTimeInterval(-step),
                                          slots: max(1, Int((delta / step).rounded()) - 1)))
            }
        }
        gaps = result
    }

    static let empty = RadarTimelineGaps(dates: [], stepMinutes: 5, history: nil)

    var isEmpty: Bool { gaps.isEmpty }
    /// Holes between two slots (the ones the slider shows as marks).
    var inner: [TimelineGap] { gaps.filter { $0.afterIndex >= 0 } }
    /// The hole directly before slot `index` (index 0: before the oldest slot).
    func before(index: Int) -> TimelineGap? { gaps.first { $0.afterIndex == index - 1 } }
    /// The hole directly after slot `index`.
    func after(index: Int) -> TimelineGap? { gaps.first { $0.afterIndex == index } }
}
