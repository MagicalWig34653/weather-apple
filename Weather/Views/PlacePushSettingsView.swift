import SwiftUI
import UIKit

/// Per-place rain-hint settings (opt-in). The explanation comes BEFORE the system permission prompt.
struct PlacePushSettingsView: View {
    let place: SavedPlace
    @Environment(PushManager.self) private var push
    @Environment(\.openURL) private var openURL
    @State private var confirmEnable = false
    @State private var working = false
    @State private var sitePage: SitePage?

    private var settings: PlacePushSettings? { push.settings(for: place.id) }

    var body: some View {
        List {
            Section {
                Toggle(NSLocalizedString("PUSH_ALERT_LABEL", value: "Regenhinweis", comment: "Push"), isOn: Binding(
                    get: { settings != nil },
                    set: { on in
                        if on { confirmEnable = true } else { Task { await push.disable(placeID: place.id) } }
                    }))
                .disabled(working)
                .accessibilityIdentifier("push-toggle")
                statusRow
            } header: {
                Text(place.name)
            } footer: {
                Text(NSLocalizedString("PUSH_PLACE_FOOTER", value: "Du bekommst eine Mitteilung, wenn es hier bald zu regnen beginnt. Der Showers-Server wertet dafür alle paar Minuten das Radar für diesen Ort aus.", comment: "Push"))
            }

            if let settings {
                Section {
                    Picker(NSLocalizedString("PUSH_LEAD_TIME", value: "Vorlaufzeit", comment: "Push"), selection: Binding(
                        get: { settings.leadMinutes },
                        set: { value in Task { await push.update(placeID: place.id, leadMinutes: value) } })) {
                        ForEach(PushLead.options, id: \.self) { Text(String(format: NSLocalizedString("PUSH_LEAD_MINUTES", value: "%lld Minuten", comment: "Push"), $0)).tag($0) }
                    }
                    Picker(NSLocalizedString("PUSH_SENSITIVITY", value: "Empfindlichkeit", comment: "Push"), selection: Binding(
                        get: { settings.sensitivity },
                        set: { value in Task { await push.update(placeID: place.id, sensitivity: value) } })) {
                        ForEach(PushSensitivity.allCases) { Text(String(format: NSLocalizedString("PUSH_SENSITIVITY_ROW", value: "%1$@ (%2$@)", comment: "Push"), $0.title, $0.detail)).tag($0) }
                    }
                    Toggle(NSLocalizedString("PUSH_TIME_SENSITIVE", value: "Zeitkritisch", comment: "Push"), isOn: Binding(
                        get: { settings.timeSensitive },
                        set: { value in Task { await push.update(placeID: place.id, timeSensitive: value) } }))
                    .accessibilityIdentifier("push-time-sensitive")
                } header: {
                    Text(NSLocalizedString("PUSH_SETTINGS_HEADER", value: "Einstellungen", comment: "Push"))
                } footer: {
                    Text(NSLocalizedString("PUSH_PLACE_SETTINGS_FOOTER", value: "Hinweis, wenn es innerhalb der Vorlaufzeit mindestens so stark regnen soll (Stufen der Radar-Legende). Danach höchstens eine Meldung pro Stunde und Ort. Zeitkritisch: Die Meldung durchbricht Fokus und Mitteilungszusammenfassung. Den Stummschalter umgeht sie nicht. In den Systemeinstellungen kannst du das für Showers abschalten.", comment: "Push"))
                }
            }

            if let settings, push.liveActivitySupport == .supported || settings.liveActivity {
                Section {
                    Toggle(RainActivityText.title.text(), isOn: Binding(
                        get: { settings.liveActivity },
                        set: { enabled in Task { await push.setLiveActivity(placeID: place.id, enabled: enabled) } }))
                    .disabled(!settings.liveActivity && (!push.liveActivitiesEnabled || push.liveActivitySupport != .supported))
                    .accessibilityIdentifier("push-live-activity")
                    if let message = push.liveActivityMessages[place.id] {
                        Text(message).font(.footnote).foregroundStyle(.secondary)
                            .accessibilityIdentifier("push-live-activity-status")
                    }
                    Text(RainActivityText.explanation.text()).font(.footnote).foregroundStyle(.secondary)
                    if !push.liveActivitiesEnabled || push.liveActivitySupport != .supported {
                        Text(RainActivityText.unavailable.text()).font(.footnote).foregroundStyle(.secondary)
                    }
                } footer: {
                    Text(RainActivityText.privacy.text())
                }
            }

            if push.authorization == .denied {
                Section {
                    Button(NSLocalizedString("PUSH_OPEN_SYSTEM_SETTINGS", value: "Systemeinstellungen öffnen", comment: "Push")) {
                        if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                    }
                    .accessibilityIdentifier("push-open-settings")
                } footer: {
                    Text(NSLocalizedString("PUSH_DENIED_FOOTER", value: "Mitteilungen sind für Showers im System ausgeschaltet. Dort kannst du sie wieder erlauben.", comment: "Push"))
                }
            }

            Section(NSLocalizedString("PUSH_DELIVERY_HEADER", value: "Zustellung", comment: "Push")) {
                Label(NSLocalizedString("PUSH_DELIVERY_TIME_SENSITIVE", value: "Zeitkritisch (oben, standardmäßig aus): Meldungen können einen Fokus oder die Mitteilungszusammenfassung durchbrechen, den Stummschalter aber nicht.", comment: "Push"), systemImage: "bell.badge")
                Label(NSLocalizedString("PUSH_DELIVERY_WATCH", value: "Apple Watch: Ist dein iPhone gesperrt (etwa beim Sport), erscheinen Mitteilungen auf der Uhr, meist mit Vibration. In der Watch-App unter Mitteilungen Showers spiegeln lassen.", comment: "Push"), systemImage: "applewatch")
                Label(NSLocalizedString("PUSH_DELIVERY_SPORT", value: "Sport: Beim Radfahren, Laufen oder anderem Training trage Showers in dem Fokus, den du dafür nutzt, als erlaubte App ein, sonst bleibt die Meldung dort stumm.", comment: "Push"), systemImage: "figure.run")
            }
            .font(.footnote)
            .labelStyle(PushHintLabelStyle())

            Section {
                Text(NSLocalizedString("PUSH_PLACE_PRIVACY", value: "An den Server gehen: das Gerätetoken deines iPhones, eine zufällige Installations-Kennung, eine Rasterzelle von etwa 1 km Kantenlänge um diesen Ort sowie Schwelle und Vorlaufzeit. Keine Koordinaten, kein Ortsname, kein Konto.", comment: "Push"))
                SitePageButton(page: .privacy, selection: $sitePage)
            }
            .font(.footnote).foregroundStyle(.secondary)
        }
        .navigationTitle(NSLocalizedString("PUSH_ALERT_LABEL", value: "Regenhinweis", comment: "Push"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await push.refreshAuthorization()
            await push.refreshLiveActivitySupport()
        }
        .sitePageSheet($sitePage)
        .alert(NSLocalizedString("PUSH_PLACE_CONFIRM_TITLE", value: "Regenhinweis aktivieren?", comment: "Push"), isPresented: $confirmEnable) {
            Button(NSLocalizedString("PUSH_CONTINUE", value: "Weiter", comment: "Push")) {
                working = true
                Task {
                    await push.enable(placeID: place.id, latitude: place.coordinate.latitude, longitude: place.coordinate.longitude)
                    working = false
                }
            }
            Button(NSLocalizedString("PUSH_READ_PRIVACY", value: "Datenschutzerklärung lesen", comment: "Push")) { sitePage = .privacy }
            Button(NSLocalizedString("COMMON_CANCEL", value: "Abbrechen", comment: "Common"), role: .cancel) {}
        } message: {
            Text(String(format: NSLocalizedString("PUSH_PLACE_CONFIRM_MESSAGE", value: "Showers meldet dir per Mitteilung, wenn es bei %@ bald zu regnen beginnt. Dafür gehen an den Showers-Server: das Gerätetoken, eine Rasterzelle von etwa 1 km (keine Koordinaten), Schwelle und Vorlaufzeit; kein Konto. Danach fragt iOS, ob Mitteilungen erlaubt sind.", comment: "Push"), place.name))
        }
    }

    @ViewBuilder private var statusRow: some View {
        if let message = push.messages[place.id] {
            VStack(alignment: .leading, spacing: 6) {
                Label(message, systemImage: "exclamationmark.triangle").font(.footnote).foregroundStyle(.orange)
                if settings != nil {
                    Button(NSLocalizedString("PUSH_RETRY_NOW", value: "Jetzt erneut versuchen", comment: "Push")) { Task { await push.start() } }.font(.footnote)
                }
            }
        } else if settings != nil {
            Label(push.status(for: place.id) == .active ? NSLocalizedString("PUSH_STATUS_ACTIVE", value: "Aktiv", comment: "Push") : NSLocalizedString("PUSH_STATUS_SETTING_UP", value: "Wird eingerichtet …", comment: "Push"),
                  systemImage: push.status(for: place.id) == .active ? "checkmark.circle" : "clock")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }
}

private struct PushHintLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .top, spacing: 10) {
            configuration.icon.foregroundStyle(.secondary).frame(width: 24)
            configuration.title
        }
    }
}
