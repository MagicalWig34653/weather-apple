import Foundation

/// Short lines for the slot the slider shows now: which holes lie directly before and after it.
enum TimelineGapText {
    static func lines(for index: Int, gaps: RadarTimelineGaps, calendar: Calendar = .current, locale: Locale = .current) -> [String] { [] }
    static func range(_ gap: TimelineGap, calendar: Calendar = .current, locale: Locale = .current) -> String { "" }
}
