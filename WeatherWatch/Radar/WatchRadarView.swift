import SwiftUI
import MapKit
import WatchKit

/// Radar map: map snapshot behind a locally cropped radar frame, time selected with the Digital Crown.
/// Foreground only. Coordinates never leave the device except as MapKit snapshot geometry (Apple).
struct WatchRadarView: View {
    let place: SavedPlace

    @StateObject private var store = WatchRadarStore()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale
    @State private var zoom: RadarCrop.Zoom = .local
    @State private var crown = Double(WatchRadarSlots.currentIndex)
    @State private var backdrop: WatchMapBackdropResult?
    @State private var backdropFailed = false
    @State private var playing = false
    @State private var mapSize: CGSize = .zero
    @State private var provider = WatchMapBackdrop()
    @FocusState private var crownFocused: Bool

    var body: some View {
        VStack(spacing: 2) {
            // The geometry reader sits in an overlay so the measured size can never feed back into layout.
            Color.black
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay {
                    GeometryReader { geo in
                        mapArea(size: geo.size)
                            .onAppear { mapSize = geo.size }
                            .onChange(of: geo.size) { _, new in mapSize = new }
                    }
                }
                .clipped()
            footer
        }
        .navigationTitle(place.name)
        .navigationBarTitleDisplayMode(.inline)
        .focusable()
        .focused($crownFocused)
        .digitalCrownRotation($crown, from: 0, through: Double(WatchRadarSlots.count - 1), by: 1,
                              sensitivity: .low, isContinuous: false, isHapticFeedbackEnabled: true)
        .onChange(of: crown) { _, value in
            let index = Int(value.rounded())
            if index != store.selectedIndex { store.select(index: index) }
        }
        .onChange(of: store.selectedIndex) { _, index in
            if Int(crown.rounded()) != index { crown = Double(index) }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { if store.state == .idle { open() } } else if phase == .background { close() }
        }
        .onChange(of: zoom) { _, _ in open() }
        .onChange(of: store.state) { _, state in
            if state != .ready { playing = false }
        }
        .task(id: BackdropKey(size: mapSize, zoom: zoom, dark: colorScheme == .dark)) { await loadBackdrop() }
        .task(id: playing) { await play() }
        .onAppear { crownFocused = true; if store.state == .idle { open() } }
        .onDisappear { close(); provider.clear() }
    }

    // MARK: Map

    @ViewBuilder
    private func mapArea(size: CGSize) -> some View {
        ZStack {
            Color.black
            if let backdrop {
                Image(decorative: backdrop.image, scale: displayScale)
                    .resizable().frame(width: size.width, height: size.height)
            }
            if let backdrop, let layout = store.layout, let frame = store.selectedImage {
                let rect = radarRect(layout: layout, backdrop: backdrop)
                Image(decorative: frame, scale: 1)
                    .resizable().interpolation(.medium)
                    .opacity(0.8)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
            }
            if let backdrop {
                let m = CGPoint(x: backdrop.markerPixel.x / displayScale, y: backdrop.markerPixel.y / displayScale)
                Circle().fill(.white).frame(width: 9, height: 9)
                    .overlay(Circle().stroke(.blue, lineWidth: 2.5))
                    .position(m)
                    .accessibilityHidden(true)
            }
            overlayState
            playButton.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing).padding(4)
        }
        .frame(width: size.width, height: size.height)
        .clipped()
        .contentShape(Rectangle())
        .onTapGesture { cycleZoom() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(WatchText.string("Radar map"))
        .accessibilityValue(timeDescription)
        .accessibilityAdjustableAction { direction in
            store.select(index: store.selectedIndex + (direction == .increment ? 1 : -1))
        }
        .accessibilityHint(WatchText.string("Tap to change zoom"))
    }

    @ViewBuilder
    private var overlayState: some View {
        switch store.state {
        case .idle, .loading:
            if store.selectedImage == nil { ProgressView().padding(6).background(.black.opacity(0.5), in: Capsule()) }
        case .failed(let failure):
            notice(WatchText.string(message(failure)), symbol: failure == .backend(.stale) ? "clock.badge.exclamationmark" : "exclamationmark.triangle")
        case .ready:
            if store.selectedImage == nil {
                if store.slotFailures[store.selectedIndex] != nil {
                    notice(WatchText.string("Frame unavailable"), symbol: "exclamationmark.triangle")
                } else {
                    ProgressView().padding(6).background(.black.opacity(0.5), in: Capsule())
                }
            }
        }
    }

