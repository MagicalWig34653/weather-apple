import XCTest
@testable import Weather

final class WarnGeometryTests: XCTestCase {
    static func sampleData() throws -> Data {
        let bundle = Bundle(for: WarnGeometryTests.self)
        let url = try XCTUnwrap(bundle.url(forResource: "warn_geometry_sample", withExtension: "bin", subdirectory: "Fixtures/warn"))
        return try Data(contentsOf: url)
    }

    func testDecodeReadsThreeCells() throws {
        let geometry = try WarnGeometry.decode(try Self.sampleData())
        XCTAssertEqual(geometry.cells.map(\.id), ["100000001", "100000002", "100000003"])
        XCTAssertEqual(geometry.cells[1].rings.count, 2)
        XCTAssertEqual(geometry.cells[0].minLat, 51.0, accuracy: 1e-9)
        XCTAssertEqual(geometry.cells[0].maxLon, 11.0, accuracy: 1e-9)
    }

    func testBadMagicIsRejected() throws {
        var data = try Self.sampleData()
        data[0] = 0x58
        XCTAssertThrowsError(try WarnGeometry.decode(data)) { XCTAssertEqual($0 as? WarnGeometryError, .badFormat) }
    }

    func testTruncatedDataIsRejected() throws {
        let data = try Self.sampleData()
        for cut in [0, 4, 8, 20, data.count - 1] {
            XCTAssertThrowsError(try WarnGeometry.decode(data.prefix(cut)), "cut \(cut)") {
                XCTAssertEqual($0 as? WarnGeometryError, .badFormat)
            }
        }
    }

    func testTrailingBytesAreRejected() throws {
        var data = try Self.sampleData()
        data.append(0)
        XCTAssertThrowsError(try WarnGeometry.decode(data)) { XCTAssertEqual($0 as? WarnGeometryError, .badFormat) }
    }

    func testMissingResourceThrows() {
        XCTAssertThrowsError(try WarnGeometry.bundled(in: Bundle(for: WarnGeometryTests.self), name: "does_not_exist")) {
            XCTAssertEqual($0 as? WarnGeometryError, .missingResource)
        }
    }
}
