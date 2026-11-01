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
                    Section("Gespeicherte Orte") {
                        ForEach(store.places) { place in
                            HStack {
                                Button {
                                    store.select(place)
                                    dismiss()
                                } label: {
                                    HStack {
                                        Label(place.name, systemImage: "mappin.circle.fill")
                                        Spacer()
                                        if place.id == store.selectedPlace.id { Image(systemName: "checkmark") }
                                    }.foregroundStyle(.primary).contentShape(Rectangle())
                                }
                                .buttonStyle(.borderless)
                                Button {
                                    pushPlaceID = place.id
                                } label: {
                                    Image(systemName: push.settings(for: place.id) != nil ? "bell.fill" : "bell")
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel("Regenhinweis")
                                .accessibilityValue(push.settings(for: place.id) != nil ? "An" : "Aus")
                                .accessibilityIdentifier("place-push")
                            }
                            .swipeActions(edge: .leading) {
                                Button("Umbenennen") { newName = place.name; renamePlace = place }.tint(.blue)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    guard let index = store.places.firstIndex(where: { $0.id == place.id }) else { return }
                                    store.deletePlaces(at: IndexSet(integer: index))
                                } label: {
                                    Label("Löschen", systemImage: "trash")
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
                    } label: { Label("Aktuellen Standort verwenden", systemImage: "location") }
                }
                if isSearching {
                    Section { HStack { ProgressView(); Text("Orte werden gesucht …") } }
                }
                if let searchMessage {
                    Section { Text(searchMessage).foregroundStyle(.secondary) }
                }
                if !results.isEmpty {
                    Section("Suchergebnisse") {
                        ForEach(Array(results.enumerated()), id: \.offset) { _, item in
                            Button {
                                let coordinate = item.location.coordinate
                                store.select(SavedPlace(name: item.name ?? "Ausgewählter Ort", coordinate: WeatherCoordinate(
                                    latitude: coordinate.latitude, longitude: coordinate.longitude)))
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.name ?? "Ort").foregroundStyle(.primary)
                                    if let address = item.address?.shortAddress {
                                        Text(address).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
                Section {
                    Text("Orte und eigene Namen bleiben auf diesem Gerät. Die Suche verwendet Apple-Kartendienste. Zum Speichern eines ausgewählten Orts auf das Lesezeichen in der Karte tippen.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Deine Orte")
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
            .searchable(text: $query, prompt: "Stadt, Adresse oder Ort")
            .onSubmit(of: .search) { Task { await search() } }
            .onChange(of: query) { _, value in
                if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    searchGeneration = UUID()
                    results = []
                    isSearching = false
                    searchMessage = nil
                }
            }
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
            .alert("Ort umbenennen", isPresented: Binding(get: { renamePlace != nil }, set: { if !$0 { renamePlace = nil } })) {
                TextField("Name", text: $newName)
                Button("Speichern") {
                    if let place = renamePlace { store.rename(place, name: newName) }
                    renamePlace = nil
                }
                Button("Abbrechen", role: .cancel) { renamePlace = nil }
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
                    Button(role: .destructive) { Task { await push.removeRegion(id: entry.id) } } label: { Label("Löschen", systemImage: "trash") }
                }
            }
            Button { regionRoute = .new } label: { Label("Region hinzufügen", systemImage: "plus.circle") }
                .disabled(push.regionSupport != .supported || !push.canAddRegion)
                .accessibilityIdentifier("region-new")
            if push.regionSupport != .supported { RegionSupportNote(support: push.regionSupport).font(.footnote) }
            else if !push.canAddRegion {
                Label("Höchstens \(PushGrid.maxRegions) Regionen (insgesamt höchstens \(PushManager.maxSubscriptions) Hinweise).", systemImage: "info.circle")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if let notice = push.regionNotice { Label(notice, systemImage: "exclamationmark.triangle").font(.footnote).foregroundStyle(.orange) }
        } header: { Text("Regionen") }
        footer: { Text("Regenhinweis für einen Umkreis (5, 10 oder 25 km) statt für einen einzelnen Ort. Name und Mittelpunkt bleiben auf diesem Gerät; der Server erhält nur einen groben Bereich.") }
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
            if results.isEmpty { searchMessage = "Keine passenden Orte gefunden." }
        } catch {
            guard searchGeneration == requestID else { return }
            results = []
            searchMessage = "Die Ortssuche ist gerade nicht verfügbar. Du kannst einen Punkt auf der Karte auswählen."
        }
        isSearching = false
    }
}
