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

    struct Cell: Equatable, Codable, Sendable {
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
