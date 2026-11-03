@preconcurrency import ActivityKit
import Foundation

@MainActor
protocol RainActivityManaging: AnyObject {
    var activitiesEnabled: Bool { get }
    func start(eligible: @escaping @MainActor (String) -> Bool,
               startToken: @escaping @MainActor (Data) async -> Void,
               activityToken: @escaping @MainActor (String, Data) async -> Void,
               ended: @escaping @MainActor (String, Data?) async -> Void)
    func end(subscriptionID: String?) async
    func startFallback(attributes: RainActivityAttributes, state: RainActivityAttributes.ContentState) throws
}

/// Only ActivityKit work lives here; networking, consent and retry ownership stay in PushManager.
@MainActor
final class SystemRainActivityManager: RainActivityManaging {
    private var startTask: Task<Void, Never>?
    private var activitiesTask: Task<Void, Never>?
    private var tokenTasks: [String: Task<Void, Never>] = [:]
    private var latestTokens: [String: Data] = [:]
    private var stateTasks: [String: Task<Void, Never>] = [:]
    private var expiryTasks: [String: Task<Void, Never>] = [:]
    private var eligible: (@MainActor (String) -> Bool)?
    private var onToken: (@MainActor (String, Data) async -> Void)?
    private var onEnd: (@MainActor (String, Data?) async -> Void)?

    var activitiesEnabled: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    deinit {
        startTask?.cancel(); activitiesTask?.cancel()
        tokenTasks.values.forEach { $0.cancel() }
        stateTasks.values.forEach { $0.cancel() }
        expiryTasks.values.forEach { $0.cancel() }
    }

    func start(eligible: @escaping @MainActor (String) -> Bool,
               startToken: @escaping @MainActor (Data) async -> Void,
               activityToken: @escaping @MainActor (String, Data) async -> Void,
               ended: @escaping @MainActor (String, Data?) async -> Void) {
        self.eligible = eligible; onToken = activityToken; onEnd = ended
        guard startTask == nil else { return }
        startTask = Task {
            if let token = Activity<RainActivityAttributes>.pushToStartToken { await startToken(token) }
            for await token in Activity<RainActivityAttributes>.pushToStartTokenUpdates {
                guard !Task.isCancelled else { break }
                await startToken(token)
            }
        }
        activitiesTask = Task { [weak self] in
            for activity in Activity<RainActivityAttributes>.activities { await self?.observe(activity) }
            for await activity in Activity<RainActivityAttributes>.activityUpdates {
                guard !Task.isCancelled else { break }
                await self?.observe(activity)
            }
        }
    }

    private func observe(_ activity: Activity<RainActivityAttributes>) async {
        guard tokenTasks[activity.id] == nil else { return }
        guard eligible?(activity.attributes.subscriptionID) == true,
              tokenTasks.isEmpty, activity.activityState != .ended, activity.activityState != .dismissed else {
            await activity.end(nil, dismissalPolicy: .immediate)
            await onEnd?(activity.attributes.subscriptionID, activity.pushToken)
            return
        }
        let sub = activity.attributes.subscriptionID
        tokenTasks[activity.id] = Task { [weak self] in
            if let token = activity.pushToken {
                self?.latestTokens[activity.id] = token
                await self?.onToken?(sub, token)
            }
            for await token in activity.pushTokenUpdates {
                guard !Task.isCancelled else { break }
                self?.latestTokens[activity.id] = token
                await self?.onToken?(sub, token)
            }
        }
        stateTasks[activity.id] = Task { [weak self] in
            for await state in activity.activityStateUpdates {
                guard !Task.isCancelled else { break }
                if state == .ended || state == .dismissed {
                    await self?.finished(activity)
                    break
                }
            }
        }
        // Running activities have an eight-hour local upper bound. Tokenless server reservations
        // expire after 15 minutes and are released separately; this timer never gates their cleanup.
        expiryTasks[activity.id] = Task { [weak self] in
            let seconds = max(0, min(28_800, activity.content.state.referenceTime.addingTimeInterval(28_800).timeIntervalSinceNow))
            do { try await Task.sleep(for: .seconds(seconds)) } catch { return }
            await activity.end(nil, dismissalPolicy: .immediate)
            await self?.finished(activity)
        }
    }

    private func finished(_ activity: Activity<RainActivityAttributes>) async {
        guard let tokenTask = tokenTasks.removeValue(forKey: activity.id) else { return }
        tokenTask.cancel()
        // Remove/cancel observers before awaiting the callback (which may trigger another sync).
        stateTasks.removeValue(forKey: activity.id)?.cancel()
        expiryTasks.removeValue(forKey: activity.id)?.cancel()
        let token = latestTokens.removeValue(forKey: activity.id) ?? activity.pushToken
        await onEnd?(activity.attributes.subscriptionID, token)
    }

    func end(subscriptionID: String?) async {
        for activity in Activity<RainActivityAttributes>.activities
        where subscriptionID == nil || activity.attributes.subscriptionID == subscriptionID {
            await activity.end(nil, dismissalPolicy: .immediate)
            await finished(activity)
        }
    }

    enum FallbackError: Error { case disabled, alreadyActive, staleOrDry }

    /// Explicit caller action only. Never invoked by the token observation or push-sync path.
    func startFallback(attributes: RainActivityAttributes, state: RainActivityAttributes.ContentState) throws {
        guard activitiesEnabled else { throw FallbackError.disabled }
        guard Activity<RainActivityAttributes>.activities.isEmpty else { throw FallbackError.alreadyActive }
        guard !state.isStale(at: Date()), state.phase != .dry else { throw FallbackError.staleOrDry }
        let activity = try Activity.request(attributes: attributes,
                                            content: ActivityContent(state: state, staleDate: state.effectiveStaleDate), pushType: .token)
        Task { [weak self] in await self?.observe(activity) }
    }
}
