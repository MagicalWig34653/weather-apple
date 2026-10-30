import SwiftUI

struct InformationSheet: View {
    var source: RadarSource = .cache
    var attribution: RadarAttribution = .default
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("ShowerNow · frühe Testversion") {
                    Text("Regenradar und kurzfristige Ortsprognose für Deutschland. Noch keine automatischen Regenwarnungen, Widgets oder Watch-App.")
                    Text("Die Karte zeigt Messbilder und Radarvorhersagen getrennt. Die Punktprognose basiert auf Fünf-Minuten-Intervallen; minutengenaue Zusagen sind daraus nicht ableitbar.")
                }
                Section("Datenquellen") {
                    Text("\(attribution.attribution). \(attribution.modificationNotice). Niederschlagswerte für die Ortsprognose umgerechnet und aufbereitet.")
                    Text("Radarbilder aktuell: \(source.label). Normalerweise liefert der ShowerNow-Radar-Server die Bilder; bei Fehlern oder veralteten Daten lädt die App sie selbstständig direkt vom DWD-Kartendienst.")
                    Link("Deutscher Wetterdienst · Open Data", destination: URL(string: "https://opendata.dwd.de/weather/radar/composite/rv/")!)
                    Link("DWD · Nutzungsbedingungen", destination: URL(string: "https://www.dwd.de/DE/service/copyright/copyright_node.html")!)
                    Text("Karte und Ortssuche: Apple MapKit. Quellenhinweise der Karte bleiben eingeblendet.")
                }
                Section("Datenschutz") {
                    Text("Kein Konto und keine Analyse- oder Werbe-SDKs. Gespeicherte Orte und eigene Namen bleiben lokal.")
                    Text("Radarbilder lädt die App vom ShowerNow-Radar-Server. Er sieht nur den Abruf selbst (technisch die IP-Adresse), keinen Ort, keine Cookies und keine Standortverläufe. Bei Fehlern oder veralteten Daten ruft die App die Radarbilder direkt beim DWD ab.")
                    Text("Für eine Ortsprognose erhält der DWD weiterhin direkt einen Kartenausschnitt um die ausgewählte Position. Karten und Suchanfragen werden von Apple verarbeitet. Dabei fallen Netzwerkdaten wie die IP-Adresse an.")
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
