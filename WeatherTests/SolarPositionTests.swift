import XCTest
@testable import Weather

// Referenzwerte: JPL Horizons API (https://ssd.jpl.nasa.gov/api/horizons.api), abgerufen am 31.10.2026.
// COMMAND='10' (Sonne), EPHEM_TYPE=OBSERVER, CENTER='coord@399', COORD_TYPE=GEODETIC, SITE_COORD='lon,lat,0',
// QUANTITIES='4' (Azimut/Höhe, APPARENT=AIRLESS, also ohne Refraktion), TLIST in Julianischen Tagen (UT).
// Werte unten 1:1 übernommen (Azimut von Norden, Höhe in Grad). Toleranz 0,5 Grad.
final class SolarPositionTests: XCTestCase {
    struct Ref { let utc: String; let az: Double; let el: Double }
    let tolerance = 0.5

    func date(_ s: String) -> Date { ISO8601DateFormatter().date(from: s)! }

    func check(_ refs: [Ref], lat: Double, lon: Double, file: StaticString = #filePath, line: UInt = #line) {
        for r in refs {
            let p = SolarPosition.position(at: date(r.utc), latitude: lat, longitude: lon)
            XCTAssertEqual(p.elevation, r.el, accuracy: tolerance, "Höhe \(r.utc)", file: file, line: line)
            var dAz = abs(p.azimuth - r.az)
            if dAz > 180 { dAz = 360 - dAz }
            XCTAssertLessThan(dAz, tolerance, "Azimut \(r.utc): \(p.azimuth) vs \(r.az)", file: file, line: line)
        }
    }

    func testBerlin31October2026() {
        check([
            Ref(utc: "2026-10-31T06:00:00Z", az: 112.324034, el: -0.921709),
            Ref(utc: "2026-10-31T08:00:00Z", az: 137.537897, el: 13.961014),
            Ref(utc: "2026-10-31T11:00:00Z", az: 182.635850, el: 23.276603),
            Ref(utc: "2026-10-31T14:00:00Z", az: 226.882583, el: 11.750969),
            Ref(utc: "2026-10-31T16:00:00Z", az: 251.515703, el: -3.879864),
        ], lat: 52.5, lon: 13.4)
    }

    func testSummerSolstice48N8E() {
        check([
            Ref(utc: "2026-06-21T03:00:00Z", az: 46.948877, el: -4.451877),
            Ref(utc: "2026-06-21T05:00:00Z", az: 68.715751, el: 12.478457),
            Ref(utc: "2026-06-21T10:00:00Z", az: 136.094099, el: 59.652263),
            Ref(utc: "2026-06-21T15:00:00Z", az: 258.470807, el: 41.987210),
            Ref(utc: "2026-06-21T19:00:00Z", az: 301.894832, el: 3.457304),
        ], lat: 48, lon: 8)
    }

    func testWinterSolstice48N8E() {
        check([
            Ref(utc: "2026-12-21T07:30:00Z", az: 128.134162, el: 1.183048),
            Ref(utc: "2026-12-21T09:00:00Z", az: 146.166620, el: 11.413617),
            Ref(utc: "2026-12-21T11:00:00Z", az: 173.707622, el: 18.321702),
            Ref(utc: "2026-12-21T13:00:00Z", az: 202.294054, el: 15.514394),
            Ref(utc: "2026-12-21T15:30:00Z", az: 233.340164, el: 0.133805),
        ], lat: 48, lon: 8)
    }

    func testEquinox2027_48N8E() {
        check([
            Ref(utc: "2027-03-20T05:30:00Z", az: 89.121888, el: -1.123402),
            Ref(utc: "2027-03-20T08:00:00Z", az: 118.588870, el: 23.054574),
            Ref(utc: "2027-03-20T11:00:00Z", az: 168.147968, el: 41.228470),
            Ref(utc: "2027-03-20T14:00:00Z", az: 224.423831, el: 32.621553),
            Ref(utc: "2027-03-20T17:00:00Z", az: 263.349306, el: 5.875699),
        ], lat: 48, lon: 8)
    }

