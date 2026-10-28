import SwiftUI

@main
struct WeatherApp: App {
    @State private var store = WeatherStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RadarScreen(store: store)
                .tint(.cyan)
                .task { await store.refresh() }
                .task(id: scenePhase) {
                    guard scenePhase == .active else { return }
                    while !Task.isCancelled {
                        if store.needsRefresh { await store.refresh() }
                        do { try await Task.sleep(for: .seconds(300)) }
                        catch { return }
                    }
                }
        }
    }
}
