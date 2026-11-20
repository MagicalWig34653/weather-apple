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

        /// True when the content itself declares that the system re-renders the activity at the event time: `staleDate` equals the event
        /// time of a running countdown (set by the app when it starts an activity locally; a server doing the same for `stale-date` is
        /// option D in docs/live-activity-a.md). Only then may the card show a ticking countdown: `Text(timerInterval:)` freezes at
        /// "0:00" and the view is not re-run at the event time (measured 20.11.2026), it is only re-run when the activity turns stale.
        public var staleAtEvent: Bool {
            guard phase == .startsIn || phase == .endsIn, let event = eventDate, let stale = staleDate else { return false }
            return abs(stale.timeIntervalSince(event)) < 1
        }

        /// Also guards older payloads without staleDate. Stale must never be presented as dry.
        public func isStale(at date: Date) -> Bool {
            date >= effectiveStaleDate
        }

        /// Age limit of the data: 20 minutes after the reference time, or an earlier server `staleDate`. A `staleDate` that only marks
        /// the event time (`staleAtEvent`) is no age limit.
        public var effectiveStaleDate: Date {
            let age = referenceTime.addingTimeInterval(1_200)
            return staleAtEvent ? age : min(staleDate ?? age, age)
        }

        /// Stale date to hand to ActivityKit (`ActivityContent.staleDate`; for pushes the `stale-date` key): the event time while a
        /// countdown runs (and the event lies within the 20 minute freshness window), otherwise `effectiveStaleDate`. The system does not
        /// re-render a Live Activity at the event time (measured 20.11.: "0:00" stayed 107 s), but it does when the activity turns stale;
        /// the card then reads "Endet gleich"/"Regen gleich" (see `RainActivityPresentation`).
        public func activityStaleDate(now: Date) -> Date {
            guard phase == .startsIn || phase == .endsIn, let event = eventDate, event > now, event < effectiveStaleDate else { return effectiveStaleDate }
            return event
        }

        /// This state as the app hands it to ActivityKit: while a countdown runs, `staleDate` becomes the event time so that the card
        /// knows (`staleAtEvent`) the system re-renders at the event and may count down.
        public func markingStaleAtEvent(now: Date) -> ContentState {
            var copy = self
            let stale = activityStaleDate(now: now)
            if let event = eventDate, stale == event { copy.staleDate = event }
            return copy
        }
    }
}

#if canImport(ActivityKit) && os(iOS)
extension RainActivityAttributes: ActivityAttributes {}
#endif

/// Pure timing rules shared by the Live Activity and its regression tests.
enum RainActivityTiming {
    static func countdownInterval(now: Date, target: Date) -> ClosedRange<Date> {
        min(now, target)...target
    }

    static func timelineDates(state: RainActivityAttributes.ContentState, now: Date) -> [Date] {
        var dates = [now]
        if state.effectiveStaleDate > now { dates.append(state.effectiveStaleDate) }
        if state.phase == .startsIn || state.phase == .endsIn,
           let event = state.eventDate, event > now {
            dates.append(event)
        }
        return Array(Set(dates)).sorted()
    }
}
