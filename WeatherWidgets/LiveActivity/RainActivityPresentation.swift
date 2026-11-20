#if WIDGET_LOGIC_TESTS
@testable import Weather
#endif
import SwiftUI

/// UI interpretation of one Live-Activity state. Stale data never reads as dry and never shows a countdown.
struct RainActivityPresentation: Equatable {
    let phase: RainActivityAttributes.Phase
    let isStale: Bool
    /// Countdown target; nil when stale, absent, or already in the past.
    let countdownTarget: Date?
    let referenceTime: Date
    /// Set for region payloads (area share, maximum class, radius); nil for places.
    let region: RainActivityRegionPresentation?

    init(state: RainActivityAttributes.ContentState, contextIsStale: Bool, now: Date, localRadiusKm: Int? = nil) {
        phase = state.phase
        referenceTime = state.referenceTime
        // The activity's stale date may be the event time (`activityStaleDate`): a context flag that arrives with a reached event of a
        // running countdown while the data is still fresh is "event reached" ("Endet gleich"), not "outdated".
        let eventReached = (state.phase == .startsIn || state.phase == .endsIn) && state.eventDate.map { $0 <= now } == true
        isStale = state.isStale(at: now) || (contextIsStale && !eventReached)
        region = state.isRegion ? RainActivityRegionPresentation(state: state, isStale: isStale, localRadiusKm: localRadiusKm) : nil
        if !isStale, state.phase == .startsIn || state.phase == .endsIn,
           let date = state.eventDate, date > now {
            countdownTarget = date
        } else {
            countdownTarget = nil
        }
    }


    // MARK: Design A (tinted glass): one large element, tone, short Watch texts

    enum Tone: Equatable { case rain, dry, stale }

    /// Large element of the card: a countdown with a small label, or one statement.
    enum Hero: Equatable {
        case countdown(label: String, target: Date)
        case statement(String)
    }

    var tone: Tone {
        if isStale { return .stale }
        return phase == .dry ? .dry : .rain
    }

    /// Place and area cards share the labels; the area is named by the card title (name, radius), not by the label.
    var hero: Hero {
        if isStale { return .statement(NSLocalizedString("WIDGET_STALE", value: "Daten veraltet", comment: "Live Activity")) }
        switch phase {
        case .startsIn:
            if let target = countdownTarget {
                return .countdown(label: NSLocalizedString("ACTIVITY_RAIN_IN", value: "Regen in", comment: "Live Activity, followed by a countdown"),
                                  target: target)
            }
            return .statement(NSLocalizedString("ACTIVITY_RAIN_IMMINENT", value: "Regen gleich", comment: "Live Activity"))
        case .endsIn:
            if let target = countdownTarget { return .countdown(label: Self.endsInLabel, target: target) }
            return .statement(NSLocalizedString("ACTIVITY_ENDS_IMMINENT", value: "Endet gleich", comment: "Live Activity"))
        case .raining: return .statement(NSLocalizedString("WIDGET_RAINING", value: "Es regnet", comment: "Live Activity"))
        case .dry: return .statement(NSLocalizedString("WIDGET_DRY", value: "Trocken", comment: "Live Activity"))
        }
    }

    /// Small line under a statement; countdowns and the "imminent" statements have none.
    var heroDetail: String? {
        if isStale { return NSLocalizedString("WIDGET_NO_RELIABLE", value: "Keine verlässliche Aussage", comment: "Live Activity") }
        switch phase {
        case .raining: return NSLocalizedString("WIDGET_NO_END", value: "Ende nicht absehbar", comment: "Live Activity")
        case .dry: return NSLocalizedString("WIDGET_NO_RAIN_EXPECTED", value: "Vorerst kein Regen erwartet", comment: "Live Activity")
        case .startsIn, .endsIn: return nil
        }
    }

    /// Watch card title: the name only (the area radius would not fit), the radius alone when there is no name.
    func watchTitle(name: String?) -> String? { region?.watchTitle(name: name) ?? name }

