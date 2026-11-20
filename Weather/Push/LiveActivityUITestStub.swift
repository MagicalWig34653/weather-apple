#if DEBUG
import ActivityKit
import Foundation

/// Debug builds only (`-UITestLiveActivity <state>`): starts one local Live Activity with sample data so the real system
/// presentation (lock screen, Dynamic Island) can be looked at in the simulator. No server, no push token, no place data.
/// States: startsIn, raining, endsIn, stale, regionStartsIn, regionRaining, dry (shown as a normal state), startsInSoon and
/// endsInSoon (event in 25 s, to watch the countdown run out). `-UITestLiveActivityName` sets the title.
/// `-UITestLiveActivityEnd default|immediate` ends the running sample activity with a dry final state instead of starting one
/// (a local stand-in for a server `event: end`; no APNs involved).
@MainActor
enum LiveActivityUITestStub {
    static let subscriptionID = "uitest-live-activity"

    static func startIfRequested() {
        let args = CommandLine.arguments
        if let e = args.firstIndex(of: "-UITestLiveActivityEnd"), e + 1 < args.count {
            let policy: ActivityUIDismissalPolicy = args[e + 1] == "immediate" ? .immediate : .default
            let final = RainActivityAttributes.ContentState(phase: .dry, intensityClass: 0, referenceTime: Date())
            Task {
                for activity in Activity<RainActivityAttributes>.activities where activity.attributes.subscriptionID == subscriptionID {
                    await activity.end(ActivityContent(state: final, staleDate: nil), dismissalPolicy: policy)
                    NSLog("LAStub ended %@", args[e + 1])
                }
            }
            return
        }
        guard let i = args.firstIndex(of: "-UITestLiveActivity"), i + 1 < args.count else { NSLog("LAStub no args"); return }
        let name = args.firstIndex(of: "-UITestLiveActivityName").flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil } ?? "Zuhause"
        let now = Date()
        func state(_ phase: RainActivityAttributes.Phase, in minutes: Double? = nil, ageMinutes: Double = 4, maxClass: Int = 3,
                   wet: Int? = nil, peak: Int? = nil, radius: Int? = nil) -> RainActivityAttributes.ContentState {
            .init(phase: phase, eventDate: minutes.map { now.addingTimeInterval($0 * 60) }, intensityClass: maxClass,
                  referenceTime: now.addingTimeInterval(-ageMinutes * 60), staleDate: nil,
                  wetSharePercent: wet, peakSharePercent: peak, regionRadiusKm: radius)
        }
        let content: RainActivityAttributes.ContentState
        switch args[i + 1] {
        case "startsIn": content = state(.startsIn, in: 8.5, maxClass: 2)
        case "raining": content = state(.raining)
        case "endsIn": content = state(.endsIn, in: 5.5, ageMinutes: 1)
        case "stale": content = state(.raining, ageMinutes: 36)
        case "regionStartsIn": content = state(.startsIn, in: 12.5, maxClass: 4, wet: 0, peak: 34, radius: 10)
        case "dry": content = state(.dry, maxClass: 0)
        case "startsInSoon": content = state(.startsIn, in: 0.4, maxClass: 2)
        case "endsInSoon": content = state(.endsIn, in: 0.4, ageMinutes: 1)
        case "regionRaining": content = state(.raining, maxClass: 4, wet: 34, peak: 60, radius: 10)
        default: return
        }
        // `-UITestLiveActivityStale event|age`: stale date = event time (what the app/server should send) or the old 20 minutes.
        let eventStale = args.firstIndex(of: "-UITestLiveActivityStale").map { $0 + 1 < args.count && args[$0 + 1] == "event" } ?? false
        let stale = eventStale ? content.activityStaleDate(now: now) : now.addingTimeInterval(1_200)
        Task {
            for old in Activity<RainActivityAttributes>.activities { await old.end(nil, dismissalPolicy: .immediate) }
            do {
                _ = try Activity.request(attributes: RainActivityAttributes(displayName: name, subscriptionID: subscriptionID),
                                         content: ActivityContent(state: content, staleDate: stale), pushType: nil)
                NSLog("LAStub started %@", args[i + 1])
            } catch {
                NSLog("LAStub failed %@", String(describing: error))
            }
        }
    }
}
#endif
