import Foundation

/// What the bar on the bottom edge of the forecast header shows. Pure logic (no UI) so it can be tested.
enum UpdateProgressDisplay: Equatable {
    /// No update runs (also after success, an unchanged answer, a failure or a cancellation).
    case hidden
    /// An update runs but reports no total size: the bar runs through, there is no number.
    case running
    /// Every request of the load reports its size: the fill is the progress (0...1), the percent is shown on the right.
    case measured(Double)

    /// The radar part of an update (manifest, tiles) reports no total, so as long as it runs the whole update is not
    /// measurable; a percent for the forecast alone would pass for the progress of everything.
    static func make(isForecastLoading: Bool, isRadarLoading: Bool, reading: LoadProgress.Reading) -> UpdateProgressDisplay {
        guard isForecastLoading || isRadarLoading else { return .hidden }
        if isRadarLoading { return .running }
        if case .measured(let value) = reading { return .measured(min(max(value, 0), 1)) }
        return .running
    }

    /// Whole percent, rounded down: "100 %" only when the load is really finished.
    static func percentText(_ fraction: Double) -> String {
        let clamped = min(max(fraction, 0), 1)
        return (floor(clamped * 100) / 100).formatted(.percent.precision(.fractionLength(0)))
    }

    /// Moving part of the running bar as a share of the width (0...1) for a phase in 0...1 (one pass left to right).
    static func sweepSegment(phase: Double) -> ClosedRange<Double> {
        let width = 0.35
        let start = -width + (1 + width) * min(max(phase, 0), 1)
        return max(start, 0)...min(start + width, 1)
    }
}