    /// Short area share for the Watch card; nil for places, stale and dry.
    var watchShareText: String? { region?.shortShareText }

    var symbol: String {
        if isStale { return "clock.badge.exclamationmark" }
        switch phase {
        case .startsIn: return "cloud.drizzle.fill"
        case .raining, .endsIn: return "cloud.rain.fill"
        case .dry: return "sun.max.fill"
        }
    }

    var headline: String {
        if let region {
            return region.headline(phase: phase, isStale: isStale, hasCountdown: countdownTarget != nil)
        }
        if isStale { return NSLocalizedString("WIDGET_STALE", value: "Daten veraltet", comment: "Live Activity") }
        switch phase {
        case .startsIn:
            return countdownTarget == nil
                ? NSLocalizedString("ACTIVITY_RAIN_IMMINENT", value: "Regen gleich", comment: "Live Activity")
                : NSLocalizedString("ACTIVITY_RAIN_IN", value: "Regen in", comment: "Live Activity, followed by a countdown")
        case .raining, .endsIn: return NSLocalizedString("WIDGET_RAINING", value: "Es regnet", comment: "Live Activity")
        case .dry: return NSLocalizedString("WIDGET_DRY", value: "Trocken", comment: "Live Activity")
        }
    }

    /// Text next to/below the headline when there is no countdown.
    var detail: String? {
        if isStale { return NSLocalizedString("WIDGET_NO_RELIABLE", value: "Keine verlässliche Aussage", comment: "Live Activity") }
        switch phase {
        case .startsIn: return nil
        case .raining: return NSLocalizedString("WIDGET_NO_END", value: "Ende nicht absehbar", comment: "Live Activity")
        case .endsIn:
            return countdownTarget == nil
                ? NSLocalizedString("ACTIVITY_ENDS_IMMINENT", value: "Endet gleich", comment: "Live Activity")
                : Self.endsInLabel
        case .dry: return NSLocalizedString("WIDGET_NO_RAIN_EXPECTED", value: "Vorerst kein Regen erwartet", comment: "Live Activity")
        }
    }

    /// "Endet in", shown next to a countdown.
    static var endsInLabel: String { NSLocalizedString("ACTIVITY_ENDS_IN", value: "Endet in", comment: "Live Activity, followed by a countdown") }

    var color: Color {
        if isStale { return .orange }
        return phase == .dry ? .green : .cyan
    }

    var compactLabel: String {
        if isStale { return NSLocalizedString("WIDGET_STALE_SHORT", value: "Veraltet", comment: "Live Activity") }
        if let region, phase != .dry, let short = region.compactShareText { return short }
        switch phase {
        case .startsIn, .raining, .endsIn: return NSLocalizedString("WIDGET_RAIN", value: "Regen", comment: "Live Activity")
        case .dry: return NSLocalizedString("WIDGET_DRY", value: "Trocken", comment: "Live Activity")
        }
    }
}

enum RainActivityPlace {
    /// Resolves an empty displayName (remote start) through the local mapping and PlaceStore.
    /// Regions have no deep link; name and radius come from the local region mapping (never from the server).
    static func resolve(_ attributes: RainActivityAttributes) -> (name: String?, url: URL?, radiusKm: Int?) {
        let trimmed = attributes.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let defaults = UserDefaults(suiteName: SharedConfig.appGroup) else {
            return (trimmed.isEmpty ? nil : trimmed, nil, nil)
        }
        if let region = attributes.regionInfo(in: defaults) {
            return (trimmed.isEmpty ? region.name : trimmed, nil, region.radiusKm)
        }
        guard let id = attributes.placeID(in: defaults) else {
            return (trimmed.isEmpty ? nil : trimmed, nil, nil)
        }
        if trimmed.isEmpty,
           let place = try? PlaceStore().load().places.first(where: { $0.id == id }) {
            return (place.name, WidgetDeepLink.url(for: id), nil)
        }
        return (trimmed.isEmpty ? nil : trimmed, WidgetDeepLink.url(for: id), nil)
    }
}
