import Foundation

struct SavedPlace: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    var name: String
    var coordinate: WeatherCoordinate
}
