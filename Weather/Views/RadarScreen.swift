import Charts
import SwiftUI

struct RadarScreen: View {
    @Bindable var store: WeatherStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(WarnManager.self) private var warn
    @Environment(WarnFeedStore.self) private var warnFeed
    @State private var sheet: Sheet?
    @State private var showSave = false
    @State private var showLegend = false
    @AppStorage(ForestPreference.key) private var forestVisible = false
    /// Local value readout of the tapped point (2 m fields) and the "read centre value" request counter.
    @State private var readout: ReadoutState?
    @State private var readoutRevision = 0
    @State private var placeName = ""
    @State private var radarLoadState: RadarLoadState?
    /// Calms the per-slot loading hint (see `SlotFeedbackGate`); `heldFeedback` is what is currently shown.
    @State private var feedbackGate = SlotFeedbackGate()
    @State private var heldFeedback: (text: String, failed: Bool)?
    @State private var displayNow = Date()
    /// Slot index under the finger while scrubbing; drives thumb and time label independent of tile loading.
    @State private var scrubIndex: Int?
    /// Fine-scrubbing stage while the finger is down (`nil` when not dragging).
    @State private var scrubStage: ScrubStage?
    @State private var mapBottomInset: CGFloat = 70
    @State private var screenWidth: CGFloat?
    @Namespace private var glassNamespace

    private enum Sheet: String, Identifiable {
        case places, details, information, warnings
        var id: String { rawValue }
    }

    /// Value readout exists only for 2 m fields with a known native scale.
    private var canReadValue: Bool { store.layers.activeManifest?.nativeScale != nil && store.activeLayer.isAirField }

