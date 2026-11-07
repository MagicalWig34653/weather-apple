import SwiftUI

/// Warnings block of the "Mitteilungen" page: sections for a `List`. Only present with server capability `warnings_push`.
struct WarnSettingsView: View {
    let manager: WarnManager
    @State private var confirmEnable = false
    private typealias P = WarnSettingsPresentation

    var body: some View {
        let rows = P.rows(capability: manager.capabilityWarningsPush, settings: manager.settings)
        if !rows.isEmpty {
            Section {
                ForEach(rows.indices, id: \.self) { index in rowView(rows[index]) }
                if let notice = manager.notice {
                    Text(P.noticeText(notice)).font(.footnote).foregroundStyle(.secondary)
                        .accessibilityIdentifier("warn-notice")
                }
            } header: {
                Text("WARN_HEADER")
            } footer: {
                Text("WARN_FOOTER")
            }
        }
    }

    @ViewBuilder private func rowView(_ row: P.Row) -> some View {
        switch row {
        case .disclaimer:
            Label(P.disclaimer(), systemImage: "info.circle")
                .font(.footnote).foregroundStyle(.secondary)
                .accessibilityIdentifier("warn-disclaimer")
        case .mainToggle:
            Toggle("WARN_TOGGLE", isOn: Binding(
                get: { manager.settings.enabled },
                set: { on in if on { confirmEnable = true } else { Task { await manager.setEnabled(false) } } }))
            .accessibilityIdentifier("warn-toggle")
            .alert("WARN_CONFIRM_TITLE", isPresented: $confirmEnable) {
                Button("WARN_CONFIRM_ACTION") { Task { await manager.setEnabled(true) } }
                Button("WARN_CANCEL", role: .cancel) {}
            } message: {
                Text("WARN_CONFIRM_MESSAGE")
            }
        case .typeToggle(let kind):
            Toggle(P.kindTitle(kind), isOn: Binding(
                get: { manager.settings.types.contains(kind) },
                set: { on in Task { await manager.setType(kind, on: on) } }))
            .accessibilityIdentifier("warn-type-\(kind.rawValue)")
        case .minLevel(let kind):
            Picker("WARN_MIN_LEVEL", selection: Binding(
                get: { manager.settings.level(for: kind) },
                set: { level in Task { await manager.setMinSeverity(kind, level: level) } })) {
                ForEach(1...4, id: \.self) { Text(P.levelTitle($0)).tag($0) }
            }
            .accessibilityLabel(P.accessibilityLabel(row, settings: manager.settings))
            .accessibilityIdentifier("warn-level-\(kind.rawValue)")
        case .timeSensitive:
            Toggle("WARN_TIME_SENSITIVE", isOn: Binding(
                get: { manager.settings.timeSensitive },
                set: { on in Task { await manager.setTimeSensitive(on) } }))
            .accessibilityIdentifier("warn-time-sensitive")
        case .timeSensitiveHint:
            Text(P.timeSensitiveHint()).font(.footnote).foregroundStyle(.secondary)
        }
    }
}
