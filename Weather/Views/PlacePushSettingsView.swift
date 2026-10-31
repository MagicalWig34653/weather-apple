import SwiftUI
import UIKit

/// Per-place rain-hint settings (opt-in). The explanation comes BEFORE the system permission prompt.
struct PlacePushSettingsView: View {
    let place: SavedPlace
    @Environment(PushManager.self) private var push
    @Environment(\.openURL) private var openURL
    @State private var confirmEnable = false
    @State private var working = false

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
                } header: {
                    Text("Einstellungen")
                } footer: {
                    Text("Hinweis, wenn es innerhalb der Vorlaufzeit mindestens so stark regnen soll (Stufen der Radar-Legende). Danach höchstens eine Meldung pro Stunde und Ort.")
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
                Label("Zeitkritisch: Meldungen können einen Fokus oder die Mitteilungszusammenfassung durchbrechen. Du kannst das in den Systemeinstellungen für ShowerNow abschalten.", systemImage: "bell.badge")
                Label("Apple Watch: Ist dein iPhone gesperrt, erscheinen Mitteilungen auf der Uhr, meist mit Vibration. In der Watch-App unter Mitteilungen ShowerNow spiegeln lassen.", systemImage: "applewatch")
                Label("Radfahren: Trage ShowerNow im Fokus „Radfahren“ (oder „Fahren“) als erlaubte App ein, sonst bleibt die Meldung dort stumm.", systemImage: "figure.outdoor.cycle")
            }
            .font(.footnote)
            .labelStyle(PushHintLabelStyle())

            Section {
                Text("An den Server gehen: das Gerätetoken deines iPhones, eine zufällige Installations-Kennung, eine Rasterzelle von etwa 1 km Kantenlänge um diesen Ort sowie Schwelle und Vorlaufzeit. Keine Koordinaten, kein Ortsname, kein Konto.")
                Link("Datenschutzerklärung", destination: RadarBackendConfig.privacyPolicyURL)
            }
            .font(.footnote).foregroundStyle(.secondary)
        }
        .navigationTitle("Regenhinweis")
        .navigationBarTitleDisplayMode(.inline)
        .task { await push.refreshAuthorization() }
        .alert("Regenhinweis aktivieren?", isPresented: $confirmEnable) {
            Button("Weiter") {
                working = true
                Task {
                    await push.enable(placeID: place.id, latitude: place.coordinate.latitude, longitude: place.coordinate.longitude)
                    working = false
                }
            }
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
