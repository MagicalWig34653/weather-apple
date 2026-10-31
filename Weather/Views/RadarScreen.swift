import Charts
import SwiftUI

struct RadarScreen: View {
    @Bindable var store: WeatherStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var sheet: Sheet?
    @State private var showSave = false
    @State private var placeName = ""
    @State private var radarLoadState: RadarLoadState?
    @State private var refreshTapFeedback = false
    @State private var displayNow = Date()
    /// Slot index under the finger while scrubbing; drives thumb and time label independent of tile loading.
    @State private var scrubIndex: Int?
    /// Fine-scrubbing stage while the finger is down (`nil` when not dragging).
    @State private var scrubStage: ScrubStage?
    @State private var mapBottomInset: CGFloat = 70

    private enum Sheet: String, Identifiable {
        case places, details, information
        var id: String { rawValue }
    }

    var body: some View {
        ZStack(alignment: .top) {
            RadarMap(place: store.selectedPlace, date: store.frameDate,
                     referenceTime: store.frameReference, centerRevision: store.centerRevision,
                     reloadRevision: store.radarReloadRevision,
                     timeline: store.timeline, prefetchActive: scenePhase == .active && !store.isPlaying,
                     bottomInset: mapBottomInset,
                     onSelect: { store.selectMapPoint(latitude: $0.latitude, longitude: $0.longitude) },
                     onBackendFailure: { loaded in if loaded == 0 { store.backendImagesUnavailable() } },
                     onLoadState: { state in
                         guard state.frameDate == store.frameDate, state.referenceTime == store.frameReference,
                               state.reloadRevision == store.radarReloadRevision else { return }
                         radarLoadState = state
                         store.acceptRadarLoadState(state)
                     })
                .ignoresSafeArea()
                .accessibilityLabel("Regenradar für \(store.selectedPlace.name)")
                .accessibilityHint("Lange auf die Karte drücken, um einen Ort zu wählen")
            VStack(spacing: 6) {
                Spacer()
                if let label = scrubStage?.label {
                    Label(label, systemImage: "slider.horizontal.3")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(.regularMaterial, in: Capsule())
                        .accessibilityHidden(true)
                }
                if let slot = slotFeedback {
                    Label(slot.text, systemImage: slot.failed ? "exclamationmark.triangle.fill" : "clock.arrow.circlepath")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(.regularMaterial, in: Capsule())
                        .accessibilityIdentifier("radar-slot-status")
                }
                if store.timeline != nil {
                    Text("\(store.radarAttribution.attribution) · \(store.radarSource.label)"
                         + (store.historyStatus == .unavailable && store.radarSource == .cache ? " · Historie nicht verfügbar" : ""))
                        .font(.caption2).foregroundStyle(.secondary)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(.thinMaterial, in: Capsule())
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
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                        .accessibilityAddTraits(.updatesFrequently)
                }
                HStack {
                    Spacer()
                    VStack(spacing: 14) {
                        Button { store.requestLocation() } label: {
                            Image(systemName: "location.fill").font(.system(size: 20)).frame(width: 46, height: 46)
                        }.accessibilityLabel("Aktuellen Standort verwenden")
                        Button { sheet = .information } label: {
                            Image(systemName: "info.circle").font(.system(size: 20)).frame(width: 46, height: 46)
                        }.accessibilityLabel("Datenquellen und Datenschutz")
                    }
                    .glassEffect(.regular, in: Capsule())
                    .buttonStyle(.plain)
                    .font(.title3)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
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
            }
        }
        .alert("Ort speichern", isPresented: $showSave) {
            TextField("Name", text: $placeName)
            Button("Speichern") { store.saveSelection(name: placeName) }
            Button("Abbrechen", role: .cancel) { }
        } message: { Text("Name und Koordinaten werden nur auf diesem Gerät gespeichert.") }
        .task(id: store.isPlaying) {
            guard store.isPlaying else { return }
            // Playback covers only a window (at most 3 h of past); start there if the slider is further back.
            if let timeline = store.timeline {
                let start = PlaybackWindow.startIndex(dates: timeline.dates, reference: timeline.referenceTime, pastHours: store.pastHours)
                if store.selectedFrame < start { store.selectedFrame = start }
            }
            var waitingFrame = store.frameDate
            var waitingSince = Date()
            while !Task.isCancelled {
                do { try await Task.sleep(for: .milliseconds(reduceMotion ? 3000 : 2000)) }
                catch { return }
                guard let timeline = store.timeline, !timeline.dates.isEmpty else { return }
                if waitingFrame != store.frameDate {
                    waitingFrame = store.frameDate
                    waitingSince = Date()
                }
                if let load = currentRadarLoadState, load.shouldStopPlayback {
                    store.isPlaying = false
                    return
                }
                // Wait for actual requests, but keep offline/no-event frames from stalling playback forever.
                let frameFinished = currentRadarLoadState.map { $0.requested > 0 && $0.pending == 0 } ?? false
                guard frameFinished || Date().timeIntervalSince(waitingSince) >= 12 else { continue }
                store.selectedFrame = PlaybackWindow.nextIndex(after: store.selectedFrame, dates: timeline.dates,
                                                               reference: timeline.referenceTime, pastHours: store.pastHours)
                waitingFrame = store.frameDate
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
        .onChange(of: sheet) { _, value in
            if value != nil { store.isPlaying = false }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { store.isPlaying = false }
        }
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
                .glassEffect(.regular, in: Capsule())
            }.buttonStyle(.plain).accessibilityLabel("Ort auswählen: \(store.selectedPlace.name)")
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
            refreshControl

        }
    }

    private var currentRadarLoadState: RadarLoadState? {
        guard let state = radarLoadState,
              state.frameDate == store.frameDate,
              state.referenceTime == store.frameReference,
              state.reloadRevision == store.radarReloadRevision else { return nil }
        return state
    }

    /// Slot shown by thumb and label: the scrub position wins over the store while dragging.
    private var displayedIndex: Int { scrubIndex ?? store.selectedFrame }

    private var displayedDate: Date? {
        guard let dates = store.timeline?.dates, dates.indices.contains(displayedIndex) else { return store.frameDate }
        return dates[displayedIndex]
    }

    /// Honest per-slot hint: the map never shows another slot's image as this slot's state.
    private var slotFeedback: (text: String, failed: Bool)? {
        guard store.timeline != nil, !store.isPlaying, let date = displayedDate else { return nil }
        let time = date.formatted(date: .omitted, time: .shortened)
        switch TimelineSlot.status(for: currentRadarLoadState) {
        case .ready: return nil
        case .loading: return ("Radar für \(time) lädt …", false)
        case .failed: return ("Radar für \(time) nicht geladen", true)
        }
    }

    private var radarIsLoading: Bool {
        if store.isRadarLoading { return true }
        if let state = currentRadarLoadState { return !state.isSettled }
        return refreshTapFeedback || (store.radarError == nil && store.timeline != nil)
    }

    private var refreshAccessibilityStatus: String {
        if store.isRadarLoading { return "Radar-Datenstand wird aktualisiert" }
        if refreshTapFeedback && currentRadarLoadState == nil { return "Radar wird aktualisiert" }
        if let error = store.radarError { return "Radar konnte nicht aktualisiert werden: \(error). Erneut versuchen." }
        guard let state = currentRadarLoadState else { return "Radar wartet auf Kartendaten" }
        let bytes = ByteCountFormatter.string(fromByteCount: state.receivedBodyBytes, countStyle: .file)
        let prefetched = ByteCountFormatter.string(fromByteCount: state.prefetchedBodyBytes, countStyle: .file)
        let preloadStatus = " Vorladen in dieser Sitzung: \(prefetched)."
        if state.failed > 0 { return "\(state.failed) Radarkacheln fehlen, \(state.succeeded) geladen. \(bytes) empfangen. Erneut versuchen." }
        if state.pending > 0 { return "Radar lädt. \(state.succeeded) Kacheln empfangen, \(state.pending) Anfragen offen. \(bytes) empfangen." }
        if state.requested == 0 && state.isViewportIdle { return "Für diesen Kartenausschnitt wurden keine neuen Radarkacheln angefordert." }
        if state.requested == 0 { return "Radar wartet auf Kachelanfragen" }
        let pointStatus = store.isForecastLoading ? "lädt noch" : store.forecastError != nil ? "nicht aktualisiert" : store.forecast != nil ? "verfügbar" : "nicht verfügbar"
        let cacheStatus = state.receivedBodyBytes == 0 && state.cacheHits > 0 && state.cacheHits == state.succeeded ? " Aus dem Zwischenspeicher, kein neuer Radar-Download." : " \(bytes) empfangen."
        return "\(state.succeeded) angeforderte Radarkacheln geladen.\(cacheStatus) Ortsprognose \(pointStatus)." + preloadStatus
    }

    private var radarTransferLabel: String {
        guard let state = currentRadarLoadState else { return "Radar" }
        if state.prefetchedBodyBytes > 0 {
            let total = ByteCountFormatter.string(fromByteCount: state.prefetchedBodyBytes, countStyle: .file)
            return "Radar · Vorladen \(total)"
        }
        if state.isSettled && state.failed == 0 && state.cacheHits > 0 && state.cacheHits == state.succeeded && state.receivedBodyBytes == 0 { return "Radar · Cache" }
        guard state.receivedBodyBytes > 0 else { return "Radar" }
        if state.receivedBodyBytes < 100_000 {
            let kilobytes = Double(state.receivedBodyBytes) / 1_000
            return "Radar · \(kilobytes.formatted(.number.precision(.fractionLength(1)))) kB"
        }
        let megabytes = Double(state.receivedBodyBytes) / 1_000_000
        return "Radar · \(megabytes.formatted(.number.precision(.fractionLength(1)))) MB"
    }

    private var refreshControl: some View {
        Button {
            store.isPlaying = false
            radarLoadState = nil
            refreshTapFeedback = true
            Task { await store.refresh() }
            // Keep immediate tap acknowledgement visible even when all metadata is cached.
            Task {
                try? await Task.sleep(for: .milliseconds(600))
                refreshTapFeedback = false
            }
        } label: {
            HStack(spacing: 5) {
                Text(radarTransferLabel)
                    .font(.caption.weight(.medium))
                    .fixedSize(horizontal: true, vertical: true)
                ZStack {
                    if radarIsLoading {
                        if reduceMotion {
                            Image(systemName: "arrow.down.circle").font(.system(size: 18))
                        } else {
                            ProgressView().controlSize(.small)
                        }
                    } else {
                        Image(systemName: (currentRadarLoadState?.failed ?? 0) > 0 || store.radarError != nil ? "exclamationmark.arrow.circlepath" : currentRadarLoadState?.isSettled == true && (currentRadarLoadState?.succeeded ?? 0) > 0 ? "checkmark" : "arrow.clockwise")
                            .font(.system(size: 18))
                    }
                }
                .frame(width: 28, height: 28)
                .overlay { Circle().strokeBorder(.secondary.opacity(0.35), lineWidth: 1) }
            }
            .padding(.horizontal, 10)
            .frame(minHeight: 44)
            .glassEffect(.regular.interactive(), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(refreshTapFeedback || store.isRadarLoading)
        .accessibilityLabel("Wetterdaten aktualisieren")
        .accessibilityValue(refreshAccessibilityStatus)
        .accessibilityHint("Empfangene Datenmenge nur für Radarbilder dieses Karten-Ladevorgangs; ohne Grundkarte und Ortsprognose")
        .accessibilityIdentifier("radar-refresh")
    }

    private var timeline: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 4) {
                    frameLabel
                    HStack(spacing: 12) {
                        playButton
                        timeSlider
                        nowButton
                    }
                }
            } else {
                HStack(spacing: 8) {
                    playButton
                    timeSlider
                    frameLabel
                    nowButton
                }
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
        .buttonStyle(.plain)
        .disabled(store.timeline == nil)
        .accessibilityLabel(store.isPlaying ? "Animation pausieren" : "Radaranimation starten")
    }

    private var displayedIsForecast: Bool {
        guard let date = displayedDate, let timeline = store.timeline else { return false }
        return date > timeline.referenceTime
    }

    private var frameLabel: some View {
        VStack(spacing: 0) {
            if let date = displayedDate {
                Text(date, style: .time).font(.subheadline.weight(.semibold)).monospacedDigit()
                if let day = otherDayLabel(for: date) {
                    Text(day).font(.caption2).foregroundStyle(.secondary)
                }
            }
            Text(displayedIsForecast ? "Vorhersage" : "Messung")
                .font(.caption2.weight(.medium))
                .foregroundStyle(displayedIsForecast ? .orange : .cyan)
        }
        .fixedSize(horizontal: true, vertical: true)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("radar-frame-label")
    }

    /// With up to 48 hours of past the time alone is ambiguous: name the day when it is not the reference day.
    private func otherDayLabel(for date: Date) -> String? {
        guard let reference = store.timeline?.referenceTime,
              !Calendar.current.isDate(date, inSameDayAs: reference) else { return nil }
        return date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }

    @ViewBuilder private var nowButton: some View {
        if let timeline = store.timeline {
            Button {
                store.isPlaying = false
                store.selectedFrame = timeline.dates.firstIndex(of: timeline.referenceTime) ?? 0
            } label: {
                Text("Jetzt").font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: true, vertical: true)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder private var timeSlider: some View {
        if let timeline = store.timeline, timeline.dates.count > 1 {
            TimelineScrubSlider(count: timeline.dates.count, displayedIndex: displayedIndex, onScrub: { index in
                store.isPlaying = false
                if scrubIndex != index { scrubIndex = index }
                if store.selectedFrame != index { store.selectedFrame = index }
            }, onEnd: { scrubIndex = nil }, stage: $scrubStage)
            .sensoryFeedback(.selection, trigger: scrubIndex) { _, new in new != nil }
            .sensoryFeedback(.impact(weight: .light), trigger: scrubStage) { old, new in old != nil && new != nil }
            .overlay(alignment: .bottom) {
                GeometryReader { geometry in
                    let boundary = Double(timeline.dates.firstIndex(of: timeline.referenceTime) ?? 0) / Double(timeline.dates.count - 1)
                    HStack(spacing: 0) {
                        Color.cyan.frame(width: geometry.size.width * boundary)
                        Color.orange
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
                    if store.selectedFrame != index { store.selectedFrame = index }
                }), in: 0...Double(timeline.dates.count - 1), step: 1)
                .accessibilityLabel("Radarzeitpunkt")
                .accessibilityValue("\(displayedDate.map { otherDayLabel(for: $0).map { day in day + ", " } ?? "" } ?? "")\(displayedDate?.formatted(date: .omitted, time: .shortened) ?? "Unbekannt"), \(displayedIsForecast ? "Vorhersage" : "Messung")")
                .accessibilityHint("Von \(timeline.dates.first!.formatted(date: .abbreviated, time: .shortened)) bis \(timeline.dates.last!.formatted(date: .omitted, time: .shortened)). Beim Ziehen mit dem Finger nach oben vom Regler weg wird die Steuerung feiner.")
            }
        } else {
            Text(store.isLoading ? "Radar lädt …" : "Keine Radarzeiten")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
    }

    private var forecastCard: some View {
        HStack(spacing: 4) {
            Button { sheet = .details } label: {
                HStack(spacing: 6) {
                    Text(dynamicTypeSize.isAccessibilitySize ? "Prognosedetails" : forecastHeadline)
                        .font(.subheadline.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("forecast-details")
            .accessibilityHint("Öffnet Niederschlagsverlauf, Datenalter und Prognosehinweise")
            Button {
                placeName = store.selectedPlace.name
                showSave = true
            } label: {
                Image(systemName: store.places.contains(where: { $0.id == store.selectedPlace.id }) ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 20)).frame(width: 44, height: 44)
            }
            .accessibilityLabel("Ausgewählten Ort speichern oder umbenennen")
        }
        .padding(.leading, 14).padding(.trailing, 4)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22))
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
            return store.radarSource == .cache
                ? "Das Radarbild für diesen Zeitpunkt fehlt. Bitte erneut aktualisieren."
                : "Einige Radarkacheln fehlen. Bitte erneut aktualisieren."
        }
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
