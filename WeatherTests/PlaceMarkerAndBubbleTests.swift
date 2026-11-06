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
    func testScrubGlowBreathStaysWithinRangeAndOrbitIsStaticForReducedMotion() {
        for step in 0..<100 {
            let value = ScreenGlow.breath(at: Double(step) * 0.37)
            XCTAssertGreaterThanOrEqual(value, 0.82 - 0.0001)
            XCTAssertLessThanOrEqual(value, 1.0001)
        }
        XCTAssertEqual(ScreenGlow.orbitAngle(at: 5, reduceMotion: true), 0)
        XCTAssertNotEqual(ScreenGlow.orbitAngle(at: 3, reduceMotion: false), ScreenGlow.orbitAngle(at: 6, reduceMotion: false))
        XCTAssertEqual(ScreenGlow.orbitAngle(at: ScreenGlow.orbitPeriod, reduceMotion: false), 0, accuracy: 0.001)
        XCTAssertEqual(ScreenGlow.stops(for: .orange).count, 5)
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
