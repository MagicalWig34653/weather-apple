import XCTest
@testable import Weather

/// Brain 20.11.2026: the lock screen still showed "Endet in 0:00" 78 s after the event. `Text(timerInterval:)` stands at "0:00" and the
/// system re-renders a Live Activity at the event time only when it turns stale (earliest ~117 s after the update, measured). So a
/// countdown may only be shown when the content declares `staleDate` = event time AND at least 150 s remain; in every other case the card
/// shows a statement or a clock time, never a ticking timer. Uses only API that exists before the fix (red against de9818a).
final class RainActivityNoFrozenTimerTests: XCTestCase {
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func timed(_ phase: RainActivityAttributes.Phase, seconds: Double, staleAtEvent: Bool) -> RainActivityAttributes.ContentState {
        var s = RainActivityAttributes.ContentState(phase: phase, eventDate: now.addingTimeInterval(seconds), intensityClass: 2,
                                                    referenceTime: now.addingTimeInterval(-60))
        if staleAtEvent { s.staleDate = s.eventDate }
        return s
    }

    private func p(_ s: RainActivityAttributes.ContentState, stale: Bool = false, at: Date? = nil) -> RainActivityPresentation {
        RainActivityPresentation(state: s, contextIsStale: stale, now: at ?? now, localRadiusKm: nil)
    }

    func testNoCountdownBelowTheMinimumForAnyContent() {
        for phase in [RainActivityAttributes.Phase.startsIn, .endsIn] {
            let imminent = phase == .startsIn ? "Regen gleich" : "Endet gleich"
            for seconds in [-3_600.0, -1, 0, 30, 90, 119, 121, 149] {
                for trusted in [true, false] {
                    let pr = p(timed(phase, seconds: seconds, staleAtEvent: trusted))
                    XCTAssertNil(pr.countdownTarget, "\(phase) \(seconds) s trusted=\(trusted)")
                    XCTAssertEqual(pr.hero, .statement(imminent), "\(phase) \(seconds) s trusted=\(trusted)")
                    XCTAssertEqual(pr.tone, .rain)
                }
            }
        }
    }

    func testCountdownOnlyWithTheStaleDateAtTheEventAndEnoughTimeLeft() {
        for phase in [RainActivityAttributes.Phase.startsIn, .endsIn] {
            for seconds in [150.0, 151, 300, 1_000] {
                XCTAssertEqual(p(timed(phase, seconds: seconds, staleAtEvent: true)).countdownTarget, now.addingTimeInterval(seconds))
                XCTAssertNil(p(timed(phase, seconds: seconds, staleAtEvent: false)).countdownTarget,
                             "remote update (stale-date = reference + 20 min): the view is not re-run at the event, a timer would stand at 0:00")
            }
        }
    }

    /// Remote update: stale date far in the future, event in 30 s: at no point of time a timer.
    func testRemoteUpdateWithEventInThirtySecondsNeverShowsATimer() {
        var s = timed(.endsIn, seconds: 30, staleAtEvent: false)
        s.staleDate = now.addingTimeInterval(20 * 60)
        for offset in [0.0, 29, 30, 78, 120, 600] {
            let pr = p(s, at: now.addingTimeInterval(offset))
            XCTAssertNil(pr.countdownTarget, "offset \(offset)")
            XCTAssertEqual(pr.hero, .statement("Endet gleich"))
        }
    }
}
