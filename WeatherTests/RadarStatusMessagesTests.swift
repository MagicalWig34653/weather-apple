import XCTest
@testable import Weather

/// Notices under the forecast header: a radar image problem must not hide the reason of a forecast failure.
final class RadarStatusMessagesTests: XCTestCase {
    func testForecastReasonAndRadarProblemAreShownTogetherForecastFirst() {
        let messages = RadarStatusMessages.messages(RadarStatusInput(
            radarImageMissing: true, radarFromCache: false, forecastError: "Die DWD-Wetterdaten sind momentan nicht erreichbar.",
            forecastShown: true, forecastFailureConfirmed: true))
        XCTAssertEqual(messages.count, 2)
        XCTAssertTrue(messages[0].hasPrefix("Ortsprognose:"), messages[0])
        XCTAssertTrue(messages[1].contains("Radarkacheln"), messages[1])
    }

    func testFirstForecastFailureWithShownForecastIsNotAnnounced() {
        let messages = RadarStatusMessages.messages(RadarStatusInput(
            radarImageMissing: true, forecastError: "x", forecastShown: true, forecastFailureConfirmed: false))
        XCTAssertEqual(messages.count, 1)
        XCTAssertFalse(messages[0].hasPrefix("Ortsprognose:"))
    }

    func testForecastErrorWithoutAnyForecastIsShownAtOnce() {
        let messages = RadarStatusMessages.messages(RadarStatusInput(forecastError: "kein Netz", forecastShown: false))
        XCTAssertEqual(messages, ["Ortsprognose: kein Netz"])
    }

    func testAtMostTwoNoticesAndSystemMessagesFirst() {
        let messages = RadarStatusMessages.messages(RadarStatusInput(
            locationMessage: "Standort aus", radarImageMissing: true, forecastError: "e", forecastShown: false))
        XCTAssertEqual(messages.count, RadarStatusMessages.limit)
        XCTAssertEqual(messages[0], "Standort aus")
        XCTAssertTrue(messages[1].hasPrefix("Ortsprognose:"), "forecast reason before the image problem")
    }

    func testOtherLayerShowsOnlyItsImageProblem() {
        let messages = RadarStatusMessages.messages(RadarStatusInput(
            radarLayerActive: false, layerTitle: "Luftdruck", radarImageMissing: true, forecastError: "e"))
        XCTAssertEqual(messages.count, 1)
        XCTAssertTrue(messages[0].contains("Luftdruck"))
    }

    func testNothingToReportGivesNoNotice() {
        XCTAssertTrue(RadarStatusMessages.messages(RadarStatusInput()).isEmpty)
    }
}
