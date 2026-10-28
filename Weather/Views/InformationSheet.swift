import SwiftUI

struct InformationSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("ShowerNow · frühe Testversion") {
                    Text("Regenradar und kurzfristige Ortsprognose für Deutschland. Noch keine automatischen Regenwarnungen, Widgets oder Watch-App.")
                    Text("Die Karte zeigt Messbilder und Radarvorhersagen getrennt. Die Punktprognose basiert auf Fünf-Minuten-Intervallen; minutengenaue Zusagen sind daraus nicht ableitbar.")
                }
                Section("Datenquellen") {
                    Text("Datenbasis: Deutscher Wetterdienst. Radarbilder über den DWD-Kartendienst; Niederschlagswerte für die Ortsprognose umgerechnet und aufbereitet.")
                    Link("Deutscher Wetterdienst · Open Data", destination: URL(string: "https://opendata.dwd.de/weather/radar/composite/rv/")!)
                    Link("DWD · Nutzungsbedingungen", destination: URL(string: "https://www.dwd.de/DE/service/copyright/copyright_node.html")!)
                    Text("Karte und Ortssuche: Apple MapKit. Quellenhinweise der Karte bleiben eingeblendet.")
                }
                Section("Datenschutz") {
                    Text("Kein Konto, kein eigener Server und keine Analyse- oder Werbe-SDKs. Gespeicherte Orte und eigene Namen bleiben lokal.")
                    Text("Die App verbindet sich direkt mit DWD und Apple. Für eine Ortsprognose erhält der DWD einen Kartenausschnitt um die ausgewählte Position. Karten und Suchanfragen werden von Apple verarbeitet. Dabei fallen Netzwerkdaten wie die IP-Adresse an.")
                    Text("Standortzugriff ist optional und wird nur bei Nutzung angefordert. Keine Hintergrundortung. Punktanfragen werden nicht in einem Festplatten-Netzwerkcache gespeichert.")
                    Text("Die App ist eine frühe Testversion. Prognosen können abweichen; bei fehlenden oder veralteten Daten wird keine aktuelle Aussage zugesichert.")
                }
            }
            .navigationTitle("Über ShowerNow")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
        }
    }
}
