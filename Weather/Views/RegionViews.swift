import MapKit
import SwiftUI
import UIKit

enum RegionText {
    static let explanation = NSLocalizedString("REGION_EXPLANATION", value: "Showers meldet dir per Mitteilung, wenn Regen diese Region erreicht. Dafür gehen an den Showers-Server: das Gerätetoken, der Mittelpunkt gröber als eine Rasterzelle (etwa 2 km, keine Koordinaten), der Radius, Schwelle, Auslöseanteil und Vorlaufzeit; kein Konto, kein Name. Danach fragt iOS, ob Mitteilungen erlaubt sind.", comment: NSLocalizedString("REGION_SETTINGS_TITLE", value: "Region", comment: "Region"))
    static let privacyFootnote = NSLocalizedString("REGION_PRIVACY_FOOTNOTE", value: "An den Server gehen: das Gerätetoken, eine zufällige Installations-Kennung, der Mittelpunkt gröber als eine Rasterzelle (etwa 2 km), der Radius sowie Schwelle, Auslöseanteil und Vorlaufzeit. Keine Koordinaten, kein Name, kein Konto. Der Name der Region bleibt auf diesem Gerät.", comment: NSLocalizedString("REGION_SETTINGS_TITLE", value: "Region", comment: "Region"))
    static let unsupported = NSLocalizedString("REGION_UNSUPPORTED", value: "Regionen sind derzeit nicht verfügbar.", comment: NSLocalizedString("REGION_SETTINGS_TITLE", value: "Region", comment: "Region"))
    static let unknown = NSLocalizedString("REGION_SUPPORT_UNKNOWN", value: "Ob der Server Regionen unterstützt, konnte nicht geprüft werden.", comment: NSLocalizedString("REGION_SETTINGS_TITLE", value: "Region", comment: "Region"))

    static func shareTitle(_ percent: Int) -> String {
        switch percent {
        case 1: NSLocalizedString("REGION_SHARE_1", value: "Vereinzelt (ab 1 %)", comment: NSLocalizedString("REGION_SETTINGS_TITLE", value: "Region", comment: "Region"))
        case 25: NSLocalizedString("REGION_SHARE_25", value: "Flächig (ab 25 %)", comment: NSLocalizedString("REGION_SETTINGS_TITLE", value: "Region", comment: "Region"))
        default: NSLocalizedString("REGION_SHARE_10", value: "Verbreitet (ab 10 %)", comment: NSLocalizedString("REGION_SETTINGS_TITLE", value: "Region", comment: "Region"))
        }
    }

    static func title(_ region: RegionPushSettings) -> String { region.name ?? String(format: NSLocalizedString("REGION_TITLE_RADIUS", value: "Umkreis %lld km", comment: NSLocalizedString("REGION_SETTINGS_TITLE", value: "Region", comment: "Region")), region.radiusKm) }
    static func detail(_ region: RegionPushSettings) -> String {
        String(format: NSLocalizedString("REGION_DETAIL", value: "Umkreis %1$lld km · ab %2$lld %% der Fläche", comment: NSLocalizedString("REGION_SETTINGS_TITLE", value: "Region", comment: "Region")), region.radiusKm, region.sharePercent)
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
        .accessibilityLabel(String(format: NSLocalizedString("REGION_PREVIEW_LABEL", value: "Kartenvorschau: Umkreis %lld Kilometer", comment: NSLocalizedString("REGION_SETTINGS_TITLE", value: "Region", comment: "Region")), radiusKm))
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
                    Label(NSLocalizedString("REGION_OUTSIDE", value: "Dieser Mittelpunkt liegt außerhalb des Radargebiets.", comment: NSLocalizedString("REGION_SETTINGS_TITLE", value: "Region", comment: "Region")), systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                }
            } footer: { Text(NSLocalizedString("REGION_PREVIEW_FOOTER", value: "Der Kreis zeigt den überwachten Bereich. Der Mittelpunkt wird vor dem Senden auf etwa 2 km gerundet.", comment: NSLocalizedString("REGION_SETTINGS_TITLE", value: "Region", comment: "Region"))) }

