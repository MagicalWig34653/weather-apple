import Foundation

/// Pure time logic for the point forecast (no network). The 20-minute staleness limit
/// (`RainForecast.maximumAge`) is unchanged; this only decides when to load and what to say.
///
/// A run with nominal time N is expected on the 5-minute UTC grid about N + 3 min; the forecast is
/// requested at N + 200 s. Until a newer run is expected the DWD index and point caches stay in use.
enum ForecastRefreshPolicy {
    /// Request time after the nominal run time.
    static let fetchDelay: TimeInterval = 200
    /// Grace after `fetchDelay` before "the weather service has nothing newer" may be said.
    static let grace: TimeInterval = 60
    /// Fast repeats after a failure or a missing run (like `RadarPollSchedule.backoff`).
    static let backoff: [TimeInterval] = [20, 30, 60]
    /// A failure counts as real only after one repeat also failed.
    static let confirmedFailures = 2
    /// Low Power Mode / Low Data Mode: no fast cadence, at most every 5 minutes.
    static let restrictedInterval: TimeInterval = 300
    static let jitter: TimeInterval = 10
    static let maxFastFailures = 6

    /// Newest run the server is expected to offer at `now`.
    static func expectedRun(at now: Date) -> Date { RadarPollSchedule.nominal(at: now) }

    /// True when the shown run is older than the expected newest one (or nothing is shown).
    static func newRunExpected(shown: Date?, now: Date) -> Bool {
        guard let shown else { return true }
        return shown < expectedRun(at: now)
    }

    /// The service was asked after N + 200 s + grace and had nothing newer than `shown`.
    static func serverBehind(shown: Date, checkedAt: Date?, now: Date) -> Bool {
        let expected = expectedRun(at: now)
        guard shown < expected, let checkedAt else { return false }
        return checkedAt >= expected.addingTimeInterval(fetchDelay + grace)
    }
}

/// Wait times between forecast loads of the visible app.
struct ForecastRefreshSchedule {
    private let random: () -> Double
    private var gapNominal: Date?
    private var gapPolls = 0

    init(random: @escaping () -> Double = { Double.random(in: 0..<1) }) { self.random = random }

    /// - Parameters:
    ///   - shown: run of the forecast shown after the load just made.
    ///   - failures: consecutive failed loads (0 after a success).
    mutating func nextDelay(now: Date, shown: Date?, failures: Int, restricted: Bool) -> TimeInterval {
        let policy = ForecastRefreshPolicy.self
        let expected = policy.expectedRun(at: now)
        let due = expected.addingTimeInterval(policy.fetchDelay)
        let untilNext = due.addingTimeInterval(RadarPollSchedule.gridInterval).timeIntervalSince(now)
        var delay: TimeInterval
        if failures > 0 {
            // Bounded: after a few fast repeats fall back to the restricted cadence instead of a steady loop.
            delay = failures > policy.maxFastFailures ? policy.restrictedInterval : policy.backoff[min(failures - 1, policy.backoff.count - 1)]
        } else if policy.newRunExpected(shown: shown, now: now) {
            if now < due {
                delay = due.timeIntervalSince(now) + random() * policy.jitter
            } else {
                // The run is due but not there yet: bounded fast repeats until the next slot.
                if gapNominal != expected { gapNominal = expected; gapPolls = 0 }
                delay = policy.backoff[min(gapPolls, policy.backoff.count - 1)]
                gapPolls += 1
            }
        } else {
            // Current run shown: wait for the next run (N + 300 s + 200 s).
            delay = untilNext + random() * policy.jitter
        }
        if restricted { delay = max(delay, policy.restrictedInterval) }
        return max(1, delay)
    }
}
