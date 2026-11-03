import SwiftUI

/// UI interpretation of one Live-Activity state. Stale data never reads as dry and never shows a countdown.
struct RainActivityPresentation: Equatable {
    let phase: RainActivityAttributes.Phase
    let isStale: Bool
    /// Countdown target; nil when stale, absent, or already in the past.
    let countdownTarget: Date?
    let referenceTime: Date

    init(state: RainActivityAttributes.ContentState, contextIsStale: Bool, now: Date) {
        phase = state.phase
        referenceTime = state.referenceTime
        isStale = contextIsStale || state.isStale(at: now)
        if !isStale, state.phase == .startsIn || state.phase == .endsIn,
           let date = state.eventDate, date > now {
            countdownTarget = date
        } else {
            countdownTarget = nil
        }
    }

    var symbol: String {
        if isStale { return "clock.badge.exclamationmark" }
        switch phase {
        case .startsIn: return "cloud.drizzle.fill"
        case .raining, .endsIn: return "cloud.rain.fill"
        case .dry: return "sun.max.fill"
        }
    }

    var headline: LocalizedStringKey {
        if isStale { return "Daten veraltet" }
        switch phase {
        case .startsIn: return countdownTarget == nil ? "Regen gleich" : "Regen in"
        case .raining: return "Es regnet"
        case .endsIn: return "Es regnet"
        case .dry: return "Trocken"
        }
    }

    /// Text next to/below the headline when there is no countdown.
    var detail: LocalizedStringKey? {
        if isStale { return "Keine verlässliche Aussage" }
        switch phase {
        case .startsIn: return nil
        case .raining: return "Ende nicht absehbar"
        case .endsIn: return countdownTarget == nil ? "Endet gleich" : "Endet in"
        case .dry: return "Vorerst kein Regen erwartet"
        }
    }

    var color: Color {
        if isStale { return .orange }
        return phase == .dry ? .green : .cyan
    }

    var compactLabel: LocalizedStringKey {
        if isStale { return "Veraltet" }
        switch phase {
        case .startsIn, .raining, .endsIn: return "Regen"
        case .dry: return "Trocken"
        }
    }
}

enum RainActivityPlace {
    /// Resolves an empty displayName (remote start) through the local mapping and PlaceStore.
    static func resolve(_ attributes: RainActivityAttributes) -> (name: String?, url: URL?) {
        let trimmed = attributes.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let defaults = UserDefaults(suiteName: SharedConfig.appGroup),
              let id = attributes.placeID(in: defaults) else {
            return (trimmed.isEmpty ? nil : trimmed, nil)
        }
        if trimmed.isEmpty,
           let place = try? PlaceStore().load().places.first(where: { $0.id == id }) {
            return (place.name, WidgetDeepLink.url(for: id))
        }
        return (trimmed.isEmpty ? nil : trimmed, WidgetDeepLink.url(for: id))
    }
}
