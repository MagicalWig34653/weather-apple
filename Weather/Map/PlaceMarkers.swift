import MapKit
import UIKit

/// Pure logic for the tappable place markers: which places get a marker and how the map focuses a place.
enum PlaceFocus {
    static let defaultSpanMeters: Double = 180_000
    static let minimumSpanMeters: Double = 20_000

    /// Zoom after a jump: a closer view keeps its zoom (at least `minimumSpanMeters`), a wider view zooms in.
    static func spanMeters(current: Double?) -> Double {
        guard let current, current.isFinite, current > 0 else { return defaultSpanMeters }
        return min(max(current, minimumSpanMeters), defaultSpanMeters)
    }

    static func region(latitude: Double, longitude: Double, currentSpanMeters: Double?) -> MKCoordinateRegion {
        let span = spanMeters(current: currentSpanMeters)
        return MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                                  latitudinalMeters: span, longitudinalMeters: span)
    }

    /// Saved places only (never a location history); the selected place already has the main pin.
    static func markers(places: [SavedPlace], selectedID: UUID) -> [SavedPlace] {
        places.filter { $0.id != selectedID && $0.coordinate.isSupported }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    static func accessibilityLabel(for name: String) -> String { "Zum Ort \(name) springen" }
}

final class PlaceAnnotation: NSObject, MKAnnotation {
    let place: SavedPlace
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: place.coordinate.latitude, longitude: place.coordinate.longitude)
    }
    var title: String? { place.name }
    init(place: SavedPlace) { self.place = place }
}

/// Small name marker: dot plus the place name in a capsule. At least 44 pt high, so it is easy to hit.
final class PlaceMarkerView: MKAnnotationView {
    static let reuseID = "place-marker"
    var onActivate: (() -> Void)?

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        collisionMode = .rectangle
        displayPriority = .defaultHigh
        isAccessibilityElement = true
        accessibilityTraits = .button
        canShowCallout = false
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    override var annotation: MKAnnotation? { didSet { render() } }

    private func render() {
        guard let name = annotation?.title ?? nil else { return }
        accessibilityLabel = PlaceFocus.accessibilityLabel(for: name)
        accessibilityIdentifier = "place-marker-\(name)"
        let text = NSAttributedString(string: name, attributes: [.font: UIFont.systemFont(ofSize: 12, weight: .semibold),
                                                                  .foregroundColor: UIColor.label])
        let textSize = text.size()
        let width = min(ceil(textSize.width) + 28, 180)
        let size = CGSize(width: max(width, 44), height: 44)
        let chip = CGRect(x: (size.width - width) / 2, y: 7, width: width, height: 30)
        image = UIGraphicsImageRenderer(size: size).image { context in
            let path = UIBezierPath(roundedRect: chip, cornerRadius: 15)
            UIColor.systemBackground.withAlphaComponent(0.88).setFill()
            path.fill()
            UIColor.systemCyan.setStroke()
            path.lineWidth = 1.5
            path.stroke()
            let dot = CGRect(x: chip.minX + 8, y: chip.midY - 3, width: 6, height: 6)
            UIColor.systemCyan.setFill()
            UIBezierPath(ovalIn: dot).fill()
            let textRect = CGRect(x: chip.minX + 18, y: chip.midY - textSize.height / 2,
                                  width: chip.width - 24, height: textSize.height)
            text.draw(with: textRect, options: [.truncatesLastVisibleLine, .usesLineFragmentOrigin], context: nil)
        }
        bounds = CGRect(origin: .zero, size: size)
        centerOffset = CGPoint(x: 0, y: -size.height / 2 + 4)
    }

    override func accessibilityActivate() -> Bool {
        onActivate?()
        return onActivate != nil
    }
}
