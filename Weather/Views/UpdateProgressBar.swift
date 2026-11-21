import SwiftUI

/// Thin bar on the bottom edge of the forecast header while data is updated. Decorative for VoiceOver: the header carries
/// the percent as its accessibility value and its text never changes. Fill = progress where the size is known ("measured"),
/// else a segment runs through the whole width (no number). With Reduce Motion nothing moves: the fill steps without
/// animation, an unmeasured update shows the whole bar at a lower opacity.
struct UpdateProgressBar: View {
    let display: UpdateProgressDisplay
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    static let height: CGFloat = 3
    private static let sweepSeconds = 1.4

    /// Debug builds: `-UITestReduceMotion` forces the reduced-motion branch (the simulator has no launch switch for the system setting).
    private static var forcedReduceMotion: Bool {
        #if DEBUG
        return CommandLine.arguments.contains("-UITestReduceMotion")
        #else
        return false
        #endif
    }

    private static var exposedForUITests: Bool {
        #if DEBUG
        return ForecastUITestStub.mode != nil
        #else
        return false
        #endif
    }

    private var reduceMotion: Bool { systemReduceMotion || Self.forcedReduceMotion }

    /// Test-visible state: `measured:<percent>`, `running`, `running-static`.
    private var stateDescription: String {
        switch display {
        case .hidden: "hidden"
        case .running: reduceMotion ? "running-static" : "running"
        case .measured(let value): "measured:\(Int(floor(value * 100)))"
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle().fill(.primary.opacity(0.18))
                switch display {
                case .hidden:
                    EmptyView()
                case .measured(let value):
                    Rectangle().fill(.primary)
                        .frame(width: geometry.size.width * value)
                        .animation(reduceMotion ? nil : .linear(duration: 0.12), value: value)
                case .running:
                    if reduceMotion {
                        Rectangle().fill(.primary.opacity(0.6))
                    } else {
                        TimelineView(.animation) { context in
                            let phase = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: Self.sweepSeconds) / Self.sweepSeconds
                            let segment = UpdateProgressDisplay.sweepSegment(phase: phase)
                            Rectangle().fill(.primary)
                                .frame(width: geometry.size.width * (segment.upperBound - segment.lowerBound))
                                .offset(x: geometry.size.width * segment.lowerBound)
                        }
                    }
                }
            }
        }
        .frame(height: Self.height)
        .allowsHitTesting(false)
        .accessibilityElement()
        .accessibilityIdentifier("update-progress-bar")
        .accessibilityValue(stateDescription)
        .accessibilityHidden(!Self.exposedForUITests)
    }
}