    func testSouthernHemisphere() {
        // 45 S, 0 E, 2026-12-21 12:00 UTC (Horizons): Sonne fast genau im Norden.
        check([Ref(utc: "2026-12-21T12:00:00Z", az: 358.793633, el: 68.432388)], lat: -45, lon: 0)
    }

    // MARK: Polar

    func testPolarDayAndNightLongyearbyen() {
        // 78,22 N, 15,65 O (Horizons): 21.6. 00:00 UTC Höhe 12,04; 12:00 UTC 34,76. 21.12. 00:00 -34,70; 12:00 -12,09.
        check([
            Ref(utc: "2026-06-21T00:00:00Z", az: 14.261240, el: 12.039985),
            Ref(utc: "2026-06-21T12:00:00Z", az: 197.021969, el: 34.757836),
            Ref(utc: "2026-12-21T00:00:00Z", az: 18.135008, el: -34.696835),
            Ref(utc: "2026-12-21T12:00:00Z", az: 195.113935, el: -12.091239),
        ], lat: 78.22, lon: 15.65)

        let summer = date("2026-06-21T00:00:00Z")
        XCTAssertTrue(SolarPosition.crossings(from: summer, to: summer.addingTimeInterval(48 * 3600),
                                              latitude: 78.22, longitude: 15.65).isEmpty)
        XCTAssertNil(SolarPosition.nextSunset(after: summer, latitude: 78.22, longitude: 15.65))
        XCTAssertEqual(SolarPosition.sunLabel(at: summer, latitude: 78.22, longitude: 15.65, timeZone: TimeZone(identifier: "UTC")!),
                       "Sonne den ganzen Tag")

        let winter = date("2026-12-21T12:00:00Z")
        XCTAssertTrue(SolarPosition.crossings(from: winter, to: winter.addingTimeInterval(48 * 3600),
                                              latitude: 78.22, longitude: 15.65).isEmpty)
        XCTAssertNil(SolarPosition.nextSunrise(after: winter, latitude: 78.22, longitude: 15.65))
        XCTAssertEqual(SolarPosition.sunLabel(at: winter, latitude: 78.22, longitude: 15.65, timeZone: TimeZone(identifier: "UTC")!),
                       "Sonne geht nicht auf")
        // Horizons: Höhe -12,09 am Mittag (knapp unter -12): astronomische Dämmerung, nie Tag.
        XCTAssertEqual(SolarPosition.phase(at: winter, latitude: 78.22, longitude: 15.65), .astronomicalTwilight)
    }

    // MARK: Phasen

    func testPhaseThresholds() {
        XCTAssertEqual(SolarPosition.Phase(elevation: 10), .day)
        XCTAssertEqual(SolarPosition.Phase(elevation: -0.5), .day)
        XCTAssertEqual(SolarPosition.Phase(elevation: -0.9), .civilTwilight)
        XCTAssertEqual(SolarPosition.Phase(elevation: -6.0), .civilTwilight)
        XCTAssertEqual(SolarPosition.Phase(elevation: -6.1), .nauticalTwilight)
        XCTAssertEqual(SolarPosition.Phase(elevation: -12.1), .astronomicalTwilight)
        XCTAssertEqual(SolarPosition.Phase(elevation: -18.1), .night)
        XCTAssertLessThan(SolarPosition.Phase.night, .day)
    }

    func testPhasesOverBerlinDay() {
        // Horizons-Höhen: 06:00 UTC -0,92 (bürgerlich), 11:00 UTC 23,3 (Tag), 16:00 UTC -3,88 (bürgerlich).
        XCTAssertEqual(SolarPosition.phase(at: date("2026-10-31T06:00:00Z"), latitude: 52.5, longitude: 13.4), .civilTwilight)
        XCTAssertEqual(SolarPosition.phase(at: date("2026-10-31T11:00:00Z"), latitude: 52.5, longitude: 13.4), .day)
        XCTAssertEqual(SolarPosition.phase(at: date("2026-10-31T16:00:00Z"), latitude: 52.5, longitude: 13.4), .civilTwilight)
        XCTAssertEqual(SolarPosition.phase(at: date("2026-10-31T23:00:00Z"), latitude: 52.5, longitude: 13.4), .night)
    }