            Section(NSLocalizedString("REGION_CENTER", value: "Mittelpunkt", comment: NSLocalizedString("REGION_SETTINGS_TITLE", value: "Region", comment: "Region"))) {
                Picker(NSLocalizedString("REGION_CENTER", value: "Mittelpunkt", comment: NSLocalizedString("REGION_SETTINGS_TITLE", value: "Region", comment: "Region")), selection: Binding(get: { center.id }, set: { centerID = $0 })) {
                    ForEach(candidates) { place in
                        Text(place.id == store.selectedPlace.id && !store.places.contains(place) ? String(format: NSLocalizedString("REGION_CENTER_MAP_POINT", value: "Kartenpunkt: %@", comment: NSLocalizedString("REGION_SETTINGS_TITLE", value: "Region", comment: "Region")), place.name) : place.name).tag(place.id)
                    }
                }
                .accessibilityIdentifier("region-center")
                Picker(NSLocalizedString("REGION_RADIUS", value: "Radius", comment: NSLocalizedString("REGION_SETTINGS_TITLE", value: "Region", comment: "Region")), selection: $radiusKm) {
                    ForEach(PushGrid.regionRadiusPresetsKm, id: \.self) { Text(String(format: NSLocalizedString("REGION_RADIUS_KM", value: "%lld km", comment: NSLocalizedString("REGION_SETTINGS_TITLE", value: "Region", comment: "Region")), $0)).tag($0) }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("region-radius")
                Picker(NSLocalizedString("REGION_TRIGGER", value: "Auslöser", comment: NSLocalizedString("REGION_SETTINGS_TITLE", value: "Region", comment: "Region")), selection: $share) {
                    ForEach(PushGrid.regionSharePercents, id: \.self) { Text(RegionText.shareTitle($0)).tag($0) }
                }
                TextField(NSLocalizedString("REGION_NAME_FIELD", value: "Name (optional, nur auf diesem Gerät)", comment: NSLocalizedString("REGION_SETTINGS_TITLE", value: "Region", comment: "Region")), text: $name)
                    .accessibilityIdentifier("region-name")
            }

            Section {
                RegionSupportNote(support: push.regionSupport)
                if let failure { Label(failure, systemImage: "exclamationmark.triangle").foregroundStyle(.orange) }
                if !push.canAddRegion {
                    Label(String(format: NSLocalizedString("REGION_MAX_REACHED", value: "Es sind höchstens %lld Regionen möglich.", comment: NSLocalizedString("REGION_SETTINGS_TITLE", value: "Region", comment: "Region")), PushGrid.maxRegions), systemImage: "info.circle").foregroundStyle(.secondary)
                }
                Button {
                    confirm = true
                } label: {
                    HStack { Text(NSLocalizedString("REGION_ADD", value: "Region hinzufügen", comment: "Places")); if working { Spacer(); ProgressView() } }
                }
                .disabled(working || coarse == nil || push.regionSupport != .supported || !push.canAddRegion)
                .accessibilityIdentifier("region-add")
            } footer: { Text(NSLocalizedString("REGION_ADD_FOOTER", value: "Du bekommst eine Mitteilung, wenn Regen diese Region erreicht, sobald der gewählte Anteil der Fläche betroffen ist.", comment: NSLocalizedString("REGION_SETTINGS_TITLE", value: "Region", comment: "Region"))) }
            .font(.footnote)

            Section {
                Text(RegionText.privacyFootnote)
                SitePageButton(page: .privacy, selection: $sitePage)
            }
            .font(.footnote).foregroundStyle(.secondary)
        }
        .navigationTitle(NSLocalizedString("REGION_NEW_TITLE", value: "Neue Region", comment: NSLocalizedString("REGION_SETTINGS_TITLE", value: "Region", comment: "Region")))
        .navigationBarTitleDisplayMode(.inline)
        .task { await push.refreshRegionSupport() }
        .sitePageSheet($sitePage)
        .alert(NSLocalizedString("REGION_CONFIRM_TITLE", value: "Regenhinweis für Region aktivieren?", comment: NSLocalizedString("REGION_SETTINGS_TITLE", value: "Region", comment: "Region")), isPresented: $confirm) {
            Button(NSLocalizedString("PUSH_CONTINUE", value: "Weiter", comment: "Push")) { Task { await add() } }
            Button(NSLocalizedString("PUSH_READ_PRIVACY", value: "Datenschutzerklärung lesen", comment: "Push")) { sitePage = .privacy }
            Button(NSLocalizedString("COMMON_CANCEL", value: "Abbrechen", comment: "Common"), role: .cancel) {}
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
                    Toggle(NSLocalizedString("PUSH_ALERT_LABEL", value: "Regenhinweis", comment: "Push"), isOn: Binding(get: { true }, set: { if !$0 { confirmDelete = true } }))
                        .accessibilityIdentifier("region-toggle")
                    status(region)
                } header: { Text(RegionText.title(region)) }
                footer: { Text(NSLocalizedString("REGION_TOGGLE_FOOTER", value: "Du bekommst eine Mitteilung, wenn Regen diese Region erreicht. Ausschalten löscht die Region und ihre Registrierung auf dem Server.", comment: NSLocalizedString("REGION_SETTINGS_TITLE", value: "Region", comment: "Region"))) }

