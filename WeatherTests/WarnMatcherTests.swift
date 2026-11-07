import XCTest
@testable import Weather

final class WarnMatcherTests: XCTestCase {
    private func sampleMatcher() throws -> WarnCellMatcher {
        WarnCellMatcher(geometry: try WarnGeometry.decode(try WarnGeometryTests.sampleData()))
    }

    // Sample: 100000001 = lat 51...52, lon 10...11; 100000002 = lat 51...52, lon 11...12 with hole
    // lat 51.4...51.6, lon 11.4...11.6; 100000003 = lat 47...48, lon 9...10.

    func testPointInSquareOne() throws {
        XCTAssertEqual(try sampleMatcher().cell(containing: 51.5, lon: 10.5), "100000001")
    }

    func testPointInHoleIsNil() throws {
        XCTAssertNil(try sampleMatcher().cell(containing: 51.5, lon: 11.5))
        XCTAssertEqual(try sampleMatcher().cell(containing: 51.5, lon: 11.2), "100000002")
    }

    func testPointOutsideIsNil() throws {
        XCTAssertNil(try sampleMatcher().cell(containing: 40, lon: 5))
    }

    func testPointOnSharedEdgePicksSmallerID() throws {
        XCTAssertEqual(try sampleMatcher().cell(containing: 51.5, lon: 11.0), "100000001")
    }

    func testPointOnHoleEdgeCountsAsInsideCell() throws {
        XCTAssertEqual(try sampleMatcher().cell(containing: 51.5, lon: 11.4), "100000002")
    }

    func testNearestCellUsesDistanceLimit() throws {
        let m = try sampleMatcher()
        // 0.05 degrees (~5.5 km) east of square 3 (lon 10.0 edge).
        XCTAssertEqual(m.nearestCell(lat: 47.5, lon: 10.05, maxDistanceKm: 10), "100000003")
        XCTAssertNil(m.nearestCell(lat: 47.5, lon: 10.05, maxDistanceKm: 2))
        XCTAssertEqual(m.nearestCell(lat: 51.5, lon: 10.5, maxDistanceKm: 1), "100000001")
    }

    func testCircleInsideOneSquare() throws {
        XCTAssertEqual(try sampleMatcher().cells(intersectingCircleLat: 51.2, lon: 10.5, radiusKm: 5, limit: 64), ["100000001"])
    }

    func testCircleOverTwoSquares() throws {
        XCTAssertEqual(try sampleMatcher().cells(intersectingCircleLat: 51.2, lon: 11.0, radiusKm: 5, limit: 64),
                       ["100000001", "100000002"])
    }

    func testSmallCircleMidSquareThree() throws {
        XCTAssertEqual(try sampleMatcher().cells(intersectingCircleLat: 47.5, lon: 9.5, radiusKm: 0.1, limit: 64), ["100000003"])
    }

    func testCircleFullyInsideHoleTouchesNothing() throws {
        XCTAssertEqual(try sampleMatcher().cells(intersectingCircleLat: 51.5, lon: 11.5, radiusKm: 1, limit: 64), [])
    }

    func testCircleOverlappingHoleBorderTouchesCell() throws {
        // Hole spans lon 11.4...11.6 (about 14 km wide at 51.5 N); radius 12 km reaches the hole edge.
        XCTAssertEqual(try sampleMatcher().cells(intersectingCircleLat: 51.5, lon: 11.5, radiusKm: 12, limit: 64), ["100000002"])
    }

    func testCircleOutsideReachesNothing() throws {
        XCTAssertEqual(try sampleMatcher().cells(intersectingCircleLat: 40, lon: 5, radiusKm: 25, limit: 64), [])
    }

    func testLimitKeepsNearestToCenter() throws {
        let r = try sampleMatcher().cells(intersectingCircleLat: 51.2, lon: 10.9, radiusKm: 20, limit: 1)
        XCTAssertEqual(r, ["100000001"])
        let r2 = try sampleMatcher().cells(intersectingCircleLat: 51.2, lon: 11.1, radiusKm: 20, limit: 1)
        XCTAssertEqual(r2, ["100000002"])
    }

    func testBoundingBoxPreselectionSkipsFarCells() throws {
        let m = try sampleMatcher()
        XCTAssertEqual(m.boundingBoxCandidateCount(lat: 47.5, lon: 9.5), 1)
        XCTAssertEqual(m.boundingBoxCandidateCount(lat: 40, lon: 5), 0)
    }
}

