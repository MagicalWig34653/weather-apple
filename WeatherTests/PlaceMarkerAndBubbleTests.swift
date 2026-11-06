import CoreGraphics
import CoreLocation
import SwiftUI
import XCTest
@testable import Weather

final class ScrubBubblePlacementTests: XCTestCase {
    private let size = CGSize(width: 100, height: 34)

    func testBubbleSitsAboveTouchPointWithClearance() {
        let result = ScrubBubblePlacement.place(thumbX: 200, bubbleSize: size, bounds: 0...400)
        XCTAssertEqual(result.centerX, 200)
        // Bubble bottom edge (offset + height / 2) is at least the clearance above the touch centre.
        XCTAssertLessThanOrEqual(result.offsetY + size.height / 2, -ScrubBubblePlacement.clearance)
    }

    func testBubbleIsClampedAtLeftAndRightEdge() {
        XCTAssertEqual(ScrubBubblePlacement.place(thumbX: 5, bubbleSize: size, bounds: 0...400).centerX, 50)
        XCTAssertEqual(ScrubBubblePlacement.place(thumbX: 395, bubbleSize: size, bounds: 0...400).centerX, 350)
    }

    func testBubbleWiderThanBoundsIsCentered() {
        XCTAssertEqual(ScrubBubblePlacement.place(thumbX: 10, bubbleSize: size, bounds: 0...60).centerX, 30)
    }

    func testLiftMovesBubbleFurtherUp() {
        let base = ScrubBubblePlacement.place(thumbX: 100, bubbleSize: size, bounds: 0...400)
        let lifted = ScrubBubblePlacement.place(thumbX: 100, bubbleSize: size, bounds: 0...400, lift: 60)
        XCTAssertEqual(lifted.offsetY, base.offsetY - 60)
    }

    func testNonFiniteThumbFallsBackToCenter() {
        XCTAssertEqual(ScrubBubblePlacement.place(thumbX: .nan, bubbleSize: size, bounds: 0...400).centerX, 200)
    }
}

final class ScreenGlowTests: XCTestCase {
    func testGlowTriggersOnlyWhenEnteringForecast() {
        XCTAssertTrue(ScreenGlow.shouldPlay(entered: true, wasShown: false))
        XCTAssertFalse(ScreenGlow.shouldPlay(entered: true, wasShown: true))
        XCTAssertFalse(ScreenGlow.shouldPlay(entered: false, wasShown: false))
    }

    func testReducedMotionStopsRotationAndShortensEffect() {
        XCTAssertGreaterThan(ScreenGlow.rotationDuration(reduceMotion: false), 0)
        XCTAssertEqual(ScreenGlow.rotationDuration(reduceMotion: true), 0)
        XCTAssertLessThanOrEqual(ScreenGlow.totalDuration(reduceMotion: false), 2.5)
        XCTAssertGreaterThanOrEqual(ScreenGlow.totalDuration(reduceMotion: false), 1.5)
        XCTAssertLessThan(ScreenGlow.totalDuration(reduceMotion: true), ScreenGlow.totalDuration(reduceMotion: false))
    }

    func testScrubGlowToneFollowsPastOrFutureWithNowCountingAsPast() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertFalse(ScreenGlow.isForecast(date: now.addingTimeInterval(-300), reference: now))
        XCTAssertFalse(ScreenGlow.isForecast(date: now, reference: now))
        XCTAssertTrue(ScreenGlow.isForecast(date: now.addingTimeInterval(300), reference: now))
    }

    func testScrubGlowUsesBlueForPastAndOrangeForFuture() {
        XCTAssertNotEqual(ScreenGlow.pastColor, ScreenGlow.futureColor)
        XCTAssertEqual(ScreenGlow.futureColor, Color.orange)
    }
}