    // MARK: Auf-/Untergang

    func testSunriseSunsetBerlinConsistentWithHorizonsBracket() {
        // Horizons: 06:00 UTC -0,92, 08:00 UTC +13,96 -> Aufgang zwischen 06:00 und 08:00 UTC; 14:00 +11,75, 16:00 -3,88 -> Untergang dazwischen.
        let start = date("2026-10-31T00:00:00Z")
        let c = SolarPosition.crossings(from: start, to: start.addingTimeInterval(24 * 3600), latitude: 52.5, longitude: 13.4)
        XCTAssertEqual(c.count, 2)
        XCTAssertTrue(c[0].isRising)
        XCTAssertFalse(c[1].isRising)
        XCTAssertGreaterThan(c[0].date, date("2026-10-31T06:00:00Z"))
        XCTAssertLessThan(c[0].date, date("2026-10-31T06:30:00Z")) // Höhe -0,92 bei 06:00, ca. 0,2 Grad/min
        XCTAssertGreaterThan(c[1].date, date("2026-10-31T15:00:00Z"))
        XCTAssertLessThan(c[1].date, date("2026-10-31T16:00:00Z"))
        // Höhe am Durchgang gleich Schwelle.
        for x in c {
            XCTAssertEqual(SolarPosition.elevation(at: x.date, latitude: 52.5, longitude: 13.4), SolarPosition.sunriseElevation, accuracy: 0.01)
        }
    }

    func testSunLabelIsTimeZoneIndependentOfCalculation() {
        // Gleicher Zeitpunkt, nur das Anzeigeformat hängt von der Zeitzone ab (MEZ = UTC+1 am 31.10.2026, Sommerzeit endete 25.10.).
        let now = date("2026-10-31T11:00:00Z")
        let utc = SolarPosition.sunLabel(at: now, latitude: 52.5, longitude: 13.4, timeZone: TimeZone(identifier: "UTC")!)
        let berlin = SolarPosition.sunLabel(at: now, latitude: 52.5, longitude: 13.4, timeZone: TimeZone(identifier: "Europe/Berlin")!)
        XCTAssertTrue(utc.hasPrefix("Sonne bis "))
        let h1 = Int(utc.suffix(5).prefix(2))!, h2 = Int(berlin.suffix(5).prefix(2))!
        XCTAssertEqual(h2, h1 + 1)
        XCTAssertEqual(utc.suffix(2), berlin.suffix(2))
    }

    func testDaylightSavingTransitionDoesNotShiftPosition() {
        // 2026-03-29 01:00 UTC beginnt die Sommerzeit (MEZ -> MESZ): Sonnenstand stetig, keine Lokalzeit im Spiel.
        let before = SolarPosition.position(at: date("2026-03-29T00:59:59Z"), latitude: 52.5, longitude: 13.4)
        let after = SolarPosition.position(at: date("2026-03-29T01:00:01Z"), latitude: 52.5, longitude: 13.4)
        XCTAssertEqual(before.elevation, after.elevation, accuracy: 0.01)
        XCTAssertEqual(before.azimuth, after.azimuth, accuracy: 0.01)
    }

    // MARK: Datumsgrenze

    func testDateLineHorizons() {
        // lat -17, lon 179,9 und -179,9 (Horizons, 20.3.2026): fast identischer Stand beiderseits der Datumsgrenze.
        check([
            Ref(utc: "2026-03-20T00:00:00Z", az: 6.891259, el: 73.127636),
            Ref(utc: "2026-03-20T18:00:00Z", az: 90.516473, el: -1.873664),
        ], lat: -17, lon: 179.9)
        check([
            Ref(utc: "2026-03-20T00:00:00Z", az: 6.205830, el: 73.149449),
            Ref(utc: "2026-03-20T18:00:00Z", az: 90.457948, el: -1.682410),
        ], lat: -17, lon: -179.9)
    }

