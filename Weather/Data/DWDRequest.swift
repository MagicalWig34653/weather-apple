import Foundation

enum DWDRequest {
    static let indexURL = URL(string: "https://opendata.dwd.de/weather/radar/composite/rv/")!
    static let endpoint = URL(string: "https://maps.dwd.de/geoserver/ows")!

    static func timestamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }

    static func date(_ text: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: text) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: text)
    }

    static func pointURL(at coordinate: WeatherCoordinate, referenceTime: Date) throws -> URL {
        guard coordinate.isSupported else { throw DWDDataError.unsupportedLocation }
        let box = [coordinate.latitude - 0.005, coordinate.longitude - 0.005,
                   coordinate.latitude + 0.005, coordinate.longitude + 0.005]
            .map { String($0) }.joined(separator: ",")
        return url(parameters: [
            "SERVICE": "WMS", "VERSION": "1.3.0", "REQUEST": "GetFeatureInfo",
            "LAYERS": "dwd:Niederschlagsradar", "QUERY_LAYERS": "dwd:Niederschlagsradar",
            "STYLES": "", "CRS": "EPSG:4326", "BBOX": box,
            "WIDTH": "3", "HEIGHT": "3", "I": "1", "J": "1",
            "FORMAT": "image/png", "INFO_FORMAT": "application/json",
            "TIME": "\(timestamp(referenceTime))/\(timestamp(referenceTime.addingTimeInterval(7200)))/PT5M",
            "DIM_REFERENCE_TIME": timestamp(referenceTime)
        ])
    }

    /// WMS 1.1.1 uses x/y axis order with EPSG:3857, matching MapKit's tile coordinates.
    static func tileURL(x: Int, y: Int, z: Int, date: Date, referenceTime: Date) -> URL {
        let halfWorld = 20_037_508.342789244
        let count = pow(2, Double(z))
        let width = 2 * halfWorld / count
        let minimumX = -halfWorld + Double(x) * width
        let maximumY = halfWorld - Double(y) * width
        let box = [minimumX, maximumY - width, minimumX + width, maximumY]
            .map { String($0) }.joined(separator: ",")
        return url(parameters: [
            "SERVICE": "WMS", "VERSION": "1.1.1", "REQUEST": "GetMap",
            "LAYERS": "dwd:Niederschlagsradar", "STYLES": "", "SRS": "EPSG:3857",
            "BBOX": box, "WIDTH": "256", "HEIGHT": "256", "FORMAT": "image/png",
            "TRANSPARENT": "TRUE", "TIME": timestamp(date),
            "DIM_REFERENCE_TIME": timestamp(referenceTime)
        ])
    }

    private static func url(parameters: [String: String]) -> URL {
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)!
        components.queryItems = parameters.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        return components.url!
    }
}
