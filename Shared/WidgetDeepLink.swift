import Foundation

enum WidgetDeepLink {
    static func url(for placeID: UUID) -> URL {
        URL(string: "\(SharedConfig.urlScheme)://place/\(placeID.uuidString)")!
    }

    static func placeID(from url: URL) -> UUID? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == SharedConfig.urlScheme,
              components.host?.lowercased() == "place",
              components.user == nil, components.password == nil, components.port == nil,
              components.query == nil, components.fragment == nil else { return nil }
        let path = components.path
        guard path.hasPrefix("/"), !path.dropFirst().contains("/") else { return nil }
        return UUID(uuidString: String(path.dropFirst()))
    }
}
