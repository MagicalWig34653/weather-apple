#if DEBUG
import ActivityKit
import Foundation

/// Debug builds only (`-UITestLiveActivity <state>`): starts one local Live Activity with sample data so the real system
/// presentation (lock screen, Dynamic Island) can be looked at in the simulator. No server, no push token, no place data.
/// States: startsIn, raining, endsIn, stale, regionStartsIn, regionRaining. `-UITestLiveActivityName` sets the title.
@MainActor
enum LiveActivityUITestStub {
    static let subscriptionID = "uitest-live-activity"

    static func startIfRequested() {
        let args = CommandLine.arguments
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
        case "regionRaining": content = state(.raining, maxClass: 4, wet: 34, peak: 60, radius: 10)
        default: return
        }
        Task {
            for old in Activity<RainActivityAttributes>.activities { await old.end(nil, dismissalPolicy: .immediate) }
            do {
                _ = try Activity.request(attributes: RainActivityAttributes(displayName: name, subscriptionID: subscriptionID),
                                         content: ActivityContent(state: content, staleDate: now.addingTimeInterval(1_200)), pushType: nil)
                NSLog("LAStub started %@", args[i + 1])
            } catch {
                NSLog("LAStub failed %@", String(describing: error))
            }
        }
    }
}
#endif
