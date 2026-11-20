import ActivityKit
import SwiftUI
import WidgetKit

struct RainLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RainActivityAttributes.self) { context in
            RainActivityContent(context: context)
                .activityBackgroundTint(nil)
                .widgetURL(RainActivityPlace.resolve(context.attributes).url)
        } dynamicIsland: { context in
            let link = RainActivityPlace.resolve(context.attributes).url
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    RainActivityTimeline(context: context) { p, title in
                        HStack(spacing: 6) {
                            Image(systemName: p.symbol).foregroundStyle(p.color).accessibilityHidden(true)
                            if let title { Text(title).font(.subheadline).foregroundStyle(.secondary).lineLimit(1) }
                        }
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    RainActivityTimeline(context: context) { p, _ in
                        Text(WidgetAsOfText.string(for: p.referenceTime)).font(.caption).foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    RainActivityTimeline(context: context) { p, _ in
                        RainIslandBottom(p: p).accessibilityElement(children: .combine)
                    }
                }
            } compactLeading: {
                RainActivityTimeline(context: context) { p, _ in
                    Image(systemName: p.symbol).foregroundStyle(p.color).accessibilityHidden(true)
                }
            } compactTrailing: {
                RainActivityTimeline(context: context) { p, _ in
                    if p.countdownTarget != nil {
                        RainCountdown(p: p, context: context)
                            .frame(maxWidth: 48).foregroundStyle(p.color)
                    } else {
                        Text(p.compactLabel).foregroundStyle(p.color)
                    }
                }
            } minimal: {
                RainActivityTimeline(context: context) { p, _ in
                    Image(systemName: p.symbol).foregroundStyle(p.color).accessibilityHidden(true)
                }
            }
            .widgetURL(link)
            .keylineTint(.cyan)
        }
        // Apple: ActivityFamily.small is the watchOS Smart Stack family; without this opt-in watchOS renders its own default.
        .supplementalActivityFamilies([.small])
    }
}

/// Lock screen / iPad (family `.medium`) or, with the opt-in above, the compact Smart Stack card (`.small`).
struct RainActivityContent: View {
    let context: ActivityViewContext<RainActivityAttributes>
    @Environment(\.activityFamily) private var family

    var body: some View {
        RainActivityTimeline(context: context) { p, title in
            if family == .small {
                RainWatchCardView(p: p, title: p.watchTitle(name: RainActivityPlace.resolve(context.attributes).name))
            } else {
                RainLockScreenView(p: p, title: title)
            }
        }
    }
}

/// Re-evaluates at event and stale boundaries without requiring a new remote update.
struct RainActivityTimeline<Content: View>: View {
    let context: ActivityViewContext<RainActivityAttributes>
    @ViewBuilder let content: (RainActivityPresentation, String?) -> Content

    var body: some View {
        let place = RainActivityPlace.resolve(context.attributes)
        TimelineView(.explicit(RainActivityTiming.timelineDates(state: context.state, now: .now))) { timeline in
            let p = RainActivityPresentation(state: context.state, contextIsStale: context.isStale, now: timeline.date,
                                             localRadiusKm: place.radiusKm)
            content(p, p.region.map { $0.title(name: place.name) } ?? place.name)
        }
    }
}

struct RainCountdown: View {
    let p: RainActivityPresentation
    let context: ActivityViewContext<RainActivityAttributes>

    var body: some View {
        if let target = p.countdownTarget {
            Text(timerInterval: RainActivityTiming.countdownInterval(now: .now, target: target), countsDown: true, showsHours: false)
                .monospacedDigit().multilineTextAlignment(.trailing)
        } else {
            EmptyView()
        }
    }
}

#if DEBUG
private extension RainActivityAttributes.ContentState {
    static func sample(_ phase: RainActivityAttributes.Phase, in minutes: Double? = nil, stale: Bool = false) -> Self {
        let ref = Date.now.addingTimeInterval(stale ? -3_600 : 0)
        return .init(phase: phase, eventDate: minutes.map { ref.addingTimeInterval($0 * 60) },
                     intensityClass: 2, referenceTime: ref, staleDate: nil)
    }
}

private extension RainActivityAttributes.ContentState {
    static func region(_ phase: RainActivityAttributes.Phase, in minutes: Double? = nil, wet: Int, peak: Int, maxClass: Int = 4,
                       stale: Bool = false) -> Self {
        var state = sample(phase, in: minutes, stale: stale)
        state.intensityClass = maxClass
        state.wetSharePercent = wet; state.peakSharePercent = peak; state.regionRadiusKm = 10
        return state
    }
}

private let previewAttributes = RainActivityAttributes(displayName: "Zuhause", subscriptionID: "preview")
private let previewRegionAttributes = RainActivityAttributes(displayName: "Umland", subscriptionID: "preview-region")

#Preview("Lock Screen", as: .content, using: previewAttributes) {
    RainLiveActivity()
} contentStates: {
    RainActivityAttributes.ContentState.sample(.startsIn, in: 12)
    RainActivityAttributes.ContentState.sample(.raining)
    RainActivityAttributes.ContentState.sample(.endsIn, in: 18)
    RainActivityAttributes.ContentState.sample(.dry)
    RainActivityAttributes.ContentState.sample(.dry, stale: true)
}

#Preview("Island compact", as: .dynamicIsland(.compact), using: previewAttributes) {
    RainLiveActivity()
} contentStates: {
    RainActivityAttributes.ContentState.sample(.startsIn, in: 12)
    RainActivityAttributes.ContentState.sample(.dry, stale: true)
}

#Preview("Island expanded", as: .dynamicIsland(.expanded), using: previewAttributes) {
    RainLiveActivity()
} contentStates: {
    RainActivityAttributes.ContentState.sample(.endsIn, in: 18)
    RainActivityAttributes.ContentState.sample(.raining)
}

#Preview("Island minimal", as: .dynamicIsland(.minimal), using: previewAttributes) {
    RainLiveActivity()
} contentStates: {
    RainActivityAttributes.ContentState.sample(.raining)
}

#Preview("Lock Screen Umkreis", as: .content, using: previewRegionAttributes) {
    RainLiveActivity()
} contentStates: {
    RainActivityAttributes.ContentState.region(.startsIn, in: 12, wet: 0, peak: 34)
    RainActivityAttributes.ContentState.region(.raining, wet: 34, peak: 60)
    RainActivityAttributes.ContentState.region(.endsIn, in: 18, wet: 12, peak: 40, maxClass: 8)
    RainActivityAttributes.ContentState.region(.dry, wet: 0, peak: 0, maxClass: 0)
    RainActivityAttributes.ContentState.region(.raining, wet: 34, peak: 60, stale: true)
}

#Preview("Island expanded Umkreis", as: .dynamicIsland(.expanded), using: previewRegionAttributes) {
    RainLiveActivity()
} contentStates: {
    RainActivityAttributes.ContentState.region(.startsIn, in: 12, wet: 0, peak: 34)
    RainActivityAttributes.ContentState.region(.raining, wet: 34, peak: 60)
}

#Preview("Island compact Umkreis", as: .dynamicIsland(.compact), using: previewRegionAttributes) {
    RainLiveActivity()
} contentStates: {
    RainActivityAttributes.ContentState.region(.startsIn, in: 12, wet: 0, peak: 34)
    RainActivityAttributes.ContentState.region(.raining, wet: 34, peak: 60)
}
#endif
