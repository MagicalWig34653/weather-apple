import SwiftUI
import UIKit

struct InformationSheet: View {
    var store: WeatherStore
    @Environment(PushManager.self) private var push
    @Environment(DeviceLinkManager.self) private var deviceLink
    @Environment(WarnManager.self) private var warn
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

    private func page<Content: View>(_ title: LocalizedStringKey, id: String, @ViewBuilder _ content: () -> Content) -> some View {
        List { content() }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier(id)
    }

    private func row(_ title: LocalizedStringKey, id: String, symbol: String) -> some View {
        NavigationLink(value: id) { Label(title, systemImage: symbol) }
            .accessibilityIdentifier("info-row-\(id)")
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("INFO_INTRO_1")
                    Text("INFO_INTRO_2")
                }
                Section {
                    row("INFO_ROW_SOURCES", id: "sources", symbol: "map")
                    row("INFO_ROW_PRIVACY", id: "privacy", symbol: "hand.raised")
                    row("INFO_ROW_WIDGETS", id: "widgets", symbol: "applewatch")
                    row("INFO_ROW_ALERTS", id: "alerts", symbol: "bell")
                    row("INFO_ROW_PAST", id: "past", symbol: "clock.arrow.circlepath")
                    row("INFO_ROW_SUPPORT", id: "support", symbol: "questionmark.circle")
                }
                if deviceLink.isAvailable { DeviceLinkSection(manager: deviceLink) }
            }
            .navigationTitle("Über Showers")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: String.self) { id in
                switch id {
                case "sources": page("INFO_ROW_SOURCES", id: "info-page-sources") { sourcesContent }
                case "privacy": page("INFO_ROW_PRIVACY", id: "info-page-privacy") { privacyContent }
                case "widgets": page("INFO_ROW_WIDGETS", id: "info-page-widgets") { widgetsContent }
                case "alerts": page("INFO_ROW_ALERTS", id: "info-page-alerts") { alertsContent }
                case "past": page("INFO_ROW_PAST", id: "info-page-past") { pastSection }
                default: page("INFO_ROW_SUPPORT", id: "info-page-support") { supportContent }
                }
            }
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
            .sitePageSheet($sitePage)
            .task {
                await warn.refreshCapabilities()
                await deviceLink.refresh()
                await deviceLink.runWindowPolling()
            }
        }
    }

    @ViewBuilder private var widgetsContent: some View {
                Section("Widgets und Apple Watch") {
                    Text("Widgets verwenden deine gespeicherten Orte. Den Ort wählst du beim Bearbeiten des Widgets; Antippen öffnet ihn in der App. Die Aktualisierung im Hintergrund bestimmt das System. Achte auf das angezeigte Datenalter.")
                    Text("Deine gespeicherten Orte werden mit Name, Koordinate und Kennung an deine gekoppelte Apple Watch übertragen, wenn dort Showers installiert ist. Die Übertragung kann verzögert erfolgen. Ein aktueller, nicht gespeicherter Standort wird nicht übertragen.")
                }
    }

    @ViewBuilder private var alertsContent: some View {
                WarnSettingsView(manager: warn)
                Section {
                    Text(push.summary).accessibilityIdentifier("push-status")
                    if push.isAnyEnabled {
                        Button("Alle Mitteilungen ausschalten", role: .destructive) { Task { await push.resetAll() } }
                    }
                    if push.canSendTest || push.testState != .idle {
                        testRow
                    }
                    if let installationID = push.installationID {
                        InstallationIDRow(installationID: installationID)
                    }
                    SitePageButton(page: .privacy, selection: $sitePage)
                } header: {
                    Text("Mitteilungen")
                } footer: {
                    Text("Einstellen kannst du Regenhinweise je Ort (Glockensymbol) oder für Regionen unter „Deine Orte“. Ausschalten löscht die Registrierung auf dem Server.")
                }
    }

    @ViewBuilder private var sourcesContent: some View {
                Section("Datenquellen") {
                    Text("\(store.radarAttribution.attribution). \(store.radarAttribution.modificationNotice). Niederschlagswerte für die Ortsprognose umgerechnet und aufbereitet.")
                    Text("Radarbilder aktuell: \(store.radarSource.label). Normalerweise liefert der Showers-Radar-Server die Bilder; bei Fehlern oder veralteten Daten lädt die App sie selbstständig direkt vom DWD-Kartendienst.")
                    layerSources
                    Link("Deutscher Wetterdienst · Open Data", destination: URL(string: "https://opendata.dwd.de/weather/radar/composite/rv/")!)
                    Link("DWD · Nutzungsbedingungen", destination: URL(string: "https://www.dwd.de/DE/service/copyright/copyright_node.html")!)
                    Text("Karte und Ortssuche: Apple MapKit. Quellenhinweise der Karte bleiben eingeblendet.")
                    Text("Warngebiete (Landkreise und kreisfreie Städte): Quelle: Deutscher Wetterdienst, © GeoBasis-DE / BKG 2021 (Daten modifiziert).")
                }
    }

    @ViewBuilder private var privacyContent: some View {
                Section("Datenschutz") {
                    Text("Kein Konto und keine Analyse- oder Werbe-SDKs. Gespeicherte Orte und eigene Namen bleiben auf deinem iPhone und deiner gekoppelten Apple Watch; sie werden nicht an den Showers-Server übertragen.")
                    Text("Widgets und Apple Watch verwenden ausschließlich gespeicherte Orte und rufen deren Prognosen direkt beim DWD ab. Die Kopplung überträgt nur die aktuelle Ortsliste, keinen Standortverlauf. Die zuletzt gültige Prognose je Ort wird lokal für Widgets gespeichert.")
                    Text("Radarbilder lädt die App vom Showers-Radar-Server. Der Radar-Dienst selbst führt keine Zugriffsprotokolle und speichert keine IP-Adressen oder Abfragedetails. Wie bei jeder Internetverbindung sieht der vorgeschaltete Server technisch bedingt die IP-Adresse deines Abrufs; die Radar-Anfragen enthalten keinen Ort, keine Cookies und keine Kennung. Bei Fehlern oder veralteten Daten ruft die App die Radarbilder direkt beim DWD ab. Bilder der Zusatzebenen kommen nur vom Showers-Server. Blendest du die Legende der Blitze ein, lädt die App das Legendenbild direkt vom DWD (bei Wolken ggf. von EUMETSAT); dabei sieht der Anbieter technisch bedingt deine IP-Adresse, aber keinen Ort.")
                    Text("Für eine Ortsprognose erhält der DWD weiterhin direkt einen Kartenausschnitt um die ausgewählte Position. Karten und Suchanfragen werden von Apple verarbeitet: Bei der Ortssuche gehen Suchtext und ein fester Suchbereich (Deutschland, nicht dein Standort) an Apple, nie an den Radar-Dienst oder den DWD; Apple sieht dabei technisch bedingt die IP-Adresse. Es gelten Apples Datenschutzbestimmungen.")
                    Text("Die Karte auf der Apple Watch wird über Apple Karten geladen; dabei geht die Koordinate des Ortes an Apple. Die Radarbilder kommen ohne Ortsangabe vom Server.")
                    Text("Nur wenn du Regenhinweise für einen Ort einschaltest: Der Showers-Server erhält dein Gerätetoken, eine zufällige Installations-Kennung, eine Rasterzelle von etwa 1 km um den Ort (keine Koordinaten, kein Ortsname) sowie Schwelle und Vorlaufzeit; kein Konto. Bei einer Region speichert der Server stattdessen einen groben Bereich: den Mittelpunkt gröber als eine Rasterzelle (etwa 2 km), den Radius und den Auslöseanteil; der Name der Region bleibt auf dem Gerät. Beim Ausschalten, Löschen des Orts oder der Region oder Zurücksetzen werden diese Daten gelöscht.")
                    Text("DEVICE_LINK_PRIVACY")
                    Text("Standortzugriff ist optional und wird nur bei Nutzung angefordert. Keine Hintergrundortung. Punktanfragen werden nicht in einem Festplatten-Netzwerkcache gespeichert.")
                    SitePageButton(page: .privacy, selection: $sitePage)
                    SitePageButton(page: .support, selection: $sitePage)
                    SitePageButton(page: .about, selection: $sitePage)
                    Text("Die App ist eine frühe Testversion. Prognosen können abweichen; bei fehlenden oder veralteten Daten wird keine aktuelle Aussage zugesichert.")
                }
    }

    @ViewBuilder private var supportContent: some View {
        Section {
            SitePageButton(page: .privacy, selection: $sitePage)
            SitePageButton(page: .support, selection: $sitePage)
            SitePageButton(page: .about, selection: $sitePage)
        }
        Section { Text("Showers · frühe Testversion").font(.footnote).foregroundStyle(.secondary) }
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
        let modelLayers = ModelLayerSources.visibleLayers(manifestPresent: { store.layers.snapshot($0).manifest != nil })
        ForEach(ModelLayerSources.lines(modelLayersAvailable: !modelLayers.isEmpty, forest: ForestInfo.bundled), id: \.id) { line in
            Text(line.text).accessibilityIdentifier("layer-source-\(line.id)")
        }
        if store.layers.snapshot(.clouds).manifest != nil {
            Link("EUMETSAT · EUMETView", destination: URL(string: "https://view.eumetsat.int")!)
        }
        Text("Zusatzebenen (Luftdruck, Blitze, Wolken, Temperatur, Feuchte) liefert der Showers-Server nur, wenn sie dort aktiviert sind; sonst sind sie ausgegraut. Einen Ersatzweg direkt beim DWD gibt es für sie nicht.")
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

/// Source lines for the model layers (temperature, dew point, humidity) and the optional forest layer; shown only while the layers exist.
enum ModelLayerSources {
    struct Line: Equatable { let id: String, text: String }

    static let iconText = "Temperatur-, Taupunkt- und Feuchtekarten: DWD ICON-D2/ICON-EU Modelldaten (CC BY 4.0, Quelle: Deutscher Wetterdienst), bildlich wiedergegeben und aufbereitet (verändert). Modellprognosen, keine Messwerte."

    static func visibleLayers(manifestPresent: (RadarLayer) -> Bool) -> [RadarLayer] {
        [RadarLayer.temperature, .dewpoint, .humidity].filter(manifestPresent)
    }

    static func lines(modelLayersAvailable: Bool, forest: ForestInfo?) -> [Line] {
        guard modelLayersAvailable else { return [] }
        var result = [Line(id: "icon", text: iconText)]
        if let forest {
            result.append(Line(id: "worldcover", text: "Optionale Waldfläche: \(forest.attribution) (CC BY 4.0); \(forest.modificationNotice)."))
        }
        return result
    }
}
