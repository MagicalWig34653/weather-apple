import MapKit
import SwiftUI
import UIKit

enum RegionText {
    static let explanation = "ShowerNow meldet dir per Mitteilung, wenn Regen diese Region erreicht. Dafür gehen an den ShowerNow-Server: das Gerätetoken, der Mittelpunkt gröber als eine Rasterzelle (etwa 2 km, keine Koordinaten), der Radius, Schwelle, Auslöseanteil und Vorlaufzeit; kein Konto, kein Name. Danach fragt iOS, ob Mitteilungen erlaubt sind."
    static let privacyFootnote = "An den Server gehen: das Gerätetoken, eine zufällige Installations-Kennung, der Mittelpunkt gröber als eine Rasterzelle (etwa 2 km), der Radius sowie Schwelle, Auslöseanteil und Vorlaufzeit. Keine Koordinaten, kein Name, kein Konto. Der Name der Region bleibt auf diesem Gerät."
    static let unsupported = "Server unterstützt noch keine Regionen."
    static let unknown = "Ob der Server Regionen unterstützt, konnte nicht geprüft werden."

    static func shareTitle(_ percent: Int) -> String {
        switch percent {
        case 1: "Vereinzelt (ab 1 %)"
        case 25: "Flächig (ab 25 %)"
        default: "Verbreitet (ab 10 %)"
        }
    }

    static func title(_ region: RegionPushSettings) -> String { region.name ?? "Umkreis \(region.radiusKm) km" }
    static func detail(_ region: RegionPushSettings) -> String {
        "Umkreis \(region.radiusKm) km · ab \(region.sharePercent) % der Fläche"
    }
}

/// Circle on a map around the (rounded) center. The preview shows what the server evaluates.
struct RegionPreviewMap: View {
    let latitude: Double
    let longitude: Double
    let radiusKm: Int
    @State private var position: MapCameraPosition = .automatic

    private var center: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }

    var body: some View {
        Map(position: $position, interactionModes: []) {
            MapCircle(center: center, radius: Double(radiusKm) * 1000)
                .foregroundStyle(.blue.opacity(0.22))
                .stroke(.blue, lineWidth: 2)
            Marker("", systemImage: "scope", coordinate: center).tint(.blue)
        }
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear { fit() }
        .onChange(of: radiusKm) { fit() }
        .onChange(of: latitude) { fit() }
        .onChange(of: longitude) { fit() }
        .accessibilityElement()
        .accessibilityLabel("Kartenvorschau: Umkreis \(radiusKm) Kilometer")
        .accessibilityIdentifier("region-preview")
    }

    private func fit() {
        position = .region(MKCoordinateRegion(center: center, latitudinalMeters: Double(radiusKm) * 2600, longitudinalMeters: Double(radiusKm) * 2600))
    }
}

/// Status of the server capability, shown wherever a region can be created.
struct RegionSupportNote: View {
    let support: PushRegionSupport
    var body: some View {
        switch support {
        case .supported: EmptyView()
        case .unsupported:
            Label(RegionText.unsupported, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                .accessibilityIdentifier("region-unsupported")
        case .unknown:
            Label(RegionText.unknown, systemImage: "wifi.exclamationmark").foregroundStyle(.orange)
                .accessibilityIdentifier("region-unknown")
        }
    }
}

/// Create a region: center (map selection or saved place), radius preset, trigger share, optional local name.
struct RegionCreateView: View {
    @Bindable var store: WeatherStore
    @Environment(PushManager.self) private var push
    @Environment(\.dismiss) private var dismiss
    @State private var centerID: UUID?
    @State private var radiusKm = 10
    @State private var share = PushGrid.defaultRegionSharePercent
    @State private var name = ""
    @State private var confirm = false
    @State private var working = false
    @State private var failure: String?
    @State private var sitePage: SitePage?

    private var candidates: [SavedPlace] {
        var list = [store.selectedPlace]
        list += store.places.filter { $0.id != store.selectedPlace.id }
        return list
    }
    private var center: SavedPlace { candidates.first { $0.id == centerID } ?? store.selectedPlace }
    private var coarse: (latitude: Double, longitude: Double)? {
        PushGrid.cell(latitude: center.coordinate.latitude, longitude: center.coordinate.longitude)
            .map { PushGrid.coordinate(of: PushGrid.coarseCenter(of: $0)) }
    }