                Section {
                    TextField(NSLocalizedString("REGION_NAME_FIELD", value: "Name (optional, nur auf diesem Gerät)", comment: NSLocalizedString("REGION_SETTINGS_TITLE", value: "Region", comment: "Region")), text: $name)
                        .onSubmit { Task { await push.updateRegion(id: regionID, name: name) } }
                    Picker(NSLocalizedString("REGION_RADIUS", value: "Radius", comment: NSLocalizedString("REGION_SETTINGS_TITLE", value: "Region", comment: "Region")), selection: Binding(get: { region.radiusKm },
                                                        set: { v in Task { await push.updateRegion(id: regionID, radiusKm: v) } })) {
                        ForEach(PushGrid.regionRadiusPresetsKm, id: \.self) { Text(String(format: NSLocalizedString("REGION_RADIUS_KM", value: "%lld km", comment: NSLocalizedString("REGION_SETTINGS_TITLE", value: "Region", comment: "Region")), $0)).tag($0) }
                    }
                    Picker(NSLocalizedString("REGION_TRIGGER", value: "Auslöser", comment: NSLocalizedString("REGION_SETTINGS_TITLE", value: "Region", comment: "Region")), selection: Binding(get: { region.sharePercent },
                                                          set: { v in Task { await push.updateRegion(id: regionID, sharePercent: v) } })) {
                        ForEach(PushGrid.regionSharePercents, id: \.self) { Text(RegionText.shareTitle($0)).tag($0) }
                    }
                    Picker(NSLocalizedString("PUSH_LEAD_TIME", value: "Vorlaufzeit", comment: "Push"), selection: Binding(get: { region.leadMinutes },
                                                             set: { v in Task { await push.updateRegion(id: regionID, leadMinutes: v) } })) {
                        ForEach(PushLead.options, id: \.self) { Text(String(format: NSLocalizedString("PUSH_LEAD_MINUTES", value: "%lld Minuten", comment: "Push"), $0)).tag($0) }
                    }
                    Picker(NSLocalizedString("PUSH_SENSITIVITY", value: "Empfindlichkeit", comment: "Push"), selection: Binding(get: { region.sensitivity },
                                                                 set: { v in Task { await push.updateRegion(id: regionID, sensitivity: v) } })) {
                        ForEach(PushSensitivity.allCases) { Text(String(format: NSLocalizedString("PUSH_SENSITIVITY_ROW", value: "%1$@ (%2$@)", comment: "Push"), $0.title, $0.detail)).tag($0) }
                    }
                    Toggle(NSLocalizedString("PUSH_TIME_SENSITIVE", value: "Zeitkritisch", comment: "Push"), isOn: Binding(get: { region.timeSensitive },
                                                         set: { v in Task { await push.updateRegion(id: regionID, timeSensitive: v) } }))
                } header: { Text(NSLocalizedString("PUSH_SETTINGS_HEADER", value: "Einstellungen", comment: "Push")) } footer: {
                    Text(NSLocalizedString("REGION_SETTINGS_FOOTER", value: "Meldung, sobald der gewählte Anteil der Fläche innerhalb der Vorlaufzeit mindestens so stark Regen bekommt. Danach höchstens eine Meldung pro Stunde und Region. Zeitkritisch durchbricht Fokus und Mitteilungszusammenfassung, nicht den Stummschalter.", comment: NSLocalizedString("REGION_SETTINGS_TITLE", value: "Region", comment: "Region")))
                }

