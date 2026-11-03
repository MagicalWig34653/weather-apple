import ActivityKit
import SwiftUI
import WidgetKit

struct RainLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RainActivityAttributes.self) { context in
            RainActivityTimeline(context: context) { p, title in
                RainLockScreenView(p: p, title: title)
            }
            .widgetURL(RainActivityPlace.resolve(context.attributes).url)
        } dynamicIsland: { context in
            let link = RainActivityPlace.resolve(context.attributes).url
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    RainActivityTimeline(context: context) { p, _ in
                        Image(systemName: p.symbol).font(.title2).foregroundStyle(p.color)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    RainActivityTimeline(context: context) { p, _ in
                        RainCountdown(p: p, context: context).font(.title2.bold()).foregroundStyle(p.color)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    RainActivityTimeline(context: context) { p, title in
                        VStack(spacing: 2) {
                            Text(p.headline).font(.headline)
                            if p.countdownTarget == nil, let d = p.detail {
                                Text(d).font(.caption).foregroundStyle(.secondary)
                            }
                            if let title { Text(title).font(.caption2).foregroundStyle(.secondary) }
                        }
                    }
                }
            } compactLeading: {
                RainActivityTimeline(context: context) { p, _ in
                    Image(systemName: p.symbol).foregroundStyle(p.color)
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
                    Image(systemName: p.symbol).foregroundStyle(p.color)
                }
            }
            .widgetURL(link)
            .keylineTint(.cyan)
        }
    }
}

/// Re-evaluates at the stale boundary so an expired state flips to "outdated" without a new update.
struct RainActivityTimeline<Content: View>: View {
    let context: ActivityViewContext<RainActivityAttributes>
    @ViewBuilder let content: (RainActivityPresentation, String?) -> Content

    var body: some View {
        let title = RainActivityPlace.resolve(context.attributes).name
        TimelineView(.explicit([Date.now, context.state.effectiveStaleDate])) { timeline in
            content(RainActivityPresentation(state: context.state, contextIsStale: context.isStale, now: timeline.date), title)
        }
    }
}

struct RainCountdown: View {
    let p: RainActivityPresentation
    let context: ActivityViewContext<RainActivityAttributes>

    var body: some View {
        if let target = p.countdownTarget {
            Text(timerInterval: Date.now...target, countsDown: true, showsHours: false)
                .monospacedDigit().multilineTextAlignment(.trailing)
        } else {
            EmptyView()
        }
    }
}

struct RainLockScreenView: View {
    let p: RainActivityPresentation
    let title: String?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: p.symbol).font(.largeTitle).foregroundStyle(p.color)
            VStack(alignment: .leading, spacing: 2) {
                if let title { Text(title).font(.caption).foregroundStyle(.secondary) }
                HStack(spacing: 6) {
                    Text(p.headline).font(.headline)
                    if let target = p.countdownTarget {
                        Text(timerInterval: Date.now...target, countsDown: true, showsHours: false)
                            .font(.headline.monospacedDigit()).foregroundStyle(p.color)
                    }
                }
                if p.countdownTarget == nil, let d = p.detail {
                    Text(d).font(.subheadline).foregroundStyle(.secondary)
                } else if p.phase == .endsIn, !p.isStale {
                    Text("Endet in").font(.subheadline).foregroundStyle(.secondary)
                }
                Text("Stand \(p.referenceTime, format: .dateTime.hour().minute())")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding()
        .activityBackgroundTint(Color.black.opacity(0.55))
        .activitySystemActionForegroundColor(.cyan)
        .accessibilityElement(children: .combine)
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

private let previewAttributes = RainActivityAttributes(displayName: "Zuhause", subscriptionID: "preview")

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
#endif
