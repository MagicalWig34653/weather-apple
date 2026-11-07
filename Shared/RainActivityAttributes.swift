import Foundation
#if canImport(ActivityKit) && os(iOS)
import ActivityKit
#endif

/// Shared with the widget extension and the P2 APNs payload. No coordinates or device identifiers.
public struct RainActivityAttributes: Codable, Hashable, Sendable {
    public static let placeMappingDefaultsKey = "rainActivity.subscriptionPlaces.v1"

    /// Pass the iOS App Group defaults; resolve the resulting ID through PlaceStore.
    /// Remote starts carry an empty displayName; use a neutral title if there is no local match.
    public func placeID(in defaults: UserDefaults) -> UUID? {
        guard let value = defaults.dictionary(forKey: Self.placeMappingDefaultsKey)?[subscriptionID] as? String else { return nil }
        return UUID(uuidString: value)
    }

    /// Name and radius of a region subscription, written by the app (App Group), never sent to the server.
    public static let regionMappingDefaultsKey = "rainActivity.subscriptionRegions.v1"

    public struct RegionInfo: Equatable, Sendable {
        public var name: String?
        public var radiusKm: Int?
        public init(name: String?, radiusKm: Int?) { self.name = name; self.radiusKm = radiusKm }
    }

    /// Local data of a region subscription; nil for places and unknown subscriptions.
    public func regionInfo(in defaults: UserDefaults) -> RegionInfo? {
        guard let entry = defaults.dictionary(forKey: Self.regionMappingDefaultsKey)?[subscriptionID] as? [String: Any] else { return nil }
        let name = (entry["name"] as? String).flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
        return RegionInfo(name: name, radiusKm: (entry["radiusKm"] as? Int).flatMap { $0 >= 1 ? $0 : nil })
    }

    public var displayName: String
    public var subscriptionID: String

    public init(displayName: String, subscriptionID: String) {
        self.displayName = displayName
        self.subscriptionID = subscriptionID
    }

    public enum Phase: String, Codable, Sendable {
        case startsIn, raining, endsIn, dry
    }

    /// Dates deliberately use Codable's default epoch (2001), matching P2.
    /// APS timestamp/stale-date use UNIX seconds and are outside this type.
    public struct ContentState: Codable, Hashable, Sendable {
        public var phase: Phase
        public var eventDate: Date?
        public var intensityClass: Int
        public var referenceTime: Date
        public var staleDate: Date?
        /// Region subscriptions only (Live Activity for areas). All three are optional so that point payloads
        /// and states from older servers decode unchanged (synthesized `decodeIfPresent`) and encode without them.
        /// Share of the current slot in percent (0...100); lower bound, unknown cells never count as wet.
        public var wetSharePercent: Int?
        /// Highest share in percent over the slots 0...12.
        public var peakSharePercent: Int?
        /// Radius in km (at least 1); may be absent, then the locally known radius is used.
        public var regionRadiusKm: Int?

        public init(phase: Phase, eventDate: Date? = nil, intensityClass: Int,
                    referenceTime: Date, staleDate: Date? = nil,
                    wetSharePercent: Int? = nil, peakSharePercent: Int? = nil, regionRadiusKm: Int? = nil) {
            self.phase = phase
            self.eventDate = eventDate
            self.intensityClass = intensityClass
            self.referenceTime = referenceTime
            self.staleDate = staleDate
            self.wetSharePercent = wetSharePercent
            self.peakSharePercent = peakSharePercent
            self.regionRadiusKm = regionRadiusKm
        }

        /// A region payload carries at least one of the area fields; `intensityClass` is then the maximum class in the area.
        public var isRegion: Bool { wetSharePercent != nil || peakSharePercent != nil || regionRadiusKm != nil }

        /// Also guards older payloads without staleDate. Stale must never be presented as dry.
        public func isStale(at date: Date) -> Bool {
            date >= min(staleDate ?? referenceTime.addingTimeInterval(1_200), referenceTime.addingTimeInterval(1_200))
        }

        public var effectiveStaleDate: Date {
            min(staleDate ?? referenceTime.addingTimeInterval(1_200), referenceTime.addingTimeInterval(1_200))
        }
    }
}

#if canImport(ActivityKit) && os(iOS)
extension RainActivityAttributes: ActivityAttributes {}
#endif
