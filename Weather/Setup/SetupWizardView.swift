import CoreLocation
import MapKit
import SwiftUI
import UIKit

/// First-start setup (draft texts until release by Lino). Every screen has "Später"; the system prompts appear only
/// after the explanation screen and a tap on "Weiter".
struct SetupWizardView: View {
    var store: WeatherStore
    var coordinator: SetupCoordinator
    @Environment(PushManager.self) private var push
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) private var scheme
    @State private var index = 0
    @State private var working = false
    @State private var locationState = SetupLocationState(CLLocationManager().authorizationStatus)
    @State private var query = ""
    @State private var results: [MKMapItem] = []
    @State private var searchMessage: String?
    @State private var consent = SetupAlertConsent()
    @State private var confirmAlerts = false
    @State private var sitePage: SitePage?
    @State private var alertMessage: String?
    @State private var alertsEnabled = 0

    private var steps: [SetupStep] { coordinator.steps }
    private var step: SetupStep { steps.indices.contains(index) ? steps[index] : .done }
    private let maxAlertPlaces = 3

    var body: some View {
        ZStack {
            LinearGradient(colors: scheme == .dark ? [Color(red: 0.03, green: 0.10, blue: 0.22), Color(red: 0.02, green: 0.04, blue: 0.10)]
                                               : [Color(red: 0.84, green: 0.92, blue: 1.0), Color(red: 0.93, green: 0.96, blue: 1.0)],
                           startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            VStack(spacing: 0) {
                header
                ScrollView {
                    GlassEffectContainer {
                        card.padding(20).frame(maxWidth: .infinity, alignment: .leading)
                            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 28))
                            .accessibilityElement(children: .contain)
                            .accessibilityIdentifier("setup-wizard")
                    }
                    .padding(.horizontal, 16).padding(.top, 8)
                }
                .scrollBounceBehavior(.basedOnSize)
                footer
            }
        }
        .onAppear { push.updatePlaceNames(store.places) }
        #if DEBUG
        .overlay(alignment: .topLeading) {
            // UI tests only: counters of the fake push backend (nothing is shown to people).
            if PushUITestStub.isActive {
                Color.clear.frame(width: 1, height: 1).accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(PushStubLog.shared.summary) enabled=\(push.enabledCount) working=\(working) auth=\(String(describing: push.authorization))").accessibilityIdentifier("setup-debug")
            }
        }
        #endif
        .sitePageSheet($sitePage)
        .alert(NSLocalizedString("PUSH_PLACE_CONFIRM_TITLE", value: "Regenhinweis aktivieren?", comment: "Push"), isPresented: $confirmAlerts) {
            Button(NSLocalizedString("PUSH_CONTINUE", value: "Weiter", comment: "Push")) { consent.confirm(); Task { await enableAlerts() } }
            Button(NSLocalizedString("PUSH_READ_PRIVACY", value: "Datenschutzerklärung lesen", comment: "Push")) { sitePage = .privacy }
            Button(NSLocalizedString("COMMON_CANCEL", value: "Abbrechen", comment: "Common"), role: .cancel) {}
        } message: {
            Text(String(format: NSLocalizedString("SETUP_ALERT_CONFIRM_MESSAGE", value: "Showers meldet dir per Mitteilung, wenn es bei %@ bald zu regnen beginnt. Dafür gehen an den Showers-Server: das Gerätetoken, eine zufällige Installationskennung, die Rasterzelle des Radarbildes (Kantenlänge etwa 0,7 km, keine Koordinaten), Schwelle und Vorlaufzeit; kein Konto. Mit „Weiter“ willigst du ein. Ausschalten widerruft das jederzeit und löscht die Daten auf dem Server. Danach fragt iOS, ob Mitteilungen erlaubt sind.", comment: "Setup"), selectedPlaceNames))
        }
    }

    private var selectedPlaceNames: String {
        store.places.filter { consent.selected.contains($0.id) }.map(\.name).formatted(.list(type: .and))
    }

    // MARK: Header and footer

    private var header: some View {
        HStack {
            HStack(spacing: 6) {
                ForEach(steps.indices, id: \.self) { i in
                    Capsule().fill(i == index ? Color.cyan : Color.secondary.opacity(0.35)).frame(width: i == index ? 22 : 8, height: 8)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(format: NSLocalizedString("SETUP_PROGRESS", value: "Schritt %1$lld von %2$lld", comment: "Setup"), index + 1, steps.count))
            Spacer()
            // One way to leave per screen: "Überspringen" (whole wizard) only on the welcome screen, "Später" on the others.
            if step == .welcome {
                Button(NSLocalizedString("SETUP_SKIP_ALL", value: "Überspringen", comment: "Setup")) { coordinator.finish() }
                    .accessibilityHint(NSLocalizedString("SETUP_SKIP_ALL_HINT", value: "Beendet die Einrichtung und öffnet das Radar", comment: "Setup"))
                    .accessibilityIdentifier("setup-skip-all")
            }
        }
        .padding(.horizontal, 20).padding(.top, 12)
    }

    @ViewBuilder private var footer: some View {
        VStack(spacing: 10) {
            Button { Task { await primaryAction() } } label: {
                Text(primaryTitle).frame(maxWidth: .infinity).padding(.vertical, 6)
            }
            .buttonStyle(.glassProminent)
            .disabled(working || (step == .rainAlert && !consent.canRequest))
            .accessibilityIdentifier("setup-primary")
            // Waiting indicator while the system is asked (permission status, prompt, opt-in); gone on success, timeout and error.
            .overlay(alignment: .leading) {
                if working {
                    ProgressView().padding(.leading, 18)
                        .accessibilityLabel(NSLocalizedString("SETUP_WORKING", value: "Bitte warten …", comment: "Setup"))
                        .accessibilityIdentifier("setup-working")
                }
            }
            if let later = laterTitle {
                Button(later) { advance() }
                    .buttonStyle(.glass)
                    .frame(minHeight: 44)
                    // A running opt-in ends the step itself; leaving meanwhile would advance twice. The location wait stays skippable.
                    .disabled(working && step == .rainAlert)
                    .accessibilityIdentifier("setup-later")
            }
        }
        .padding(.horizontal, 20).padding(.bottom, 16).padding(.top, 8)
    }

    private var primaryTitle: String {
        switch step {
        case .welcome: NSLocalizedString("SETUP_START", value: "Los geht’s", comment: "Setup")
        case .done: NSLocalizedString("SETUP_TO_RADAR", value: "Zum Radar", comment: "Setup")
        case .rainAlert: NSLocalizedString("SETUP_ALERT_ENABLE", value: "Regenhinweis einschalten", comment: "Setup")
        default: NSLocalizedString("SETUP_NEXT", value: "Weiter", comment: "Setup")
        }
    }

    private var laterTitle: String? {
        switch step {
        case .welcome, .done: nil
        default: NSLocalizedString("SETUP_LATER", value: "Später", comment: "Setup")
        }
    }

    // MARK: Cards

    @ViewBuilder private var card: some View {
        switch step {
        case .welcome: welcomeCard
        case .location: locationCard
        case .places: placesCard
        case .rainAlert: rainAlertCard
        case .done: doneCard
        }
    }

    private func title(_ text: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol).font(.largeTitle).foregroundStyle(.cyan).accessibilityHidden(true)
            Text(text).font(.title.bold()).accessibilityAddTraits(.isHeader)
        }
    }

    private func body(_ text: String) -> some View { Text(text).font(.body).foregroundStyle(.primary.opacity(0.8)).fixedSize(horizontal: false, vertical: true) }

    private var welcomeCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            title(NSLocalizedString("SETUP_WELCOME_TITLE", value: "Willkommen bei Showers", comment: "Setup"), symbol: "cloud.rain")
            body(NSLocalizedString("SETUP_WELCOME_BODY", value: "Regenradar, Prognose für deinen Ort und auf Wunsch ein Regenhinweis.", comment: "Setup"))
            Label(NSLocalizedString("SETUP_WELCOME_PRIVACY", value: "Kein Konto, kein Tracking.", comment: "Setup"), systemImage: "hand.raised")
            Label(NSLocalizedString("SETUP_WELCOME_SOURCES", value: "Daten vom Deutschen Wetterdienst und von EUMETNET OPERA.", comment: "Setup"), systemImage: "map")
        }
    }

    @ViewBuilder private var locationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            title(NSLocalizedString("SETUP_LOCATION_TITLE", value: "Dein Standort", comment: "Setup"), symbol: "location")
            body(NSLocalizedString("SETUP_LOCATION_BODY", value: "Für Karte und Prognose an deinem Ort. Für die Prognose geht nur der Punkt an den Deutschen Wetterdienst, nicht an Showers. Showers fragt nur nach dem Standort, während die App geöffnet ist.", comment: "Setup"))
            Label(NSLocalizedString("SETUP_LOCATION_NOT", value: "Es wird kein Standortverlauf gespeichert.", comment: "Setup"), systemImage: "checkmark.shield")
            Button(NSLocalizedString("SETUP_LOCATION_SEARCH", value: "Lieber einen Ort suchen", comment: "Setup")) { advance() }
                .frame(minHeight: 44).accessibilityIdentifier("setup-location-search")
        }
    }

    private var placesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            title(NSLocalizedString("SETUP_PLACES_TITLE", value: "Deine Orte", comment: "Setup"), symbol: "mappin.and.ellipse")
            body(NSLocalizedString("SETUP_PLACES_BODY", value: "Speichere bis zu drei Orte, für die du die Prognose schnell sehen möchtest. Das ist freiwillig.", comment: "Setup"))
            ForEach(store.places) { place in
                Label(place.name, systemImage: "checkmark.circle.fill").foregroundStyle(.primary)
            }
            if canSaveCurrentLocation {
                Button {
                    store.saveSelection(name: store.selectedPlace.name)
                } label: { Label(NSLocalizedString("SETUP_PLACES_SAVE_LOCATION", value: "Aktuellen Standort speichern", comment: "Setup"), systemImage: "location") }
                    .buttonStyle(.glass).frame(minHeight: 44).accessibilityIdentifier("setup-save-location")
            }
            if store.places.count < maxAlertPlaces {
                TextField(NSLocalizedString("PLACES_SEARCH_PROMPT", value: "Stadt, Adresse oder Ort", comment: "Places"), text: $query)
                    .textFieldStyle(.plain).padding(12).frame(minHeight: 44)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 12)).submitLabel(.search)
                    .onSubmit { Task { await search() } }
                    .accessibilityIdentifier("setup-search")
                if let searchMessage { Text(searchMessage).font(.footnote).foregroundStyle(.secondary) }
                ForEach(Array(results.prefix(4).enumerated()), id: \.offset) { _, item in
                    Button { add(item) } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name ?? NSLocalizedString("PLACES_ITEM_FALLBACK", value: "Ort", comment: "Places")).foregroundStyle(.primary)
                            if let address = item.address?.shortAddress { Text(address).font(.caption).foregroundStyle(.secondary) }
                        }.frame(maxWidth: .infinity, alignment: .leading).frame(minHeight: 44).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("setup-result")
                }
            }
            Text(NSLocalizedString("SETUP_PLACES_PRIVACY", value: "Orte bleiben auf diesem Gerät und deiner Apple Watch. Die Suche nutzt Apple-Kartendienste.", comment: "Setup"))
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private var rainAlertCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            title(NSLocalizedString("SETUP_ALERT_TITLE", value: "Regenhinweis", comment: "Setup"), symbol: "bell.badge")
            body(NSLocalizedString("SETUP_ALERT_BODY", value: "Wir melden dir, wenn an deinem Ort Regen beginnt. Dafür gehen an den Showers-Server das Gerätetoken, eine zufällige Installationskennung, die Rasterzelle des Radarbildes (etwa 0,7 km Kantenlänge) sowie Schwelle und Vorlaufzeit. Kein genauer Standort, kein Ortsname, kein Konto. Du kannst das jederzeit ausschalten; dann werden die Daten auf dem Server gelöscht.", comment: "Setup"))
            Label(NSLocalizedString("SETUP_ALERT_GERMANY", value: "Bisher nur für Orte in Deutschland.", comment: "Setup"), systemImage: "info.circle")
            Text(NSLocalizedString("SETUP_ALERT_CHOOSE", value: "Für welche Orte?", comment: "Setup")).font(.headline)
            if store.places.isEmpty {
                body(NSLocalizedString("SETUP_ALERT_NO_PLACES", value: "Speichere zuerst einen Ort, zum Beispiel in den Orten.", comment: "Setup"))
            }
            ForEach(store.places) { place in
                let supported = PushGrid.cell(latitude: place.coordinate.latitude, longitude: place.coordinate.longitude) != nil
                Toggle(isOn: Binding(get: { consent.selected.contains(place.id) }, set: { consent.set(place.id, on: $0) })) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(place.name)
                        if !supported {
                            Text(NSLocalizedString("SETUP_ALERT_OUTSIDE", value: "Außerhalb von Deutschland: Radar ja, Hinweis noch nicht.", comment: "Setup")).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .disabled(!supported)
                .frame(minHeight: 44)
                .accessibilityIdentifier("setup-alert-place")
            }
            if let alertMessage { Label(alertMessage, systemImage: "exclamationmark.triangle").font(.footnote).foregroundStyle(.orange) }
            // "Nothing preselected" only before a choice; once a place is ticked the note is about the pending confirmation.
            // After a refusal only the denial message above stays (nothing is pending any more).
            if consent.canRequest, !permissionRefused {
                Text(NSLocalizedString("SETUP_ALERT_PENDING_NOTE", value: "Der Regenhinweis wird erst nach deiner Bestätigung eingeschaltet.", comment: "Setup"))
                    .font(.footnote).foregroundStyle(.secondary).accessibilityIdentifier("setup-alert-note-pending")
            } else if !consent.canRequest {
                Text(NSLocalizedString("SETUP_ALERT_PROMPT_NOTE", value: "Nichts ist vorgewählt. Erst nach deiner Zustimmung fragt iOS, ob Showers Mitteilungen senden darf.", comment: "Setup"))
                    .font(.footnote).foregroundStyle(.secondary).accessibilityIdentifier("setup-alert-note-none")
            }
        }
    }

    /// The enable attempt ended with "not allowed" in iOS (the denial message is shown).
    private var permissionRefused: Bool { alertMessage != nil && push.authorization == .denied }

    private var doneCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            title(NSLocalizedString("SETUP_DONE_TITLE", value: "Fertig", comment: "Setup"), symbol: "checkmark.circle")
            body(NSLocalizedString("SETUP_DONE_BODY", value: "Noch ein paar Tipps, ganz ohne Abfrage:", comment: "Setup"))
            Label(NSLocalizedString("SETUP_TIP_WIDGET", value: "Widget zum Home-Bildschirm hinzufügen", comment: "Setup"), systemImage: "rectangle.on.rectangle")
            Label(NSLocalizedString("SETUP_TIP_LIVE", value: "Live-Aktivität für den Regenbeginn in den Ortseinstellungen", comment: "Setup"), systemImage: "bolt.badge.clock")
            Label(NSLocalizedString("SETUP_TIP_WATCH", value: "Showers auf der Apple Watch", comment: "Setup"), systemImage: "applewatch")
            Label(NSLocalizedString("SETUP_TIP_WARNINGS", value: "Amtliche DWD-Warnungen in der Warnungsliste", comment: "Setup"), systemImage: "exclamationmark.triangle")
            body(NSLocalizedString("SETUP_DONE_AGAIN", value: "Die Einrichtung findest du jederzeit unter „Über Showers“.", comment: "Setup"))
        }
    }

    // MARK: Actions

    private var canSaveCurrentLocation: Bool {
        locationState == .allowed && store.selectedPlace.name == NSLocalizedString("STORE_CURRENT_LOCATION", value: "Aktueller Standort", comment: "Weather store message")
            && !store.places.contains(where: { $0.id == store.selectedPlace.id }) && store.places.count < maxAlertPlaces
    }

    private func advance() {
        working = false
        if index + 1 < steps.count {
            if reduceMotion { index += 1 } else { withAnimation(.smooth(duration: 0.3)) { index += 1 } }
            prepareStep()
        } else { coordinator.finish() }
    }

    private func prepareStep() {
        locationState = SetupLocationState(CLLocationManager().authorizationStatus)
        // Rain alert is opt-in per place: nothing is preselected.
        if step == .rainAlert { consent = SetupAlertConsent(); alertMessage = nil }
    }

    private func primaryAction() async {
        switch step {
        case .welcome, .places, .done: advance()
        case .location:
            working = true
            store.requestLocation()
            // The system prompt is answered outside our control; wait for a decision, then move on.
            for _ in 0..<200 where CLLocationManager().authorizationStatus == .notDetermined {
                try? await Task.sleep(for: .milliseconds(300))
            }
            advance()
        case .rainAlert:
            // Only asks for consent; enabling happens in the dialog's "Weiter".
            alertMessage = nil
            confirmAlerts = true
        }
    }

    @MainActor private func enableAlerts() async {
        working = true
        alertMessage = nil
        let places = store.places
        alertsEnabled += await consent.enableConfirmed(in: places.map(\.id)) { id in
            guard let place = places.first(where: { $0.id == id }) else { return false }
            let ok = await push.enable(placeID: place.id, latitude: place.coordinate.latitude, longitude: place.coordinate.longitude)
            if !ok, let message = push.messages[place.id] { alertMessage = message }
            return ok
        }
        working = false
        if alertMessage == nil || alertsEnabled > 0 { advance() }
    }

    @MainActor private func search() async {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return }
        searchMessage = nil
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = term
        request.region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 51.1, longitude: 10.4),
                                            span: MKCoordinateSpan(latitudeDelta: 9, longitudeDelta: 14))
        #if DEBUG
        if let fixed = PushUITestStub.searchResult(for: term) { results = [fixed]; return }
        #endif
        do {
            results = try await MKLocalSearch(request: request).start().mapItems
            if results.isEmpty { searchMessage = NSLocalizedString("PLACES_NO_RESULTS", value: "Keine passenden Orte gefunden.", comment: "Places") }
        } catch {
            results = []
            searchMessage = NSLocalizedString("PLACES_SEARCH_UNAVAILABLE", value: "Die Ortssuche ist gerade nicht verfügbar. Du kannst einen Punkt auf der Karte auswählen.", comment: "Places")
        }
    }

    private func add(_ item: MKMapItem) {
        let c = item.location.coordinate
        let name = item.name ?? NSLocalizedString("PLACES_SELECTED_FALLBACK", value: "Ausgewählter Ort", comment: "Places")
        store.select(SavedPlace(name: name, coordinate: WeatherCoordinate(latitude: c.latitude, longitude: c.longitude)))
        store.saveSelection(name: name)
        results = []; query = ""
    }
}

