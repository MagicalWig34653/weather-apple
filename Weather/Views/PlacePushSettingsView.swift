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
                Toggle("Regenhinweis", isOn: Binding(
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
                Text("Du bekommst eine Mitteilung, wenn es hier bald zu regnen beginnt. Der ShowerNow-Server wertet dafür alle paar Minuten das Radar für diesen Ort aus.")
            }

            if let settings {
                Section {
                    Picker("Vorlaufzeit", selection: Binding(
                        get: { settings.leadMinutes },
                        set: { value in Task { await push.update(placeID: place.id, leadMinutes: value) } })) {
                        ForEach(PushLead.options, id: \.self) { Text("\($0) Minuten").tag($0) }
                    }
                    Picker("Empfindlichkeit", selection: Binding(
                        get: { settings.sensitivity },
                        set: { value in Task { await push.update(placeID: place.id, sensitivity: value) } })) {
                        ForEach(PushSensitivity.allCases) { Text("\($0.title) (\($0.detail))").tag($0) }
                    }
                    Toggle("Zeitkritisch", isOn: Binding(
                        get: { settings.timeSensitive },
                        set: { value in Task { await push.update(placeID: place.id, timeSensitive: value) } }))
                    .accessibilityIdentifier("push-time-sensitive")
                } header: {
                    Text("Einstellungen")
                } footer: {
                    Text("Hinweis, wenn es innerhalb der Vorlaufzeit mindestens so stark regnen soll (Stufen der Radar-Legende). Danach höchstens eine Meldung pro Stunde und Ort. Zeitkritisch: Die Meldung durchbricht Fokus und Mitteilungszusammenfassung. Den Stummschalter umgeht sie nicht. In den Systemeinstellungen kannst du das für ShowerNow abschalten.")
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
                    Button("Systemeinstellungen öffnen") {
                        if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                    }
                    .accessibilityIdentifier("push-open-settings")
                } footer: {
                    Text("Mitteilungen sind für ShowerNow im System ausgeschaltet. Dort kannst du sie wieder erlauben.")
                }
            }

            Section("Zustellung") {
                Label("Zeitkritisch (oben, standardmäßig aus): Meldungen können einen Fokus oder die Mitteilungszusammenfassung durchbrechen, den Stummschalter aber nicht.", systemImage: "bell.badge")
                Label("Apple Watch: Ist dein iPhone gesperrt (etwa beim Sport), erscheinen Mitteilungen auf der Uhr, meist mit Vibration. In der Watch-App unter Mitteilungen ShowerNow spiegeln lassen.", systemImage: "applewatch")
                Label("Sport: Beim Radfahren, Laufen oder anderem Training trage ShowerNow in dem Fokus, den du dafür nutzt, als erlaubte App ein, sonst bleibt die Meldung dort stumm.", systemImage: "figure.run")
            }
            .font(.footnote)
            .labelStyle(PushHintLabelStyle())

            Section {
                Text("An den Server gehen: das Gerätetoken deines iPhones, eine zufällige Installations-Kennung, eine Rasterzelle von etwa 1 km Kantenlänge um diesen Ort sowie Schwelle und Vorlaufzeit. Keine Koordinaten, kein Ortsname, kein Konto.")
                SitePageButton(page: .privacy, selection: $sitePage)
            }
            .font(.footnote).foregroundStyle(.secondary)
        }
        .navigationTitle("Regenhinweis")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await push.refreshAuthorization()
            await push.refreshLiveActivitySupport()
        }
        .sitePageSheet($sitePage)
        .alert("Regenhinweis aktivieren?", isPresented: $confirmEnable) {
            Button("Weiter") {
                working = true
                Task {
                    await push.enable(placeID: place.id, latitude: place.coordinate.latitude, longitude: place.coordinate.longitude)
                    working = false
                }
            }
            Button("Datenschutzerklärung lesen") { sitePage = .privacy }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("ShowerNow meldet dir per Mitteilung, wenn es bei \(place.name) bald zu regnen beginnt. Dafür gehen an den ShowerNow-Server: das Gerätetoken, eine Rasterzelle von etwa 1 km (keine Koordinaten), Schwelle und Vorlaufzeit; kein Konto. Danach fragt iOS, ob Mitteilungen erlaubt sind.")
        }
    }

    @ViewBuilder private var statusRow: some View {
        if let message = push.messages[place.id] {
            VStack(alignment: .leading, spacing: 6) {
                Label(message, systemImage: "exclamationmark.triangle").font(.footnote).foregroundStyle(.orange)
                if settings != nil {
                    Button("Jetzt erneut versuchen") { Task { await push.start() } }.font(.footnote)
                }
            }
        } else if settings != nil {
            Label(push.status(for: place.id) == .active ? "Aktiv" : "Wird eingerichtet …",
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
