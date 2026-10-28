import Charts
import SwiftUI

struct RadarScreen: View {
    @Bindable var store: WeatherStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var sheet: Sheet?
    @State private var showSave = false
    @State private var placeName = ""
    @State private var tileFailed = false
    @State private var displayNow = Date()
    @State private var mapBottomInset: CGFloat = 300

    private enum Sheet: String, Identifiable {
        case places, details, information
        var id: String { rawValue }
    }

    var body: some View {
        ZStack(alignment: .top) {
            RadarMap(place: store.selectedPlace, date: store.frameDate,
                     referenceTime: store.frameReference, centerRevision: store.centerRevision,
                     reloadRevision: store.radarReloadRevision,
                     bottomInset: mapBottomInset,
                     onSelect: { store.selectMapPoint(latitude: $0.latitude, longitude: $0.longitude) },
                     onTileError: { tileFailed = true })
                .ignoresSafeArea()
                .accessibilityLabel("Regenradar für \(store.selectedPlace.name)")
            VStack(spacing: 10) {
                header
                if let message = statusMessage {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                        .accessibilityAddTraits(.updatesFrequently)
                }
                HStack {
                    Spacer()
                    VStack(spacing: 14) {
                        Button { store.requestLocation() } label: {
                            Image(systemName: "location.fill").frame(width: 46, height: 46)
                        }.accessibilityLabel("Aktuellen Standort verwenden")
                        Button { sheet = .information } label: {
                            Image(systemName: "info.circle").frame(width: 46, height: 46)
                        }.accessibilityLabel("Datenquellen und Datenschutz")
                    }
                    .background(.regularMaterial, in: Capsule())
                    .buttonStyle(.plain)
                    .font(.title3)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 12) {
                timeline
                forecastCard
            }
            .padding(16)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { mapBottomInset = $0 }
            .background(.regularMaterial, in: UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28))
        }
        .sheet(item: $sheet) { item in
            switch item {
            case .places: PlacesSheet(store: store)
            case .details: ForecastDetails(store: store)
            case .information: InformationSheet()
            }
        }
        .alert("Ort speichern", isPresented: $showSave) {
            TextField("Name", text: $placeName)
            Button("Speichern") { store.saveSelection(name: placeName) }
            Button("Abbrechen", role: .cancel) { }
        } message: { Text("Name und Koordinaten werden nur auf diesem Gerät gespeichert.") }
        .task(id: store.isPlaying) {
            guard store.isPlaying else { return }
            while !Task.isCancelled {
                do { try await Task.sleep(for: .milliseconds(reduceMotion ? 3000 : 2000)) }
                catch { return }
                guard let timeline = store.timeline, !timeline.dates.isEmpty else { return }
                store.selectedFrame = (store.selectedFrame + 1) % timeline.dates.count
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
        .onChange(of: store.timeline?.referenceTime) { _, _ in tileFailed = false }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button { sheet = .places } label: {
                HStack(spacing: 10) {
                    Image(systemName: "cloud.rain.fill").font(.title2).foregroundStyle(.cyan)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.selectedPlace.name).font(.headline).lineLimit(1)
                        Text("Regenradar").font(.caption).foregroundStyle(.secondary)
                    }
                    Image(systemName: "chevron.down").font(.caption.bold())
                }
                .padding(.horizontal, 16).padding(.vertical, 11)
                .background(.regularMaterial, in: Capsule())
            }.buttonStyle(.plain).accessibilityLabel("Ort auswählen: \(store.selectedPlace.name)")
            Spacer(minLength: 0)
            Button {
                store.isPlaying = false
                tileFailed = false
                Task { await store.refresh() }
            } label: {
                Group {
                    if store.isLoading { ProgressView() }
                    else { Image(systemName: "arrow.clockwise") }
                }.frame(width: 46, height: 46)
                    .background(.regularMaterial, in: Circle())
            }.buttonStyle(.plain).disabled(store.isLoading).accessibilityLabel("Wetterdaten aktualisieren")
        }
    }

    private var timeline: some View {
        VStack(spacing: 8) {
            HStack {
                Button { store.isPlaying.toggle() } label: {
                    Image(systemName: store.isPlaying ? "pause.fill" : "play.fill")
                        .frame(width: 42, height: 42)
                        .background(.quaternary, in: Circle())
                }
                .disabled(store.timeline == nil)
                .accessibilityLabel(store.isPlaying ? "Animation pausieren" : "Radaranimation starten")
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(store.isForecastFrame ? "VORHERSAGE" : "MESSUNG")
                            .foregroundStyle(store.isForecastFrame ? .orange : .cyan)
                        if let date = store.frameDate { Text(date, style: .time).foregroundStyle(.primary) }
                    }.font(.caption.bold()).monospacedDigit()
                    if let reference = store.timeline?.referenceTime {
                        Text("DWD · Lauf \(reference.formatted(date: .omitted, time: .shortened)) · \(age(reference))")
                            .font(.caption2).foregroundStyle(.secondary)
                    } else {
                        Text("Daten: Deutscher Wetterdienst").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if store.timeline != nil {
                    Button("Jetzt") {
                        store.isPlaying = false
                        store.selectedFrame = store.timeline?.dates.firstIndex(of: store.timeline!.referenceTime) ?? 0
                    }.font(.subheadline.bold())
                }
            }
            if let timeline = store.timeline, timeline.dates.count > 1 {
                Slider(value: Binding(get: { Double(store.selectedFrame) }, set: {
                    store.isPlaying = false
                    store.selectedFrame = Int($0)
                }), in: 0...Double(timeline.dates.count - 1), step: 1)
                .accessibilityLabel("Radarzeitpunkt")
                .accessibilityValue(store.frameDate?.formatted(date: .omitted, time: .shortened) ?? "Unbekannt")
                GeometryReader { geometry in
                    let boundary = Double(timeline.dates.firstIndex(of: timeline.referenceTime) ?? 0) / Double(timeline.dates.count - 1)
                    HStack(spacing: 0) {
                        Color.cyan.frame(width: geometry.size.width * boundary)
                        Color.orange
                    }.clipShape(Capsule())
                    Rectangle().fill(.primary).frame(width: 2, height: 9)
                        .offset(x: max(0, geometry.size.width * boundary - 1), y: -3)
                }.frame(height: 3).accessibilityLabel("Grenze zwischen Messung und Vorhersage")
                HStack {
                    Text(timeline.dates.first!, style: .time)
                    Spacer()
                    Text("Messung · Vorhersage").foregroundStyle(.secondary)
                    Spacer()
                    Text(timeline.dates.last!, style: .time)
                }.font(.caption2).monospacedDigit()
            } else {
                Text(store.isLoading ? "Radar wird geladen …" : "Keine Radarzeitpunkte verfügbar")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var forecastCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Button { sheet = .details } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(forecastHeadline).font(.headline).foregroundStyle(.primary)
                        if let forecast = store.forecast {
                            TimelineView(.periodic(from: .now, by: 60)) { _ in
                                Text("Datenstand \(forecast.referenceTime.formatted(date: .omitted, time: .shortened)) · \(age(forecast.referenceTime))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        } else {
                            Text("Kurzfristige Ortsprognose").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }.buttonStyle(.plain).accessibilityHint("Öffnet den Niederschlagsverlauf")
                Button {
                    placeName = store.selectedPlace.name
                    showSave = true
                } label: {
                    Image(systemName: store.places.contains(where: { $0.id == store.selectedPlace.id }) ? "bookmark.fill" : "bookmark")
                        .frame(width: 40, height: 40)
                }.accessibilityLabel("Ausgewählten Ort speichern oder umbenennen")
            }
            if let forecast = store.forecast {
                RainChart(forecast: forecast, compact: true).frame(height: 54)
                    .onTapGesture { sheet = .details }
            }
            Text("Vorhersagen können abweichen. Lange auf die Karte drücken, um einen Ort zu wählen.")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    private var forecastHeadline: String {
        guard let forecast = store.forecast else {
            return store.isLoading ? "Regenprognose wird geladen …" : "Prognose nicht verfügbar"
        }
        if store.forecastError != nil || forecast.isStale(at: displayNow) {
            return "Ältere Prognose · bitte aktualisieren"
        }
        return forecast.summary(at: displayNow)
    }

    private var statusMessage: String? {
        if let message = store.locationMessage { return message }
        if let message = store.storageMessage { return message }
        if tileFailed { return "Radarkacheln konnten nicht vollständig geladen werden. Bitte aktualisieren." }
        if let error = store.radarError { return "Radar: \(error)" }
        if let error = store.forecastError { return "Ortsprognose: \(error)" }
        return nil
    }

    private func age(_ date: Date) -> String {
        let minutes = max(0, Int(Date().timeIntervalSince(date) / 60))
        return minutes == 0 ? "gerade aktualisiert" : "vor \(minutes) Min."
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
                        if store.forecastError != nil || forecast.isStale(at: context.date) {
                            Label("Die Prognose ist nicht aktuell bestätigt.", systemImage: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                        }
                        Text("Radarprognosen beschreiben die erwartete Entwicklung. Gerade bei entstehenden oder sich auflösenden Schauern können Beginn, Ende und Intensität abweichen.")
                        Text("Datenbasis: Deutscher Wetterdienst. Niederschlagswerte umgerechnet und als Ortsprognose aufbereitet.")
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
