import SwiftUI

struct InformationSheet: View {
    var store: WeatherStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("ShowerNow · frühe Testversion") {
                    Text("Regenradar und kurzfristige Ortsprognose für Deutschland. Noch keine automatischen Regenwarnungen, Widgets oder Watch-App.")
                    Text("Die Karte zeigt Messbilder und Radarvorhersagen getrennt. Die Punktprognose basiert auf Fünf-Minuten-Intervallen; minutengenaue Zusagen sind daraus nicht ableitbar.")
                }
                pastSection
                Section("Datenquellen") {
                    Text("\(store.radarAttribution.attribution). \(store.radarAttribution.modificationNotice). Niederschlagswerte für die Ortsprognose umgerechnet und aufbereitet.")
                    Text("Radarbilder aktuell: \(store.radarSource.label). Normalerweise liefert der ShowerNow-Radar-Server die Bilder; bei Fehlern oder veralteten Daten lädt die App sie selbstständig direkt vom DWD-Kartendienst.")
                    Link("Deutscher Wetterdienst · Open Data", destination: URL(string: "https://opendata.dwd.de/weather/radar/composite/rv/")!)
                    Link("DWD · Nutzungsbedingungen", destination: URL(string: "https://www.dwd.de/DE/service/copyright/copyright_node.html")!)
                    Text("Karte und Ortssuche: Apple MapKit. Quellenhinweise der Karte bleiben eingeblendet.")
                }
                Section("Datenschutz") {
                    Text("Kein Konto und keine Analyse- oder Werbe-SDKs. Gespeicherte Orte und eigene Namen bleiben lokal.")
                    Text("Radarbilder lädt die App vom ShowerNow-Radar-Server. Der Radar-Dienst selbst führt keine Zugriffsprotokolle und speichert keine IP-Adressen oder Abfragedetails. Wie bei jeder Internetverbindung sieht der vorgeschaltete Server technisch bedingt die IP-Adresse deines Abrufs; die Radar-Anfragen enthalten keinen Ort, keine Cookies und keine Kennung. Bei Fehlern oder veralteten Daten ruft die App die Radarbilder direkt beim DWD ab.")
                    Text("Für eine Ortsprognose erhält der DWD weiterhin direkt einen Kartenausschnitt um die ausgewählte Position. Karten und Suchanfragen werden von Apple verarbeitet: Bei der Ortssuche gehen Suchtext und ein fester Suchbereich (Deutschland, nicht dein Standort) an Apple, nie an den Radar-Dienst oder den DWD; Apple sieht dabei technisch bedingt die IP-Adresse. Es gelten Apples Datenschutzbestimmungen.")
                    Text("Standortzugriff ist optional und wird nur bei Nutzung angefordert. Keine Hintergrundortung. Punktanfragen werden nicht in einem Festplatten-Netzwerkcache gespeichert.")
                    Link("Datenschutzerklärung", destination: RadarBackendConfig.privacyPolicyURL)
                        .accessibilityHint("Öffnet die Datenschutzerklärung im Browser")
                        .accessibilityIdentifier("privacy-policy-link")
                    Text("Die App ist eine frühe Testversion. Prognosen können abweichen; bei fehlenden oder veralteten Daten wird keine aktuelle Aussage zugesichert.")
                }
            }
            .navigationTitle("Über ShowerNow")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
        }
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
