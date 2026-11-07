import SwiftUI

@main
struct WeatherApp: App {
    @UIApplicationDelegateAdaptor(PushAppDelegate.self) private var appDelegate
    @State private var store = WeatherStore()
    @State private var phoneSession = PhoneSession.live()
    @State private var push: PushManager
    @State private var deviceLink = DeviceLinkManager.live()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let manager = PushManager.live()
        PushAppDelegate.manager = manager
        _push = State(initialValue: manager)
    }

    var body: some Scene {
        WindowGroup {
            RadarScreen(store: store)
                .tint(.cyan)
                .environment(push)
                .environment(deviceLink)
                .onOpenURL { store.openWidgetURL($0) }
                .onChange(of: store.places, initial: true) { _, places in
                    phoneSession.update(places: places)
                    push.updatePlaceNames(places)
                }
                .task { store.onPlacesRemoved = { ids in Task { await push.placesRemoved(ids) } } }
                .task(id: scenePhase) {
                    guard scenePhase == .active else { return }
                    phoneSession.start()
                    await push.start()
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