    var body: some View {
        List {
            Section {
                if let coarse {
                    RegionPreviewMap(latitude: coarse.latitude, longitude: coarse.longitude, radiusKm: radiusKm)
                        .listRowInsets(EdgeInsets())
                } else {
                    Label("Dieser Mittelpunkt liegt außerhalb des Radargebiets.", systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                }
            } footer: { Text("Der Kreis zeigt den überwachten Bereich. Der Mittelpunkt wird vor dem Senden auf etwa 2 km gerundet.") }

            Section("Mittelpunkt") {
                Picker("Mittelpunkt", selection: Binding(get: { center.id }, set: { centerID = $0 })) {
                    ForEach(candidates) { place in
                        Text(place.id == store.selectedPlace.id && !store.places.contains(place) ? "Kartenpunkt: \(place.name)" : place.name).tag(place.id)
                    }
                }
                .accessibilityIdentifier("region-center")
                Picker("Radius", selection: $radiusKm) {
                    ForEach(PushGrid.regionRadiusPresetsKm, id: \.self) { Text("\($0) km").tag($0) }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("region-radius")
                Picker("Auslöser", selection: $share) {
                    ForEach(PushGrid.regionSharePercents, id: \.self) { Text(RegionText.shareTitle($0)).tag($0) }
                }
                TextField("Name (optional, nur auf diesem Gerät)", text: $name)
                    .accessibilityIdentifier("region-name")
            }

            Section {
                RegionSupportNote(support: push.regionSupport)
                if let failure { Label(failure, systemImage: "exclamationmark.triangle").foregroundStyle(.orange) }
                if !push.canAddRegion {
                    Label("Es sind höchstens \(PushGrid.maxRegions) Regionen möglich.", systemImage: "info.circle").foregroundStyle(.secondary)
                }
                Button {
                    confirm = true
                } label: {
                    HStack { Text("Region hinzufügen"); if working { Spacer(); ProgressView() } }
                }
                .disabled(working || coarse == nil || push.regionSupport != .supported || !push.canAddRegion)
                .accessibilityIdentifier("region-add")
            } footer: { Text("Du bekommst eine Mitteilung, wenn Regen diese Region erreicht, sobald der gewählte Anteil der Fläche betroffen ist.") }
            .font(.footnote)

            Section {
                Text(RegionText.privacyFootnote)
                SitePageButton(page: .privacy, selection: $sitePage)
            }
            .font(.footnote).foregroundStyle(.secondary)
        }
        .navigationTitle("Neue Region")
        .navigationBarTitleDisplayMode(.inline)
        .task { await push.refreshRegionSupport() }
        .sitePageSheet($sitePage)
        .alert("Regenhinweis für Region aktivieren?", isPresented: $confirm) {
            Button("Weiter") { Task { await add() } }
            Button("Datenschutzerklärung lesen") { sitePage = .privacy }
            Button("Abbrechen", role: .cancel) {}
        } message: { Text(RegionText.explanation) }
    }

    private func add() async {
        working = true; failure = nil
        let result = await push.addRegion(latitude: center.coordinate.latitude, longitude: center.coordinate.longitude,
                                          radiusKm: radiusKm, sharePercent: share, name: name)
        working = false
        switch result {
        case .added: dismiss()
        case .failed(let message): failure = message
        }
    }
}

/// Edit or delete a region. Deleting is the opt-out (the server subscription is deleted).
struct RegionSettingsView: View {
    let regionID: UUID
    @Environment(PushManager.self) private var push
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var name = ""
    @State private var confirmDelete = false
    @State private var sitePage: SitePage?

    var body: some View {
        List {
            if let region = push.region(for: regionID) {
                Section {
                    let coordinate = PushGrid.coordinate(of: region.center)
                    RegionPreviewMap(latitude: coordinate.latitude, longitude: coordinate.longitude, radiusKm: region.radiusKm)
                        .listRowInsets(EdgeInsets())
                    Toggle("Regenhinweis", isOn: Binding(get: { true }, set: { if !$0 { confirmDelete = true } }))
                        .accessibilityIdentifier("region-toggle")
                    status(region)
                } header: { Text(RegionText.title(region)) }
                footer: { Text("Du bekommst eine Mitteilung, wenn Regen diese Region erreicht. Ausschalten löscht die Region und ihre Registrierung auf dem Server.") }

                Section {
                    TextField("Name (optional, nur auf diesem Gerät)", text: $name)
                        .onSubmit { Task { await push.updateRegion(id: regionID, name: name) } }
                    Picker("Radius", selection: Binding(get: { region.radiusKm },
                                                        set: { v in Task { await push.updateRegion(id: regionID, radiusKm: v) } })) {
                        ForEach(PushGrid.regionRadiusPresetsKm, id: \.self) { Text("\($0) km").tag($0) }
                    }
                    Picker("Auslöser", selection: Binding(get: { region.sharePercent },
                                                          set: { v in Task { await push.updateRegion(id: regionID, sharePercent: v) } })) {
                        ForEach(PushGrid.regionSharePercents, id: \.self) { Text(RegionText.shareTitle($0)).tag($0) }
                    }
                    Picker("Vorlaufzeit", selection: Binding(get: { region.leadMinutes },
                                                             set: { v in Task { await push.updateRegion(id: regionID, leadMinutes: v) } })) {
                        ForEach(PushLead.options, id: \.self) { Text("\($0) Minuten").tag($0) }
                    }
                    Picker("Empfindlichkeit", selection: Binding(get: { region.sensitivity },
                                                                 set: { v in Task { await push.updateRegion(id: regionID, sensitivity: v) } })) {
                        ForEach(PushSensitivity.allCases) { Text("\($0.title) (\($0.detail))").tag($0) }
                    }
                    Toggle("Zeitkritisch", isOn: Binding(get: { region.timeSensitive },
                                                         set: { v in Task { await push.updateRegion(id: regionID, timeSensitive: v) } }))
                } header: { Text("Einstellungen") } footer: {
                    Text("Meldung, sobald der gewählte Anteil der Fläche innerhalb der Vorlaufzeit mindestens so stark Regen bekommt. Danach höchstens eine Meldung pro Stunde und Region. Zeitkritisch durchbricht Fokus und Mitteilungszusammenfassung, nicht den Stummschalter.")
                }

                if push.authorization == .denied {
                    Section {
                        Button("Systemeinstellungen öffnen") {
                            if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                        }
                    } footer: { Text("Mitteilungen sind für ShowerNow im System ausgeschaltet.") }
                }

                Section {
                    Text(RegionText.privacyFootnote)
                    SitePageButton(page: .privacy, selection: $sitePage)
                }
                .font(.footnote).foregroundStyle(.secondary)

                Section {
                    Button("Region löschen", role: .destructive) { confirmDelete = true }
                        .accessibilityIdentifier("region-delete")
                }
            }
        }
        .navigationTitle("Region")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { name = push.region(for: regionID)?.name ?? "" }
        .onDisappear { Task { await push.updateRegion(id: regionID, name: name) } }
        .sitePageSheet($sitePage)
        .confirmationDialog("Region löschen?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Löschen", role: .destructive) {
                Task { await push.removeRegion(id: regionID); dismiss() }
            }
            Button("Abbrechen", role: .cancel) {}
        } message: { Text("Der Regenhinweis wird ausgeschaltet und auf dem Server gelöscht.") }
    }

    @ViewBuilder private func status(_ region: RegionPushSettings) -> some View {
        if let message = push.messages[regionID] {
            VStack(alignment: .leading, spacing: 6) {
                Label(message, systemImage: "exclamationmark.triangle").font(.footnote).foregroundStyle(.orange)
                Button("Jetzt erneut versuchen") { Task { await push.start() } }.font(.footnote)
            }
        } else {
            let active = push.regionStatus(for: regionID) == .active
            Label(active ? "Aktiv" : "Wird eingerichtet …", systemImage: active ? "checkmark.circle" : "clock")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }
}
