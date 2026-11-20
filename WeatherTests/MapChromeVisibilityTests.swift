import XCTest
@testable import Weather

/// Pure state of "slider dragged -> own controls away, map free" (Build 53).
final class MapChromeVisibilityTests: XCTestCase {
    func testStartsVisible() {
        let state = MapChromeVisibility()
        XCTAssertFalse(state.isChromeHidden)
        XCTAssertFalse(state.isDragging)
    }

    func testTouchDownWithoutMovementKeepsChromeVisible() {
        var state = MapChromeVisibility()
        state.dragMoved(distance: 0)
        XCTAssertTrue(state.isDragging)
        XCTAssertFalse(state.isChromeHidden, "a plain tap must not flicker the screen")
    }

    func testSmallWobbleBelowThresholdKeepsChromeVisible() {
        var state = MapChromeVisibility()
        state.dragMoved(distance: MapChromeVisibility.activationDistance - 0.5)
        XCTAssertFalse(state.isChromeHidden)
    }

    func testMovementFromThresholdHidesChrome() {
        var state = MapChromeVisibility()
        state.dragMoved(distance: MapChromeVisibility.activationDistance)
        XCTAssertTrue(state.isDragging)
        XCTAssertTrue(state.isChromeHidden)
    }

    func testStaysHiddenUntilEndEvenWhenFingerReturnsToStart() {
        var state = MapChromeVisibility()
        state.dragMoved(distance: 40)
        state.dragMoved(distance: 0)
        XCTAssertTrue(state.isChromeHidden, "no flicker while the finger is still down")
        state.dragMoved(distance: 3)
        XCTAssertTrue(state.isChromeHidden)
    }

    func testEndRestoresChrome() {
        var state = MapChromeVisibility()
        state.dragMoved(distance: 40)
        state.dragEnded()
        XCTAssertFalse(state.isChromeHidden)
        XCTAssertFalse(state.isDragging)
    }

    func testEndWithoutDragIsHarmlessAndIdempotent() {
        var state = MapChromeVisibility()
        state.dragEnded()
        XCTAssertEqual(state, MapChromeVisibility())
        state.dragMoved(distance: 40)
        state.dragEnded()
        state.dragEnded()
        XCTAssertEqual(state, MapChromeVisibility())
    }

    func testNextDragStartsFreshAndVisible() {
        var state = MapChromeVisibility()
        state.dragMoved(distance: 40)
        state.dragEnded()
        state.dragMoved(distance: 0)
        XCTAssertFalse(state.isChromeHidden, "the second touch is a new touch: hidden only after movement")
        state.dragMoved(distance: 20)
        XCTAssertTrue(state.isChromeHidden)
    }

    func testNonFiniteAndNegativeDistancesNeverHide() {
        var state = MapChromeVisibility()
        state.dragMoved(distance: .nan)
        XCTAssertFalse(state.isChromeHidden)
        state.dragMoved(distance: -50)
        XCTAssertFalse(state.isChromeHidden)
        state.dragMoved(distance: .infinity)
        XCTAssertFalse(state.isChromeHidden, "an invalid value is no drag")
    }

    /// Cancellation, interruption, background, layer switch and disappearing all end through `dragEnded`;
    /// whatever state the drag was in (before or after activation), the end leaves the screen visible.
    func testEveryEndPathLeavesNothingHidden() {
        for distance in [0, 3, 8, 40, 400] as [CGFloat] {
            var state = MapChromeVisibility()
            state.dragMoved(distance: distance)
            state.dragEnded()
            XCTAssertFalse(state.isChromeHidden, "distance \(distance)")
            XCTAssertFalse(state.isDragging, "distance \(distance)")
        }
    }
}
