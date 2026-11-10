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
                Text(NSLocalizedString("INFO_TEST_SEND", value: "Testmeldung senden", comment: "Info"))
                if push.testState == .sending { Spacer(); ProgressView() }
            }
        }
        .disabled(push.testState == .sending || !push.canSendTest)
        .accessibilityIdentifier("push-test-button")
        switch push.testState {
        case .sent:
            Label(NSLocalizedString("PUSH_TEST_SENT", value: "Testmeldung gesendet. Sie sollte gleich ankommen (höchstens 3 pro Stunde).", comment: "Info"), systemImage: "checkmark.circle")
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
            .navigationTitle(NSLocalizedString("INFO_TITLE", value: "Über Showers", comment: "Info"))
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
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(NSLocalizedString("COMMON_DONE", value: "Fertig", comment: "Common")) { dismiss() } } }
            .sitePageSheet($sitePage)
            .task {
                await warn.refreshCapabilities()
                await deviceLink.refresh()
                await deviceLink.runWindowPolling()
            }
        }
    }

    @ViewBuilder private var widgetsContent: some View {
                Section(NSLocalizedString("INFO_ROW_WIDGETS", value: "Widgets und Apple Watch", comment: "Info")) {
                    Text(NSLocalizedString("INFO_WIDGETS_1", value: "Widgets verwenden deine gespeicherten Orte. Den Ort wählst du beim Bearbeiten des Widgets; Antippen öffnet ihn in der App. Die Aktualisierung im Hintergrund bestimmt das System. Achte auf das angezeigte Datenalter.", comment: "Info"))
                    Text(NSLocalizedString("INFO_WIDGETS_2", value: "Deine gespeicherten Orte werden mit Name, Koordinate und Kennung an deine gekoppelte Apple Watch übertragen, wenn dort Showers installiert ist. Die Übertragung kann verzögert erfolgen. Ein aktueller, nicht gespeicherter Standort wird nicht übertragen.", comment: "Info"))
                }
                if let d = WidgetDiagnostics.load() {
                    Section(NSLocalizedString("INFO_WIDGET_DIAG_TITLE", value: "Diagnose", comment: "Info")) {
                        Text(String(format: NSLocalizedString("INFO_WIDGET_DIAG_RUN", value: "Widget zuletzt aktualisiert: %@ (%@)", comment: "Info"),
                                    d.lastRun.formatted(date: .abbreviated, time: .shortened), Self.diagOutcomeText(d.outcome)))
                        if let ref = d.dataReference {
                            Text(String(format: NSLocalizedString("INFO_WIDGET_DIAG_DATA", value: "Datenstand: %@", comment: "Info"), LocaleFormat.time(ref)))
                        }
                        Text(String(format: NSLocalizedString("INFO_WIDGET_DIAG_NEXT", value: "Nächste Aktualisierung angefordert: %@", comment: "Info"), LocaleFormat.time(d.nextReload)))
                    }
                }
    }

    private static func diagOutcomeText(_ outcome: WidgetDiagnostics.Outcome) -> String {
        switch outcome {
        case .live: NSLocalizedString("INFO_WIDGET_DIAG_LIVE", value: "neu geladen", comment: "Info")
        case .cache: NSLocalizedString("INFO_WIDGET_DIAG_CACHE", value: "gespeicherte Prognose", comment: "Info")
        case .unavailable: NSLocalizedString("INFO_WIDGET_DIAG_UNAVAILABLE", value: "nicht verfügbar", comment: "Info")
        }
    }

    @ViewBuilder private var alertsContent: some View {
                WarnSettingsView(manager: warn)
                Section {
                    Text(push.summary).accessibilityIdentifier("push-status")
                    if push.isAnyEnabled {
                        Button(NSLocalizedString("INFO_ALERTS_OFF_ALL", value: "Alle Mitteilungen ausschalten", comment: "Info"), role: .destructive) { Task { await push.resetAll() } }
                    }
                    if push.canSendTest || push.testState != .idle {
                        testRow
                    }
                    if let installationID = push.installationID {
                        InstallationIDRow(installationID: installationID)
                    }
                    SitePageButton(page: .privacy, selection: $sitePage)
                } header: {
                    Text(NSLocalizedString("INFO_ROW_ALERTS", value: "Mitteilungen", comment: "Info"))
                } footer: {
                    Text(NSLocalizedString("INFO_ALERTS_FOOTER", value: "Einstellen kannst du Regenhinweise je Ort (Glockensymbol) oder für Regionen unter „Deine Orte“. Ausschalten löscht die Registrierung auf dem Server.", comment: "Info"))
                }
    }

    @ViewBuilder private var sourcesContent: some View {
                Section(NSLocalizedString("INFO_ROW_SOURCES", value: "Datenquellen", comment: "Info")) {
                    Text(String(format: NSLocalizedString("INFO_SOURCES_1", value: "%1$@. %2$@. Niederschlagswerte für die Ortsprognose umgerechnet und aufbereitet.", comment: "Info"), store.radarAttribution.attribution, store.radarAttribution.modificationNotice))
                    Text(String(format: NSLocalizedString("INFO_SOURCES_2", value: "Radarbilder aktuell: %@. Normalerweise liefert der Showers-Radar-Server die Bilder; bei Fehlern oder veralteten Daten lädt die App sie selbstständig direkt vom DWD-Kartendienst.", comment: "Info"), store.radarSource.label))
                    layerSources
                    Link(NSLocalizedString("INFO_LINK_DWD", value: "Deutscher Wetterdienst · Open Data", comment: "Info"), destination: URL(string: "https://opendata.dwd.de/weather/radar/composite/rv/")!)
                    Link(NSLocalizedString("INFO_LINK_DWD_TERMS", value: "DWD · Nutzungsbedingungen", comment: "Info"), destination: URL(string: "https://www.dwd.de/DE/service/copyright/copyright_node.html")!)
                    Text(NSLocalizedString("INFO_SOURCES_MAPKIT", value: "Karte und Ortssuche: Apple MapKit. Quellenhinweise der Karte bleiben eingeblendet.", comment: "Info"))
                    Text(NSLocalizedString("INFO_SOURCES_WARN_AREAS", value: "Warngebiete (Landkreise und kreisfreie Städte): Quelle: Deutscher Wetterdienst, © GeoBasis-DE / BKG 2021 (Daten modifiziert).", comment: "Info"))
                }
    }

    @ViewBuilder private var privacyContent: some View {
                Section(NSLocalizedString("INFO_ROW_PRIVACY", value: "Datenschutz", comment: "Info")) {
                    Text(NSLocalizedString("INFO_PRIVACY_1", value: "Kein Konto und keine Analyse- oder Werbe-SDKs. Gespeicherte Orte, ihre Namen und deine Einstellungen bleiben auf deinem Gerät und deiner gekoppelten Apple Watch. Nur wenn du Regenhinweise einschaltest, geht eine gröbere Ortsangabe an den Radar-Dienst (siehe unten).", comment: "Info"))
                    Text(NSLocalizedString("INFO_PRIVACY_2", value: "Widgets und Apple Watch verwenden ausschließlich gespeicherte Orte und rufen deren Prognosen direkt beim DWD ab. Die Kopplung überträgt nur die aktuelle Ortsliste, keinen Standortverlauf. Die zuletzt gültige Prognose je Ort wird lokal für Widgets gespeichert.", comment: "Info"))
                    Text(NSLocalizedString("INFO_PRIVACY_3", value: "Radarbilder lädt die App vom Showers-Radar-Dienst. Der Radar-Dienst selbst führt keine Zugriffsprotokolle und speichert keine IP-Adressen oder Abfragedetails. Ihm ist ein Reverse Proxy vorgeschaltet, der technisch bedingt die IP-Adresse jedes Abrufs sieht und sie befristet protokolliert; die Radar-Anfragen enthalten keinen Ort, keine Cookies und keine Kennung. Bei Fehlern oder veralteten Daten ruft die App die Radarbilder direkt beim DWD ab. Bilder der Zusatzebenen kommen nur vom Radar-Dienst. Blendest du die Legende der Blitze ein, lädt die App das Legendenbild direkt vom DWD (bei Wolken ggf. von EUMETSAT); dabei sieht die jeweilige Stelle technisch bedingt deine IP-Adresse, aber keinen Ort.", comment: "Info"))
                    Text(NSLocalizedString("INFO_PRIVACY_4", value: "Die Prognose für einen Ort fragt die App direkt beim DWD ab; dabei sind der abgefragte Punkt und, wie bei jeder Internetverbindung, deine IP-Adresse für den DWD sichtbar. Karten und Suchanfragen werden von Apple verarbeitet: Bei der Ortssuche gehen Suchtext und ein fester Suchbereich (Deutschland, nicht dein Standort) an Apple, nie an den Radar-Dienst oder den DWD; Apple sieht dabei technisch bedingt die IP-Adresse. Es gelten Apples Datenschutzbestimmungen.", comment: "Info"))
                    Text(NSLocalizedString("INFO_PRIVACY_5", value: "Die Karte auf der Apple Watch wird über Apple Karten geladen; dabei geht die Koordinate des Ortes an Apple. Die Radarbilder kommen ohne Ortsangabe vom Server.", comment: "Info"))
                    Text(NSLocalizedString("INFO_PRIVACY_6", value: "Nur wenn du Regenhinweise für einen Ort einschaltest: Der Radar-Dienst erhält dein Gerätetoken, eine zufällige Installationskennung, die Rasterzelle des Radarbildes um den Ort (Kantenlänge etwa 0,7 km; keine Koordinaten, kein Ortsname) sowie Schwelle und Vorlaufzeit; kein Konto. Bei einer Region speichert der Server stattdessen einen groben Bereich: den Mittelpunkt gröber als eine Rasterzelle (etwa 2 km), den Radius und den Auslöseanteil; der Name der Region bleibt auf dem Gerät. Beim Ausschalten, Löschen des Orts oder der Region oder Zurücksetzen werden diese Daten gelöscht.", comment: "Info"))
                    Text("DEVICE_LINK_PRIVACY")
                    Text(NSLocalizedString("INFO_PRIVACY_LOCATION", value: "Standortzugriff ist optional und wird nur bei Nutzung angefordert. Keine Hintergrundortung. Punktanfragen werden nicht in einem Festplatten-Netzwerkcache gespeichert.", comment: "Info"))
                    SitePageButton(page: .privacy, selection: $sitePage)
                    SitePageButton(page: .support, selection: $sitePage)
                    SitePageButton(page: .about, selection: $sitePage)
                    Text(NSLocalizedString("INFO_PRIVACY_BETA", value: "Prognosen können abweichen. Bei fehlenden oder veralteten Daten gibt die App keine aktuelle Aussage.", comment: "Info"))
                }
    }

    @ViewBuilder private var supportContent: some View {
        Section {
            SitePageButton(page: .privacy, selection: $sitePage)
            SitePageButton(page: .support, selection: $sitePage)
            SitePageButton(page: .about, selection: $sitePage)
        }
        Section { Text(NSLocalizedString("INFO_SUPPORT_FOOTER", value: "Showers", comment: "Info")).font(.footnote).foregroundStyle(.secondary) }
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
        Text(NSLocalizedString("INFO_LAYER_SOURCES_NOTE", value: "Zusatzebenen (Luftdruck, Blitze, Wolken, Temperatur, Feuchte) liefert der Showers-Radar-Dienst. Sind sie dort nicht verfügbar, sind sie ausgegraut. Ein Direktabruf beim DWD ist dafür nicht vorgesehen.", comment: "Info"))
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
                .accessibilityHint(unavailable ? NSLocalizedString("INFO_PAST_UNAVAILABLE_HINT", value: "Derzeit nicht verfügbar", comment: "Info") : "")
                .accessibilityIdentifier("past-hours-\(hours)")
            }
        } header: {
            Text(NSLocalizedString("INFO_ROW_PAST", value: "Maximale Vergangenheit", comment: "Info"))
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
        let base = NSLocalizedString("INFO_PAST_FOOTER_BASE", value: "Wie weit die Zeitleiste in die Vergangenheit reicht. Mehr Vergangenheit lädt mehr Bilder (Datenvolumen).", comment: "Info")
        if store.radarSource == .direct {
            return base + " " + NSLocalizedString("INFO_PAST_FOOTER_DIRECT", value: "Beim Abruf direkt vom DWD ist nur 1 Stunde Vergangenheit verfügbar.", comment: "Info")
        }
        switch store.historyStatus {
        case .unavailable:
            return base + " " + NSLocalizedString("INFO_PAST_FOOTER_UNAVAILABLE", value: "Historie nicht verfügbar: Die Zeitleiste zeigt derzeit nur etwa die letzte Stunde.", comment: "Info")
        case .loaded(let hours) where hours < RadarPastWindow.options.last!:
            return base + " " + String(format: NSLocalizedString("INFO_PAST_FOOTER_SERVER_MAX", value: "Der Server liefert derzeit höchstens %@.", comment: "Info"), RadarPastWindow.label(hours))
        default:
            return base
        }
    }
}