/// Real bundled district geometry (DWD layer Warngebiete_Kreise). Coordinates are public landmarks.
final class WarnBundledGeometryTests: XCTestCase {
    private static let matcher: WarnCellMatcher = {
        // Hosted unit tests run inside the app, so the app bundle holds the resource.
        let geometry = try! WarnGeometry.bundled(in: Bundle.main)
        return WarnCellMatcher(geometry: geometry)
    }()

    func testBundledFileHasAllDistricts() throws {
        let g = try WarnGeometry.bundled(in: Bundle.main)
        XCTAssertEqual(g.cells.count, 402)
        XCTAssertEqual(Set(g.cells.map(\.id)).count, 402)
        XCTAssertTrue(g.cells.allSatisfy { $0.id.count == 9 })
    }

    func testLandmarksMapToExpectedDistricts() {
        let expected: [(String, Double, Double, String)] = [
            ("Berlin Brandenburger Tor", 52.5163, 13.3777, "111000000"),
            ("Hamburg Rathaus", 53.5503, 9.9920, "102000000"),
            ("Muenchen Marienplatz", 48.1374, 11.5755, "909184999"),
            ("Koeln Dom", 50.9413, 6.9583, "105315000"),
            ("Nuernberg Hbf", 49.4457, 11.0828, "109564000"),
            ("Zugspitze", 47.4210, 10.9863, "109180000"),
            ("Dresden Frauenkirche", 51.0519, 13.7415, "114612000"),
            ("Rostock", 54.0924, 12.0991, "113003000"),
            ("Leipzig", 51.3397, 12.3731, "114713000"),
            ("Frankfurt Roemer", 50.1106, 8.6821, "106412000"),
            ("Cuxhaven Alte Liebe (Kueste)", 53.8670, 8.7050, "903352002"),
            ("Westerland Sylt (Kueste)", 54.9079, 8.3039, "901054002"),
            ("Helgoland", 54.1800, 7.8900, "901056002"),
        ]
        for (name, lat, lon, id) in expected {
            XCTAssertEqual(Self.matcher.cell(containing: lat, lon: lon), id, name)
        }
    }

    func testOutsideGermanyIsNil() {
        XCTAssertNil(Self.matcher.cell(containing: 48.8566, lon: 2.3522)) // Paris
        XCTAssertNil(Self.matcher.cell(containing: 48.2082, lon: 16.3738)) // Wien
    }

    func testOffshorePointFallsBackToNearestDistrict() {
        // Open North Sea off Cuxhaven: outside every polygon, nearest cell is a coastal district.
        XCTAssertNil(Self.matcher.cell(containing: 53.95, lon: 8.55))
        let near = Self.matcher.nearestCell(lat: 53.95, lon: 8.55, maxDistanceKm: 25)
        XCTAssertNotNil(near)
        XCTAssertNil(Self.matcher.nearestCell(lat: 48.8566, lon: 2.3522, maxDistanceKm: 25))
    }

    func testBerlinPointFallsInExactlyOneDistrict() {
        XCTAssertEqual(Self.matcher.allCells(containing: 52.52, lon: 13.40), ["111000000"])
    }

    func testRegionAroundMuenchenReachesNeighbours() {
        let ids = Self.matcher.cells(intersectingCircleLat: 48.1374, lon: 11.5755, radiusKm: 25, limit: 64)
        XCTAssertTrue(ids.contains("909184999"))
        XCTAssertGreaterThan(ids.count, 1)
        XCTAssertLessThanOrEqual(ids.count, 64)
        XCTAssertEqual(ids, ids.sorted())
    }

    func testSmallRegionInBerlinIsOneDistrict() {
        XCTAssertEqual(Self.matcher.cells(intersectingCircleLat: 52.52, lon: 13.40, radiusKm: 5, limit: 64), ["111000000"])
    }

    func testDistrictsDoNotOverlapAtLandmarks() {
        for (lat, lon) in [(53.8670, 8.7050), (54.9079, 8.3039), (54.18, 7.89), (50.1106, 8.6821), (48.1374, 11.5755)] {
            XCTAssertEqual(Self.matcher.allCells(containing: lat, lon: lon).count, 1, "\(lat),\(lon)")
        }
    }
}
