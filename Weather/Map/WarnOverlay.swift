import MapKit
import SwiftUI

/// Colors and line patterns per warning level. The level is never carried by color alone: the dash pattern differs too
/// (and the list next to the map names every level in words).
enum WarnStyle {
    static func uiColor(_ level: Int) -> UIColor {
        switch min(max(level, 1), 4) {
        case 1: UIColor(red: 0.95, green: 0.78, blue: 0.0, alpha: 1)
        case 2: UIColor(red: 0.97, green: 0.55, blue: 0.0, alpha: 1)
        case 3: UIColor(red: 0.85, green: 0.12, blue: 0.12, alpha: 1)
        default: UIColor(red: 0.55, green: 0.1, blue: 0.7, alpha: 1)
        }
    }

    static func color(_ level: Int) -> Color { Color(uiColor(level)) }

    /// Dash pattern in points; nil = solid (level 4).
    static func dashPattern(_ level: Int) -> [Double]? {
        switch min(max(level, 1), 4) {
        case 1: [1, 5]
        case 2: [6, 4]
        case 3: [14, 4]
        default: nil
        }
    }

    static func lineWidth(_ level: Int) -> Double { level >= 4 ? 3.5 : 2 }
}

enum WarnOverlayModel {
    /// Highest level per cell (a cell with several warnings is drawn once).
    static func maxSeverityByCell(_ warnings: [ActiveWarning]) -> [WarnCellID: Int] {
        var result: [WarnCellID: Int] = [:]
        for warning in warnings {
            for cell in warning.warncellIDs { result[cell] = max(result[cell] ?? 0, warning.severity) }
        }
        return result
    }

    struct Shape: Equatable {
        var outer: [WarnGeometry.Point]
        var holes: [[WarnGeometry.Point]]
        static func == (l: Shape, r: Shape) -> Bool {
            l.outer.count == r.outer.count && l.holes.count == r.holes.count
                && zip(l.outer, r.outer).allSatisfy { $0.lat == $1.lat && $0.lon == $1.lon }
        }
    }

    /// The geometry stores outer rings and holes alike (even-odd rule). Nesting depth decides: even = outer ring,
    /// odd = hole of the smallest enclosing outer ring.
    static func shapes(of cell: WarnGeometry.Cell) -> [Shape] {
        let rings = cell.rings.filter { $0.count >= 3 }
        func inside(_ p: WarnGeometry.Point, _ ring: [WarnGeometry.Point]) -> Bool {
            var result = false
            var j = ring.count - 1
            for i in 0..<ring.count {
                let a = ring[i], b = ring[j]
                if (a.lat > p.lat) != (b.lat > p.lat), p.lon < (b.lon - a.lon) * (p.lat - a.lat) / (b.lat - a.lat) + a.lon { result.toggle() }
                j = i
            }
            return result
        }
        func area(_ ring: [WarnGeometry.Point]) -> Double {
            var sum = 0.0
            var j = ring.count - 1
            for i in 0..<ring.count { sum += (ring[j].lon + ring[i].lon) * (ring[j].lat - ring[i].lat); j = i }
            return abs(sum / 2)
        }
        let parents: [[Int]] = rings.indices.map { i in rings.indices.filter { $0 != i && inside(rings[i][0], rings[$0]) } }
        var shapes: [Int: Shape] = [:]
        for i in rings.indices where parents[i].count % 2 == 0 { shapes[i] = Shape(outer: rings[i], holes: []) }
        for i in rings.indices where parents[i].count % 2 == 1 {
            let candidates = parents[i].filter { parents[$0].count == parents[i].count - 1 }
            if let host = candidates.min(by: { area(rings[$0]) < area(rings[$1]) }) { shapes[host]?.holes.append(rings[i]) }
        }
        return rings.indices.compactMap { shapes[$0] }
    }
}

/// Map of the warned districts (polygons of the bundled geometry). The list is the accessible alternative.
struct WarnMapView: UIViewRepresentable {
    let severityByCell: [WarnCellID: Int]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let geometry: WarnGeometry? = try? WarnGeometry.bundled()

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.preferredConfiguration = MKStandardMapConfiguration(elevationStyle: .flat)
        map.pointOfInterestFilter = .excludingAll
        map.showsCompass = false
        map.isRotateEnabled = false
        map.accessibilityIdentifier = "warn-map"
        map.accessibilityLabel = Bundle.main.localizedString(forKey: "WARN_MAP_LABEL", value: nil, table: nil)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        guard context.coordinator.shown != severityByCell else { return }
        context.coordinator.shown = severityByCell
        map.removeOverlays(map.overlays)
        var rect = MKMapRect.null
        if let geometry = Self.geometry {
            for cell in geometry.cells {
                guard let level = severityByCell[cell.id] else { continue }
                for shape in WarnOverlayModel.shapes(of: cell) {
                    let polygon = MKPolygon(coordinates: shape.outer.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) },
                                            count: shape.outer.count,
                                            interiorPolygons: shape.holes.map { hole in
                                                MKPolygon(coordinates: hole.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }, count: hole.count)
                                            })
                    polygon.title = String(level)
                    map.addOverlay(polygon)
                    rect = rect.union(polygon.boundingMapRect)
                }
            }
        }
        if rect.isNull {
            map.setRegion(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 51.1, longitude: 10.4),
                                             span: MKCoordinateSpan(latitudeDelta: 9, longitudeDelta: 9)), animated: false)
        } else {
            map.setVisibleMapRect(rect, edgePadding: UIEdgeInsets(top: 40, left: 30, bottom: 40, right: 30), animated: !reduceMotion)
        }
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var shown: [WarnCellID: Int]?

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polygon = overlay as? MKPolygon else { return MKOverlayRenderer(overlay: overlay) }
            let level = Int(polygon.title ?? "") ?? 1
            let renderer = MKPolygonRenderer(polygon: polygon)
            renderer.fillColor = WarnStyle.uiColor(level).withAlphaComponent(0.28)
            renderer.strokeColor = WarnStyle.uiColor(level)
            renderer.lineWidth = WarnStyle.lineWidth(level)
            renderer.lineDashPattern = WarnStyle.dashPattern(level)?.map { NSNumber(value: $0) }
            return renderer
        }
    }
}