    func testLongitudeNormalizationAndEquivalence() {
        let d = date("2026-10-31T09:00:00Z")
        let a = SolarPosition.position(at: d, latitude: 10, longitude: 190)
        let b = SolarPosition.position(at: d, latitude: 10, longitude: -170)
        XCTAssertEqual(a.elevation, b.elevation, accuracy: 1e-9)
        XCTAssertEqual(a.azimuth, b.azimuth, accuracy: 1e-9)
        XCTAssertEqual(SolarPosition.normalizeLongitude(190), -170, accuracy: 1e-12)
        XCTAssertEqual(SolarPosition.normalizeLongitude(-540), -180, accuracy: 1e-12)
    }

    func testUTCMidnightBoundaryIsContinuous() {
        let a = SolarPosition.position(at: date("2026-10-31T23:59:30Z"), latitude: 35, longitude: 139)
        let b = SolarPosition.position(at: date("2026-11-01T00:00:30Z"), latitude: 35, longitude: 139)
        XCTAssertEqual(a.elevation, b.elevation, accuracy: 0.5)
        XCTAssertEqual(a.azimuth, b.azimuth, accuracy: 1.0)
    }

    // MARK: Raster

    func testGridMatchesPointwiseAndOrientation() {
        let d = date("2026-10-31T11:00:00Z")
        let (north, south, west, east) = (55.0, 47.0, 5.0, 15.0)
        let rows = 4, cols = 5
        let grid = SolarPosition.elevationGrid(at: d, north: north, south: south, west: west, east: east, rows: rows, columns: cols)
        XCTAssertEqual(grid.count, rows * cols)
        for r in 0..<rows {
            for c in 0..<cols {
                let lat = north + (south - north) * (Double(r) + 0.5) / Double(rows)
                let lon = west + (east - west) * (Double(c) + 0.5) / Double(cols)
                XCTAssertEqual(grid[r * cols + c], SolarPosition.elevation(at: d, latitude: lat, longitude: lon), accuracy: 1e-9)
            }
        }
        XCTAssertGreaterThan(grid[(rows - 1) * cols], grid[0]) // Mittag: südlicher = höher
    }

    func testGridAcrossDateLine() {
        let d = date("2026-10-31T00:00:00Z")
        let grid = SolarPosition.elevationGrid(at: d, north: 10, south: -10, west: 170, east: -170, rows: 2, columns: 4)
        // Spaltenmitten: 172.5, 177.5, -177.5, -172.5
        let expectedLon = [172.5, 177.5, 182.5, 187.5]
        for (c, lon) in expectedLon.enumerated() {
            XCTAssertEqual(grid[c], SolarPosition.elevation(at: d, latitude: 5, longitude: lon), accuracy: 1e-9)
        }
    }

    func testPhaseGridTerminator() {
        // 11:00 UTC am 31.10.: Tag über Mitteleuropa, tiefe Nacht über dem Ostpazifik.
        let d = date("2026-10-31T11:00:00Z")
        let g = SolarPosition.phaseGrid(at: d, north: 60, south: 40, west: -140, east: 20, rows: 1, columns: 16)
        XCTAssertEqual(g.first, .night)
        XCTAssertEqual(g.last, .day)
        XCTAssertEqual(g, g.sorted()) // von West nach Ost monoton zum Tag
    }

    func testRefraction() {
        XCTAssertEqual(SolarPosition.refraction(forElevation: 0), 0.48, accuracy: 0.1)
        XCTAssertLessThan(SolarPosition.refraction(forElevation: 45), 0.03)
        XCTAssertEqual(SolarPosition.refraction(forElevation: -5), 0)
    }

    func testGridPerformance() {
        let d = date("2026-10-31T11:00:00Z")
        measure {
            _ = SolarPosition.elevationGrid(at: d, north: 90, south: -90, west: -180, east: 180, rows: 300, columns: 600)
        }
    }
}
