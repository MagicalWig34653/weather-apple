import Foundation
import Darwin

/// Pro gespeichertem Ort nur die letzte gültige Prognose; keine Abrufzeiten oder Ortskoordinaten.
struct ForecastCache: Sendable {
    enum CacheError: Error { case invalidForecast }
    private let directory: URL
    private let placeStore: PlaceStore?

    init() throws {
        let container = try SharedConfig.sharedContainerURL()
        self.init(directory: container.appendingPathComponent("ForecastCache", isDirectory: true),
                  placeStore: try PlaceStore())
    }

    /// Ohne PlaceStore nur für isolierte Cache-Tests; Produktzugriffe prüfen immer die Ortsliste.
    init(directory: URL, placeStore: PlaceStore? = nil) {
        self.directory = directory
        self.placeStore = placeStore
    }

    func load(for placeID: UUID) throws -> RainForecast? {
        try withLock {
            try withPlaces { places in
                if let places {
                    try retainUnlocked(placeIDs: Set(places.map(\.id)))
                    guard places.contains(where: { $0.id == placeID }) else { return nil }
                }
                return try loadUnlocked(for: placeID)
            }
        }
    }

    private func loadUnlocked(for placeID: UUID) throws -> RainForecast? {
        let url = fileURL(for: placeID)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let forecast = try JSONDecoder().decode(RainForecast.self, from: Data(contentsOf: url))
        guard Self.isValid(forecast) else { throw CacheError.invalidForecast }
        return forecast
    }

    func save(_ forecast: RainForecast, for placeID: UUID) throws {
        guard Self.isValid(forecast) else { throw CacheError.invalidForecast }
        try withLock {
            try withPlaces { places in
                if let places {
                    try retainUnlocked(placeIDs: Set(places.map(\.id)))
                    guard places.contains(where: { $0.id == placeID }) else { return }
                }
                // Ortsprüfung, Vergleich und Schreiben sind gegenüber Ortsänderungen unteilbar.
                if let previous = try? loadUnlocked(for: placeID), previous.referenceTime > forecast.referenceTime { return }
                try JSONEncoder().encode(forecast).write(to: fileURL(for: placeID),
                                                       options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            }
        }
    }

    func remove(for placeID: UUID) throws {
        try withLock {
            let url = fileURL(for: placeID)
            if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
        }
    }

    func retain(placeIDs: Set<UUID>) throws {
        try withLock {
            try withPlaces { places in
                // Ein älterer Aufrufer-Snapshot darf keine inzwischen gelöschten Orte behalten.
                let currentIDs = places.map { Set($0.map(\.id)) }
                try retainUnlocked(placeIDs: currentIDs.map { $0.intersection(placeIDs) } ?? placeIDs)
            }
        }
    }

    private func retainUnlocked(placeIDs: Set<UUID>) throws {
        for url in try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
            guard url.pathExtension == "json", let id = UUID(uuidString: url.deletingPathExtension().lastPathComponent),
                  !placeIDs.contains(id) else { continue }
            try FileManager.default.removeItem(at: url)
        }
    }

    private func withPlaces<T>(_ body: ([SavedPlace]?) throws -> T) throws -> T {
        if let placeStore { return try placeStore.withSnapshot { try body($0.places) } }
        return try body(nil)
    }

    // Die unveränderte Lockdatei wird nie ersetzt oder gelöscht: alle Prozesse sperren denselben Inode.
    private func withLock<T>(_ body: () throws -> T) throws -> T {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let descriptor = Darwin.open(directory.appendingPathComponent(".lock").path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        defer { Darwin.close(descriptor) }
        while flock(descriptor, LOCK_EX) != 0 {
            guard errno == EINTR else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        }
        defer { _ = flock(descriptor, LOCK_UN) }
        return try body()
    }

    private func fileURL(for placeID: UUID) -> URL { directory.appendingPathComponent(placeID.uuidString + ".json") }

    private static func isValid(_ forecast: RainForecast) -> Bool {
        guard forecast.referenceTime.timeIntervalSinceReferenceDate.isFinite, !forecast.samples.isEmpty else { return false }
        var previous = Date.distantPast
        var hasValue = false
        for sample in forecast.samples {
            guard sample.date.timeIntervalSinceReferenceDate.isFinite, sample.date > previous else { return false }
            if let amount = sample.amountMM {
                guard amount.isFinite, amount >= 0 else { return false }
                hasValue = true
            }
            previous = sample.date
        }
        return hasValue
    }
}
