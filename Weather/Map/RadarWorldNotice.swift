import Foundation

/// Fixed notes of the world rain map (NOAA RRQPE, satellite estimate). The estimate note is always shown while the
/// layer is active (decision 17.11.2026); coverage and missing-data notes appear only while they apply.
/// No logo, no endorsement wording: the source is named only in the credit line and under "Datenquellen".
enum RadarWorldNotice {
    enum Coverage: Equatable { case full, degraded, outside }

    enum Kind: String, Equatable { case estimate, degraded, outside, unavailable }

    struct Notice: Equatable, Identifiable {
        let kind: Kind
        let text: String
        var id: String { kind.rawValue }
    }

    /// Data from 60° S to 70° N; north of 60° N the product flags most pixels as degraded (drawn paler by the backend).
    static func coverage(latitude: Double) -> Coverage {
        guard latitude.isFinite else { return .full }
        if latitude > 70 || latitude < -60 { return .outside }
        return latitude > 60 ? .degraded : .full
    }

    static var estimateText: String {
        NSLocalizedString("RADAR_WORLD_ESTIMATE_NOTE", value: "Schätzung aus Satellitendaten, ungenauer als Radar. Keine Vorhersage.",
                          comment: "Fixed note on the world rain map")
    }

    static func notices(active: RadarLayer, availability: LayerAvailability, centerLatitude: Double?) -> [Notice] {
        guard active == .radarWorld else { return [] }
        var result = [Notice(kind: .estimate, text: estimateText)]
        switch availability {
        case .unknown:
            break
        case .available:
            switch coverage(latitude: centerLatitude ?? .nan) {
            case .full: break
            case .degraded:
                result.append(Notice(kind: .degraded, text: NSLocalizedString(
                    "RADAR_WORLD_DEGRADED_NOTE", value: "Nördlich von 60° N sind die Schätzwerte eingeschränkt und blasser dargestellt.",
                    comment: "World rain map: degraded data north of 60 N")))
            case .outside:
                result.append(Notice(kind: .outside, text: NSLocalizedString(
                    "RADAR_WORLD_OUTSIDE_NOTE", value: "Hier gibt es keine Werte: Die Weltkarte reicht nur von 60° S bis 70° N.",
                    comment: "World rain map: map centre outside the covered area")))
            }
        case .notPublished, .unreachable, .invalid, .stale:
            result.append(Notice(kind: .unavailable, text: unavailableText(availability)))
        }
        return result
    }

    /// The layer stays chosen (no silent switch to another source); the map shows no rain picture and says why.
    static func unavailableText(_ availability: LayerAvailability) -> String {
        switch availability {
        case .stale:
            NSLocalizedString("RADAR_WORLD_STALE_NOTE", value: "Regen Welt: keine aktuellen Daten. Die Karte zeigt deshalb keinen Regen.",
                              comment: "World rain map: newest data too old")
        case .unreachable:
            NSLocalizedString("RADAR_WORLD_UNREACHABLE_NOTE", value: "Regen Welt: Server nicht erreichbar. Die Karte zeigt deshalb keinen Regen.",
                              comment: "World rain map: server unreachable")
        case .invalid:
            NSLocalizedString("RADAR_WORLD_INVALID_NOTE", value: "Regen Welt: Daten nicht lesbar. Die Karte zeigt deshalb keinen Regen.",
                              comment: "World rain map: unreadable manifest")
        default:
            NSLocalizedString("RADAR_WORLD_UNAVAILABLE_NOTE", value: "Regen Welt ist derzeit nicht verfügbar. Die Karte zeigt deshalb keinen Regen.",
                              comment: "World rain map: layer not published")
        }
    }
}