    @ViewBuilder
    private var playButton: some View {
        if store.state == .ready {
            Button { playing.toggle() } label: {
                Image(systemName: playing ? "pause.fill" : "play.fill").font(.footnote)
            }
            .buttonStyle(.bordered)
            .frame(width: 36, height: 30)
            .accessibilityLabel(WatchText.string(playing ? "Pause" : "Play"))
        }
    }

    private func notice(_ text: String, symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.footnote).multilineTextAlignment(.center)
            .padding(8)
            .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 10))
            .padding(6)
    }

    private func message(_ failure: WatchRadarStore.Failure) -> String {
        switch failure {
        case .backend(.stale): "Radar data is out of date"
        case .backend(.unreachable), .backend(.notPublished): "Radar unavailable. Check the connection."
        case .outsideCoverage: "Outside the supported radar area"
        default: "Radar unavailable"
        }
    }

    private func radarRect(layout: RadarCrop.Layout, backdrop: WatchMapBackdropResult) -> CGRect {
        let b = layout.imageBounds
        let a = backdrop.projection.pixelPoint(forMercator: CGPoint(x: b.minX, y: b.maxY))
        let c = backdrop.projection.pixelPoint(forMercator: CGPoint(x: b.maxX, y: b.minY))
        return CGRect(x: a.x / displayScale, y: a.y / displayScale,
                      width: (c.x - a.x) / displayScale, height: (c.y - a.y) / displayScale)
    }

    // MARK: Footer

    private var footer: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            if let time = store.selectedTime, store.manifest != nil {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 4) {
                        Text(time, style: .time).font(.headline).monospacedDigit()
                        Text(WatchText.string(isForecast ? "Forecast" : "Observed"))
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 4)
                            .background(isForecast ? Color.orange.opacity(0.35) : Color.green.opacity(0.35), in: Capsule())
                        if isForecast { Text(WatchText.string("Preview")).font(.caption2).foregroundStyle(.secondary) }
                    }
                    Text(relativeText + (ageText.map { " · " + $0 } ?? ""))
                        .font(.caption2).foregroundStyle(store.isStale ? .orange : .secondary)
                        .lineLimit(2).minimumScaleFactor(0.8)
                }
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            } else {
                Text(WatchText.string("Source: DWD · radar nowcast")).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 6)
    }

    private var isForecast: Bool {
        store.selectedIndex > WatchRadarSlots.currentIndex
    }

    private var relativeText: String {
        let minutes = (store.selectedIndex - WatchRadarSlots.currentIndex) * 5
        if minutes == 0 { return WatchText.string("Now") }
        return String(format: WatchText.string(minutes > 0 ? "In %d min" : "%d min ago"), abs(minutes))
    }

    private var ageText: String? {
        guard let ref = store.referenceTime else { return nil }
        let minutes = max(0, Int(Date().timeIntervalSince(ref) / 60))
        return WatchText.age(minutes)
    }

    private var timeDescription: String {
        guard let time = store.selectedTime else { return "" }
        return time.formatted(date: .omitted, time: .shortened) + ", " + relativeText
    }

    // MARK: Actions

    private func open() {
        guard scenePhase == .active || scenePhase == .inactive else { return }
        store.load(place: place, zoom: zoom)
    }

    private func close() {
        playing = false
        store.stop()
    }

    private func cycleZoom() {
        let all = RadarCrop.Zoom.allCases
        zoom = all[(all.firstIndex(of: zoom)! + 1) % all.count]
        WKInterfaceDevice.current().play(.click)
    }

    private struct BackdropKey: Equatable { let size: CGSize; let zoom: RadarCrop.Zoom; let dark: Bool }

    private func loadBackdrop() async {
        guard mapSize.width > 20, mapSize.height > 20 else { return }
        let mapZoom: WatchMapZoom = switch zoom { case .local: .near; case .regional: .regional; case .wide: .wide }
        let request = WatchMapBackdropRequest(
            coordinate: CLLocationCoordinate2D(latitude: place.coordinate.latitude, longitude: place.coordinate.longitude),
            zoom: mapZoom, size: mapSize, scale: min(3, max(1, displayScale)),
            appearance: colorScheme == .dark ? .dark : .light)
        do {
            backdrop = try await provider.backdrop(for: request)
            backdropFailed = false
        } catch is CancellationError {
        } catch {
            backdropFailed = true
        }
    }

    /// Advances through already loaded frames about twice a second; stops at the end of the range.
    private func play() async {
        guard playing else { return }
        if store.selectedIndex >= WatchRadarSlots.count - 1 { store.select(index: 0) }
        while !Task.isCancelled, playing, scenePhase == .active {
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            let next = store.selectedIndex + 1
            if next >= WatchRadarSlots.count { playing = false; return }
            if store.loadedSlotIndices.contains(next) { store.select(index: next) }
        }
    }
}
