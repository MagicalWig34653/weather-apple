import CoreGraphics
import CoreLocation
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

final class PlaceFocusTests: XCTestCase {
    func testRegionCentersOnPlaceWithDefaultSpan() {
        let region = PlaceFocus.region(latitude: 48.1, longitude: 11.5, currentSpanMeters: nil)
        XCTAssertEqual(region.center.latitude, 48.1, accuracy: 1e-9)
        XCTAssertEqual(region.center.longitude, 11.5, accuracy: 1e-9)
        XCTAssertEqual(PlaceFocus.spanMeters(current: nil), PlaceFocus.defaultSpanMeters)
    }

    func testZoomedInViewKeepsItsZoomButWideViewZoomsIn() {
        XCTAssertEqual(PlaceFocus.spanMeters(current: 60_000), 60_000)
        XCTAssertEqual(PlaceFocus.spanMeters(current: 2_000_000), PlaceFocus.defaultSpanMeters)
        XCTAssertEqual(PlaceFocus.spanMeters(current: 1_000), PlaceFocus.minimumSpanMeters)
        XCTAssertEqual(PlaceFocus.spanMeters(current: .nan), PlaceFocus.defaultSpanMeters)
    }

    func testMarkersExcludeSelectedPlaceAndAreOrderedByName() {
        let a = SavedPlace(name: "Zürich", coordinate: WeatherCoordinate(latitude: 47, longitude: 8))
        let b = SavedPlace(name: "Aachen", coordinate: WeatherCoordinate(latitude: 50, longitude: 6))
        let c = SavedPlace(name: "Köln", coordinate: WeatherCoordinate(latitude: 51, longitude: 7))
        let markers = PlaceFocus.markers(places: [a, b, c], selectedID: c.id)
        XCTAssertEqual(markers.map(\.name), ["Aachen", "Zürich"])
    }

    func testAccessibilityLabelNamesThePlace() {
        XCTAssertEqual(PlaceFocus.accessibilityLabel(for: "Köln"), "Zum Ort Köln springen")
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
}
