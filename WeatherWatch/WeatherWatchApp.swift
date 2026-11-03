import SwiftUI

@main
struct WeatherWatchApp: App {
    @StateObject private var store: WatchStore
    private let session: WatchSession
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let store = WatchStore.live()
        _store = StateObject(wrappedValue: store)
        session = WatchSession(store: store)
        session.start()
    }

    var body: some Scene {
        WindowGroup {
            WatchPlacesView(store: store)
                .task { session.start() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { session.start() }
                }
        }
    }
}
