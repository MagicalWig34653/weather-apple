import Foundation

/// Identifiers shared by the app, widgets, watch app and watch widgets.
enum SharedConfig {
    static let appGroup = "group.de.linolaske.showernow"
    static let urlScheme = "showernow"

    /// App-Group-Container; nur in Debug-Builds (z. B. Simulator ohne Signing, ohne Entitlements)
    /// Fallback auf ein lokales Verzeichnis, damit Persistenz testbar bleibt. Release schlägt weiterhin fehl.
    static func sharedContainerURL() throws -> URL {
        if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) { return url }
        #if DEBUG
        let dir = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                              appropriateFor: nil, create: true).appendingPathComponent("SharedFallback", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
        #else
        throw PlaceStore.StorageError.appGroupUnavailable
        #endif
    }
}
