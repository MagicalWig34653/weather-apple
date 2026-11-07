import XCTest
@testable import Weather

/// Display texts and share logic of a region Live Activity (Shared/RainActivityRegionPresentation.swift).
final class RainActivityRegionPresentationTests: XCTestCase {
    private func state(_ phase: RainActivityAttributes.Phase, wet: Int? = nil, peak: Int? = nil, maxClass: Int = 4,
                       radius: Int? = nil) -> RainActivityAttributes.ContentState {
        .init(phase: phase, intensityClass: maxClass, referenceTime: Date(timeIntervalSinceReferenceDate: 0),
              wetSharePercent: wet, peakSharePercent: peak, regionRadiusKm: radius)
    }

    private func p(_ s: RainActivityAttributes.ContentState, stale: Bool = false, local: Int? = nil, _ locale: String = "de") -> RainActivityRegionPresentation {
        RainActivityRegionPresentation(state: s, isStale: stale, localRadiusKm: local, locale: locale)
    }

    func testRainingShowsCurrentShareAndStrongestClass() {
        let r = p(state(.raining, wet: 34, peak: 60, maxClass: 4, radius: 10))
        XCTAssertEqual(r.shareText, "34 % der Fläche nass")
        XCTAssertEqual(r.intensityText, "Stärkste Stufe 4 (leicht)")
        XCTAssertEqual(r.radiusText, "Umkreis 10 km")
        XCTAssertEqual(r.barFraction ?? 0, 0.34, accuracy: 0.0001)
        XCTAssertEqual(r.compactShareText, "34 %")
        XCTAssertEqual(r.title(name: "Garten"), "Garten · Umkreis 10 km")
        XCTAssertEqual(r.title(name: nil), "Umkreis 10 km")
    }

    func testStartsInShowsPeakShareWithoutBar() {
        let r = p(state(.startsIn, wet: 0, peak: 34, radius: 10))
        XCTAssertEqual(r.shareText, "bis zu 34 % der Fläche nass")
        XCTAssertNil(r.barFraction)
    }

    func testSharesAreClampedAndZeroOrMissingValuesShowNoShare() {
        XCTAssertEqual(p(state(.raining, wet: 250)).share?.percent, 100)
        XCTAssertNil(p(state(.raining, wet: -5)).share)
        XCTAssertNil(p(state(.raining, wet: 0, peak: 0)).shareText)
        XCTAssertNil(p(state(.startsIn)).shareText)
        // raining without a current share falls back to the peak
        XCTAssertEqual(p(state(.raining, wet: 0, peak: 20)).shareText, "bis zu 20 % der Fläche nass")
    }

    func testDryAndStaleHideShareAndClassButKeepRadius() {
        let dry = p(state(.dry, wet: 0, peak: 0, maxClass: 0, radius: 5))
        XCTAssertNil(dry.shareText); XCTAssertNil(dry.intensityText)
        XCTAssertEqual(dry.radiusText, "Umkreis 5 km")
        let stale = p(state(.raining, wet: 50, peak: 70, radius: 10), stale: true)
        XCTAssertNil(stale.shareText); XCTAssertNil(stale.intensityText); XCTAssertNil(stale.barFraction)
        XCTAssertEqual(stale.headline(phase: .raining, isStale: true, hasCountdown: false), "Daten veraltet")
    }

    func testRadiusFallsBackToLocalValueAndIgnoresInvalid() {
        XCTAssertEqual(p(state(.raining, wet: 10), local: 25).radiusKm, 25)
        XCTAssertEqual(p(state(.raining, wet: 10, radius: 10), local: 25).radiusKm, 10, "payload wins")
        XCTAssertNil(p(state(.raining, wet: 10, radius: 0)).radiusKm)
        XCTAssertNil(p(state(.raining, wet: 10)).radiusText)
    }

    func testClassWordsFollowTheSensitivityLevels() {
        func word(_ c: Int) -> String { p(state(.raining, wet: 1, maxClass: c)).intensityText ?? "" }
        XCTAssertTrue(word(1).hasSuffix("(sehr leicht)")); XCTAssertTrue(word(2).hasSuffix("(sehr leicht)"))
        XCTAssertTrue(word(3).hasSuffix("(leicht)")); XCTAssertTrue(word(4).hasSuffix("(leicht)"))
        XCTAssertTrue(word(5).hasSuffix("(mäßig)")); XCTAssertTrue(word(7).hasSuffix("(mäßig)"))
        XCTAssertTrue(word(8).hasSuffix("(stark)")); XCTAssertTrue(word(15).hasSuffix("(stark)"))
        XCTAssertNil(p(state(.raining, wet: 1, maxClass: 0)).intensityText)
    }

    func testHeadlinesPerPhase() {
        let r = p(state(.raining, wet: 1))
        XCTAssertEqual(r.headline(phase: .startsIn, isStale: false, hasCountdown: true), "Regen im Umkreis in")
        XCTAssertEqual(r.headline(phase: .startsIn, isStale: false, hasCountdown: false), "Regen im Umkreis gleich")
        XCTAssertEqual(r.headline(phase: .raining, isStale: false, hasCountdown: false), "Es regnet im Umkreis")
        XCTAssertEqual(r.headline(phase: .endsIn, isStale: false, hasCountdown: true), "Es regnet im Umkreis")
        XCTAssertEqual(r.headline(phase: .dry, isStale: false, hasCountdown: false), "Im Umkreis trocken")
    }

    func testEnglishTexts() {
        let r = p(state(.raining, wet: 34, radius: 10), "en")
        XCTAssertEqual(r.shareText, "34% of the area wet")
        XCTAssertEqual(r.radiusText, "10 km radius")
        XCTAssertEqual(r.intensityText, "Strongest level 4 (light)")
    }
}
