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

        public init(phase: Phase, eventDate: Date? = nil, intensityClass: Int,
                    referenceTime: Date, staleDate: Date? = nil) {
            self.phase = phase
            self.eventDate = eventDate
            self.intensityClass = intensityClass
            self.referenceTime = referenceTime
            self.staleDate = staleDate
        }

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