/// "Einrichtung" section of the information sheet: state per permission, link to iOS settings, restart.
struct SetupInfoSection: View {
    var store: WeatherStore
    var coordinator: SetupCoordinator
    @Environment(PushManager.self) private var push
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss

    private var location: SetupLocationState { SetupLocationState(CLLocationManager().authorizationStatus) }

    var body: some View {
        Section {
            LabeledContent(NSLocalizedString("SETUP_INFO_LOCATION", value: "Standort", comment: "Setup")) {
                Text(locationText)
            }
            LabeledContent(NSLocalizedString("SETUP_INFO_NOTIFICATIONS", value: "Mitteilungen", comment: "Setup")) {
                Text(notificationText)
            }
            Button(NSLocalizedString("SETUP_INFO_OPEN_SETTINGS", value: "In iOS-Einstellungen öffnen", comment: "Setup")) {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            .accessibilityIdentifier("setup-open-settings")
            Button(NSLocalizedString("SETUP_INFO_RESTART", value: "Einrichtung erneut starten", comment: "Setup")) {
                dismiss()
                coordinator.restart(store: store, push: push)
            }
            .accessibilityIdentifier("setup-restart")
        } header: { Text(NSLocalizedString("SETUP_INFO_HEADER", value: "Einrichtung", comment: "Setup")) }
    }

    private var locationText: String {
        switch location {
        case .allowed: NSLocalizedString("SETUP_STATE_ALLOWED", value: "Erlaubt", comment: "Setup")
        case .denied: NSLocalizedString("SETUP_STATE_DENIED", value: "Nicht erlaubt", comment: "Setup")
        case .notDetermined: NSLocalizedString("SETUP_STATE_OPEN", value: "Noch offen", comment: "Setup")
        }
    }

    private var notificationText: String {
        switch push.authorization {
        case .authorized: NSLocalizedString("SETUP_STATE_ALLOWED", value: "Erlaubt", comment: "Setup")
        case .denied: NSLocalizedString("SETUP_STATE_DENIED", value: "Nicht erlaubt", comment: "Setup")
        case .notDetermined, .unknown: NSLocalizedString("SETUP_STATE_OPEN", value: "Noch offen", comment: "Setup")
        }
    }
}
