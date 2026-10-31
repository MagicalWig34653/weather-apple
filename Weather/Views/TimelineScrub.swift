import CoreGraphics
import Foundation
import SwiftUI

/// Pure logic for fine scrubbing: the further the finger is moved vertically away from the slider,
/// the smaller the share of horizontal finger movement that is applied (as in Apple's video scrubber).
/// Kept free of UI so the stage thresholds and the relative calculation are unit-testable.
enum ScrubStage: Int, CaseIterable, Comparable, Sendable {
    case normal, half, quarter, fine

    static func < (lhs: ScrubStage, rhs: ScrubStage) -> Bool { lhs.rawValue < rhs.rawValue }

    /// Share of the horizontal finger movement that moves the position.
    var factor: Double {
        switch self {
        case .normal: 1
        case .half: 0.5
        case .quarter: 0.25
        case .fine: 0.1
        }
    }

    /// Vertical distance in points beyond the slider's own height at which this stage begins (at default type size).
    var enterDistance: CGFloat {
        switch self {
        case .normal: 0
        case .half: 40
        case .quarter: 90
        case .fine: 150
        }
    }

    /// Short German feedback while dragging; `nil` for the normal stage.
    var label: String? {
        switch self {
        case .normal: nil
        case .half: "Halbe Geschwindigkeit"
        case .quarter: "Viertel-Geschwindigkeit"
        case .fine: "Feinsteuerung"
        }
    }

    /// Going back to a coarser stage needs this much margin (points) to avoid flicker at a threshold.
    static let hysteresis: CGFloat = 10

    /// Stage for a vertical distance. `scale` widens the thresholds for larger Dynamic Type (>= 1).
    static func stage(forDistance distance: CGFloat, previous: ScrubStage = .normal, scale: CGFloat = 1) -> ScrubStage {
        let scale = max(1, scale)
        var stage = previous
        while let next = ScrubStage(rawValue: stage.rawValue + 1), distance >= next.enterDistance * scale { stage = next }
        while stage != .normal, let coarser = ScrubStage(rawValue: stage.rawValue - 1),
              distance < stage.enterDistance * scale - hysteresis * scale { stage = coarser }
        return stage
    }
}

/// One drag from touch-down to lift. The position is fractional (in slots) and only the movement
/// since the last event is scaled, so a stage change never makes the thumb jump.
struct ScrubSession: Equatable {
    private(set) var position: Double
    private(set) var stage: ScrubStage = .normal
    private var lastX: CGFloat
    let count: Int

    /// Touching near the thumb keeps the current slot; touching the track elsewhere jumps there (like a normal slider).
    init(touchX: CGFloat, currentIndex: Int, trackWidth: CGFloat, inset: CGFloat, count: Int, grabRadius: CGFloat = 22) {
        self.count = max(count, 1)
        self.lastX = touchX
        let current = Double(min(max(currentIndex, 0), self.count - 1))
        let span = Double(self.count - 1)
        let thumbX = inset + CGFloat(span > 0 ? current / span : 0) * trackWidth
        if abs(touchX - thumbX) <= grabRadius || trackWidth <= 0 {
            position = current
        } else {
            let fraction = min(max(Double((touchX - inset) / trackWidth), 0), 1)
            position = fraction * span
        }
    }

    var index: Int { TimelineSlot.index(for: position, count: count) }

    /// Applies the finger movement since the last event with the factor of the (possibly new) stage.
    @discardableResult
    mutating func update(x: CGFloat, verticalDistance: CGFloat, trackWidth: CGFloat, scale: CGFloat = 1) -> Int {
        stage = ScrubStage.stage(forDistance: verticalDistance, previous: stage, scale: scale)
        if trackWidth > 0, x.isFinite {
            let delta = Double((x - lastX) / trackWidth) * Double(count - 1) * stage.factor
            position = min(max(position + delta, 0), Double(count - 1))
        }
        if x.isFinite { lastX = x }
        return index
    }
}

