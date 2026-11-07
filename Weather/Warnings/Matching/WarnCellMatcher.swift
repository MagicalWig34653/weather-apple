import Foundation

/// Maps places and regions to DWD warning districts, entirely on the device.
/// Coordinates never leave the matcher; only the resulting cell IDs are meant for a subscription.
struct WarnCellMatcher: Sendable {
    private let geometry: WarnGeometry
    private static let kmPerDegree = 111.32
    private static let edgeEpsilon = 1e-9

    init(geometry: WarnGeometry) { self.geometry = geometry }

    /// District containing the point (nil outside the outlines, including open sea). On shared borders
    /// the smallest ID wins.
    func cell(containing lat: Double, lon: Double) -> WarnCellID? {
        allCells(containing: lat, lon: lon).first
    }

    /// All districts containing the point, sorted (more than one only on borders or overlapping layers).
    func allCells(containing lat: Double, lon: Double) -> [WarnCellID] {
        geometry.cells.compactMap { cell in
            Self.inBox(cell, lat, lon) && Self.contains(cell, lat, lon) ? cell.id : nil
        }
    }

    /// Containing district, otherwise (coast, harbour, sea) the nearest one within `maxDistanceKm`.
    func nearestCell(lat: Double, lon: Double, maxDistanceKm: Double) -> WarnCellID? {
        if let id = cell(containing: lat, lon: lon) { return id }
        var best: (id: WarnCellID, d: Double)?
        for cell in geometry.cells {
            let d = Self.boundaryDistanceKm(cell, lat, lon, cutoff: min(best?.d ?? .infinity, maxDistanceKm))
            if d <= maxDistanceKm, d < (best?.d ?? .infinity) { best = (cell.id, d) }
        }
        return best?.id
    }

    /// Districts intersecting the disc (center, radius), sorted by ID. If there are more than `limit`,
    /// the `limit` nearest to the center are kept. Empty if the disc touches no district (e.g. open sea).
    func cells(intersectingCircleLat lat: Double, lon: Double, radiusKm: Double, limit: Int = 64) -> [WarnCellID] {
        let dLat = radiusKm / Self.kmPerDegree
        let dLon = radiusKm / (Self.kmPerDegree * max(cos(lat * .pi / 180), 0.01))
        var hits: [(id: WarnCellID, d: Double)] = []
        for cell in geometry.cells where cell.maxLat >= lat - dLat && cell.minLat <= lat + dLat
            && cell.maxLon >= lon - dLon && cell.minLon <= lon + dLon {
            if Self.contains(cell, lat, lon) { hits.append((cell.id, 0)); continue }
            let d = Self.boundaryDistanceKm(cell, lat, lon, cutoff: radiusKm)
            if d <= radiusKm { hits.append((cell.id, d)) }
        }
        if hits.count > limit { hits = Array(hits.sorted { ($0.d, $0.id) < ($1.d, $1.id) }.prefix(max(limit, 0))) }
        return hits.map(\.id).sorted()
    }

    /// Number of cells whose bounding box contains the point (the only ones that get a polygon test).
    func boundingBoxCandidateCount(lat: Double, lon: Double) -> Int {
        geometry.cells.reduce(0) { $0 + (Self.inBox($1, lat, lon) ? 1 : 0) }
    }

    // MARK: - Geometry

    private static func inBox(_ c: WarnGeometry.Cell, _ lat: Double, _ lon: Double) -> Bool {
        lat >= c.minLat - edgeEpsilon && lat <= c.maxLat + edgeEpsilon
            && lon >= c.minLon - edgeEpsilon && lon <= c.maxLon + edgeEpsilon
    }

    /// Even-odd ray casting over all rings; points on an edge count as inside.
    private static func contains(_ cell: WarnGeometry.Cell, _ lat: Double, _ lon: Double) -> Bool {
        var inside = false
        for ring in cell.rings where ring.count >= 3 {
            var j = ring.count - 1
            for i in 0..<ring.count {
                let a = ring[i], b = ring[j]
                if onSegment(lat, lon, a, b) { return true }
                if (a.lat > lat) != (b.lat > lat),
                   lon < (b.lon - a.lon) * (lat - a.lat) / (b.lat - a.lat) + a.lon { inside.toggle() }
                j = i
            }
        }
        return inside
    }

    private static func onSegment(_ lat: Double, _ lon: Double, _ a: WarnGeometry.Point, _ b: WarnGeometry.Point) -> Bool {
        let cross = (b.lon - a.lon) * (lat - a.lat) - (b.lat - a.lat) * (lon - a.lon)
        guard abs(cross) <= edgeEpsilon else { return false }
        return lat >= min(a.lat, b.lat) - edgeEpsilon && lat <= max(a.lat, b.lat) + edgeEpsilon
            && lon >= min(a.lon, b.lon) - edgeEpsilon && lon <= max(a.lon, b.lon) + edgeEpsilon
    }

    /// Distance in km from the point to the nearest ring edge (local equirectangular approximation).
    /// Stops early (returns a value above `cutoff`) when the bounding box is farther than `cutoff`.
    private static func boundaryDistanceKm(_ cell: WarnGeometry.Cell, _ lat: Double, _ lon: Double, cutoff: Double) -> Double {
        let kx = kmPerDegree * cos(lat * .pi / 180), ky = kmPerDegree
        let boxDx = max(cell.minLon - lon, 0, lon - cell.maxLon) * kx
        let boxDy = max(cell.minLat - lat, 0, lat - cell.maxLat) * ky
        guard (boxDx * boxDx + boxDy * boxDy).squareRoot() <= cutoff else { return .infinity }
        var best = Double.infinity
        for ring in cell.rings where ring.count >= 2 {
            var j = ring.count - 1
            for i in 0..<ring.count {
                let ax = (ring[j].lon - lon) * kx, ay = (ring[j].lat - lat) * ky
                let bx = (ring[i].lon - lon) * kx, by = (ring[i].lat - lat) * ky
                let dx = bx - ax, dy = by - ay
                let len2 = dx * dx + dy * dy
                let t = len2 == 0 ? 0 : min(max(-(ax * dx + ay * dy) / len2, 0), 1)
                let px = ax + t * dx, py = ay + t * dy
                best = min(best, (px * px + py * py).squareRoot())
                j = i
            }
        }
        return best
    }
}
