import XCTest
@testable import Weather

/// Presentation of one Live-Activity state for design A (tinted glass): lock screen, Dynamic Island, Watch Smart Stack.
/// Texts are German here (the host app bundle has no widget table, `value:` defaults apply); en/de parity is covered by
/// `tools/check_l10n.sh --strict`.
final class RainActivityPresentationTests: XCTestCase {
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func state(_ phase: RainActivityAttributes.Phase, in minutes: Double? = nil, ageMinutes: Double = 4,
                       maxClass: Int = 2, wet: Int? = nil, peak: Int? = nil, radius: Int? = nil) -> RainActivityAttributes.ContentState {
        .init(phase: phase, eventDate: minutes.map { now.addingTimeInterval($0 * 60) }, intensityClass: maxClass,
              referenceTime: now.addingTimeInterval(-ageMinutes * 60), wetSharePercent: wet, peakSharePercent: peak,
              regionRadiusKm: radius)
    }

    /// Event `seconds` from now. `trusted` = the content declares `staleDate` = event time (what the app sets when it starts an activity).
    private func timed(_ phase: RainActivityAttributes.Phase, seconds: Double, trusted: Bool, wet: Int? = nil, peak: Int? = nil,
                       radius: Int? = nil) -> RainActivityAttributes.ContentState {
        var s = RainActivityAttributes.ContentState(phase: phase, eventDate: now.addingTimeInterval(seconds), intensityClass: 2,
                                                    referenceTime: now.addingTimeInterval(-60), wetSharePercent: wet,
                                                    peakSharePercent: peak, regionRadiusKm: radius)
        if trusted { s.staleDate = s.eventDate }
        return s
    }

    private func p(_ s: RainActivityAttributes.ContentState, stale: Bool = false, at: Date? = nil, local: Int? = nil) -> RainActivityPresentation {
        RainActivityPresentation(state: s, contextIsStale: stale, now: at ?? now, localRadiusKm: local)
    }

    // MARK: Hero

    func testStartsInWithFutureEventIsCountdownWithSmallLabel() {
        let pr = p(timed(.startsIn, seconds: 480, trusted: true))
        XCTAssertEqual(pr.hero, .countdown(label: "Regen in", target: now.addingTimeInterval(480)))
        XCTAssertNil(pr.heroDetail)
        XCTAssertEqual(pr.tone, .rain)
    }

    func testStartsInWithPassedEventIsStatement() {
        let pr = p(state(.startsIn, in: -1))
        XCTAssertEqual(pr.hero, .statement("Regen gleich"))
        XCTAssertNil(pr.countdownTarget)
    }

    func testEndsInUsesEndsLabelNotHeadline() {
        let pr = p(timed(.endsIn, seconds: 300, trusted: true))
        XCTAssertEqual(pr.hero, .countdown(label: "Endet in", target: now.addingTimeInterval(300)))
        XCTAssertEqual(p(state(.endsIn, in: 0)).hero, .statement("Endet gleich"))
    }

    func testRainingIsStatementWithOpenEnd() {
        let pr = p(state(.raining))
        XCTAssertEqual(pr.hero, .statement("Es regnet"))
        XCTAssertEqual(pr.heroDetail, "Ende nicht absehbar")
        XCTAssertEqual(pr.tone, .rain)
    }

    func testDryIsGreenToneStatement() {
        let pr = p(state(.dry))
        XCTAssertEqual(pr.hero, .statement("Trocken"))
        XCTAssertEqual(pr.heroDetail, "Vorerst kein Regen erwartet")
        XCTAssertEqual(pr.tone, .dry)
    }

    func testStaleNeverCountsDownNorReadsAsDry() {
        // by age (> 20 min), by context flag, and with a future event date: always the orange statement.
        for pr in [p(state(.startsIn, in: 8, ageMinutes: 25)), p(state(.startsIn, in: 8), stale: true), p(state(.dry), stale: true)] {
            XCTAssertEqual(pr.hero, .statement("Daten veraltet"))
            XCTAssertEqual(pr.heroDetail, "Keine verlässliche Aussage")
            XCTAssertEqual(pr.tone, .stale)
            XCTAssertNil(pr.countdownTarget)
        }
    }

    /// Lino/Brain 20.11.: "0:00" stood frozen after the event (the system does not re-run the view at the event time, only when the
    /// activity turns stale). With the activity's stale date set to the event time, the context flag arrives at the event: the card then
    /// must read "Endet gleich"/"Regen gleich" (data is not old), never "Daten veraltet" and never a frozen countdown.
    func testContextStaleAtTheEventReadsAsImminentNotOutdated() {
        for (phase, text) in [(RainActivityAttributes.Phase.endsIn, "Endet gleich"), (.startsIn, "Regen gleich")] {
            let pr = p(state(phase, in: 0), stale: true)
            XCTAssertEqual(pr.hero, .statement(text))
            XCTAssertEqual(pr.tone, .rain)
            XCTAssertNil(pr.countdownTarget)
            XCTAssertNil(pr.heroDetail)
        }
    }

