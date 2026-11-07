import SwiftUI

@main
struct WeatherApp: App {
    @UIApplicationDelegateAdaptor(PushAppDelegate.self) private var appDelegate
    @State private var store = WeatherStore()
    @State private var phoneSession = PhoneSession.live()
    @State private var push: PushManager
    @State private var deviceLink = DeviceLinkManager.live()
    @State private var warn: WarnManager
    @State private var warnFeed: WarnFeedStore
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let manager = PushManager.live()
        PushAppDelegate.manager = manager
        _push = State(initialValue: manager)
        let warnManager = WarnManager.live(push: manager)
        _warn = State(initialValue: warnManager)
        _warnFeed = State(initialValue: WarnFeedStore.live(warn: warnManager))
    }

    var body: some Scene {
        WindowGroup {
            RadarScreen(store: store)
                .tint(.cyan)
                .environment(push)
                .environment(deviceLink)
                .environment(warn)
                .environment(warnFeed)
                .onOpenURL { store.openWidgetURL($0) }
                .onChange(of: store.places, initial: true) { _, places in
                    phoneSession.update(places: places)
                    push.updatePlaceNames(places)
                    warn.targets = { WarnManager.targets(places: places, push: push) }
                    Task { await warn.reconcile() }
                    warnFeed.reloadPlaces()
                }
                .onChange(of: push.state.regions) { _, _ in
                    Task { await warn.reconcile() }
                    warnFeed.reloadPlaces()
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
                // Public warning list (no location sent); only while the server offers `warnings`, throttled in the store.
                .task(id: scenePhase) {
                    guard scenePhase == .active else { return }
                    await warn.refreshCapabilities()
                    while !Task.isCancelled {
                        await warnFeed.refresh()
                        do { try await Task.sleep(for: .seconds(300)) } catch { return }
                    }
                }
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
