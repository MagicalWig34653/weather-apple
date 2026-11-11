import MapKit
import SwiftUI

private enum RegionRoute: Hashable { case new, edit(UUID) }

struct PlacesSheet: View {
    @Bindable var store: WeatherStore
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [MKMapItem] = []
    @State private var isSearching = false
    @State private var searchMessage: String?
    @State private var renamePlace: SavedPlace?
    @State private var newName = ""
    @State private var searchGeneration = UUID()
    @State private var pushPlaceID: UUID?
    @State private var regionRoute: RegionRoute?
    @Environment(PushManager.self) private var push

    var body: some View {
        NavigationStack {
            List {
                if let message = store.storageMessage {
                    Section { Label(message, systemImage: "exclamationmark.triangle") }
                }
                if !store.places.isEmpty {
                    Section(NSLocalizedString("PLACES_SAVED_SECTION", value: "Gespeicherte Orte", comment: "Places")) {
                        ForEach(store.places) { place in
                            HStack {
                                Button {
                                    store.select(place)
                                    dismiss()
                                } label: {
                                    HStack {
                                        Label(place.name, systemImage: "mappin.circle.fill")
                                        Spacer()
                                        if place.id == store.selectedPlace.id { Image(systemName: "checkmark").accessibilityHidden(true) }
                                    }.foregroundStyle(.primary).contentShape(Rectangle())
                                }
                                .buttonStyle(.borderless)
                                .accessibilityAddTraits(place.id == store.selectedPlace.id ? .isSelected : [])
                                Button {
                                    pushPlaceID = place.id
                                } label: {
                                    Image(systemName: push.settings(for: place.id) != nil ? "bell.fill" : "bell")
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel(String(format: NSLocalizedString("PLACES_ALERT_FOR", value: "Regenhinweis für %@", comment: "Places"), place.name))
                                .accessibilityInputLabels([String(format: NSLocalizedString("PLACES_ALERT_FOR", value: "Regenhinweis für %@", comment: "Places"), place.name),
                                                           NSLocalizedString("PUSH_ALERT_LABEL", value: "Regenhinweis", comment: "Places")])
                                .accessibilityValue(push.settings(for: place.id) != nil ? NSLocalizedString("PLACES_ALERT_ON", value: "An", comment: "Places") : NSLocalizedString("PLACES_ALERT_OFF", value: "Aus", comment: "Places"))
                                .accessibilityIdentifier("place-push")
                            }
                            .swipeActions(edge: .leading) {
                                Button(NSLocalizedString("PLACES_RENAME", value: "Umbenennen", comment: "Places")) { newName = place.name; renamePlace = place }.tint(.blue)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    guard let index = store.places.firstIndex(where: { $0.id == place.id }) else { return }
                                    store.deletePlaces(at: IndexSet(integer: index))
                                } label: {
                                    Label(NSLocalizedString("COMMON_DELETE", value: "Löschen", comment: "Common"), systemImage: "trash")
                                }
                                .accessibilityIdentifier("delete-place")
                            }
                        }.onDelete(perform: store.deletePlaces)
                    }
                }
                regionsSection
                Section {
                    Button {
                        store.requestLocation()
                        dismiss()
                    } label: { Label(NSLocalizedString("RADAR_USE_LOCATION", value: "Aktuellen Standort verwenden", comment: "Radar"), systemImage: "location") }
                }
                if isSearching {
                    Section { HStack { ProgressView(); Text(NSLocalizedString("PLACES_SEARCHING", value: "Orte werden gesucht …", comment: "Places")) } }
                }
                if let searchMessage {
                    Section { Text(searchMessage).foregroundStyle(.secondary) }
                }
                if !results.isEmpty {
                    Section(NSLocalizedString("PLACES_RESULTS_SECTION", value: "Suchergebnisse", comment: "Places")) {
                        ForEach(Array(results.enumerated()), id: \.offset) { _, item in
                            Button {
                                let coordinate = item.location.coordinate
                                store.select(SavedPlace(name: item.name ?? NSLocalizedString("PLACES_SELECTED_FALLBACK", value: "Ausgewählter Ort", comment: "Places"), coordinate: WeatherCoordinate(
                                    latitude: coordinate.latitude, longitude: coordinate.longitude)))
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.name ?? NSLocalizedString("PLACES_ITEM_FALLBACK", value: "Ort", comment: "Places")).foregroundStyle(.primary)
                                    if let address = item.address?.shortAddress {
                                        Text(address).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
                Section {
                    Text(NSLocalizedString("PLACES_FOOTNOTE", value: "Orte und eigene Namen bleiben auf diesem Gerät. Die Suche verwendet Apple-Kartendienste. Zum Speichern eines ausgewählten Orts auf das Lesezeichen in der Karte tippen.", comment: "Places"))
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle(NSLocalizedString("PLACES_TITLE", value: "Deine Orte", comment: "Places"))
            .navigationDestination(item: $pushPlaceID) { id in
                if let place = store.places.first(where: { $0.id == id }) { PlacePushSettingsView(place: place) }
            }
            .navigationDestination(item: $regionRoute) { route in
                switch route {
                case .new: RegionCreateView(store: store)
                case .edit(let id): RegionSettingsView(regionID: id)
                }
            }
            .task { await push.refreshRegionSupport() }
            .searchable(text: $query, prompt: NSLocalizedString("PLACES_SEARCH_PROMPT", value: "Stadt, Adresse oder Ort", comment: "Places"))
            .onSubmit(of: .search) { Task { await search() } }
            .onChange(of: query) { _, value in
                if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    searchGeneration = UUID()
                    results = []
                    isSearching = false
                    searchMessage = nil
                }
            }
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(NSLocalizedString("COMMON_DONE", value: "Fertig", comment: "Common")) { dismiss() } } }
            .alert(NSLocalizedString("PLACES_RENAME_TITLE", value: "Ort umbenennen", comment: "Places"), isPresented: Binding(get: { renamePlace != nil }, set: { if !$0 { renamePlace = nil } })) {
                TextField(NSLocalizedString("COMMON_NAME", value: "Name", comment: "Text field"), text: $newName)
                Button(NSLocalizedString("COMMON_SAVE", value: "Speichern", comment: "Common")) {
                    if let place = renamePlace { store.rename(place, name: newName) }
                    renamePlace = nil
                }
                Button(NSLocalizedString("COMMON_CANCEL", value: "Abbrechen", comment: "Common"), role: .cancel) { renamePlace = nil }
            }
        }
    }

    @ViewBuilder private var regionsSection: some View {
        Section {
            ForEach(push.regionsSorted, id: \.id) { entry in
                Button { regionRoute = .edit(entry.id) } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Label(RegionText.title(entry.settings), systemImage: "circle.dashed").foregroundStyle(.primary)
                            Text(RegionText.detail(entry.settings)).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: push.regionStatus(for: entry.id) == .active ? "bell.fill" : "clock").foregroundStyle(.secondary)
                    }.contentShape(Rectangle())
                }
                .accessibilityIdentifier("region-row")
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) { Task { await push.removeRegion(id: entry.id) } } label: { Label(NSLocalizedString("COMMON_DELETE", value: "Löschen", comment: "Common"), systemImage: "trash") }
                }
            }
            Button { regionRoute = .new } label: { Label(NSLocalizedString("REGION_ADD", value: "Region hinzufügen", comment: "Places"), systemImage: "plus.circle") }
                .disabled(push.regionSupport != .supported || !push.canAddRegion)
                .accessibilityIdentifier("region-new")
            if push.regionSupport != .supported { RegionSupportNote(support: push.regionSupport).font(.footnote) }
            else if !push.canAddRegion {
                Label(String(format: NSLocalizedString("PLACES_REGION_LIMIT", value: "Höchstens %1$lld Regionen (insgesamt höchstens %2$lld Hinweise).", comment: "Places"), PushGrid.maxRegions, PushManager.maxSubscriptions), systemImage: "info.circle")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if let notice = push.regionNotice { Label(notice, systemImage: "exclamationmark.triangle").font(.footnote).foregroundStyle(.orange) }
        } header: { Text(NSLocalizedString("PLACES_REGIONS_HEADER", value: "Regionen", comment: "Places")) }
        footer: { Text(NSLocalizedString("PLACES_REGIONS_FOOTER", value: "Regenhinweis für einen Umkreis (5, 10 oder 25 km) statt für einen einzelnen Ort. Name und Mittelpunkt bleiben auf diesem Gerät; der Server erhält nur einen groben Bereich.", comment: "Places")) }
    }

    @MainActor private func search() async {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return }
        let requestID = UUID()
        searchGeneration = requestID
        isSearching = true
        searchMessage = nil
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = term
        request.region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 51.1, longitude: 10.4),
                                            span: MKCoordinateSpan(latitudeDelta: 9, longitudeDelta: 14))
        do {
            let response = try await MKLocalSearch(request: request).start()
            guard searchGeneration == requestID else { return }
            results = response.mapItems
            if results.isEmpty { searchMessage = NSLocalizedString("PLACES_NO_RESULTS", value: "Keine passenden Orte gefunden.", comment: "Places") }
        } catch {
            guard searchGeneration == requestID else { return }
            results = []
            searchMessage = NSLocalizedString("PLACES_SEARCH_UNAVAILABLE", value: "Die Ortssuche ist gerade nicht verfügbar. Du kannst einen Punkt auf der Karte auswählen.", comment: "Places")
        }
        isSearching = false
    }
}
