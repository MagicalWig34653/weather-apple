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
    func ageDescription(at now: Date) -> String {
        let minutes = max(0, Int(now.timeIntervalSince(referenceTime) / 60))
        if minutes < 60 { return "Stand vor \(minutes) Min." }
        return "Stand vor \(minutes / 60) Std. \(minutes % 60) Min."
    }

    func summary(at now: Date) -> String {
        guard !isStale(at: now) else { return "Prognosedaten sind veraltet" }
        let remaining = samples.filter { $0.date >= now }
        guard !remaining.isEmpty else { return "Keine aktuelle Prognose verfügbar" }
        let firstRain = remaining.first { ($0.rateMMPerHour ?? -1) >= Self.rainThresholdMMPerHour }
        if let firstRain {
            let earlierUnknown = remaining.contains { $0.date <= firstRain.date && $0.amountMM == nil }
            if earlierUnknown { return "Regen möglich · Daten teilweise unvollständig" }
            let minutes = Int(max(0, firstRain.date.timeIntervalSince(now) / 60))
            if minutes < 5 { return "Regen am ausgewählten Ort" }
            return "Regen voraussichtlich in etwa \(minutes) Min."
        }
        guard remaining.allSatisfy({ $0.amountMM != nil }) else {
            return "Keine verlässliche Regenaussage verfügbar"
        }
        return "Vorerst kein messbarer Regen erwartet"
    }
}

struct RadarTimeline: Sendable {
    let referenceTime: Date
    let dates: [Date]
    /// Set when the frames come from the radar cache backend; `nil` means direct DWD tiles.
    var backend: RadarManifest?
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

    var errorDescription: String? {
        switch self {
        case .unsupportedLocation: "Der Ort liegt außerhalb des unterstützten Radargebiets."
        case .invalidResponse: "Die Wetterdaten konnten nicht gelesen werden."
        case .emptyBody: "Die Wetterdaten konnten nicht gelesen werden (leere Antwort)."
        case .oversizedBody: "Die Wetterdaten konnten nicht gelesen werden (Antwort zu groß)."
        case .malformedPayload: "Die Wetterdaten konnten nicht gelesen werden (kein gültiges Datenformat)."
        case .unexpectedPayload: "Die Wetterdaten konnten nicht gelesen werden (unerwarteter Inhalt)."
        case .invalidTimeFormat: "Die Wetterdaten konnten nicht gelesen werden (Zeitangaben ungültig)."
        case .serviceFailure: "Die Wetterdaten konnten nicht gelesen werden (Fehlermeldung des DWD-Dienstes)."
        case .runUnavailable: "Der angekündigte DWD-Datenlauf ist am Radardienst noch nicht verfügbar. Bitte erneut versuchen."
        case .unavailable: "Die DWD-Wetterdaten sind momentan nicht erreichbar."
        case .staleData: "Der DWD stellt momentan keinen ausreichend aktuellen Datenlauf bereit."
        case .incompleteForecast: "Der DWD liefert für diesen Ort keine vollständige Prognose."
        case .mismatchedRun: "Die Wetterdaten gehören zu einem anderen Datenlauf. Bitte erneut laden."
        }
    }
}
