import Foundation

/// DWD warning-cell ID, 9 digits. For districts: Type 1 = "1" + AGS5 + "000", type 10 (split coastal
/// districts and Munich) = prefix "9". Matches the `warncell` the DISTRICT feed delivers.
typealias WarnCellID = String

enum WarnGeometryError: Error, Equatable { case badFormat, missingResource }

/// Bundled district outlines (format WGEO1, see `tools/warn_geometry.py`). Pure local data; no network.
/// Source: DWD layer `Warngebiete_Kreise`, (c) GeoBasis-DE / BKG 2021 (Daten modifiziert).
struct WarnGeometry: Sendable {
    typealias Point = (lat: Double, lon: Double)

    struct Cell: Sendable {
        let id: WarnCellID
        let minLat, minLon, maxLat, maxLon: Double
        /// Outer rings and holes alike; membership uses the even-odd rule.
        let rings: [[Point]]
    }

    /// Sorted by ID.
    let cells: [Cell]

    static let resourceName = "WarnGeometry"

    static func bundled(in bundle: Bundle = .main, name: String = resourceName) throws -> WarnGeometry {
        guard let url = bundle.url(forResource: name, withExtension: "bin"),
              let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { throw WarnGeometryError.missingResource }
        return try decode(data)
    }

    static func decode(_ data: Data) throws -> WarnGeometry {
        var r = Reader(data: data)
        guard try r.bytes(5) == Array("WGEO1".utf8) else { throw WarnGeometryError.badFormat }
        let count = Int(try r.uint32())
        var cells: [Cell] = []
        cells.reserveCapacity(min(count, 1_000))
        for _ in 0..<count {
            let id = try r.uint32()
            let minLat = Double(try r.int32()) / 1e5, minLon = Double(try r.int32()) / 1e5
            let maxLat = Double(try r.int32()) / 1e5, maxLon = Double(try r.int32()) / 1e5
            let ringCount = Int(try r.uint16())
            var rings: [[Point]] = []
            for _ in 0..<ringCount {
                let n = Int(try r.uint32())
                guard n <= r.remaining / 8 else { throw WarnGeometryError.badFormat }
                var ring: [Point] = []
                ring.reserveCapacity(n)
                for _ in 0..<n { ring.append((Double(try r.int32()) / 1e5, Double(try r.int32()) / 1e5)) }
                rings.append(ring)
            }
            cells.append(Cell(id: String(id), minLat: minLat, minLon: minLon, maxLat: maxLat, maxLon: maxLon, rings: rings))
        }
        guard r.remaining == 0 else { throw WarnGeometryError.badFormat }
        return WarnGeometry(cells: cells.sorted { $0.id < $1.id })
    }

    private struct Reader {
        let data: Data
        var offset = 0
        var remaining: Int { data.count - offset }

        init(data: Data) { self.data = Data(data) }   // re-base indices (slices keep their startIndex)

        mutating func bytes(_ n: Int) throws -> [UInt8] {
            guard n >= 0, remaining >= n else { throw WarnGeometryError.badFormat }
            defer { offset += n }
            return Array(data[offset..<offset + n])
        }
        mutating func uint16() throws -> UInt16 { let b = try bytes(2); return UInt16(b[0]) | UInt16(b[1]) << 8 }
        mutating func uint32() throws -> UInt32 {
            let b = try bytes(4)
            return UInt32(b[0]) | UInt32(b[1]) << 8 | UInt32(b[2]) << 16 | UInt32(b[3]) << 24
        }
        mutating func int32() throws -> Int32 { Int32(bitPattern: try uint32()) }
    }
}
