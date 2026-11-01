import Foundation

/// Radar pixel grid used by the push backend (`grid_version` 1): the ingest image of 1024 x 1311 pixels
/// in EPSG:3857 with a fixed bounding box (backend `RadarConstants.bbox`, `docs-site/content/api.md`).
/// The app computes the cell locally; coordinates never leave the device.
enum PushGrid {
    static let version = 1
    static let width = 1024
    static let height = 1311
    /// minX, minY, maxX, maxY in Web-Mercator meters.
    static let bbox: [Double] = [612_257.0, 5_942_074.0, 1_736_584.0, 7_381_298.0]
    static let earthRadius = 6_378_137.0

    struct Cell: Equatable, Hashable, Codable, Sendable {
        let x: Int
        let y: Int
    }

    /// `x = floor((X - bbox0) / (bbox2 - bbox0) * 1024)`, `y = floor((bbox3 - Y) / (bbox3 - bbox1) * 1311)`;
    /// `nil` outside the image (backend: `x >= b0, x < b2, y > b1, y <= b3`).
    static func cell(latitude: Double, longitude: Double) -> Cell? {
        guard latitude.isFinite, longitude.isFinite, abs(latitude) < 85, abs(longitude) <= 180 else { return nil }
        let x = earthRadius * longitude * .pi / 180
        let y = earthRadius * log(tan(.pi / 4 + latitude * .pi / 360))
        guard x >= bbox[0], x < bbox[2], y > bbox[1], y <= bbox[3] else { return nil }
        let cx = Int(((x - bbox[0]) / (bbox[2] - bbox[0]) * Double(width)).rounded(.down))
        let cy = Int(((bbox[3] - y) / (bbox[3] - bbox[1]) * Double(height)).rounded(.down))
        return Cell(x: min(cx, width - 1), y: min(cy, height - 1))
    }
}

/// Circle regions (backend draft `docs/research/push-regionen.md`): the center is stored coarser (3 x 3 cells,
/// about 2 km), the radius is sent in grid cells. No coordinates ever leave the device.
extension PushGrid {
    static let regionCenterBlock = 3
    static let regionRadiusCellsRange = 3...40
    static let regionRadiusPresetsKm = [5, 10, 25]
    static let regionSharePercents = [1, 10, 25]
    static let defaultRegionSharePercent = 10
    static let maxRegions = 3

    /// Middle cell of the 3 x 3 block that contains `cell`.
    static func coarseCenter(of cell: Cell) -> Cell {
        let block = regionCenterBlock
        return Cell(x: min((cell.x / block) * block + block / 2, width - 1),
                    y: min((cell.y / block) * block + block / 2, height - 1))
    }

    /// Geographic middle of a cell (for the circle preview only; never sent).
    static func coordinate(of cell: Cell) -> (latitude: Double, longitude: Double) {
        let x = bbox[0] + (Double(cell.x) + 0.5) / Double(width) * (bbox[2] - bbox[0])
        let y = bbox[3] - (Double(cell.y) + 0.5) / Double(height) * (bbox[3] - bbox[1])
        let longitude = x / earthRadius * 180 / .pi
        let latitude = (2 * atan(exp(y / earthRadius)) - .pi / 2) * 180 / .pi
        return (latitude, longitude)
    }

    /// Radius in grid cells at the latitude of the center: a cell is about 1098 m in Web Mercator and
    /// `1098 * cos(latitude)` m on the ground. Clamped to the backend range 3...40.
    static func radiusCells(km: Int, latitude: Double) -> Int {
        let cellMeters = (bbox[2] - bbox[0]) / Double(width) * cos(latitude * .pi / 180)
        let cells = Int((Double(km) * 1000 / cellMeters).rounded())
        return min(max(cells, regionRadiusCellsRange.lowerBound), regionRadiusCellsRange.upperBound)
    }
}

/// Rain intensity thresholds as classes 1...15 of the DWD legend (`MapLegend.precipitationRadar`).
enum PushSensitivity: String, Codable, CaseIterable, Identifiable, Sendable {
    case light, moderate, heavy
    var id: String { rawValue }

    /// Legend class sent as `threshold`.
    var threshold: Int {
        switch self {
        case .light: 3      // from 0.4 mm/h
        case .moderate: 5   // from 2 mm/h
        case .heavy: 8      // from 7.5 mm/h
        }
    }
    var title: String {
        switch self {
        case .light: "Leicht"
        case .moderate: "Mäßig"
        case .heavy: "Stark"
        }
    }
    var detail: String {
        switch self {
        case .light: "ab 0,4 mm/h"
        case .moderate: "ab 2 mm/h"
        case .heavy: "ab 7,5 mm/h"
        }
    }
}

enum PushLead {
    static let options = [10, 20, 30]
    static let defaultMinutes = 20
}