    func testContextStaleBeforeTheEventOrOtherPhasesOrOldDataStaysOutdated() {
        XCTAssertEqual(p(state(.endsIn, in: 3), stale: true).tone, .stale, "event not reached: still outdated")
        XCTAssertEqual(p(state(.raining), stale: true).tone, .stale)
        XCTAssertEqual(p(state(.dry, in: -1), stale: true).tone, .stale)
        XCTAssertEqual(p(state(.endsIn, in: -1, ageMinutes: 25), stale: true).tone, .stale, "older than 20 minutes: outdated")
    }

    func testActivityStaleDateIsTheEventTimeWhileACountdownRuns() {
        let e = state(.endsIn, in: 5)
        XCTAssertEqual(e.activityStaleDate(now: now), now.addingTimeInterval(300))
        XCTAssertEqual(state(.startsIn, in: 30).activityStaleDate(now: now), state(.startsIn, in: 30).effectiveStaleDate, "event after the 20 min limit")
        XCTAssertEqual(state(.endsIn, in: -1).activityStaleDate(now: now), state(.endsIn, in: -1).effectiveStaleDate, "event already passed")
        XCTAssertEqual(state(.raining).activityStaleDate(now: now), state(.raining).effectiveStaleDate)
    }

    func testStaleBoundaryIsExactlyTwentyMinutes() {
        XCTAssertEqual(p(state(.raining, ageMinutes: 19.9)).tone, .rain)
        XCTAssertEqual(p(state(.raining, ageMinutes: 20)).tone, .stale)
    }

    func testCountdownTurnsIntoStatementAfterTheEvent() {
        let s = timed(.startsIn, seconds: 480, trusted: true)
        XCTAssertEqual(p(s, at: now.addingTimeInterval(5 * 60)).hero, .countdown(label: "Regen in", target: now.addingTimeInterval(480)))
        XCTAssertEqual(p(s, at: now.addingTimeInterval(6 * 60)).hero, .statement("Regen gleich"), "120 s left: below the minimum, no countdown")
        XCTAssertEqual(p(s, at: now.addingTimeInterval(8 * 60)).hero, .statement("Regen gleich"))
    }

    // MARK: Never a frozen "0:00" (Brain 20.11.2026: lock screen still showed "Endet in 0:00" 78 s after the event)

    func testClockTargetForAllRemainingTimes() {
        for phase in [RainActivityAttributes.Phase.startsIn, .endsIn] {
            for seconds in [-3_600.0, -1, 0, 30, 90, 119, 121, 149] {
                for trusted in [true, false] {
                    XCTAssertNil(p(timed(phase, seconds: seconds, trusted: trusted)).clockTarget, "\(phase) \(seconds) s trusted=\(trusted)")
                }
            }
            for seconds in [150.0, 151, 300, 1_000] {
                let target = now.addingTimeInterval(seconds)
                XCTAssertNil(p(timed(phase, seconds: seconds, trusted: true)).clockTarget)
                let clock = p(timed(phase, seconds: seconds, trusted: false))
                XCTAssertEqual(clock.clockTarget, target)
                if case .clock(_, let d) = clock.hero { XCTAssertEqual(d, target) } else { XCTFail("clock expected at \(seconds) s") }
            }
        }
    }

    func testClockLabelsAndNoTimerForRemoteUpdates() {
        XCTAssertEqual(p(timed(.startsIn, seconds: 600, trusted: false)).hero.clockLabel, "Regen ab")
        XCTAssertEqual(p(timed(.endsIn, seconds: 600, trusted: false)).hero.clockLabel, "Endet um")
        XCTAssertNil(p(timed(.startsIn, seconds: 600, trusted: true)).hero.clockLabel)
    }

    /// Event far away but not trusted, then the clock passes the event without any re-render: a clock time stays valid text.
    func testClockTimeStaysTheSameAfterTheEvent() {
        let s = timed(.startsIn, seconds: 600, trusted: false)
        let target = now.addingTimeInterval(600)
        XCTAssertEqual(p(s, at: now).hero, .clock(label: "Regen ab", date: target))
        XCTAssertEqual(p(s, at: now.addingTimeInterval(601)).hero, .statement("Regen gleich"), "if the view is re-run after the event")
    }

    func testStaleAtEventDoesNotMeanOutdatedAndKeepsTwentyMinuteAgeLimit() {
        let s = timed(.startsIn, seconds: 300, trusted: true)
        XCTAssertTrue(s.staleAtEvent)
        XCTAssertFalse(s.isStale(at: now.addingTimeInterval(301)), "the event-time stale date is no age limit")
        XCTAssertEqual(s.effectiveStaleDate, s.referenceTime.addingTimeInterval(1_200))
        XCTAssertTrue(s.isStale(at: s.referenceTime.addingTimeInterval(1_200)))
        var other = timed(.startsIn, seconds: 300, trusted: false); other.staleDate = now.addingTimeInterval(100)
        XCTAssertFalse(other.staleAtEvent, "an earlier server stale date is an age limit")
        XCTAssertTrue(other.isStale(at: now.addingTimeInterval(101)))
    }

