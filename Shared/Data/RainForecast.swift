import Foundation

struct WeatherCoordinate: Codable, Hashable, Sendable {
    let latitude: Double
    let longitude: Double

    var isSupported: Bool {
        latitude.isFinite && longitude.isFinite
            && (45.0...56.5).contains(latitude) && (0.0...20.0).contains(longitude)
    }
}

struct RainSample: Identifiable, Codable, Sendable {
    let date: Date
    /// Accumulation during the five-minute interval ending at `date`.
    let amountMM: Double?
    var rateMMPerHour: Double? { amountMM.map { $0 * 12 } }
    var id: Date { date }
}

struct RainForecast: Codable, Sendable {
    let referenceTime: Date
    let samples: [RainSample]

    static let maximumAge: TimeInterval = 20 * 60
    static let rainThresholdMMPerHour: Double = 0.1

    var isStale: Bool { isStale(at: Date()) }
    var summary: String { summary(at: Date()) }

    func isStale(at now: Date) -> Bool {
        now.timeIntervalSince(referenceTime) > Self.maximumAge
            || referenceTime.timeIntervalSince(now) > 60
    }

    /// Age of the DWD run, e.g. "Stand vor 7 Min." (the run time, not the fetch time).
    func ageDescription(at now: Date, bundle: Bundle = .main) -> String {
        let minutes = max(0, Int(now.timeIntervalSince(referenceTime) / 60))
        if minutes < 60 {
            return String(format: NSLocalizedString("DATA_AGE_MINUTES", bundle: bundle, value: "Stand vor %d Min.", comment: "Age of the DWD run, minutes"), minutes)
        }
        return String(format: NSLocalizedString("DATA_AGE_HOURS_MINUTES", bundle: bundle, value: "Stand vor %1$d Std. %2$d Min.", comment: "Age of the DWD run, hours and minutes"),
                      minutes / 60, minutes % 60)
    }

    func summary(at now: Date, bundle: Bundle = .main) -> String {
        RainOutlook.evaluate(self, at: now).summary(bundle: bundle)
    }
}


enum DWDDataError: LocalizedError, Equatable {
    case unsupportedLocation
    /// Generic unreadable answer (e.g. a non-HTTP response or an image that fails validation).
    case invalidResponse
    case emptyBody
    case oversizedBody
    /// Body is not valid JSON or lacks required fields (HTML from a gateway, truncated JSON).
    case malformedPayload
    /// Valid JSON of the wrong shape (type is not FeatureCollection, count mismatch).
    case unexpectedPayload
    case invalidTimeFormat
    /// HTTP 200 with a ServiceException other than a not-yet-available run.
    case serviceFailure
    case unavailable
    case runUnavailable
    case staleData
    case incompleteForecast
    case mismatchedRun

    var errorDescription: String? { message(bundle: .main) }

    func message(bundle: Bundle) -> String {
        switch self {
        case .unsupportedLocation: NSLocalizedString("DATA_ERR_UNSUPPORTED_LOCATION", bundle: bundle, value: "Der Ort liegt außerhalb des unterstützten Radargebiets.", comment: "Data error")
        case .invalidResponse: NSLocalizedString("DATA_ERR_INVALID_RESPONSE", bundle: bundle, value: "Die Wetterdaten konnten nicht gelesen werden.", comment: "Data error")
        case .emptyBody: NSLocalizedString("DATA_ERR_EMPTY_BODY", bundle: bundle, value: "Die Wetterdaten konnten nicht gelesen werden (leere Antwort).", comment: "Data error")
        case .oversizedBody: NSLocalizedString("DATA_ERR_OVERSIZED_BODY", bundle: bundle, value: "Die Wetterdaten konnten nicht gelesen werden (Antwort zu groß).", comment: "Data error")
        case .malformedPayload: NSLocalizedString("DATA_ERR_MALFORMED_PAYLOAD", bundle: bundle, value: "Die Wetterdaten konnten nicht gelesen werden (kein gültiges Datenformat).", comment: "Data error")
        case .unexpectedPayload: NSLocalizedString("DATA_ERR_UNEXPECTED_PAYLOAD", bundle: bundle, value: "Die Wetterdaten konnten nicht gelesen werden (unerwarteter Inhalt).", comment: "Data error")
        case .invalidTimeFormat: NSLocalizedString("DATA_ERR_INVALID_TIME", bundle: bundle, value: "Die Wetterdaten konnten nicht gelesen werden (Zeitangaben ungültig).", comment: "Data error")
        case .serviceFailure: NSLocalizedString("DATA_ERR_SERVICE_FAILURE", bundle: bundle, value: "Die Wetterdaten konnten nicht gelesen werden (Fehlermeldung des DWD-Dienstes).", comment: "Data error")
        case .runUnavailable: NSLocalizedString("DATA_ERR_RUN_UNAVAILABLE", bundle: bundle, value: "Der angekündigte DWD-Datenlauf ist am Radardienst noch nicht verfügbar. Bitte erneut versuchen.", comment: "Data error")
        case .unavailable: NSLocalizedString("DATA_ERR_UNAVAILABLE", bundle: bundle, value: "Die DWD-Wetterdaten sind momentan nicht erreichbar.", comment: "Data error")
        case .staleData: NSLocalizedString("DATA_ERR_STALE", bundle: bundle, value: "Der DWD stellt momentan keinen ausreichend aktuellen Datenlauf bereit.", comment: "Data error")
        case .incompleteForecast: NSLocalizedString("DATA_ERR_INCOMPLETE", bundle: bundle, value: "Der DWD liefert für diesen Ort keine vollständige Prognose.", comment: "Data error")
        case .mismatchedRun: NSLocalizedString("DATA_ERR_MISMATCHED_RUN", bundle: bundle, value: "Die Wetterdaten gehören zu einem anderen Datenlauf. Bitte erneut laden.", comment: "Data error")
        }
    }
}