                // Only offered when the server announces `live_activity_regions`; an already enabled one stays switchable.
                if push.regionLiveActivityAvailable || region.liveActivity {
                    Section {
                        Toggle(RainActivityText.title.text(), isOn: Binding(
                            get: { region.liveActivity },
                            set: { enabled in Task { await push.setRegionLiveActivity(regionID: regionID, enabled: enabled) } }))
                        .disabled(!region.liveActivity && (!push.liveActivitiesEnabled || !push.regionLiveActivityAvailable))
                        .accessibilityIdentifier("region-live-activity")
                        if let message = push.liveActivityMessages[regionID] {
                            Text(message).font(.footnote).foregroundStyle(.secondary)
                                .accessibilityIdentifier("region-live-activity-status")
                        }
                        Text(RainActivityText.regionExplanation.text()).font(.footnote).foregroundStyle(.secondary)
                        if !push.liveActivitiesEnabled || !push.regionLiveActivityAvailable {
                            Text(RainActivityText.unavailable.text()).font(.footnote).foregroundStyle(.secondary)
                        }
                    } footer: {
                        Text(RainActivityText.regionPrivacy.text())
                    }
                }

                if push.authorization == .denied {
                    Section {
                        Button(NSLocalizedString("PUSH_OPEN_SYSTEM_SETTINGS", value: "Systemeinstellungen öffnen", comment: "Push")) {
                            if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                        }
                    } footer: { Text(NSLocalizedString("PUSH_DENIED_FOOTER_SHORT", value: "Mitteilungen sind für Showers im System ausgeschaltet.", comment: "Push")) }
                }

                Section {
                    Text(RegionText.privacyFootnote)
                    SitePageButton(page: .privacy, selection: $sitePage)
                }
                .font(.footnote).foregroundStyle(.secondary)

                Section {
                    Button(NSLocalizedString("REGION_DELETE_BUTTON", value: "Region löschen", comment: NSLocalizedString("REGION_SETTINGS_TITLE", value: "Region", comment: "Region")), role: .destructive) { confirmDelete = true }
                        .accessibilityIdentifier("region-delete")
                }
            }
        }
        .navigationTitle(NSLocalizedString("REGION_SETTINGS_TITLE", value: "Region", comment: "Region"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await push.refreshRegionSupport() }
        .onAppear { name = push.region(for: regionID)?.name ?? "" }
        .onDisappear { Task { await push.updateRegion(id: regionID, name: name) } }
        .sitePageSheet($sitePage)
        .confirmationDialog(NSLocalizedString("REGION_DELETE_TITLE", value: "Region löschen?", comment: "Region"), isPresented: $confirmDelete, titleVisibility: .visible) {
            Button(NSLocalizedString("COMMON_DELETE", value: "Löschen", comment: "Common"), role: .destructive) {
                Task { await push.removeRegion(id: regionID); dismiss() }
            }
            Button(NSLocalizedString("COMMON_CANCEL", value: "Abbrechen", comment: "Common"), role: .cancel) {}
        } message: { Text(NSLocalizedString("REGION_DELETE_MESSAGE", value: "Der Regenhinweis wird ausgeschaltet und auf dem Server gelöscht.", comment: "Region")) }
    }

    @ViewBuilder private func status(_ region: RegionPushSettings) -> some View {
        if let message = push.messages[regionID] {
            VStack(alignment: .leading, spacing: 6) {
                Label(message, systemImage: "exclamationmark.triangle").font(.footnote).foregroundStyle(.orange)
                Button(NSLocalizedString("PUSH_RETRY_NOW", value: "Jetzt erneut versuchen", comment: "Push")) { Task { await push.start() } }.font(.footnote)
            }
        } else {
            let active = push.regionStatus(for: regionID) == .active
            Label(active ? NSLocalizedString("PUSH_STATUS_ACTIVE", value: "Aktiv", comment: "Push") : NSLocalizedString("PUSH_STATUS_SETTING_UP", value: "Wird eingerichtet …", comment: "Push"), systemImage: active ? "checkmark.circle" : "clock")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }
}
