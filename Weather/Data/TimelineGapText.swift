import Foundation

/// Short lines for the slot the slider shows now: which holes lie directly before and after it.
enum TimelineGapText {
    static func lines(for index: Int, gaps: RadarTimelineGaps, calendar: Calendar = .current, locale: Locale = .current) -> [String] {
        var result: [String] = []
        if let gap = gaps.before(index: index) {
            result.append(String(format: NSLocalizedString("TIMELINE_GAP_BEFORE", value: "Davor fehlen Daten: %@", comment: "Timeline: hole before the shown slot"),
                                 range(gap, calendar: calendar, locale: locale)))
        }
        if let gap = gaps.after(index: index) {
            result.append(String(format: NSLocalizedString("TIMELINE_GAP_AFTER", value: "Danach fehlen Daten: %@", comment: "Timeline: hole after the shown slot"),
                                 range(gap, calendar: calendar, locale: locale)))
        }
        return result
    }

    /// "20:20–20:45" within one day; with the weekday on both ends across midnight ("Mi 22:00–Do 04:40").
    static func range(_ gap: TimelineGap, calendar: Calendar = .current, locale: Locale = .current) -> String {
        let time = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).hour().minute()
        let day = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).weekday(.abbreviated)
        if gap.from == gap.to { return gap.from.formatted(time) }
        if calendar.isDate(gap.from, inSameDayAs: gap.to) { return gap.from.formatted(time) + "\u{2013}" + gap.to.formatted(time) }
        return gap.from.formatted(day) + " " + gap.from.formatted(time) + "\u{2013}" + gap.to.formatted(day) + " " + gap.to.formatted(time)
    }
}
