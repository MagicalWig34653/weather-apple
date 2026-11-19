import Foundation

/// Notes of the rain maps beyond Germany. Europe: only the missing-data note (layer stays chosen, 19.11.).
/// Fixed notes of the world rain map (NOAA RRQPE, satellite estimate). The estimate note is always shown while the
/// layer is active (decision 17.11.2026); coverage and missing-data notes appear only while they apply.
/// No logo, no endorsement wording: the source is named only in the credit line and under "Datenquellen".
enum RainLayerNotice {
    enum Coverage: Equatable { case full, degraded, outside }

    enum Kind: String, Equatable { case estimate, degraded, outside, unavailable }

    struct Notice: Equatable, Identifiable {
        let kind: Kind
        let text: String
        /// Accessibility identifier: `radar-world-note-<kind>` or `radar-eu-note-<kind>`.
        let identifier: String
        var id: String { identifier }
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
        // Europe (OPERA, radar measurement): no estimate or coverage note, only the one missing-data note.
        if active == .radarEU {
            switch availability {
            case .notPublished, .unreachable, .invalid, .stale:
                return [Notice(kind: .unavailable, text: europeUnavailableText(availability), identifier: "radar-eu-note-unavailable")]
            case .unknown, .available:
                return []
            }
        }
        guard active == .radarWorld else { return [] }
        var result = [Notice(kind: .estimate, text: estimateText, identifier: "radar-world-note-estimate")]
        switch availability {
        case .unknown:
            break
        case .available:
            switch coverage(latitude: centerLatitude ?? .nan) {
            case .full: break
            case .degraded:
                result.append(Notice(kind: .degraded, text: NSLocalizedString(
                    "RADAR_WORLD_DEGRADED_NOTE", value: "Nördlich von 60° N sind die Schätzwerte eingeschränkt und blasser dargestellt.",
                    comment: "World rain map: degraded data north of 60 N"), identifier: "radar-world-note-degraded"))
            case .outside:
                result.append(Notice(kind: .outside, text: NSLocalizedString(
                    "RADAR_WORLD_OUTSIDE_NOTE", value: "Hier gibt es keine Werte: Die Weltkarte reicht nur von 60° S bis 70° N.",
                    comment: "World rain map: map centre outside the covered area"), identifier: "radar-world-note-outside"))
            }
        case .notPublished, .unreachable, .invalid, .stale:
            result.append(Notice(kind: .unavailable, text: unavailableText(availability), identifier: "radar-world-note-unavailable"))
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

    static func europeUnavailableText(_ availability: LayerAvailability) -> String {
        switch availability {
        case .stale:
            NSLocalizedString("RADAR_EU_STALE_NOTE", value: "Regen Europa: keine aktuellen Daten. Die Karte zeigt deshalb keinen Regen.",
                              comment: "Europe rain map: newest data too old")
        case .unreachable:
            NSLocalizedString("RADAR_EU_UNREACHABLE_NOTE", value: "Regen Europa: Server nicht erreichbar. Die Karte zeigt deshalb keinen Regen.",
                              comment: "Europe rain map: server unreachable")
        case .invalid:
            NSLocalizedString("RADAR_EU_INVALID_NOTE", value: "Regen Europa: Daten nicht lesbar. Die Karte zeigt deshalb keinen Regen.",
                              comment: "Europe rain map: unreadable manifest")
        default:
            NSLocalizedString("RADAR_EU_UNAVAILABLE_NOTE", value: "Regen Europa ist derzeit nicht verfügbar. Die Karte zeigt deshalb keinen Regen.",
                              comment: "Europe rain map: layer not published")
        }
    }
}
