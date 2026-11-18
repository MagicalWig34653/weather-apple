import Foundation

/// Which notices the radar screen shows under the forecast header, in order. Several can apply at once;
/// a radar image problem must not hide the reason of a forecast failure (and the other way round).
struct RadarStatusInput: Equatable {
    var locationMessage: String?
    var storageMessage: String?
    /// Radar layer is shown (not pressure, lightning, ...).
    var radarLayerActive = true
    var layerTitle = ""
    var radarImageMissing = false
    var radarFromCache = true
    var radarError: String?
    var forecastError: String?
    var forecastShown = false
    var forecastFailureConfirmed = false
    var radarNotice: String?
}

enum RadarStatusMessages {
    /// At most this many notices are stacked.
    static let limit = 2

    static func messages(_ input: RadarStatusInput) -> [String] {
        var result: [String] = []
        if let message = input.locationMessage { result.append(message) }
        if let message = input.storageMessage { result.append(message) }
        // The forecast reason comes before the image problem: it explains the header above.
        if input.radarLayerActive, let error = input.forecastError, !input.forecastShown || input.forecastFailureConfirmed {
            result.append(String(format: NSLocalizedString("RADAR_STATUS_FORECAST_ERROR", value: "Ortsprognose: %@", comment: "Radar"), error))
        }
        if input.radarImageMissing {
            if !input.radarLayerActive {
                result.append(String(format: NSLocalizedString("RADAR_STATUS_LAYER_IMAGE_MISSING", value: "Das Bild der Ebene %@ für diesen Zeitpunkt fehlt. Bitte erneut aktualisieren.", comment: "Radar"), input.layerTitle))
            } else {
                result.append(input.radarFromCache
                    ? NSLocalizedString("RADAR_STATUS_IMAGE_MISSING", value: "Das Radarbild für diesen Zeitpunkt fehlt. Bitte erneut aktualisieren.", comment: "Radar")
                    : NSLocalizedString("RADAR_STATUS_TILES_MISSING", value: "Einige Radarkacheln fehlen. Bitte erneut aktualisieren.", comment: "Radar"))
            }
        }
        if input.radarLayerActive {
            if let error = input.radarError { result.append(String(format: NSLocalizedString("RADAR_STATUS_RADAR_ERROR", value: "Radar: %@", comment: "Radar"), error)) }
            if let notice = input.radarNotice { result.append(notice) }
        }
        return Array(result.prefix(limit))
    }
}