    var body: some View {
        ZStack(alignment: .top) {
            RadarMap(place: store.selectedPlace, date: store.displayFrameDate,
                     referenceTime: store.displayFrameReference, centerRevision: store.centerRevision,
                     reloadRevision: store.radarReloadRevision,
                     timeline: store.displayTimeline, prefetchActive: scenePhase == .active && !store.isPlaying,
                     bottomInset: mapBottomInset, layer: store.activeLayer,
                     visibleManifest: store.activeLayer == .cloudmask ? store.layers.sunVisibleManifest?.backend : nil,
                     scale: store.layers.activeManifest?.nativeScale,
                     showForest: forestVisible,
                     readoutRevision: readoutRevision,
                     onReadout: { state in
                         readout = state
                         if let state, state.announce { UIAccessibility.post(notification: .announcement, argument: state.spoken) }
                     },
                     onSelect: { store.selectMapPoint(latitude: $0.latitude, longitude: $0.longitude) },
                     onBackendFailure: { loaded in
                         // Optional layers have no fallback: a failed layer image never switches the radar source.
                         if loaded == 0, store.activeLayer == .radar { store.backendImagesUnavailable() }
                     },
                     onLoadState: { state in
                         guard state.frameDate == store.displayFrameDate, state.referenceTime == store.displayFrameReference,
                               state.reloadRevision == store.radarReloadRevision else { return }
                         radarLoadState = state
                         if store.activeLayer == .radar { store.acceptRadarLoadState(state) }
                     })
                .ignoresSafeArea()
                .accessibilityLabel("\(store.activeLayer.spokenName) für \(store.selectedPlace.name)")
                .accessibilityHint("Lange auf die Karte drücken, um einen Ort zu wählen")
                .accessibilityAction(named: Text(NSLocalizedString("TEMP_READ_CENTER", value: "Wert in Kartenmitte vorlesen", comment: "VoiceOver action"))) {
                    if canReadValue { readoutRevision += 1 }
                }
            VStack(spacing: 6) {
                Spacer()
                if let label = scrubStage?.label {
                    Label(label, systemImage: "slider.horizontal.3")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .glassEffect(.regular, in: Capsule())
                        .accessibilityHidden(true)
                }
                if let slot = heldFeedback {
                    Label(slot.text, systemImage: slot.failed ? "exclamationmark.triangle.fill" : "clock.arrow.circlepath")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .glassEffect(.regular, in: Capsule())
                        .transition(.opacity)
                        .accessibilityIdentifier("radar-slot-status")
                }
                if let readout {
                    Label(readout.text, systemImage: "scope")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .glassEffect(.regular, in: Capsule())
                        .accessibilityLabel(readout.spoken)
                        .accessibilityIdentifier("radar-readout")
                }
                if let line = ForestPreference.sourceLine(base: store.displayAttributionLine, layer: store.activeLayer,
                                                          visible: forestVisible, info: ForestInfo.bundled) {
                    Text(line)
                        .font(.caption2).foregroundStyle(.secondary)
                        .lineLimit(ForestPreference.isShown(layer: store.activeLayer, visible: forestVisible, info: ForestInfo.bundled) ? 6 : 2)
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .glassEffect(.regular, in: Capsule())
                        .accessibilityIdentifier("radar-attribution")
                }
            }
            .padding(.bottom, 8)
            .allowsHitTesting(false)
            VStack(spacing: 10) {
                header
                forecastCard
                if let message = statusMessage {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).fixedSize(horizontal: false, vertical: true).padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
                        .accessibilityAddTraits(.updatesFrequently)
                }
                GlassEffectContainer(spacing: 8) {
                    HStack(alignment: .top, spacing: 10) {
                        Spacer()
                        if showLegend {
                            Group {
                                if store.activeLayer == .radar {
                                    RadarLegendPanel(legend: .precipitationRadar)
                                } else {
                                    RadarLayerLegendPanel(
                                        layer: store.activeLayer, manifest: store.layers.activeManifest,
                                        humidityChoices: [RadarLayer.dewpoint, .humidity].filter { store.layers.availability($0) == .available },
                                        onSelectLayer: { store.layers.select($0) })
                                }
                            }
                            .glassEffectID("legend-panel", in: glassNamespace)
                        }
                        VStack(spacing: 10) {
                            Button { store.requestLocation() } label: {
                                Image(systemName: "location.fill").font(.system(size: 20)).frame(width: 46, height: 46)
                                    .glassControl(Circle())
                            }.accessibilityLabel("Aktuellen Standort verwenden")
                            Button { withAnimation(reduceMotion ? nil : .bouncy(duration: 0.4)) { showLegend.toggle() } } label: {
                                Image(systemName: "paintpalette").font(.system(size: 20)).frame(width: 46, height: 46)
                                    .glassControl(Circle())
                            }
                            .accessibilityLabel("Legende \(store.activeLayer.title)")
                            .accessibilityValue(showLegend ? "eingeblendet" : "ausgeblendet")
                            .accessibilityHint(RadarLayerLegendText.toggleHint(for: store.activeLayer))
                            .accessibilityIdentifier("radar-legend-toggle")
                            if canReadValue {
                                Button { readoutRevision += 1 } label: {
                                    Image(systemName: "scope").font(.system(size: 20)).frame(width: 46, height: 46)
                                        .glassControl(Circle())
                                }
                                .accessibilityLabel(NSLocalizedString("TEMP_READ_CENTER", value: "Wert in Kartenmitte vorlesen", comment: "VoiceOver action"))
                                .accessibilityIdentifier("radar-read-center")
                            }
                            if warn.capabilityWarnings { warningsButton }
                            Button { sheet = .information } label: {
                                Image(systemName: "info.circle").font(.system(size: 20)).frame(width: 46, height: 46)
                                    .glassControl(Circle())
                            }
                            .accessibilityLabel("Datenquellen und Datenschutz")
                        }
                        .buttonStyle(.plain)
                        .font(.title3)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { screenWidth = $0 }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            timeline
                .padding(.horizontal, 12)
                .padding(.top, 4)
                .padding(.bottom, 2)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { mapBottomInset = $0 }
        }

        .sheet(item: $sheet) { item in
            switch item {
            case .places: PlacesSheet(store: store)
            case .details: ForecastDetails(store: store)
            case .information: InformationSheet(store: store)
            case .warnings: WarningsListView(feed: warnFeed)
            }
        }
        .alert("Ort speichern", isPresented: $showSave) {
            TextField("Name", text: $placeName)
            Button("Speichern") { store.saveSelection(name: placeName) }
            Button("Abbrechen", role: .cancel) { }
        } message: { Text("Name und Koordinaten bleiben auf deinem iPhone und werden auch an deine gekoppelte Apple Watch übertragen, wenn dort Showers installiert ist.") }
        .task(id: store.isPlaying) {
            guard store.isPlaying else { return }
            // Playback covers only a window (at most 3 h of past); start there if the slider is further back.
            if let timeline = store.displayTimeline {
                let start = PlaybackWindow.startIndex(dates: timeline.dates, reference: timeline.referenceTime, pastHours: store.pastHours)
                if store.displayFrameIndex < start { store.displayFrameIndex = start }
            }
            var waitingFrame = store.displayFrameDate
            var waitingSince = Date()
            while !Task.isCancelled {
                do { try await Task.sleep(for: .milliseconds(reduceMotion ? 3000 : 2000)) }
                catch { return }
                guard let timeline = store.displayTimeline, !timeline.dates.isEmpty else { return }
                if waitingFrame != store.displayFrameDate {
                    waitingFrame = store.displayFrameDate
                    waitingSince = Date()
                }
                if let load = currentRadarLoadState, load.shouldStopPlayback {
                    store.isPlaying = false
                    return
                }
                // Wait for actual requests, but keep offline/no-event frames from stalling playback forever.
                let frameFinished = currentRadarLoadState.map { $0.requested > 0 && $0.pending == 0 } ?? false
                guard frameFinished || Date().timeIntervalSince(waitingSince) >= 12 else { continue }
                store.displayFrameIndex = PlaybackWindow.nextIndex(after: store.displayFrameIndex, dates: timeline.dates,
                                                                   reference: timeline.referenceTime, pastHours: store.pastHours)
                waitingFrame = store.displayFrameDate
                waitingSince = Date()
            }
        }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            while !Task.isCancelled {
                displayNow = Date()
                do { try await Task.sleep(for: .seconds(30)) }
                catch { return }
            }
        }
        .task(id: scenePhase) {
            // Which optional layers exist (404 -> greyed out). Throttled; restricted modes ask only the active one.
            guard scenePhase == .active else { return }
            await store.layers.probeAll(restricted: ProcessInfo.processInfo.isLowPowerModeEnabled)
        }
        .task(id: LayerPollKey(layer: store.activeLayer, active: scenePhase == .active)) {
            guard scenePhase == .active else { return }
            await store.layers.runPolling(for: store.activeLayer, restricted: { ProcessInfo.processInfo.isLowPowerModeEnabled })
        }
        .onChange(of: feedbackInput) { _, _ in reevaluateFeedback() }
        .task(id: feedbackInput) {
            // Re-evaluate when the show delay or the minimum display time of the hint runs out.
            while !Task.isCancelled {
                guard let wait = feedbackGate.nextCheck(wanted: feedbackInput.wanted, now: Date()) else { return }
                do { try await Task.sleep(for: .seconds(wait)) } catch { return }
                reevaluateFeedback()
            }
        }
        .onChange(of: store.activeLayer) { _, _ in
            store.isPlaying = false
            radarLoadState = nil
            scrubIndex = nil
        }
        .onChange(of: sheet) { _, value in
            if value != nil { store.isPlaying = false }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { store.isPlaying = false }
        }
    }

    private struct LayerPollKey: Equatable { let layer: RadarLayer; let active: Bool }

    /// Top right: layer choice (capsule with the active layer) plus manual reload. Reload used to be its own button;
    /// the adaptive poll already fetches `latest.json` every 10 to 60 s, so a manual reload is a rare action.
    private var layerMenu: some View {
        Menu {
            Section("Kartenebene") {
                ForEach(store.layers.offeredLayers) { layer in
                    let availability = store.layers.availability(layer)
                    Button {
                        store.isPlaying = false
                        showLegend = false
                        store.layers.select(layer)
                    } label: {
                        Label(layer.title + (availability.hint.map { " (\($0))" } ?? ""),
                              systemImage: layer == store.activeLayer ? "checkmark" : layer.symbolName)
                    }
                    .disabled(!availability.isSelectable)
                    .accessibilityLabel(layer.spokenName + (availability.hint.map { ", \($0)" } ?? "")
                                        + (layer == store.activeLayer ? ", ausgewählt" : ""))
                    .accessibilityIdentifier("radar-layer-\(layer.rawValue)")
                }
            }
            Section {
                Button {
                    store.isPlaying = false
                    radarLoadState = nil
                    Task { await store.refresh() }
                    Task { await store.layers.probeAll(force: true, restricted: ProcessInfo.processInfo.isLowPowerModeEnabled) }
                } label: {
                    Label("Daten neu laden", systemImage: "arrow.clockwise")
                }
                .disabled(store.isRadarLoading)
                .accessibilityHint("Lädt den aktuellen Datenstand der Karte neu")
                .accessibilityIdentifier("radar-refresh")
            }
        } label: {
            HStack(spacing: 6) {
                if store.isRadarLoading || store.layers.isLoading {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: store.activeLayer.symbolName).font(.system(size: 17, weight: .semibold))
                }
                if !dynamicTypeSize.isAccessibilitySize {
                    Text(store.activeLayer.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                        .minimumScaleFactor(0.7).truncationMode(.tail)
                }
                Image(systemName: "chevron.down").font(.caption.bold())
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .glassControl(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Kartenebene wählen")
        .accessibilityValue(store.activeLayer.spokenName)
        .accessibilityHint("Wählt genau eine Ebene: Regenradar, Luftdruck, Blitze, Wolken, Sonne sowie Temperatur und Feuchte, soweit angeboten. Enthält auch Daten neu laden.")
        .accessibilityIdentifier("radar-layer-menu")
    }

    /// Entry to the official warnings; only with the server capability `warnings`. Quiet: a symbol, colored and counted
    /// only while a warning applies to a saved place.
    private var warningsButton: some View {
        let relevant = warnFeed.relevantWarnings(now: displayNow)
        let summary = WarningPresentation.summary(of: relevant)
        let stale = warnFeed.staleness(now: displayNow) == .stale
        return Button { sheet = .warnings } label: {
            Image(systemName: summary.count > 0 ? WarningPresentation.levelSymbol(summary.maxLevel) : "exclamationmark.triangle")
                .font(.system(size: 20)).frame(width: 46, height: 46)
                .foregroundStyle(summary.count > 0 ? WarnStyle.color(summary.maxLevel) : Color.primary)
                .glassControl(Circle())
                .overlay(alignment: .topTrailing) {
                    if summary.count > 0 {
                        Text("\(summary.count)").font(.system(size: 11, weight: .bold)).foregroundStyle(summary.maxLevel <= 2 ? Color.black : Color.white)
                            .padding(.horizontal, 5).frame(minWidth: 16, minHeight: 16)
                            .background(WarnStyle.color(summary.maxLevel), in: Capsule())
                            .offset(x: -2, y: 4)
                    }
                }
        }
        .accessibilityLabel(WarningPresentation.buttonLabel())
        .accessibilityValue(WarningPresentation.buttonValue(summary, stale: stale))
        .accessibilityIdentifier("radar-warnings-button")
    }

    private var header: some View {
        (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6)) : AnyLayout(HStackLayout(spacing: 12))) {
            Button { sheet = .places } label: {
                HStack(spacing: 10) {
                    Image(systemName: "cloud.rain.fill").font(.title2).foregroundStyle(.cyan)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.selectedPlace.name).font(.headline)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                            .fixedSize(horizontal: false, vertical: true)
                        if !dynamicTypeSize.isAccessibilitySize {
                            Text("Regenradar").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Image(systemName: "chevron.down").font(.caption.bold())
                }
                .padding(.horizontal, 16).padding(.vertical, 11)
                .glassControl(Capsule())
            }
            .buttonStyle(.plain)
            .layoutPriority(1) // place name wins over the layer capsule, which shrinks/truncates instead
            .accessibilityLabel("Ort auswählen: \(store.selectedPlace.name)")
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
            layerMenu
        }
    }

    private var currentRadarLoadState: RadarLoadState? {
        guard let state = radarLoadState,
              state.frameDate == store.displayFrameDate,
              state.referenceTime == store.displayFrameReference,
              state.reloadRevision == store.radarReloadRevision else { return nil }
        return state
    }

    /// Slot shown by thumb and label: the scrub position wins over the store while dragging.
    private var displayedIndex: Int { scrubIndex ?? store.displayFrameIndex }

    private var displayedDate: Date? {
        guard let dates = store.displayTimeline?.dates, dates.indices.contains(displayedIndex) else { return store.displayFrameDate }
        return dates[displayedIndex]
    }

    /// Honest per-slot hint: the map never shows another slot's image as this slot's state.
    private var slotFeedback: (text: String, failed: Bool)? {
        let layer = store.activeLayer
        if layer != .radar, store.displayTimeline == nil {
            // No data for the chosen layer (outage): a quiet hint instead of an error banner.
            if store.layers.isLoading { return ("\(layer.title) lädt …", false) }
            return ("\(layer.title) derzeit nicht verfügbar", true)
        }
        guard store.displayTimeline != nil, !store.isPlaying, let date = displayedDate else { return nil }
        let time = date.formatted(date: .omitted, time: .shortened)
        let name = layer == .radar ? "Radar" : layer.title
        switch TimelineSlot.status(for: currentRadarLoadState) {
        case .ready: return nil
        case .loading: return ("\(name) für \(time) lädt …", false)
        case .failed: return ("\(name) für \(time) nicht geladen", true)
        }
    }

    /// Raw wish plus the slot it belongs to; changes drive `reevaluateFeedback`.
    private struct FeedbackInput: Equatable {
        let wanted: SlotFeedbackGate.Wanted
        let slot: Date?
        let text: String?
    }

    private var feedbackInput: FeedbackInput {
        guard let raw = slotFeedback else { return FeedbackInput(wanted: .none, slot: nil, text: nil) }
        return FeedbackInput(wanted: raw.failed ? .failed : .loading, slot: displayedDate, text: raw.text)
    }

    private func reevaluateFeedback() {
        let input = feedbackInput
        let before = feedbackGate.display
        let display = feedbackGate.update(wanted: input.wanted, slot: input.slot, now: Date())
        let next: (text: String, failed: Bool)? = switch display {
        case .hidden: nil
        // While held after the state ended, keep the last text instead of an empty pill.
        case .loading, .failed: input.text.map { ($0, display == .failed) } ?? heldFeedback
        }
        if display == before, display != .hidden, let text = input.text, heldFeedback?.text == text { return }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) { heldFeedback = next }
    }

    private var timeline: some View {
        VStack(spacing: 0) {
            frameLabel
            HStack(spacing: dynamicTypeSize.isAccessibilitySize ? 12 : 8) {
                playButton
                timeSlider
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 26))
        .accessibilityIdentifier("radar-timeline")
    }

    private var playButton: some View {
        Button { store.isPlaying.toggle() } label: {
            Image(systemName: store.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressFeedbackButtonStyle())
        .disabled(store.displayTimeline == nil)
        .accessibilityLabel(store.isPlaying ? "Animation pausieren" : (store.activeLayer == .radar ? "Radaranimation starten" : "Animation starten"))
    }

    private var displayedIsForecast: Bool {
        guard let date = displayedDate, let timeline = store.displayTimeline else { return false }
        return ScreenGlow.isForecast(date: date, reference: timeline.referenceTime)
    }

    /// `nil` while not dragging; otherwise whether the dragged time is in the future (drives the scrub glow).
    private var scrubGlowState: Bool? { scrubIndex == nil ? nil : displayedIsForecast }

    /// Time (and day) display with a fixed size: a hidden template reserves the widest content and both lines,
    /// so measurement/forecast or another day never changes the layout (the slider must not move).
    private var frameLabel: some View {
        let stacked = dynamicTypeSize.isAccessibilitySize
        return Button {
            guard let timeline = store.displayTimeline else { return }
            store.isPlaying = false
            store.displayFrameIndex = timeline.dates.firstIndex(of: timeline.referenceTime) ?? 0
        } label: {
            Text("Mo., 88. Okt. 88:88 AM").font(.title3.weight(.semibold)).monospacedDigit()
                .lineLimit(1)
                .hidden()
                .frame(maxWidth: .infinity, minHeight: 44)
                .overlay {
                    if let date = displayedDate {
                        let time = Text(date, style: .time).font(.title3.weight(.semibold)).monospacedDigit()
                        let day = otherDayLabel(for: date).map { Text($0).font(.subheadline).foregroundStyle(.secondary) }
                        Group {
                            if let day { Text("\(day) · \(time)") } else { time }
                        }
                        .lineLimit(stacked ? 2 : 1).minimumScaleFactor(0.6)
                        .multilineTextAlignment(.center)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(PressFeedbackButtonStyle(scale: 0.97))
        .disabled(store.displayTimeline == nil)
        .accessibilityHint("Zur aktuellen Zeit springen")
        .accessibilityIdentifier("radar-frame-label")
    }

    /// With up to 48 hours of past the time alone is ambiguous: name the day when it is not the reference day.
    private func otherDayLabel(for date: Date) -> String? {
        guard let reference = store.displayTimeline?.referenceTime,
              !Calendar.current.isDate(date, inSameDayAs: reference) else { return nil }
        return date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }

    @ViewBuilder private var timeSlider: some View {
        if let timeline = store.displayTimeline, timeline.dates.count > 1 {
            TimelineScrubSlider(count: timeline.dates.count, displayedIndex: displayedIndex, onScrub: { index in
                store.isPlaying = false
                if scrubIndex != index { scrubIndex = index }
                if store.displayFrameIndex != index { store.displayFrameIndex = index }
            }, onEnd: { scrubIndex = nil }, stage: $scrubStage)
            .onChange(of: scrubGlowState) { _, state in
                if let state { ScreenGlowPresenter.updateScrub(isForecast: state, reduceMotion: reduceMotion) }
                else { ScreenGlowPresenter.endScrub() }
            }
            .sensoryFeedback(.selection, trigger: scrubIndex) { _, new in new != nil }
            .sensoryFeedback(.impact(weight: .light), trigger: scrubStage) { old, new in old != nil && new != nil }
            .overlay(alignment: .bottom) {
                GeometryReader { geometry in
                    let boundary = Double(timeline.dates.firstIndex(of: timeline.referenceTime) ?? 0) / Double(timeline.dates.count - 1)
                    HStack(spacing: 0) {
                        ScreenGlow.pastColor.frame(width: geometry.size.width * boundary)
                        ScreenGlow.futureColor
                    }
                    .clipShape(Capsule())
                    Rectangle().fill(.primary).frame(width: 2, height: 5)
                        .offset(x: max(0, geometry.size.width * boundary - 1), y: -1)
                }
                .frame(height: 2)
                .padding(.horizontal, 2)
                .accessibilityHidden(true)
                .allowsHitTesting(false)
            }
            .accessibilityRepresentation {
                // Native slider semantics for VoiceOver (adjustable, XCUI "Slider"); the drag slider stays visual.
                Slider(value: Binding(get: { Double(displayedIndex) }, set: {
                    let index = TimelineSlot.index(for: $0, count: timeline.dates.count)
                    store.isPlaying = false
                    if store.displayFrameIndex != index { store.displayFrameIndex = index }
                }), in: 0...Double(timeline.dates.count - 1), step: 1)
                .accessibilityLabel(store.activeLayer.timeAxisLabel)
                .accessibilityAdjustableAction { direction in
                    let step = direction == .increment ? 1 : -1
                    let index = TimelineAccessibility.adjusted(index: displayedIndex, by: step, count: timeline.dates.count)
                    store.isPlaying = false
                    if store.displayFrameIndex != index { store.displayFrameIndex = index }
                }
                .accessibilityValue(TimelineAccessibility.value(date: displayedDate, isForecast: displayedIsForecast, reference: timeline.referenceTime,
                                                                caption: store.activeLayer.frameCaption(isForecast: displayedIsForecast)))
                .accessibilityHint("Von \(timeline.dates.first!.formatted(date: .abbreviated, time: .shortened)) bis \(timeline.dates.last!.formatted(date: .omitted, time: .shortened)). Beim Ziehen mit dem Finger nach oben vom Regler weg wird die Steuerung feiner.")
            }
        } else {
            Text(store.activeLayer != .radar ? (store.layers.isLoading ? "\(store.activeLayer.title) lädt …" : "Keine Zeiten für \(store.activeLayer.title)")
                 : store.isLoading ? "Radar lädt …" : "Keine Radarzeiten")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
    }

    private var forecastCard: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                Button { sheet = .details } label: {
                    HStack(spacing: 6) {
                        Text(dynamicTypeSize.isAccessibilitySize ? "Prognosedetails" : forecastHeadline)
                            .font(.subheadline.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                        Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                    .glassControl(RoundedRectangle(cornerRadius: 24))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("forecast-details")
                .accessibilityHint("Öffnet Niederschlagsverlauf, Datenalter und Prognosehinweise")
                Button {
                    placeName = store.selectedPlace.name
                    showSave = true
                } label: {
                    Image(systemName: store.places.contains(where: { $0.id == store.selectedPlace.id }) ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 20)).frame(width: 48, height: 48)
                        .glassControl(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Ausgewählten Ort speichern oder umbenennen")
            }
        }
    }

    private var forecastHeadline: String {
        guard let forecast = store.forecast else {
            return store.isForecastLoading ? "Regenprognose wird geladen …" : "Prognose nicht verfügbar"
        }
        if store.forecastError != nil || forecast.isStale(at: displayNow) {
            return "Ältere Prognose (\(forecast.ageDescription(at: displayNow))) · bitte aktualisieren"
        }
        return forecast.summary(at: displayNow)
    }

    private var statusMessage: String? {
        if let message = store.locationMessage { return message }
        if let message = store.storageMessage { return message }
        if let state = currentRadarLoadState, state.failed > 0 {
            if store.activeLayer != .radar { return "Das Bild der Ebene \(store.activeLayer.title) für diesen Zeitpunkt fehlt. Bitte erneut aktualisieren." }
            return store.radarSource == .cache
                ? "Das Radarbild für diesen Zeitpunkt fehlt. Bitte erneut aktualisieren."
                : "Einige Radarkacheln fehlen. Bitte erneut aktualisieren."
        }
        if store.activeLayer != .radar { return nil }
        if let error = store.radarError { return "Radar: \(error)" }
        if let error = store.forecastError { return "Ortsprognose: \(error)" }
        if let notice = store.radarNotice { return notice }
        return nil
    }

    private func age(_ date: Date) -> String {
        let minutes = max(0, Int(Date().timeIntervalSince(date) / 60))
        return minutes == 0 ? "gerade aktualisiert" : "vor \(minutes) Min."
    }
}

/// Pure slot logic for the timeline slider, kept testable without UI.
enum TimelineSlot {
    enum Status: Equatable { case loading, failed, ready }

    /// Nearest valid slot for a raw slider value; never truncates down.
    static func index(for value: Double, count: Int) -> Int {
        guard count > 0, value.isFinite else { return 0 }
        return min(max(Int(value.rounded()), 0), count - 1)
    }

    /// `nil` means no load state of the current slot has been reported yet.
    static func status(for state: RadarLoadState?) -> Status {
        guard let state else { return .loading }
        guard state.isSettled else { return .loading }
        return state.failed > 0 && state.succeeded == 0 ? .failed : .ready
    }
}

struct RainChart: View {
    let forecast: RainForecast
    var compact = false

    var body: some View {
        Chart {
            ForEach(forecast.samples) { sample in
                if let value = sample.rateMMPerHour {
                    BarMark(x: .value("Zeit", sample.date, unit: .minute), y: .value("Niederschlag", value), width: .ratio(0.85))
                        .foregroundStyle(.cyan.gradient)
                        .accessibilityLabel(sample.date.formatted(date: .omitted, time: .shortened))
                        .accessibilityValue("\(value.formatted(.number.precision(.fractionLength(1)))) Millimeter pro Stunde")
                } else {
                    RuleMark(x: .value("Fehlender Wert", sample.date))
                        .foregroundStyle(.gray.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
                        .accessibilityLabel("Keine Daten um \(sample.date.formatted(date: .omitted, time: .shortened))")
                }
            }
            RuleMark(x: .value("Jetzt", Date())).foregroundStyle(.secondary)
        }
        .chartYScale(domain: 0...max(1, forecast.samples.compactMap(\.rateMMPerHour).max() ?? 1))
        .chartXAxis(compact ? .hidden : .automatic)
        .chartYAxis(compact ? .hidden : .automatic)
        .accessibilityLabel("Niederschlagsverlauf")
    }
}

struct ForecastDetails: View {
    @Bindable var store: WeatherStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 30)) { context in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let forecast = store.forecast {
                        Text(forecast.summary(at: context.date)).font(.title2.bold())
                        RainChart(forecast: forecast).frame(height: 220)
                        SunPlaceSection(store: store, now: context.date)
                        Text("Durchschnittliche Intensität in mm/h für Fünf-Minuten-Intervalle. Gestrichelte Markierungen zeigen fehlende Werte.")
                            .font(.caption).foregroundStyle(.secondary)
                        LabeledContent("Datenlauf", value: forecast.referenceTime.formatted(date: .abbreviated, time: .shortened))
                        Text("DWD · \(forecast.ageDescription(at: context.date))")
                            .font(.caption).foregroundStyle(.secondary)
                        LabeledContent("Radarbilder", value: store.radarSource.label)
                        if store.forecastError != nil || forecast.isStale(at: context.date) {
                            Label(store.forecastError != nil
                                  ? "Aktualisierung fehlgeschlagen. Letzte gültige Prognose, \(forecast.ageDescription(at: context.date)). Sie ist nicht aktuell bestätigt."
                                  : "Die Prognose ist nicht aktuell bestätigt.", systemImage: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                        }
                        ForecastInterpretationSection(forecast: forecast, hasCurrentError: store.forecastError != nil)
                        Text("Lange auf die Karte drücken, um einen Ort zu wählen.")
                        Text("Radarprognosen beschreiben die erwartete Entwicklung. Gerade bei entstehenden oder sich auflösenden Schauern können Beginn, Ende und Intensität abweichen.")
                        Text("\(store.radarAttribution.modificationNotice). Niederschlagswerte der Ortsprognose umgerechnet und aufbereitet.")
                            .font(.footnote).foregroundStyle(.secondary)
                    } else {
                        ContentUnavailableView("Keine Ortsprognose", systemImage: "cloud.rain", description: Text(store.forecastError ?? "Bitte Wetterdaten aktualisieren."))
                    }
                }.padding(24)
            }
            }
            .navigationTitle(store.selectedPlace.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
        }.presentationDetents([.medium, .large])
    }
}

// A fully failed frame must not fan out across every animation time.
// Idle demand, cancelled requests and partially valid frames remain distinct.
extension RadarLoadState {
    var shouldStopPlayback: Bool { succeeded == 0 && failed > 0 && pending == 0 }
}

/// "Sonne bis HH:mm" from the sun position plus, only when the cloud mask is unambiguous at the place,
/// "Aktuell klar/bewölkt (Satellit, vor N min)". Loads the newest cloud mask image when the sheet opens
/// (no location is sent; the image is the same whole-image slot for everybody).
struct SunPlaceSection: View {
    @Bindable var store: WeatherStore
    let now: Date
    @State private var cloud: (state: CloudMaskClass, slot: Date)?

    private var key: String {
        let place = store.selectedPlace
        return "\(place.coordinate.latitude),\(place.coordinate.longitude)"
    }

    var body: some View {
        let place = store.selectedPlace
        VStack(alignment: .leading, spacing: 2) {
            Label(SunPlace.sunLine(at: now, latitude: place.coordinate.latitude, longitude: place.coordinate.longitude),
                  systemImage: "sun.max")
                .accessibilityIdentifier("place-sun-line")
            if let cloud, let line = SunPlace.cloudLine(cloud.state, slotTime: cloud.slot, now: now) {
                Text(line).font(.subheadline).foregroundStyle(.secondary)
                    .accessibilityIdentifier("place-cloud-line")
            }
        }
        .font(.headline)
        .task(id: key) { await loadCloud() }
    }

    private func loadCloud() async {
        cloud = nil
        let place = store.selectedPlace
        if store.layers.snapshot(.cloudmask).manifest == nil { await store.layers.refresh(.cloudmask) }
        guard let manifest = store.layers.snapshot(.cloudmask).manifest, let slot = manifest.slots.last else { return }
        let loader = BackendRadarLoader(manifest: manifest.backend, trimsCache: false)
        guard await loader.demand(slot.url), let image = loader.image(for: slot.url),
              let state = SunPlace.cloudClass(in: image, bounds: manifest.backend.bounds,
                                              latitude: place.coordinate.latitude, longitude: place.coordinate.longitude),
              !Task.isCancelled else { return }
        cloud = (state, slot.time)
    }
}

extension View {
    /// Interactive Liquid Glass for a touchable control (press and bounce feedback); the whole shape is the touch target.
    func glassControl<S: Shape>(_ shape: S) -> some View {
        contentShape(shape).glassEffect(.regular.interactive(), in: shape)
    }
}

/// Press feedback for plain buttons that sit inside a glass card (glass on glass is avoided): small scale, none with Reduce Motion.
struct PressFeedbackButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.88
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? scale : 1)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(reduceMotion ? nil : .bouncy(duration: 0.3), value: configuration.isPressed)
    }
}