    func testMarkingStaleAtEventOnlyForARunningCountdown() {
        let running = timed(.startsIn, seconds: 300, trusted: false)
        let marked = running.markingStaleAtEvent(now: now)
        XCTAssertEqual(marked.staleDate, running.eventDate); XCTAssertTrue(marked.staleAtEvent)
        XCTAssertEqual(marked.markingStaleAtEvent(now: now), marked, "idempotent")
        for s in [state(.raining), state(.dry), timed(.endsIn, seconds: -5, trusted: false), state(.startsIn, in: 30)] {
            XCTAssertNil(s.markingStaleAtEvent(now: now).staleDate, "no running countdown within the 20 minutes: unchanged")
        }
    }

    func testRegionAndStaleCasesKeepTheNewRule() {
        XCTAssertEqual(p(timed(.startsIn, seconds: 90, trusted: true, wet: 0, peak: 34, radius: 10)).hero, .statement("Regen gleich"))
        XCTAssertEqual(p(timed(.startsIn, seconds: 900, trusted: false, wet: 0, peak: 34, radius: 10)).clockTarget, now.addingTimeInterval(900))
        XCTAssertNil(p(timed(.startsIn, seconds: 900, trusted: false), stale: true).clockTarget, "stale: orange statement, no clock")
        XCTAssertEqual(p(timed(.startsIn, seconds: 900, trusted: false), stale: true).tone, .stale)
    }

    // MARK: Region on the Watch card

    func testRegionKeepsPointHeroAndAddsShortShare() {
        let pr = p(timed(.startsIn, seconds: 720, trusted: true, wet: 0, peak: 34, radius: 10))
        XCTAssertEqual(pr.hero, .countdown(label: "Regen in", target: now.addingTimeInterval(720)))
        XCTAssertEqual(pr.watchShareText, "bis zu 34 % nass")
        XCTAssertEqual(p(state(.raining, wet: 34, peak: 60, radius: 10)).watchShareText, "34 % nass")
    }

    func testPointHasNoShareAndStaleRegionHasNone() {
        XCTAssertNil(p(state(.startsIn, in: 8)).watchShareText)
        XCTAssertNil(p(state(.raining, wet: 34, peak: 60, radius: 10), stale: true).watchShareText)
        XCTAssertNil(p(state(.dry, wet: 0, peak: 0, radius: 10)).watchShareText)
    }

    func testWatchTitleIsNameOnlyForPlacesAndRegions() {
        XCTAssertEqual(p(state(.startsIn, in: 8)).watchTitle(name: "Zuhause"), "Zuhause")
        XCTAssertNil(p(state(.startsIn, in: 8)).watchTitle(name: nil))
        let region = p(state(.raining, wet: 34, peak: 60, radius: 10))
        XCTAssertEqual(region.watchTitle(name: "Umland"), "Umland")
        XCTAssertEqual(region.watchTitle(name: nil), "Umkreis 10 km")
    }

    func testRegionRadiusFallsBackToLocalRadius() {
        let pr = p(state(.raining, wet: 34, peak: 60), local: 25)
        XCTAssertEqual(pr.watchTitle(name: nil), "Umkreis 25 km")
    }

    // MARK: Region texts (Shared, both languages)

    func testShortShareTextsInBothLanguages() {
        func r(_ locale: String) -> RainActivityRegionPresentation {
            RainActivityRegionPresentation(state: state(.startsIn, in: 12, wet: 0, peak: 34, radius: 10), isStale: false,
                                           localRadiusKm: nil, locale: locale)
        }
        XCTAssertEqual(r("de").shortShareText, "bis zu 34 % nass")
        XCTAssertEqual(r("en").shortShareText, "up to 34% wet")
        XCTAssertEqual(r("de").watchTitle(name: nil), "Umkreis 10 km")
        XCTAssertEqual(r("en").watchTitle(name: "Home area"), "Home area")
    }

    // MARK: Island texts keep working

    func testCompactLabelsAndSymbols() {
        XCTAssertEqual(p(state(.raining)).compactLabel, "Regen")
        XCTAssertEqual(p(state(.raining, wet: 34, peak: 60, radius: 10)).compactLabel, "34 %")
        XCTAssertEqual(p(state(.raining), stale: true).compactLabel, "Veraltet")
        XCTAssertEqual(p(state(.dry), stale: true).symbol, "clock.badge.exclamationmark")
    }
}

private extension RainActivityPresentation.Hero {
    var clockLabel: String? { if case .clock(let label, _) = self { return label } else { return nil } }
}
