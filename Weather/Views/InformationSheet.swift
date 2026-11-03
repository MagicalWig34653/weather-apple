import SwiftUI

struct InformationSheet: View {
    var store: WeatherStore
    @Environment(PushManager.self) private var push
    @Environment(\.dismiss) private var dismiss
    @State private var sitePage: SitePage?

    @ViewBuilder private var testRow: some View {
        Button {
            Task { await push.sendTest() }
        } label: {
            HStack {
                Text("Testmeldung senden")
                if push.testState == .sending { Spacer(); ProgressView() }
            }
        }
        .disabled(push.testState == .sending || !push.canSendTest)
        .accessibilityIdentifier("push-test-button")
        switch push.testState {
        case .sent:
            Label("Testmeldung gesendet. Sie sollte gleich ankommen (höchstens 3 pro Stunde).", systemImage: "checkmark.circle")
                .font(.footnote).foregroundStyle(.secondary).accessibilityIdentifier("push-test-result")
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .font(.footnote).foregroundStyle(.orange).accessibilityIdentifier("push-test-result")
        case .idle, .sending: EmptyView()
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("ShowerNow · frühe Testversion") {
                    Text("Regenradar und kurzfristige Ortsprognose für Deutschland. Regenhinweise als Mitteilung sind optional je gespeichertem Ort oder für einen Umkreis (Region).")
                    Text("Die Karte zeigt Messbilder und Radarvorhersagen getrennt. Die Punktprognose basiert auf Fünf-Minuten-Intervallen; minutengenaue Zusagen sind daraus nicht ableitbar.")
                }
                Section("Widgets und Apple Watch") {
                    Text("Widgets verwenden deine gespeicherten Orte. Den Ort wählst du beim Bearbeiten des Widgets; Antippen öffnet ihn in der App. Die Aktualisierung im Hintergrund bestimmt das System. Achte auf das angezeigte Datenalter.")
                    Text("Deine gespeicherten Orte werden mit Name, Koordinate und Kennung an deine gekoppelte Apple Watch übertragen, wenn dort ShowerNow installiert ist. Die Übertragung kann verzögert erfolgen. Ein aktueller, nicht gespeicherter Standort wird nicht übertragen.")
                }
                pastSection
                Section {
                    Text(push.summary).accessibilityIdentifier("push-status")
                    if push.isAnyEnabled {
                        Button("Alle Mitteilungen ausschalten", role: .destructive) { Task { await push.resetAll() } }
                    }
                    if push.canSendTest || push.testState != .idle {
                        testRow
                    }
                    SitePageButton(page: .privacy, selection: $sitePage)
                } header: {
                    Text("Mitteilungen")
                } footer: {
                    Text("Einstellen kannst du Regenhinweise je Ort (Glockensymbol) oder für Regionen unter „Deine Orte“. Ausschalten löscht die Registrierung auf dem Server.")
                }
                Section("Datenquellen") {
                    Text("\(store.radarAttribution.attribution). \(store.radarAttribution.modificationNotice). Niederschlagswerte für die Ortsprognose umgerechnet und aufbereitet.")
                    Text("Radarbilder aktuell: \(store.radarSource.label). Normalerweise liefert der ShowerNow-Radar-Server die Bilder; bei Fehlern oder veralteten Daten lädt die App sie selbstständig direkt vom DWD-Kartendienst.")
                    layerSources
                    Link("Deutscher Wetterdienst · Open Data", destination: URL(string: "https://opendata.dwd.de/weather/radar/composite/rv/")!)
                    Link("DWD · Nutzungsbedingungen", destination: URL(string: "https://www.dwd.de/DE/service/copyright/copyright_node.html")!)
                    Text("Karte und Ortssuche: Apple MapKit. Quellenhinweise der Karte bleiben eingeblendet.")
                }
                Section("Datenschutz") {
                    Text("Kein Konto und keine Analyse- oder Werbe-SDKs. Gespeicherte Orte und eigene Namen bleiben auf deinem iPhone und deiner gekoppelten Apple Watch; sie werden nicht an den ShowerNow-Server übertragen.")
                    Text("Widgets und Apple Watch verwenden ausschließlich gespeicherte Orte und rufen deren Prognosen direkt beim DWD ab. Die Kopplung überträgt nur die aktuelle Ortsliste, keinen Standortverlauf. Die zuletzt gültige Prognose je Ort wird lokal für Widgets gespeichert.")
                    Text("Radarbilder lädt die App vom ShowerNow-Radar-Server. Der Radar-Dienst selbst führt keine Zugriffsprotokolle und speichert keine IP-Adressen oder Abfragedetails. Wie bei jeder Internetverbindung sieht der vorgeschaltete Server technisch bedingt die IP-Adresse deines Abrufs; die Radar-Anfragen enthalten keinen Ort, keine Cookies und keine Kennung. Bei Fehlern oder veralteten Daten ruft die App die Radarbilder direkt beim DWD ab. Bilder der Zusatzebenen kommen nur vom ShowerNow-Server. Blendest du die Legende der Blitze ein, lädt die App das Legendenbild direkt vom DWD (bei Wolken ggf. von EUMETSAT); dabei sieht der Anbieter technisch bedingt deine IP-Adresse, aber keinen Ort.")
                    Text("Für eine Ortsprognose erhält der DWD weiterhin direkt einen Kartenausschnitt um die ausgewählte Position. Karten und Suchanfragen werden von Apple verarbeitet: Bei der Ortssuche gehen Suchtext und ein fester Suchbereich (Deutschland, nicht dein Standort) an Apple, nie an den Radar-Dienst oder den DWD; Apple sieht dabei technisch bedingt die IP-Adresse. Es gelten Apples Datenschutzbestimmungen.")
                    Text("Nur wenn du Regenhinweise für einen Ort einschaltest: Der ShowerNow-Server erhält dein Gerätetoken, eine zufällige Installations-Kennung, eine Rasterzelle von etwa 1 km um den Ort (keine Koordinaten, kein Ortsname) sowie Schwelle und Vorlaufzeit; kein Konto. Bei einer Region speichert der Server stattdessen einen groben Bereich: den Mittelpunkt gröber als eine Rasterzelle (etwa 2 km), den Radius und den Auslöseanteil; der Name der Region bleibt auf dem Gerät. Beim Ausschalten, Löschen des Orts oder der Region oder Zurücksetzen werden diese Daten gelöscht.")
                    Text("Standortzugriff ist optional und wird nur bei Nutzung angefordert. Keine Hintergrundortung. Punktanfragen werden nicht in einem Festplatten-Netzwerkcache gespeichert.")
                    SitePageButton(page: .privacy, selection: $sitePage)
                    SitePageButton(page: .support, selection: $sitePage)
                    SitePageButton(page: .about, selection: $sitePage)
                    Text("Die App ist eine frühe Testversion. Prognosen können abweichen; bei fehlenden oder veralteten Daten wird keine aktuelle Aussage zugesichert.")
                }
            }
            .navigationTitle("Über ShowerNow")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
            .sitePageSheet($sitePage)
        }
    }

    // MARK: Layer sources

    /// Source line and modification notice of every optional layer the backend currently offers (from its manifest).
    @ViewBuilder private var layerSources: some View {
        ForEach((RadarLayer.selectable + RadarLayer.auxiliary).filter(\.isBackendLayer)) { layer in
            if let manifest = store.layers.snapshot(layer).manifest {
                VStack(alignment: .leading, spacing: 2) {
                    Text(layer.title).font(.subheadline.weight(.semibold))
                    Text("\(manifest.attribution). \(manifest.modificationNotice).")
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("layer-source-\(layer.rawValue)")
            }
        }
        if store.layers.snapshot(.clouds).manifest != nil {
            Link("EUMETSAT · EUMETView", destination: URL(string: "https://view.eumetsat.int")!)
        }
        Text("Zusatzebenen (Luftdruck, Blitze, Wolken) liefert der ShowerNow-Server nur, wenn sie dort aktiviert sind; sonst sind sie ausgegraut. Einen Ersatzweg direkt beim DWD gibt es für sie nicht.")
            .font(.footnote).foregroundStyle(.secondary)
    }

    // MARK: Radar past setting

    private var pastSection: some View {
        Section {
            ForEach(RadarPastWindow.options, id: \.self) { hours in
                let unavailable = isUnavailable(hours)
                Button {
                    store.setPastHours(hours)
                } label: {
                    HStack {
                        Text(RadarPastWindow.label(hours))
                        Spacer()
                        if store.pastHours == hours { Image(systemName: "checkmark").accessibilityHidden(true) }
                    }
                    .contentShape(Rectangle())
                }
                .foregroundStyle(unavailable ? .secondary : .primary)
                .disabled(unavailable)
                .accessibilityAddTraits(store.pastHours == hours ? .isSelected : [])
                .accessibilityHint(unavailable ? "Derzeit nicht verfügbar" : "")
                .accessibilityIdentifier("past-hours-\(hours)")
            }
        } header: {
            Text("Maximale Vergangenheit")
        } footer: {
            Text(pastFooter)
        }
    }

    /// Steps beyond what the server offers are disabled; the direct DWD path has no longer past at all.
    private func isUnavailable(_ hours: Int) -> Bool {
        if store.radarSource == .direct { return hours > RadarPastWindow.directHours }
        if let offered = store.serverHistoryHours { return hours > max(offered, RadarPastWindow.directHours) }
        return false
    }

    private var pastFooter: String {
        let base = "Wie weit die Zeitleiste in die Vergangenheit reicht. Mehr Vergangenheit lädt mehr Bilder (Datenvolumen)."
        if store.radarSource == .direct {
            return base + " Beim Abruf direkt vom DWD ist nur 1 Stunde Vergangenheit verfügbar."
        }
        switch store.historyStatus {
        case .unavailable:
            return base + " Historie nicht verfügbar: Die Zeitleiste zeigt vorerst nur etwa die letzte Stunde."
        case .loaded(let hours) where hours < RadarPastWindow.options.last!:
            return base + " Der Server liefert derzeit höchstens \(RadarPastWindow.label(hours))."
        default:
            return base
        }
    }
}
