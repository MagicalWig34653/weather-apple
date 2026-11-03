import SwiftUI

struct WatchPlacesView: View {
    @ObservedObject var store: WatchStore
    @State private var path: [UUID] = []

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if let issue = store.syncIssue {
                    Label(WatchText.string(syncText(issue)), systemImage: "exclamationmark.arrow.triangle.2.circlepath")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
                if store.hasStorageIssue {
                    Label(WatchText.string("Local storage unavailable"), systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
                if store.places.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Image(systemName: "mappin.and.ellipse").font(.title2)
                        Text(WatchText.string("Save places in the iPhone app"))
                        Text(WatchText.string("Saved places sync automatically."))
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                ForEach(store.places) { place in
                    NavigationLink(value: place.id) {
                        Text(place.name)
                            .lineLimit(2)
                    }
                }
            }
            .navigationTitle("Showers")
            .navigationDestination(for: UUID.self) { id in
                WatchForecastView(store: store, placeID: id)
            }
        }
        .onAppear {
            #if DEBUG
            // Simulator screenshots only: open the first place directly (a Watch simulator cannot be tapped from the CLI).
            if ProcessInfo.processInfo.arguments.contains("-WatchOpenRadar"), let first = store.places.first {
                Task { try? await Task.sleep(for: .seconds(3)); path = [first.id] }
            }
            #endif
        }
        .onOpenURL { url in
            // Unknown or removed IDs never open a different place.
            guard let id = WidgetDeepLink.placeID(from: url),
                  store.places.contains(where: { $0.id == id }) else { return }
            path = [id]
        }
        .onChange(of: store.places) { _, places in
            path = path.filter { id in places.contains { $0.id == id } }
        }
    }

    private func syncText(_ issue: WatchStore.SyncIssue) -> String {
        switch issue {
        case .invalidPayload: "Places could not be read. Open the iPhone app."
        case .storage: "Places could not be saved."
        case .connection: "iPhone sync unavailable. Open the iPhone app."
        }
    }
}

private struct WatchForecastView: View {
    @ObservedObject var store: WatchStore
    let placeID: UUID
    @Environment(\.scenePhase) private var scenePhase
    @State private var showRadar = false
    private var place: SavedPlace? { store.places.first { $0.id == placeID } }

    var body: some View {
        ScrollView {
            TimelineView(.periodic(from: .now, by: 60)) { context in
                content(now: context.date)
            }
            .padding(.horizontal)
        }
        .navigationTitle(place?.name ?? WatchText.string("Places"))
        .navigationDestination(isPresented: $showRadar) {
            if let place { WatchRadarView(place: place) }
        }
        .onAppear {
            #if DEBUG
            // Simulator screenshots: the Watch simulator cannot be tapped from the command line.
            if ProcessInfo.processInfo.arguments.contains("-WatchOpenRadar") {
                Task { try? await Task.sleep(for: .seconds(2)); showRadar = true }
            }
            #endif
        }
        .task(id: RefreshKey(coordinate: place?.coordinate, phase: scenePhase)) {
            if scenePhase == .active { await store.refresh(placeID: placeID) }
        }
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        let forecast = store.forecasts[placeID]
        let presentation = WatchForecastPresentation(forecast: forecast, now: now)
        VStack(alignment: .leading, spacing: 12) {
            if place == nil {
                Text(WatchText.string("Save places in the iPhone app"))
            } else {
                if store.loading.contains(placeID) && forecast == nil {
                    ProgressView(WatchText.string("Loading forecast…"))
                } else {
                    Label(WatchText.status(presentation), systemImage: symbol(presentation.state))
                        .font(.headline)
                        .foregroundStyle(presentation.state == .stale ? .orange : .primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let age = presentation.ageMinutes {
                    Text(WatchText.age(age))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if let forecast {
                        Text(forecast.referenceTime, style: .time)
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                if let issue = store.forecastIssues[placeID] {
                    Text(WatchText.string(issue == .unsupportedLocation
                        ? "Outside the supported radar area"
                        : forecast == nil ? "Forecast unavailable. Try again."
                        : "Update failed. Showing the last saved forecast."))
                        .font(.footnote).foregroundStyle(.orange)
                }
                if store.hasStorageIssue {
                    Text(WatchText.string("Local storage unavailable"))
                        .font(.footnote).foregroundStyle(.orange)
                }
                Button {
                    Task { await store.refresh(placeID: placeID) }
                } label: {
                    if store.loading.contains(placeID) { ProgressView() }
                    else { Label(WatchText.string("Refresh"), systemImage: "arrow.clockwise") }
                }
                .disabled(store.loading.contains(placeID))
                .accessibilityLabel(WatchText.string("Refresh"))
                if place != nil {
                    Button { showRadar = true } label: {
                        Label(WatchText.string("Radar"), systemImage: "map")
                    }
                }
                Text(WatchText.string("Source: DWD · radar nowcast"))
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func symbol(_ state: RainOutlook.State) -> String {
        switch state {
        case .rainingNow, .endsIn: "cloud.rain.fill"
        case .startsIn: "cloud.drizzle.fill"
        case .dry: "cloud"
        case .stale: "clock.badge.exclamationmark"
        case .noData: "questionmark.circle"
        }
    }

    private struct RefreshKey: Equatable {
        let coordinate: WeatherCoordinate?
        let phase: ScenePhase
    }
}
