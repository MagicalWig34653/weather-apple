import XCTest
@testable import Weather

final class TimelineScrubTests: XCTestCase {
    func testStagesByDistance() {
        XCTAssertEqual(ScrubStage.stage(forDistance: 0), .normal)
        XCTAssertEqual(ScrubStage.stage(forDistance: 39), .normal)
        XCTAssertEqual(ScrubStage.stage(forDistance: 40), .half)
        XCTAssertEqual(ScrubStage.stage(forDistance: 90), .quarter)
        XCTAssertEqual(ScrubStage.stage(forDistance: 400), .fine)
        XCTAssertEqual(ScrubStage.stage(forDistance: 40, scale: 2), .normal)
    }

    func testHysteresisOnWayBack() {
        XCTAssertEqual(ScrubStage.stage(forDistance: 85, previous: .quarter), .quarter)
        XCTAssertEqual(ScrubStage.stage(forDistance: 79, previous: .quarter), .half)
        XCTAssertEqual(ScrubStage.stage(forDistance: 0, previous: .fine), .normal)
    }

    func testRelativeMovementAndNoJumpOnStageChange() {
        var s = ScrubSession(touchX: 100, currentIndex: 50, trackWidth: 200, inset: 0, count: 101)
        XCTAssertEqual(s.index, 50)
        s.update(x: 120, verticalDistance: 0, trackWidth: 200)
        XCTAssertEqual(s.position, 60, accuracy: 0.001)
        s.update(x: 120, verticalDistance: 100, trackWidth: 200)
        XCTAssertEqual(s.position, 60, accuracy: 0.001)
        XCTAssertEqual(s.stage, .quarter)
        s.update(x: 140, verticalDistance: 100, trackWidth: 200)
        XCTAssertEqual(s.position, 62.5, accuracy: 0.001)
        s.update(x: 140, verticalDistance: 0, trackWidth: 200)
        XCTAssertEqual(s.position, 62.5, accuracy: 0.001)
    }

    func testClampsAndRounds() {
        var s = ScrubSession(touchX: 0, currentIndex: 0, trackWidth: 100, inset: 0, count: 11)
        s.update(x: -50, verticalDistance: 0, trackWidth: 100)
        XCTAssertEqual(s.index, 0)
        s.update(x: 500, verticalDistance: 0, trackWidth: 100)
        XCTAssertEqual(s.index, 10)
        s.update(x: .nan, verticalDistance: 0, trackWidth: 100)
        XCTAssertEqual(s.index, 10)
    }

    func testTouchAwayFromThumbJumpsThere() {
        let s = ScrubSession(touchX: 100, currentIndex: 0, trackWidth: 200, inset: 0, count: 11)
        XCTAssertEqual(s.index, 5)
    }

    private let ref = Date(timeIntervalSince1970: 1_800_000_000)
    private func dates(pastSteps: Int, futureSteps: Int, step: TimeInterval = 300) -> [Date] {
        (-pastSteps...futureSteps).map { ref.addingTimeInterval(Double($0) * step) }
    }

    func testPlaybackWindowStart() {
        let d = dates(pastSteps: 576, futureSteps: 24) // 48 h past
        XCTAssertEqual(PlaybackWindow.startIndex(dates: d, reference: ref, pastHours: 1), 576 - 12)
        XCTAssertEqual(PlaybackWindow.startIndex(dates: d, reference: ref, pastHours: 2), 576 - 24)
        XCTAssertEqual(PlaybackWindow.startIndex(dates: d, reference: ref, pastHours: 48), 576 - 36)
    }

    func testPlaybackWindowFewHistoryAndGaps() {
        let few = dates(pastSteps: 6, futureSteps: 4)
        XCTAssertEqual(PlaybackWindow.startIndex(dates: few, reference: ref, pastHours: 48), 0)
        var gap = dates(pastSteps: 60, futureSteps: 4)
        gap.removeSubrange(20..<45) // hole inside the 3 h window
        let start = PlaybackWindow.startIndex(dates: gap, reference: ref, pastHours: 6)
        XCTAssertGreaterThanOrEqual(gap[start], ref.addingTimeInterval(-3 * 3600))
        XCTAssertLessThan(gap[start - 1], ref.addingTimeInterval(-3 * 3600))
        XCTAssertEqual(PlaybackWindow.startIndex(dates: [], reference: ref, pastHours: 2), 0)
    }

    func testPlaybackNextIndexLoopsAndJumpsIntoWindow() {
        let d = dates(pastSteps: 100, futureSteps: 10)
        let start = PlaybackWindow.startIndex(dates: d, reference: ref, pastHours: 48)
        XCTAssertEqual(PlaybackWindow.nextIndex(after: start, dates: d, reference: ref, pastHours: 48), start + 1)
        XCTAssertEqual(PlaybackWindow.nextIndex(after: d.count - 1, dates: d, reference: ref, pastHours: 48), start)
        XCTAssertEqual(PlaybackWindow.nextIndex(after: 3, dates: d, reference: ref, pastHours: 48), start)
        XCTAssertEqual(PlaybackWindow.nextIndex(after: 0, dates: [], reference: ref, pastHours: 2), 0)
    }
}

final class TimelineAccessibilityTests: XCTestCase {
    private var cal: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }
    private let ref = Date(timeIntervalSince1970: 1_793_000_000) // fixed reference

    func testValueSameDayHasTimeAndKind() {
        let v = TimelineAccessibility.value(date: ref.addingTimeInterval(300), isForecast: true, reference: ref, calendar: cal)
        XCTAssertTrue(v.hasSuffix(", Vorhersage"), v)
        XCTAssertFalse(v.contains("Okt") || v.contains("Nov"), v)
        let m = TimelineAccessibility.value(date: ref, isForecast: false, reference: ref, calendar: cal)
        XCTAssertTrue(m.hasSuffix(", Messung"), m)
    }

    func testValueNamesOtherDay() {
        let v = TimelineAccessibility.value(date: ref.addingTimeInterval(-86_400), isForecast: false, reference: ref, calendar: cal)
        XCTAssertGreaterThan(v.split(separator: ",").count, 2, v)
    }

    func testValueUnknownWithoutDate() {
        XCTAssertEqual(TimelineAccessibility.value(date: nil, isForecast: false, reference: ref), "Unbekannt")
    }

    func testIncrementDecrementStepsOneSlotAndClamps() {
        XCTAssertEqual(TimelineAccessibility.adjusted(index: 5, by: 1, count: 10), 6)
        XCTAssertEqual(TimelineAccessibility.adjusted(index: 5, by: -1, count: 10), 4)
        XCTAssertEqual(TimelineAccessibility.adjusted(index: 9, by: 1, count: 10), 9)
        XCTAssertEqual(TimelineAccessibility.adjusted(index: 0, by: -1, count: 10), 0)
        XCTAssertEqual(TimelineAccessibility.adjusted(index: 3, by: 1, count: 0), 0)
    }
}