/// Animation range: from (reference - min(chosen past, 3 h)) to the end of the forecast.
/// The slider itself stays usable over the whole chosen past.
enum PlaybackWindow {
    static let maximumPast: TimeInterval = 3 * 3600

    /// First slot of the window; slots are compared by time, so gaps and a variable slot count are fine.
    static func startIndex(dates: [Date], reference: Date, pastHours: Int) -> Int {
        let past = min(Double(max(pastHours, 0)) * 3600, maximumPast)
        let cutoff = reference.addingTimeInterval(-past)
        return dates.firstIndex { $0 >= cutoff } ?? 0
    }

    /// Next frame while playing: one step forward, from the window end (or before the window) to its start.
    static func nextIndex(after index: Int, dates: [Date], reference: Date, pastHours: Int) -> Int {
        guard !dates.isEmpty else { return 0 }
        let start = startIndex(dates: dates, reference: reference, pastHours: pastHours)
        guard index >= start, index + 1 < dates.count else { return start }
        return index + 1
    }
}

/// German VoiceOver text for the timeline slider (value, step and move logic), free of UI so it is unit-testable.
enum TimelineAccessibility {
    /// "HH:mm, Messung" / "Vorhersage"; names the day (e.g. "Fr., 30. Okt., 23:55, Messung") when it is not the reference day.
    static func value(date: Date?, isForecast: Bool, reference: Date?, calendar: Calendar = .current,
                      locale: Locale = Locale(identifier: "de_DE")) -> String {
        guard let date else { return "Unbekannt" }
        var text = date.formatted(.dateTime.hour().minute().locale(locale))
        if let reference, !calendar.isDate(date, inSameDayAs: reference) {
            text = date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).locale(locale)) + ", " + text
        }
        return "\(text), \(isForecast ? "Vorhersage" : "Messung")"
    }

    /// Index after a VoiceOver increment (+1) or decrement (-1); stays within the slots.
    static func adjusted(index: Int, by direction: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return min(max(index + direction, 0), count - 1)
    }
}

/// Drag-gesture slider in the look of the system slider (capsule track, glass thumb) with fine scrubbing.
struct TimelineScrubSlider: View {
    let count: Int
    let displayedIndex: Int
    let onScrub: (Int) -> Void
    let onEnd: () -> Void
    @Binding var stage: ScrubStage?
    @State private var session: ScrubSession?
    @ScaledMetric(relativeTo: .body) private var distanceScale: CGFloat = 1

    private let thumb: CGFloat = 28
    private let height: CGFloat = 44

    var body: some View {
        GeometryReader { geometry in
            let trackWidth = max(geometry.size.width - thumb, 1)
            let fraction = count > 1 ? CGFloat(min(max(displayedIndex, 0), count - 1)) / CGFloat(count - 1) : 0
            ZStack(alignment: .leading) {
                Capsule().fill(.secondary.opacity(0.3)).frame(height: 4).padding(.horizontal, thumb / 2)
                Capsule().fill(Color.accentColor).frame(width: thumb / 2 + trackWidth * fraction, height: 4)
                Circle().fill(.clear)
                    .frame(width: thumb, height: thumb)
                    .glassEffect(.regular.interactive(), in: Circle())
                    .scaleEffect(session == nil ? 1 : 1.12)
                    .offset(x: trackWidth * fraction)
            }
            .frame(width: geometry.size.width, height: height)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { value in
                    if session == nil {
                        session = ScrubSession(touchX: value.startLocation.x, currentIndex: displayedIndex,
                                               trackWidth: trackWidth, inset: thumb / 2, count: count)
                    }
                    let distance = max(0, abs(value.location.y - height / 2) - height / 2)
                    let index = session?.update(x: value.location.x, verticalDistance: distance,
                                                trackWidth: trackWidth, scale: distanceScale) ?? displayedIndex
                    stage = session?.stage
                    onScrub(index)
                }
                .onEnded { _ in
                    session = nil
                    stage = nil
                    onEnd()
                })
        }
        .frame(minWidth: 50, minHeight: height, maxHeight: height)
    }
}
