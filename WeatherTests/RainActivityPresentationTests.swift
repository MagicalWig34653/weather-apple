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

    private func p(_ s: RainActivityAttributes.ContentState, stale: Bool = false, at: Date? = nil, local: Int? = nil) -> RainActivityPresentation {
        RainActivityPresentation(state: s, contextIsStale: stale, now: at ?? now, localRadiusKm: local)
    }

    // MARK: Hero

    func testStartsInWithFutureEventIsCountdownWithSmallLabel() {
        let pr = p(state(.startsIn, in: 8))
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
        let pr = p(state(.endsIn, in: 5))
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

    func testStaleBoundaryIsExactlyTwentyMinutes() {
        XCTAssertEqual(p(state(.raining, ageMinutes: 19.9)).tone, .rain)
        XCTAssertEqual(p(state(.raining, ageMinutes: 20)).tone, .stale)
    }

    func testCountdownTurnsIntoStatementAfterTheEvent() {
        let s = state(.startsIn, in: 8)
        XCTAssertEqual(p(s, at: now.addingTimeInterval(7 * 60)).hero, .countdown(label: "Regen in", target: now.addingTimeInterval(480)))
        XCTAssertEqual(p(s, at: now.addingTimeInterval(8 * 60)).hero, .statement("Regen gleich"))
    }

    // MARK: Region on the Watch card

    func testRegionKeepsPointHeroAndAddsShortShare() {
        let pr = p(state(.startsIn, in: 12, wet: 0, peak: 34, radius: 10))
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
