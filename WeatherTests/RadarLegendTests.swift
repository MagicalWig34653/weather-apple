import XCTest
@testable import Weather

final class RadarLegendTests: XCTestCase {
    func testPrecipitationLegendMatchesDWDStyle() {
        let legend = MapLegend.precipitationRadar
        XCTAssertEqual(legend.unit, "mm/h")
        XCTAssertEqual(legend.entries.map(\.hex), [
            "#7D7D7D", "#33FFFF", "#1ACC9A", "#019934", "#4DB31B", "#99CC01", "#CCE601", "#FFFF01",
            "#FFC401", "#FF8901", "#FF4501", "#FE0000", "#E5004C", "#CC0098", "#6600CB", "#0000FE"])
        XCTAssertEqual(legend.entries.first?.opacity, 0.3)
    }

    func testEntriesHaveUniqueIDsAndGermanSpokenLabels() {
        let entries = MapLegend.precipitationRadar.entries
        XCTAssertEqual(Set(entries.map(\.id)).count, entries.count)
        for entry in entries.dropFirst() {
            XCTAssertTrue(entry.spokenLabel.hasSuffix("Millimeter pro Stunde"), entry.spokenLabel)
            XCTAssertFalse(entry.label.isEmpty)
        }
        XCTAssertEqual(entries[1].spokenLabel, "0,1 bis unter 0,2 Millimeter pro Stunde")
        XCTAssertEqual(entries.last?.spokenLabel, "ab 150 Millimeter pro Stunde")
    }
}