/// Source lines for the model layers (temperature, dew point, humidity) and the optional forest layer; shown only while the layers exist.
enum ModelLayerSources {
    struct Line: Equatable { let id: String, text: String }

    static var iconText: String { NSLocalizedString("INFO_MODEL_ICON", value: "Temperatur-, Taupunkt- und Feuchtekarten: DWD ICON-D2/ICON-EU Modelldaten (CC BY 4.0, Quelle: Deutscher Wetterdienst), bildlich wiedergegeben und aufbereitet (verändert). Modellprognosen, keine Messwerte.", comment: "Info") }

    static func visibleLayers(manifestPresent: (RadarLayer) -> Bool) -> [RadarLayer] {
        [RadarLayer.temperature, .dewpoint, .humidity].filter(manifestPresent)
    }

    static func lines(modelLayersAvailable: Bool, forest: ForestInfo?) -> [Line] {
        guard modelLayersAvailable else { return [] }
        var result = [Line(id: "icon", text: iconText)]
        if let forest {
            result.append(Line(id: "worldcover", text: String(format: NSLocalizedString("INFO_MODEL_FOREST", value: "Optionale Waldfläche: %1$@ (CC BY 4.0); %2$@.", comment: "Info"), forest.attribution, forest.modificationNotice)))
        }
        return result
    }
}
