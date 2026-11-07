import SwiftUI

@main
struct WeatherApp: App {
    @UIApplicationDelegateAdaptor(PushAppDelegate.self) private var appDelegate
    @State private var store = WeatherStore()
    @State private var phoneSession = PhoneSession.live()
    @State private var push: PushManager
    @State private var deviceLink = DeviceLinkManager.live()
    @State private var warn: WarnManager
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let manager = PushManager.live()
        PushAppDelegate.manager = manager
        _push = State(initialValue: manager)
        _warn = State(initialValue: WarnManager.live(push: manager))
    }

    var body: some Scene {
        WindowGroup {
            RadarScreen(store: store)
                .tint(.cyan)
                .environment(push)
                .environment(deviceLink)
                .environment(warn)
                .onOpenURL { store.openWidgetURL($0) }
                .onChange(of: store.places, initial: true) { _, places in
                    phoneSession.update(places: places)
                    push.updatePlaceNames(places)
                    warn.targets = { WarnManager.targets(places: places, push: push) }
                    Task { await warn.reconcile() }
                }
                .onChange(of: push.state.regions) { _, _ in
                    Task { await warn.reconcile() }
                }
                .task { store.onPlacesRemoved = { ids in Task { await push.placesRemoved(ids) } } }
                .task(id: scenePhase) {
                    guard scenePhase == .active else { return }
                    phoneSession.start()
                    await push.start()
                    await warn.refreshCapabilities()
                    await warn.reconcile()
                    await deviceLink.refresh()
                }
                .task { await store.refresh() }
                .task(id: scenePhase) {
                    guard scenePhase == .active else { return }
                    while !Task.isCancelled {
                        if store.needsRefresh { await store.refresh() }
                        do { try await Task.sleep(for: .seconds(300)) }
                        catch { return }
                    }
                }
                // Cache manifest while visible: adaptive cadence (ETag, 304), see RadarPollSchedule.
                .task(id: scenePhase) {
                    guard scenePhase == .active else { return }
                    await store.runRadarPolling()
                }
        }
    }
}
