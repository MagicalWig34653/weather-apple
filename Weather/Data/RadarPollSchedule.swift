import Foundation

/// Adaptive poll cadence for `latest.json` (pure time logic, no network).
///
/// The backend publishes on a 5-minute UTC grid; a run with nominal time N appears about
/// N + 3 min (measured 3 to 3.5 min). Around that moment the app asks more often, otherwise rarely.
/// - Window for N: [N + 165 s, N + 300 s] (expected - 15 s ... expected + 120 s), about every 10 s +/- 2 s
///   until `latestReference >= N`.
/// - New run seen: idle cadence (60 s) until the next window starts.
/// - Window over without new run: backoff 20 s, 30 s, then 60 s until the next window.
/// - Low Power Mode / Low Data Mode: idle cadence only, no window.
/// - Failures (timeout, 5xx, invalid): at least 20 s, 30 s, then 60 s, regardless of the window.
struct RadarPollSchedule {
    static let gridInterval: TimeInterval = 300
    static let expectedDelay: TimeInterval = 180
    static let windowLead: TimeInterval = 15
    static let windowTail: TimeInterval = 120
    static let windowInterval: TimeInterval = 10
    static let jitter: TimeInterval = 2
    static let idleInterval: TimeInterval = RadarBackendConfig.pollInterval
    static let backoff: [TimeInterval] = [20, 30, 60]

    /// Returns a value in 0..<1; injectable for tests.
    private let random: () -> Double
    private(set) var consecutiveFailures = 0
    private var gapNominal: Date?
    private var gapPolls = 0

    init(random: @escaping () -> Double = { Double.random(in: 0..<1) }) {
        self.random = random
    }

    /// Nominal grid time N whose window started most recently (UTC grid; the Unix epoch is a grid point).
    static func nominal(at now: Date) -> Date {
        let offset = expectedDelay - windowLead
        let slot = ((now.timeIntervalSince1970 - offset) / gridInterval).rounded(.down)
        return Date(timeIntervalSince1970: slot * gridInterval)
    }

    static func windowStart(for nominal: Date) -> Date { nominal.addingTimeInterval(expectedDelay - windowLead) }
    static func windowEnd(for nominal: Date) -> Date { nominal.addingTimeInterval(expectedDelay + windowTail) }

    private func jittered(_ value: TimeInterval) -> TimeInterval { value + (random() * 2 - 1) * Self.jitter }

    /// Seconds to wait before the next request, given what the last poll found.
    mutating func nextDelay(now: Date, latestReference: Date?, failed: Bool, restricted: Bool) -> TimeInterval {
        consecutiveFailures = failed ? consecutiveFailures + 1 : 0
        let nominal = Self.nominal(at: now)
        let missing = latestReference.map { $0 < nominal } ?? true
        let untilNextWindow = Self.windowStart(for: nominal.addingTimeInterval(Self.gridInterval)).timeIntervalSince(now)

        var delay: TimeInterval
        if restricted {
            delay = jittered(Self.idleInterval)
        } else if missing, now <= Self.windowEnd(for: nominal) {
            delay = jittered(Self.windowInterval)
        } else {
            if missing {
                if gapNominal != nominal { gapNominal = nominal; gapPolls = 0 }
                delay = jittered(Self.backoff[min(gapPolls, Self.backoff.count - 1)])
                gapPolls += 1
            } else {
                delay = jittered(Self.idleInterval)
            }
            // Never sleep past the start of the next window.
            delay = max(1, min(delay, untilNextWindow))
        }
        if consecutiveFailures > 0 {
            delay = max(delay, Self.backoff[min(consecutiveFailures - 1, Self.backoff.count - 1)])
        }
        return delay
    }
}
