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
    /// Latitude of the map centre (world rain map coverage note only).
    @State private var mapCenterLatitude: Double?
    @State private var placeName = ""
    @State private var radarLoadState: RadarLoadState?
    /// Calms the per-slot loading hint (see `SlotFeedbackGate`); `heldFeedback` is what is currently shown.
    @State private var feedbackGate = SlotFeedbackGate()
    @State private var heldFeedback: (text: String, failed: Bool)?
    @State private var displayNow = screenNow()
    /// Slot index under the finger while scrubbing; drives thumb and time label independent of tile loading.
    @State private var scrubIndex: Int?
    /// Fine-scrubbing stage while the finger is down (`nil` when not dragging).
    @State private var scrubStage: ScrubStage?
    /// Build 53: controls above the map are hidden while the slider is dragged (map, slider, time value and credit stay).
    @State private var chrome = MapChromeVisibility()
    @State private var mapBottomInset: CGFloat = 70
    @State private var screenWidth: CGFloat?
    /// Legend space: top of the legend row and top of the time pill block, in the screen's own coordinate space.
    @Environment(\.colorScheme) private var colorScheme
    @State private var legendTop: CGFloat = 0
    @State private var pillBlockTop: CGFloat?
    /// Height of the pill block (pill, on home-button devices also the credit): Apple's legal link sits above it, never under the pill.
    @State private var pillBlockHeight: CGFloat = 0
    /// Bottom safe area of the device (home indicator), measured outside the slider inset.
    @State private var deviceBottomInset: CGFloat = 0
    @Namespace private var glassNamespace
    @State private var nowJumps = 0

    fileprivate enum Sheet: String, Identifiable {
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
                     bottomInset: mapBottomInset + pillBlockHeight + 8, layer: store.activeLayer,
                     visibleManifest: store.activeLayer == .cloudmask ? store.layers.sunVisibleManifest?.backend : nil,
                     scale: store.layers.activeManifest?.nativeScale,
                     showForest: forestVisible,
                     readoutRevision: readoutRevision,
                     onReadout: { state in
                         readout = state
                         if let state, state.announce { UIAccessibility.post(notification: .announcement, argument: state.spoken) }
                     },
                     onSelect: { store.selectMapPoint(latitude: $0.latitude, longitude: $0.longitude) },
                     onCenterLatitude: { latitude in
                         // Only the world map uses it; rounded so that panning does not redraw the screen continuously.
                         let rounded = (latitude * 10).rounded() / 10
                         if mapCenterLatitude != rounded { mapCenterLatitude = rounded }
                     },
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
                .accessibilityLabel(String(format: NSLocalizedString("RADAR_MAP_LABEL", value: "%1$@ für %2$@", comment: "Radar"), store.activeLayer.spokenName, store.selectedPlace.name))
                .accessibilityHint(NSLocalizedString("RADAR_MAP_HINT", value: "Lange auf die Karte drücken, um einen Ort zu wählen", comment: "Radar"))
                .accessibilityAction(named: Text(NSLocalizedString("TEMP_READ_CENTER", value: "Wert in Kartenmitte vorlesen", comment: "VoiceOver action"))) {
                    if canReadValue { readoutRevision += 1 }
                }
            VStack(spacing: 6) {
                Spacer()
                VStack(spacing: 6) {
                    if let label = scrubStage?.label {
                        Label(label, systemImage: "slider.horizontal.3")
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .readableGlass(Capsule())
                            .accessibilityHidden(true)
                    }
                    if let slot = heldFeedback {
                        Label(slot.text, systemImage: slot.failed ? "exclamationmark.triangle.fill" : "clock.arrow.circlepath")
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .readableGlass(Capsule())
                            .transition(.opacity)
                            .accessibilityIdentifier("radar-slot-status")
                    }
                    if let readout {
                        Label(readout.text, systemImage: "scope")
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .readableGlass(Capsule())
                            .accessibilityLabel(readout.spoken)
                            .accessibilityIdentifier("radar-readout")
                    }
                }
                .allowsHitTesting(false)
                VStack(spacing: 6) {
                timePill
                // Home-button devices: the credit stays above the slider. Otherwise it is drawn below the slider (see `timeline`).
                if !hasStripBelowSlider { creditLine(sizeLimit: .xxxLarge) }
                }
                .onGeometryChange(for: CGFloat.self) { $0.frame(in: .named("radarScreen")).minY } action: { pillBlockTop = $0 }
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { pillBlockHeight = $0 }
            }
            // Close to the slider card: the gap between pill and slider is small.
            .padding(.bottom, 4)
            VStack(spacing: 10) {
                header
                forecastCard
                ForEach(statusMessages, id: \.self) { message in
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).fixedSize(horizontal: false, vertical: true).padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .readableGlass(RoundedRectangle(cornerRadius: 16), floor: darkGlassFloor)
                        .accessibilityAddTraits(.updatesFrequently)
                }
                ForEach(rainLayerNotices) { notice in
                    Label(notice.text, systemImage: notice.kind == .estimate ? "info.circle" : "exclamationmark.triangle.fill")
                        .font(.caption).fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 12).padding(.vertical, notice.kind == .estimate ? 8 : 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .readableGlass(RoundedRectangle(cornerRadius: 16), floor: darkGlassFloor)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier(notice.identifier)
                }
                // A hole in the data next to the shown slot: said plainly, never filled with a picture. In the top stack (like the
                // other notes), so the lower strip with Apple's legal link stays free.
                if !store.isPlaying, !displayedGapLines.isEmpty {
                    Label(displayedGapLines.joined(separator: "\n"), systemImage: "clock.badge.questionmark")
                        .font(.caption).fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .readableGlass(RoundedRectangle(cornerRadius: 16), floor: darkGlassFloor)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("radar-gap-note")
                }
                // The chosen past is longer than the map delivers: said once and plainly (the choice and the data stay as they are).
                if !store.isPlaying, let available = store.shortHistoryHours, let chosen = store.pastChoice {
                    Label(RadarPastWindow.shortHistoryText(available: available, chosen: chosen), systemImage: "info.circle")
                        .font(.caption).fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .readableGlass(RoundedRectangle(cornerRadius: 16), floor: darkGlassFloor)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("radar-history-short-note")
                }
                HStack(alignment: .top, spacing: 10) {
                    Spacer()
                    // The container only morphs the legend panel. The round buttons stay OUTSIDE it: inside a
                    // GlassEffectContainer their glass lives in the shared container layer, which made the zoom source unreliable.
                    GlassEffectContainer(spacing: 8) {
                        if showLegend {
                            Group {
                                if store.activeLayer == .radar {
                                    RadarLegendPanel(legend: .precipitationRadar)
                                } else {
                                    RadarLayerLegendPanel(
                                        layer: store.activeLayer, manifest: store.layers.activeManifest,
                                        humidityChoices: [RadarLayer.dewpoint, .humidity].filter { store.layers.availability($0) == .available },
                                        onSelectLayer: { store.layers.select($0) },
                                        maxHeight: pillBlockTop.map { max(0, $0 - legendTop - 8) })
                                }
                            }
                            .glassEffectID("legend-panel", in: glassNamespace)
                        }
                    }
                    VStack(spacing: 10) {
                        Button { store.requestLocation() } label: {
                            Image(systemName: "location.fill").font(.system(size: 20)).frame(width: 46, height: 46)
                                .glassControl(Circle())
                        }.accessibilityLabel(NSLocalizedString("RADAR_USE_LOCATION", value: "Aktuellen Standort verwenden", comment: "Radar"))
                            .accessibilityInputLabels([NSLocalizedString("RADAR_USE_LOCATION", value: "Aktuellen Standort verwenden", comment: "Radar"),
                                                       NSLocalizedString("VC_LOCATION", value: "Standort", comment: "Voice Control"), NSLocalizedString("VC_LOCATION_ALT", value: "Ortung", comment: "Voice Control")])
                        Button { withAnimation(reduceMotion ? nil : .bouncy(duration: 0.4)) { showLegend.toggle() } } label: {
                            Image(systemName: "paintpalette").font(.system(size: 20)).frame(width: 46, height: 46)
                                .glassControl(Circle())
                        }
                        .accessibilityLabel(String(format: NSLocalizedString("RADAR_LEGEND_LABEL", value: "Legende %@", comment: "Radar"), store.activeLayer.title))
                        .accessibilityValue(showLegend ? NSLocalizedString("RADAR_LEGEND_SHOWN", value: "eingeblendet", comment: "Radar") : NSLocalizedString("RADAR_LEGEND_HIDDEN", value: "ausgeblendet", comment: "Radar"))
                        .accessibilityHint(RadarLayerLegendText.toggleHint(for: store.activeLayer))
                        .accessibilityInputLabels([String(format: NSLocalizedString("RADAR_LEGEND_LABEL", value: "Legende %@", comment: "Radar"), store.activeLayer.title),
                                                   NSLocalizedString("VC_LEGEND", value: "Legende", comment: "Voice Control"), NSLocalizedString("VC_LEGEND_ALT", value: "Farbskala", comment: "Voice Control")])
                        .accessibilityIdentifier("radar-legend-toggle")
                        if canReadValue {
                            Button { readoutRevision += 1 } label: {
                                Image(systemName: "scope").font(.system(size: 20)).frame(width: 46, height: 46)
                                    .glassControl(Circle())
                            }
                            .accessibilityLabel(NSLocalizedString("TEMP_READ_CENTER", value: "Wert in Kartenmitte vorlesen", comment: "VoiceOver action"))
                            .accessibilityInputLabels([NSLocalizedString("TEMP_READ_CENTER", value: "Wert in Kartenmitte vorlesen", comment: "VoiceOver action"),
                                                       NSLocalizedString("VC_READ_VALUE", value: "Wert vorlesen", comment: "Voice Control")])
                            .accessibilityIdentifier("radar-read-center")
                        }
                        if warn.capabilityWarnings { warningsButton }
                        Button { sheet = .information } label: {
                            Image(systemName: "info.circle").font(.system(size: 20)).frame(width: 46, height: 46)
                                .glassControl(Circle())
                        }
                        .glassSheetSource(.information, in: glassNamespace)
                        .accessibilityLabel(NSLocalizedString("RADAR_INFO_BUTTON", value: "Datenquellen und Datenschutz", comment: "Radar"))
                        .accessibilityInputLabels([NSLocalizedString("RADAR_INFO_BUTTON", value: "Datenquellen und Datenschutz", comment: "Radar"),
                                                   NSLocalizedString("VC_INFO", value: "Info", comment: "Voice Control"), NSLocalizedString("VC_INFO_ALT", value: "Datenschutz", comment: "Voice Control")])
                    }
                    .buttonStyle(.plain)
                    .font(.title3)
                }
                .onGeometryChange(for: CGFloat.self) { $0.frame(in: .named("radarScreen")).minY } action: { legendTop = $0 }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            // While the slider is dragged the whole top block (header, forecast, notices, legend, map buttons) fades out. Only
            // opacity changes, so no layout moves and the finger on the slider is never disturbed; hidden controls can neither be
            // tapped nor reached by VoiceOver. Reduce Motion: switches instantly.
            .opacity(chrome.isChromeHidden ? 0 : 1)
            .allowsHitTesting(!chrome.isChromeHidden)
            .accessibilityHidden(chrome.isChromeHidden)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: chrome.isChromeHidden)
        }
        .coordinateSpace(name: "radarScreen")
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { screenWidth = $0 }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            timeline
                .padding(.horizontal, 12)
                .padding(.top, 4)
                .padding(.bottom, 2)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { mapBottomInset = $0 }
        }
        .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.bottom } action: { deviceBottomInset = $0 }

        .sheet(item: $sheet) { item in
            switch item {
            case .places: PlacesSheet(store: store).navigationTransition(.zoom(sourceID: item.rawValue, in: glassNamespace))
            case .details: ForecastDetails(store: store)
            case .information: InformationSheet(store: store).navigationTransition(.zoom(sourceID: item.rawValue, in: glassNamespace))
            case .warnings: WarningsListView(feed: warnFeed).navigationTransition(.zoom(sourceID: item.rawValue, in: glassNamespace))
            }
        }
        .environment(\.glassScrim, colorScheme == .dark && store.activeLayer.coversMapBrightly ? RadarLayer.brightLayerScrim : 0)
        .alert(NSLocalizedString("RADAR_SAVE_PLACE_TITLE", value: "Ort speichern", comment: "Radar"), isPresented: $showSave) {
            TextField(NSLocalizedString("COMMON_NAME", value: "Name", comment: "Text field"), text: $placeName)
            Button(NSLocalizedString("COMMON_SAVE", value: "Speichern", comment: "Common")) { store.saveSelection(name: placeName) }
            Button(NSLocalizedString("COMMON_CANCEL", value: "Abbrechen", comment: "Common"), role: .cancel) { }
        } message: { Text(NSLocalizedString("RADAR_SAVE_PLACE_MESSAGE", value: "Name und Koordinaten bleiben auf deinem iPhone und werden auch an deine gekoppelte Apple Watch übertragen, wenn dort Showers installiert ist.", comment: "Radar")) }
        .task(id: store.isPlaying) {
            guard store.isPlaying else { return }
            // Playback covers only a window (at most 3 h of past); start there if the slider is further back.
            if let timeline = store.displayTimeline {
                let start = PlaybackWindow.startIndex(dates: timeline.dates, reference: timeline.referenceTime, pastHours: store.playbackPastHours)
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
                                                                   reference: timeline.referenceTime, pastHours: store.playbackPastHours)
                waitingFrame = store.displayFrameDate
                waitingSince = Date()
            }
        }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            while !Task.isCancelled {
                displayNow = screenNow()
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
            chrome.dragEnded()
        }
        .onChange(of: sheet) { _, value in
            if value != nil { store.isPlaying = false; chrome.dragEnded() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { store.isPlaying = false; scrubIndex = nil; chrome.dragEnded() }
        }
        .onDisappear { chrome.dragEnded() }
    }

    private struct LayerPollKey: Equatable { let layer: RadarLayer; let active: Bool }

    /// One selectable layer: checkmark when active, greyed out with a hint when unavailable, note as subtitle.
    @ViewBuilder
    private func layerButton(_ layer: RadarLayer) -> some View {
        let availability = store.layers.availability(layer)
        let selected = layer == store.activeLayer
        let hint = availability.hint
        Button {
            store.isPlaying = false
            showLegend = false
            store.layers.select(layer)
        } label: {
            // The native menu shows one line only: hints go into the title in parentheses.
            Label(layer.menuTitle + (hint.map { " (\($0))" } ?? ""), systemImage: selected ? "checkmark" : layer.symbolName)
        }
        .disabled(!availability.isSelectable)
        .accessibilityLabel(layer.spokenName + (hint.map { ", \($0)" } ?? "")
                            + (selected ? NSLocalizedString("RADAR_LAYER_SELECTED_SUFFIX", value: ", ausgewählt", comment: "Radar") : ""))
        .accessibilityIdentifier("radar-layer-\(layer.rawValue)")
    }

    /// Submenu with the offered members of a group; hidden when the backend offers none. The group's symbol
    /// switches to a checkmark-free variant: the check sits on the active entry inside.
    @ViewBuilder
    private func layerGroup(_ title: String, symbol: String, layers: [RadarLayer], id: String) -> some View {
        if !layers.isEmpty {
            Menu {
                ForEach(layers) { layer in layerButton(layer) }
            } label: {
                Label(title, systemImage: symbol)
            }
            .accessibilityIdentifier(id)
        }
    }

    /// Top right: layer choice (capsule with the active layer) plus manual reload. Reload used to be its own button;
    /// the adaptive poll already fetches `latest.json` every 10 to 60 s, so a manual reload is a rare action.
    private var layerMenu: some View {
        Menu {
            // Rain: DWD Germany, OPERA Europe, NOAA world (soon).
            Menu {
                ForEach(store.layers.rainMenuEntries, id: \.layer) { entry in
                    if entry.isSoon {
                        Button {} label: {
                            // The native menu shows one line only: the "soon" note goes into the title.
                            Label(entry.layer.menuTitle + " (" + NSLocalizedString("LAYER_RADAR_SOON", value: "bald", comment: "Layer menu note") + ")",
                                  systemImage: entry.layer.symbolName)
                        }
                        .disabled(true)
                        .accessibilityLabel(entry.layer.spokenName + ", " + NSLocalizedString("LAYER_RADAR_SOON", value: "bald", comment: "Layer menu note"))
                        .accessibilityIdentifier("radar-layer-\(entry.layer.rawValue)")
                    } else {
                        layerButton(entry.layer)
                    }
                }
            } label: {
                Label(NSLocalizedString("RADAR_MENU_GROUP_RAIN", value: "Regen", comment: "Radar menu group"), systemImage: "cloud.rain")
            }
            .accessibilityIdentifier("radar-layer-group-rain")
            layerGroup(NSLocalizedString("RADAR_MENU_GROUP_PRESSURE", value: "Luftdruck", comment: "Radar menu group"),
                       symbol: "gauge.with.dots.needle.33percent", layers: store.layers.offered(RadarLayer.pressureLayers), id: "radar-layer-group-pressure")
            layerGroup(NSLocalizedString("RADAR_MENU_GROUP_HUMIDITY", value: "Feuchtigkeit", comment: "Radar menu group"),
                       symbol: "humidity", layers: store.layers.offered(RadarLayer.humidityLayers), id: "radar-layer-group-humidity")
            ForEach(store.layers.offered(RadarLayer.singleMenuLayers)) { layer in layerButton(layer) }
            Divider()
            Section {
                Button {
                    store.isPlaying = false
                    radarLoadState = nil
                    Task { await store.refresh() }
                    Task { await store.layers.probeAll(force: true, restricted: ProcessInfo.processInfo.isLowPowerModeEnabled) }
                } label: {
                    Label(NSLocalizedString("RADAR_RELOAD", value: "Daten neu laden", comment: "Radar"), systemImage: "arrow.clockwise")
                }
                .disabled(store.isRadarLoading)
                .accessibilityHint(NSLocalizedString("RADAR_RELOAD_HINT", value: "Lädt den aktuellen Datenstand der Karte neu", comment: "Radar"))
                .accessibilityIdentifier("radar-refresh")
            }
        } label: {
            // Compact chrome (padding 10, spacing 4 instead of 14/6, 19.11.): on the iPhone SE (375 pt) "Regenradar Welt" was cut to
            // "Regenradar W…"; the 12 pt gained let the title fit at about 0.8 of its size.
            HStack(spacing: 4) {
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
            .padding(.horizontal, 10)
            .frame(minHeight: 44)
            .glassControl(Capsule(), floor: darkGlassFloor)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(NSLocalizedString("RADAR_LAYER_MENU_LABEL", value: "Kartenebene wählen", comment: "Radar"))
        .accessibilityValue(store.activeLayer.spokenName)
        .accessibilityInputLabels([NSLocalizedString("RADAR_LAYER_MENU_LABEL", value: "Kartenebene wählen", comment: "Radar"), store.activeLayer.title,
                                   NSLocalizedString("VC_LAYER", value: "Kartenebene", comment: "Voice Control")])
        .accessibilityHint(NSLocalizedString("RADAR_LAYER_MENU_HINT", value: "Wählt genau eine Ebene. Untermenüs: Regen (Deutschland, Europa, Welt), Luftdruck und Feuchtigkeit; dazu Temperatur, Blitze, Wolken und Sonne. Enthält auch Daten neu laden.", comment: "Radar"))
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
        .glassSheetSource(.warnings, in: glassNamespace)
        .accessibilityLabel(WarningPresentation.buttonLabel())
        .accessibilityValue(WarningPresentation.buttonValue(summary, stale: stale))
        .accessibilityInputLabels([WarningPresentation.buttonLabel(), NSLocalizedString("VC_WARNINGS", value: "Warnungen", comment: "Voice Control")])
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
                            Text(NSLocalizedString("LAYER_RADAR_TITLE", value: "Regenradar", comment: "Radar")).font(.caption).foregroundStyle(.primary.opacity(0.85))   // .secondary measured 2.3 to 3.6 : 1
                        }
                    }
                    Image(systemName: "chevron.down").font(.caption.bold())
                }
                .padding(.horizontal, 16).padding(.vertical, 11)
                .glassControl(Capsule(), floor: darkGlassFloor)
            }
            .glassSheetSource(.places, in: glassNamespace)
            .layoutPriority(1) // place name wins over the layer capsule, which shrinks/truncates instead
            .accessibilityLabel(String(format: NSLocalizedString("RADAR_PLACE_PICK", value: "Ort auswählen: %@", comment: "Radar"), store.selectedPlace.name))
            .accessibilityInputLabels([store.selectedPlace.name, NSLocalizedString("VC_PLACE", value: "Ort auswählen", comment: "Voice Control"), NSLocalizedString("VC_PLACES", value: "Orte", comment: "Voice Control")])
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

    /// Holes in the data directly before and after the shown slot (empty without holes).
    private var displayedGapLines: [String] {
        guard let timeline = store.displayTimeline, !timeline.gaps.isEmpty else { return [] }
        return TimelineGapText.lines(for: displayedIndex, gaps: timeline.gaps)
    }

    /// Honest per-slot hint: the map never shows another slot's image as this slot's state.
    private var slotFeedback: (text: String, failed: Bool)? {
        let layer = store.activeLayer
        if layer != .radar, store.displayTimeline == nil {
            // No data for the chosen layer (outage): a quiet hint instead of an error banner.
            if store.layers.isLoading { return (String(format: NSLocalizedString("TIMELINE_LOADING_LAYER", value: "%@ lädt …", comment: "Radar"), layer.title), false) }
            // World and Europe already say why in their own note at the top (`RainLayerNotice`): no second pill for the same state.
            if layer.staysActiveWhenUnavailable { return nil }
            return (String(format: NSLocalizedString("RADAR_LAYER_UNAVAILABLE", value: "%@ derzeit nicht verfügbar", comment: "Radar"), layer.title), true)
        }
        guard store.displayTimeline != nil, !store.isPlaying, let date = displayedDate else { return nil }
        let time = date.formatted(date: .omitted, time: .shortened)
        let name = layer == .radar ? NSLocalizedString("RADAR_NAME_SHORT", value: "Radar", comment: "Radar") : layer.title
        switch TimelineSlot.status(for: currentRadarLoadState) {
        case .ready: return nil
        case .loading: return (String(format: NSLocalizedString("RADAR_SLOT_LOADING", value: "%1$@ für %2$@ lädt …", comment: "Radar"), name, time), false)
        case .failed: return (String(format: NSLocalizedString("RADAR_SLOT_FAILED", value: "%1$@ für %2$@ nicht geladen", comment: "Radar"), name, time), true)
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

    /// Short credit in the size and style of Apple Maps' legal text, no capsule. The full source text, licences and
    /// modification notices are in the information screen (Datenquellen).
    @ViewBuilder private func creditLine(sizeLimit: DynamicTypeSize = .xLarge) -> some View {
        if let line = ForestPreference.shortSourceLine(base: store.displayShortAttribution, layer: store.activeLayer,
                                                       visible: forestVisible, info: ForestInfo.bundled) {
            Text(line)
                .font(.caption2).foregroundStyle(.primary.opacity(0.75))
                .lineLimit(1).minimumScaleFactor(0.8)
                // A fixed strip below the slider: the text grows only a little with Dynamic Type (VoiceOver reads it in full).
                .dynamicTypeSize(...sizeLimit)
                .shadow(color: Color(.systemBackground).opacity(0.9), radius: 1.5)
                .shadow(color: Color(.systemBackground).opacity(0.7), radius: 3)
                .padding(.horizontal, 8)
                // Rendering only (no layout space): a faint backdrop behind the text keeps it readable on any map colour.
                .background { Capsule().fill(Color(.systemBackground).opacity(colorScheme == .dark ? (store.activeLayer.coversMapBrightly ? 0.75 : 0.6) : 0.35)).blur(radius: 2) }
                .allowsHitTesting(false)
                .accessibilityLabel(line)
                .accessibilityHint(NSLocalizedString("RADAR_CREDIT_HINT", value: "Vollständige Quellenangaben unter Datenquellen und Datenschutz", comment: "Radar"))
                .accessibilityIdentifier("radar-attribution")
        }
    }

    /// The strip between the slider card and the screen edge (home indicator devices, about 34 pt) is free: the credit
    /// goes there and the slider keeps its position. Devices with a home button have no such strip.
    private var hasStripBelowSlider: Bool { deviceBottomInset >= 20 }

    /// Widest plain time of the current locale (digits of equal width), reserves the pill's width.
    private static var widestTimeTemplate: String {
        Date(timeIntervalSinceReferenceDate: 8 * 3600 + 8 * 60).formatted(date: .omitted, time: .shortened)
    }

    /// Compact card: only the slider (the time moved to `timePill`, play/pause is the pill's tap).
    private var timeline: some View {
        timeSlider
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .readableGlass(RoundedRectangle(cornerRadius: 26), floor: darkGlassFloor)
            .accessibilityIdentifier("radar-timeline")
            // The credit hangs below the card without taking layout space: the slider keeps its position. It sits in the
            // free strip between the card and the home indicator (card bottom + 20 pt = text bottom, about 3 pt below the card).
            .overlay(alignment: .bottom) {
                if hasStripBelowSlider {
                    creditLine().offset(y: 20)
                }
            }
    }

    private var displayedIsForecast: Bool {
        guard let date = displayedDate, let timeline = store.displayTimeline else { return false }
        return ScreenGlow.isForecast(date: date, reference: timeline.referenceTime)
    }

    /// `nil` while not dragging; otherwise whether the dragged time is in the future (drives the scrub glow).
    private var scrubGlowState: Bool? { scrubIndex == nil ? nil : displayedIsForecast }

    /// Standing glass pill above the source line (calm: no sideways movement). Tint: future = orange (like the line), past = blue, subtle.
    /// Tap plays/pauses the animation, long press jumps to "Now". The pill is a plain tinted glass capsule, not inside another glass layer.
    @ViewBuilder private var timePill: some View {
        if store.displayTimeline != nil, let date = displayedDate {
            let stacked = dynamicTypeSize.isAccessibilitySize
            let forecast = displayedIsForecast
            let time = Text(date.formatted(date: .omitted, time: .shortened)).font(.title3.weight(.semibold)).monospacedDigit()
            let day = otherDayLabel(for: date).map { Text($0).font(.subheadline) }
            let playing = store.isPlaying
            HStack(spacing: 8) {
                Image(systemName: playing ? "pause.fill" : "play.fill").font(.system(size: 13, weight: .bold))
                // As wide as its content (play symbol and time). A hidden time of the widest digits keeps the width calm while
                // scrubbing; another day's label makes it wider. At the largest sizes two lines keep the height stable.
                ZStack {
                    // Largest sizes: the former wide template keeps the two-line pill as it was; otherwise only the time's width.
                    Text(stacked ? "Mo., 88. Okt. \u{00B7} 88:88 AM" : Self.widestTimeTemplate).font(.title3.weight(.semibold)).monospacedDigit().hidden()
                    Group { if let day { Text("\(day) \u{00B7} \(time)") } else { time } }
                }
                .lineLimit(stacked ? 2 : 1, reservesSpace: stacked).minimumScaleFactor(0.7)
                .multilineTextAlignment(.center)
            }
            .foregroundStyle(.primary)
            .accessibilityHidden(true)
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
            .contentShape(Capsule())
            // Dark: a dark underlay lifts the white text's contrast. Light: a light underlay and dark text (the dark one made the pill too dark).
            .background(Capsule().fill(colorScheme == .dark ? Color.black.opacity(0.3) : Color.white.opacity(0.6)))
            .glassEffect(.regular.tint((forecast ? ScreenGlow.futureColor : ScreenGlow.pastColor).opacity(colorScheme == .dark ? (forecast ? 0.5 : 0.3) : (forecast ? 0.3 : 0.2))).interactive(), in: Capsule())
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: forecast)
            .onTapGesture { togglePlayback() }
            .onLongPressGesture(minimumDuration: 0.4) { jumpToNow() }
            .sensoryFeedback(.impact(weight: .light, intensity: 0.6), trigger: nowJumps)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(playing ? NSLocalizedString("TIMELINE_PAUSE", value: "Animation pausieren", comment: "Radar") : NSLocalizedString("TIMELINE_PLAY", value: "Animation abspielen", comment: "Radar"))
            .accessibilityValue(TimelineAccessibility.value(date: date, isForecast: forecast, reference: store.displayTimeline?.referenceTime ?? date,
                                                            caption: store.activeLayer.frameCaption(isForecast: forecast)))
            .accessibilityHint(NSLocalizedString("TIMELINE_PILL_HINT", value: "Tippen: abspielen oder pausieren. Gedrückt halten: zur aktuellen Zeit springen", comment: "Radar"))
            .accessibilityAddTraits(.isButton)
            .accessibilityInputLabels([playing ? NSLocalizedString("TIMELINE_PAUSE", value: "Animation pausieren", comment: "Radar") : NSLocalizedString("TIMELINE_PLAY", value: "Animation abspielen", comment: "Radar"),
                                       playing ? NSLocalizedString("VC_PAUSE", value: "Pause", comment: "Voice Control") : NSLocalizedString("VC_PLAY", value: "Abspielen", comment: "Voice Control"),
                                       date.formatted(date: .omitted, time: .shortened)])
            .accessibilityAction(named: Text(NSLocalizedString("TIMELINE_JUMP_NOW", value: "Zur aktuellen Zeit springen", comment: "Radar"))) { jumpToNow() }
            .accessibilityAction(named: Text(playing ? NSLocalizedString("TIMELINE_PAUSE", value: "Animation pausieren", comment: "Radar") : NSLocalizedString("TIMELINE_PLAY", value: "Animation abspielen", comment: "Radar"))) { togglePlayback() }
            .accessibilityIdentifier("radar-frame-label")
        }
    }

    private func togglePlayback() { store.isPlaying.toggle() }

    private func jumpToNow() {
        guard let timeline = store.displayTimeline else { return }
        store.isPlaying = false
        store.displayFrameIndex = timeline.dates.firstIndex(of: timeline.referenceTime) ?? 0
        nowJumps += 1
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
            }, onEnd: { scrubIndex = nil; chrome.dragEnded() },
               onTravel: { chrome.dragMoved(distance: $0) }, stage: $scrubStage)
            .onChange(of: scrubGlowState) { _, state in
                if let state { ScreenGlowPresenter.updateScrub(isForecast: state, reduceMotion: reduceMotion) }
                else { ScreenGlowPresenter.endScrub() }
            }
            // Build 40: gentle tick per slot (was `.selection`), a distinct firm tap exactly once when the thumb crosses or
            // lands on "Now" (past <-> future), and the light stage tap softened. Haptics settings stay with the system.
            .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.35), trigger: scrubIndex) { old, new in
                guard let new, new != old else { return false }
                let now = timeline.dates.firstIndex(of: timeline.referenceTime)
                return TimelineNowCrossing.side(index: new, nowIndex: now) == TimelineNowCrossing.side(index: old ?? new, nowIndex: now)
            }
            .sensoryFeedback(.impact(flexibility: .rigid, intensity: 1.0), trigger: scrubIndex) { old, new in
                guard let old, let new, old != new else { return false }
                let now = timeline.dates.firstIndex(of: timeline.referenceTime)
                return TimelineNowCrossing.side(index: new, nowIndex: now) != TimelineNowCrossing.side(index: old, nowIndex: now)
            }
            .sensoryFeedback(.impact(weight: .light, intensity: 0.5), trigger: scrubStage) { old, new in old != nil && new != nil }
            .overlay(alignment: .center) {
                // Same horizontal extent as the slider track (inset by half the thumb); sits a constant 4 pt under the 4 pt track.
                // "Now" marker where the thumb centre is.
                GeometryReader { geometry in
                    let boundary = Double(timeline.dates.firstIndex(of: timeline.referenceTime) ?? 0) / Double(timeline.dates.count - 1)
                    HStack(spacing: 0) {
                        ScreenGlow.lineColor(forecast: false, dark: colorScheme == .dark).frame(width: geometry.size.width * boundary)
                        ScreenGlow.lineColor(forecast: true, dark: colorScheme == .dark)
                    }
                    .clipShape(Capsule())
                    .frame(height: 2)
                    Rectangle().fill(.primary).frame(width: 2, height: 6)
                        .offset(x: max(0, geometry.size.width * boundary - 1), y: -2)
                    // Holes in the data: a short red mark between the two slots around the hole (one Canvas, whatever the count).
                    if !timeline.gaps.isEmpty {
                        let count = timeline.dates.count
                        let gaps = timeline.gaps.gaps
                        Canvas { context, size in
                            for gap in gaps {
                                let fraction = gap.afterIndex < 0 ? 0 : (Double(gap.afterIndex) + 0.5) / Double(max(count - 1, 1))
                                let x = size.width * fraction
                                context.fill(Path(CGRect(x: min(max(x - 1.5, 0), size.width - 3), y: 0, width: 3, height: size.height)),
                                             with: .color(Color(.systemRed).opacity(0.9)))
                            }
                        }
                        .frame(width: geometry.size.width, height: 12)
                        .position(x: geometry.size.width / 2, y: 1)
                        .accessibilityHidden(true)
                        .accessibilityIdentifier("radar-timeline-gap-marks")
                    }
                }
                .frame(height: 2)
                .offset(y: 7)
                .padding(.horizontal, TimelineScrubSlider.thumbWidth / 2)
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
                                                                caption: store.activeLayer.frameCaption(isForecast: displayedIsForecast),
                                                                gapLines: displayedGapLines))
                .accessibilityHint(String(format: NSLocalizedString("TIMELINE_SLIDER_HINT", value: "Von %1$@ bis %2$@. Beim Ziehen mit dem Finger nach oben vom Regler weg wird die Steuerung feiner.", comment: "Radar"), timeline.dates.first!.formatted(date: .abbreviated, time: .shortened), timeline.dates.last!.formatted(date: .omitted, time: .shortened)))
            }
        } else {
            Text(store.activeLayer != .radar
                 ? (store.layers.isLoading ? String(format: NSLocalizedString("TIMELINE_LOADING_LAYER", value: "%@ lädt …", comment: "Radar"), store.activeLayer.title) : String(format: NSLocalizedString("TIMELINE_NO_TIMES_LAYER", value: "Keine Zeiten für %@", comment: "Radar"), store.activeLayer.title))
                 : store.isLoading ? NSLocalizedString("TIMELINE_LOADING_RADAR", value: "Radar lädt …", comment: "Radar") : NSLocalizedString("TIMELINE_NO_TIMES_RADAR", value: "Keine Radarzeiten", comment: "Radar"))
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
                        forecastLabel
                        forecastTrailing
                    }
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                    .overlay {
                        // Whole width of the bottom edge, same height as before (overlay), clipped to the pill's corners.
                        // Inside the glass (before glassControl): an overlay after the glass effect was not drawn.
                        if store.updateProgressDisplay != .hidden {
                            UpdateProgressBar(display: store.updateProgressDisplay)
                                .frame(maxHeight: .infinity, alignment: .bottom)
                                .clipShape(RoundedRectangle(cornerRadius: 24))
                        }
                    }
                    .glassControl(RoundedRectangle(cornerRadius: 24), floor: darkGlassFloor)
                }
                .buttonStyle(.plain)
                .accessibilityValue(measuredUpdateFraction.map { UpdateProgressDisplay.percentText($0) } ?? "")
                .accessibilityIdentifier("forecast-details")
                .accessibilityHint(NSLocalizedString("RADAR_FORECAST_DETAILS_HINT", value: "Öffnet Niederschlagsverlauf, Datenalter und Prognosehinweise", comment: "Radar"))
                Button {
                    placeName = store.selectedPlace.name
                    showSave = true
                } label: {
                    Image(systemName: store.places.contains(where: { $0.id == store.selectedPlace.id }) ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 20)).frame(width: 48, height: 48)
                        .glassControl(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(NSLocalizedString("RADAR_SAVE_PLACE_BUTTON", value: "Ausgewählten Ort speichern oder umbenennen", comment: "Radar"))
                .accessibilityInputLabels([NSLocalizedString("RADAR_SAVE_PLACE_BUTTON", value: "Ausgewählten Ort speichern oder umbenennen", comment: "Radar"),
                                           NSLocalizedString("VC_SAVE_PLACE", value: "Ort speichern", comment: "Voice Control"), NSLocalizedString("VC_BOOKMARK", value: "Lesezeichen", comment: "Voice Control")])
            }
        }
    }

    /// Header text for a non-current forecast, e.g. "Aktualisierung fehlgeschlagen". No age in the header
    /// (Lino 18.11.2026: "Stand vor..." weg); the details sheet still shows it.
    private func forecastStatusText(_ status: WeatherStore.ForecastStatus) -> String {
        switch status {
        case .refreshing: return NSLocalizedString("RADAR_FORECAST_CAPTION_REFRESHING", value: "Aktualisiere …", comment: "Radar")
        case .failed: return NSLocalizedString("RADAR_FORECAST_CAPTION_FAILED", value: "Aktualisierung fehlgeschlagen", comment: "Radar")
        case .serverBehind: return NSLocalizedString("RADAR_FORECAST_CAPTION_BEHIND", value: "Der Wetterdienst hat noch keinen neueren Stand", comment: "Radar")
        }
    }

    /// UI tests with the forecast stub query the spinner's frame; for real users it stays hidden from VoiceOver.
    private static var exposeSpinnerForUITests: Bool {
        #if DEBUG
        return ForecastUITestStub.mode != nil
        #else
        return false
        #endif
    }

    private var isRefreshingForecast: Bool { store.showsForecastSpinner }

    /// Share of the running update where every request reports its size; `nil` when it cannot be measured.
    private var measuredUpdateFraction: Double? {
        if case .measured(let value) = store.updateProgressDisplay { value } else { nil }
    }

    /// Chevron where it always was (right behind the text), plus the refreshing spinner at the RIGHT EDGE of the pill.
    /// No second line, no age text.
    @ViewBuilder private var forecastTrailing: some View {
        Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
        if isRefreshingForecast {
            // Measured: the percent takes the spinner's place (bar and number show the progress; a second indicator would only
            // take width and make the hint text wrap). At accessibility sizes the percent is not drawn at all: it would add a line
            // and make the pill taller; the fill stays visible and the percent is still spoken as the header's value.
            if let fraction = measuredUpdateFraction, !dynamicTypeSize.isAccessibilitySize {
                Spacer(minLength: 4)
                Text(UpdateProgressDisplay.percentText(fraction))
                    .font(.caption2.weight(.semibold)).monospacedDigit()
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    .lineLimit(1).fixedSize()
                    .accessibilityHidden(!Self.exposeSpinnerForUITests)   // spoken as the header's value instead
                    .accessibilityIdentifier("update-progress-percent")
            } else {
                Spacer(minLength: 8)
                forecastStatusIcon(.refreshing)
            }
        }
    }

    @ViewBuilder private var forecastLabel: some View {
        if let forecast = store.forecast {
            let status = store.forecastStatus(now: displayNow)
            // Failure and "server behind" replace the summary; refreshing never does (only the spinner shows it).
            let statusReplacesSummary = status != nil && status != .refreshing
            HStack(spacing: 6) {
                if statusReplacesSummary, let status { forecastStatusIcon(status) }
                Text(dynamicTypeSize.isAccessibilitySize ? NSLocalizedString("RADAR_FORECAST_DETAILS", value: "Prognosedetails", comment: "Radar")
                     : (statusReplacesSummary && status != nil ? forecastStatusText(status!) : forecast.summary(at: displayNow)))
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                    // The spoken label adds "Aktualisiere …" (no age); it is not shown as text.
                    .accessibilityLabel(status == .refreshing
                        ? "\(forecast.summary(at: displayNow)). \(forecastStatusText(.refreshing))"
                        : (statusReplacesSummary && status != nil ? forecastStatusText(status!) : forecast.summary(at: displayNow)))
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(status == .refreshing ? "forecast-refreshing" : status == .failed ? "forecast-update-failed" : status == .serverBehind ? "forecast-server-behind" : "forecast-headline")
        } else {
            Text(dynamicTypeSize.isAccessibilitySize ? NSLocalizedString("RADAR_FORECAST_DETAILS", value: "Prognosedetails", comment: "Radar")
                 : (store.isForecastLoading ? NSLocalizedString("RADAR_FORECAST_LOADING", value: "Regenprognose wird geladen …", comment: "Radar") : NSLocalizedString("RADAR_FORECAST_UNAVAILABLE", value: "Prognose nicht verfügbar", comment: "Radar")))
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder private func forecastStatusIcon(_ status: WeatherStore.ForecastStatus) -> some View {
        if status == .refreshing {
            // Non-text contrast (>= 3:1): primary tint instead of the default light grey spinner.
            // The halo in the opposite colour darkens/lightens the glass right behind the thin spokes.
            ProgressView().controlSize(.small).tint(.primary)
                .shadow(color: Color(.systemBackground).opacity(0.9), radius: 1.5)
                .shadow(color: Color(.systemBackground).opacity(0.7), radius: 3)
                .shadow(color: Color(.systemBackground).opacity(0.6), radius: 5)
                .accessibilityIdentifier("forecast-refresh-spinner")
                .accessibilityHidden(!Self.exposeSpinnerForUITests)
        } else {
            Image(systemName: "exclamationmark.triangle").font(.caption.weight(.semibold)).foregroundStyle(.orange).accessibilityHidden(true)
        }
    }

    /// Rain maps beyond Germany: world estimate/coverage notes and the one missing-data note (world and Europe).
    private var rainLayerNotices: [RainLayerNotice.Notice] {
        RainLayerNotice.notices(active: store.activeLayer, availability: store.layers.availability(store.activeLayer),
                                centerLatitude: mapCenterLatitude)
    }

    /// Notices under the header (up to two): a forecast failure and a radar image problem are shown together.
    private var statusMessages: [String] {
        RadarStatusMessages.messages(RadarStatusInput(
            locationMessage: store.locationMessage, storageMessage: store.storageMessage,
            radarLayerActive: store.activeLayer == .radar, layerTitle: store.activeLayer.title,
            radarImageMissing: (currentRadarLoadState?.failed ?? 0) > 0, radarFromCache: store.radarSource == .cache,
            radarError: store.radarError, forecastError: store.forecastError, forecastShown: store.forecast != nil,
            forecastFailureConfirmed: store.forecastFailureConfirmed, radarNotice: store.radarNotice))
    }

    private func age(_ date: Date) -> String {
        let minutes = max(0, Int(Date().timeIntervalSince(date) / 60))
        return minutes == 0 ? NSLocalizedString("RADAR_AGE_NOW", value: "gerade aktualisiert", comment: "Radar") : String(format: NSLocalizedString("RADAR_AGE_MINUTES", value: "vor %d Min.", comment: "Radar"), minutes)
    }
}

/// "Now" for the screen; UI tests with the forecast stub use the frozen time of the fixture.
private func screenNow() -> Date {
    #if DEBUG
    if ForecastUITestStub.mode != nil { return ForecastUITestStub.now }
    #endif
    return Date()
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
                    BarMark(x: .value(NSLocalizedString("RADAR_CHART_TIME", value: "Zeit", comment: "Radar"), sample.date, unit: .minute), y: .value(NSLocalizedString("RADAR_CHART_PRECIPITATION", value: "Niederschlag", comment: "Radar"), value), width: .ratio(0.85))
                        .foregroundStyle(.cyan.gradient)
                        .accessibilityLabel(sample.date.formatted(date: .omitted, time: .shortened))
                        .accessibilityValue(String(format: NSLocalizedString("RADAR_CHART_SPOKEN_RATE", value: "%@ Millimeter pro Stunde", comment: "Radar"), value.formatted(.number.precision(.fractionLength(1)))))
                } else {
                    RuleMark(x: .value(NSLocalizedString("RADAR_CHART_MISSING", value: "Fehlender Wert", comment: "Radar"), sample.date))
                        .foregroundStyle(.gray.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
                        .accessibilityLabel(String(format: NSLocalizedString("RADAR_CHART_NO_DATA", value: "Keine Daten um %@", comment: "Radar"), sample.date.formatted(date: .omitted, time: .shortened)))
                }
            }
            RuleMark(x: .value(NSLocalizedString("RADAR_CHART_NOW", value: "Jetzt", comment: "Radar"), Date())).foregroundStyle(.secondary)
        }
        .chartYScale(domain: 0...max(1, forecast.samples.compactMap(\.rateMMPerHour).max() ?? 1))
        .chartXAxis(compact ? .hidden : .automatic)
        .chartYAxis(compact ? .hidden : .automatic)
        .accessibilityLabel(NSLocalizedString("RADAR_CHART_LABEL", value: "Niederschlagsverlauf", comment: "Radar"))
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
                        Text(NSLocalizedString("RADAR_DETAILS_CAPTION", value: "Durchschnittliche Intensität in mm/h für Fünf-Minuten-Intervalle. Gestrichelte Markierungen zeigen fehlende Werte.", comment: "Radar"))
                            .font(.caption).foregroundStyle(.secondary)
                        LabeledContent(NSLocalizedString("RADAR_DETAILS_RUN", value: "Datenlauf", comment: "Radar"), value: forecast.referenceTime.formatted(date: .abbreviated, time: .shortened))
                        Text(String(format: NSLocalizedString("RADAR_DETAILS_SOURCE_AGE", value: "DWD · %@", comment: "Radar"), forecast.ageDescription(at: context.date)))
                            .font(.caption).foregroundStyle(.secondary)
                        LabeledContent(NSLocalizedString("RADAR_DETAILS_IMAGES", value: "Radarbilder", comment: "Radar"), value: store.radarSource.label)
                        if store.forecastFailureConfirmed || store.forecastStatus(now: context.date) == .serverBehind || forecast.isStale(at: context.date) {
                            Label(store.forecastFailureConfirmed
                                  ? String(format: NSLocalizedString("RADAR_DETAILS_UPDATE_FAILED", value: "Aktualisierung fehlgeschlagen. Letzte gültige Prognose, %@. Sie ist nicht aktuell bestätigt.", comment: "Radar"), forecast.ageDescription(at: context.date))
                                  : store.forecastStatus(now: context.date) == .serverBehind
                                  ? String(format: NSLocalizedString("RADAR_DETAILS_SERVER_BEHIND", value: "Der Wetterdienst hat noch keinen neueren Stand als diese Prognose, %@. Die App fragt weiter nach.", comment: "Radar"), forecast.ageDescription(at: context.date))
                                  : NSLocalizedString("RADAR_DETAILS_NOT_CONFIRMED", value: "Die Prognose ist nicht aktuell bestätigt.", comment: "Radar"), systemImage: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                        }
                        ForecastInterpretationSection(forecast: forecast, hasCurrentError: store.forecastFailureConfirmed)
                        Text(NSLocalizedString("RADAR_MAP_HINT_SENTENCE", value: "Lange auf die Karte drücken, um einen Ort zu wählen.", comment: "Radar"))
                        Text(NSLocalizedString("RADAR_DETAILS_DISCLAIMER", value: "Radarprognosen beschreiben die erwartete Entwicklung. Gerade bei entstehenden oder sich auflösenden Schauern können Beginn, Ende und Intensität abweichen.", comment: "Radar"))
                        Text(String(format: NSLocalizedString("RADAR_DETAILS_MODIFICATION", value: "%@. Niederschlagswerte der Ortsprognose umgerechnet und aufbereitet.", comment: "Radar"), store.radarAttribution.modificationNotice))
                            .font(.footnote).foregroundStyle(.secondary)
                    } else {
                        ContentUnavailableView(NSLocalizedString("RADAR_DETAILS_EMPTY_TITLE", value: "Keine Ortsprognose", comment: "Radar"), systemImage: "cloud.rain", description: Text(store.forecastError ?? NSLocalizedString("RADAR_DETAILS_EMPTY_HINT", value: "Bitte Wetterdaten aktualisieren.", comment: "Radar")))
                    }
                }.padding(24)
            }
            }
            .navigationTitle(store.selectedPlace.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(NSLocalizedString("COMMON_DONE", value: "Fertig", comment: "Common")) { dismiss() } } }
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
    /// Zoom source for a sheet: one uniform shell for places, warnings and info. Always applied as the outermost modifier on the
    /// `Button` itself, with its own plain style, outside any `GlassEffectContainer`, with a constant id; never in an if/else branch.
    fileprivate func glassSheetSource(_ sheet: RadarScreen.Sheet, in namespace: Namespace.ID) -> some View {
        buttonStyle(.plain).matchedTransitionSource(id: sheet.rawValue, in: namespace)
    }

    /// Interactive Liquid Glass for a touchable control (press and bounce feedback); the whole shape is the touch target.
    func glassControl<S: Shape>(_ shape: S, floor: Double = 0) -> some View {
        contentShape(shape).readableGlass(shape, interactive: true, floor: floor)
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

/// Which side of "Now" a slot is on ("Now" itself counts as future, so crossing fires exactly once); a change between two sides marks the firm haptic tap.
enum TimelineNowCrossing: Equatable {
    case past, future
    static func side(index: Int, nowIndex: Int?) -> TimelineNowCrossing {
        guard let nowIndex else { return .past }
        return index < nowIndex ? .past : .future
    }
}
