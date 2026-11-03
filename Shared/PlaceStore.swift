import Foundation
import Darwin

/// Gespeicherte Orte des jeweiligen Geräts; der App-Group-Container wird nicht zwischen Geräten synchronisiert.
struct PlaceStore: Sendable {
    struct Snapshot: Codable, Equatable, Sendable {
        var places: [SavedPlace]
        var selectedPlaceID: UUID?

        init(places: [SavedPlace] = [], selectedPlaceID: UUID? = nil) {
            self.places = places
            self.selectedPlaceID = selectedPlaceID
        }
    }

    enum StorageError: Error { case appGroupUnavailable }

    private let directory: URL
    private let legacyPlacesURL: URL?
    private let removeLegacy: @Sendable (URL) throws -> Void
    private var migrationMarkerURL: URL { directory.appendingPathComponent(".places-migrated") }
    private var fileURL: URL { directory.appendingPathComponent("places.json") }

    init() throws {
        let container = try SharedConfig.sharedContainerURL()
        let legacy = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                 appropriateFor: nil, create: false).appendingPathComponent("places.json")
        self.init(directory: container, legacyPlacesURL: legacy)
    }

    /// Eigene Verzeichnisse und injizierbare Bereinigung erlauben isolierte Tests.
    init(directory: URL, legacyPlacesURL: URL? = nil,
         removeLegacy: @escaping @Sendable (URL) throws -> Void = { try FileManager.default.removeItem(at: $0) }) {
        self.directory = directory
        self.legacyPlacesURL = legacyPlacesURL
        self.removeLegacy = removeLegacy
    }

    func load() throws -> Snapshot {
        try withSnapshot { $0 }
    }

    /// Cachezugriffe halten diese Sperre bis nach dem Schreiben. Ortsänderungen warten darauf.
    /// Sperrreihenfolge: ForecastCache, dann PlaceStore; niemals umgekehrt.
    func withSnapshot<T>(_ body: (Snapshot) throws -> T) throws -> T {
        try withLock { try body(loadUnlocked()) }
    }

    private func loadUnlocked() throws -> Snapshot {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            let snapshot = try JSONDecoder().decode(Snapshot.self, from: Data(contentsOf: fileURL))
            try finishMigration()
            return snapshot
        }
        // Auch nach fehlgeschlagener Bereinigung darf eine entfernte Zieldatei keinen Re-Import auslösen.
        if FileManager.default.fileExists(atPath: migrationMarkerURL.path) {
            try finishMigration()
            return Snapshot()
        }
        guard let legacyPlacesURL, FileManager.default.fileExists(atPath: legacyPlacesURL.path) else {
            return Snapshot()
        }
        let places = try JSONDecoder().decode([SavedPlace].self, from: Data(contentsOf: legacyPlacesURL))
        let snapshot = Snapshot(places: places, selectedPlaceID: places.first?.id)
        try saveUnlocked(snapshot)
        return snapshot
    }

    func save(_ snapshot: Snapshot) throws {
        try withLock { try saveUnlocked(snapshot) }
    }

    private func saveUnlocked(_ snapshot: Snapshot) throws {
        var snapshot = snapshot
        if !snapshot.places.contains(where: { $0.id == snapshot.selectedPlaceID }) {
            snapshot.selectedPlaceID = snapshot.places.first?.id
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(snapshot).write(to: fileURL,
                                                options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        try finishMigration()
    }

    private func finishMigration() throws {
        guard let legacyPlacesURL, legacyPlacesURL.standardizedFileURL != fileURL.standardizedFileURL,
              FileManager.default.fileExists(atPath: legacyPlacesURL.path) else { return }
        // Erst nach atomarem Schreiben bzw. erfolgreichem Lesen des Ziels markieren und bereinigen.
        if !FileManager.default.fileExists(atPath: migrationMarkerURL.path) {
            try Data().write(to: migrationMarkerURL, options: .atomic)
        }
        // Das gültige Ziel bleibt nutzbar; jeder weitere Start/Schreibzugriff wiederholt die Bereinigung.
        try? removeLegacy(legacyPlacesURL)
    }

    private func withLock<T>(_ body: () throws -> T) throws -> T {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let descriptor = Darwin.open(directory.appendingPathComponent(".places.lock").path,
                                     O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        defer { Darwin.close(descriptor) }
        while flock(descriptor, LOCK_EX) != 0 {
            guard errno == EINTR else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        }
        defer { _ = flock(descriptor, LOCK_UN) }
        return try body()
    }
}
