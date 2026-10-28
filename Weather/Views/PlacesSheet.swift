import MapKit
import SwiftUI

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

    var body: some View {
        NavigationStack {
            List {
                if let message = store.storageMessage {
                    Section { Label(message, systemImage: "exclamationmark.triangle") }
                }
                if !store.places.isEmpty {
                    Section("Gespeicherte Orte") {
                        ForEach(store.places) { place in
                            Button {
                                store.select(place)
                                dismiss()
                            } label: {
                                HStack {
                                    Label(place.name, systemImage: "mappin.circle.fill")
                                    Spacer()
                                    if place.id == store.selectedPlace.id { Image(systemName: "checkmark") }
                                }.foregroundStyle(.primary)
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
