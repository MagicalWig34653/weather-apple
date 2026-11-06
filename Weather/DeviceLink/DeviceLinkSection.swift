import SwiftUI

/// "Betreiber-Diagnose" section of the info sheet. The caller inserts it only when `DeviceLinkManager.isAvailable`;
/// there is no hidden or disabled variant (the section must not exist at all in App Store installs).
struct DeviceLinkSection: View {
    var manager: DeviceLinkManager

    private var isOn: Binding<Bool> {
        Binding(get: {
            switch manager.phase {
            case .codeOpen, .linked, .requesting: true
            default: false
            }
        }, set: { value in Task { await manager.setEnabled(value) } })
    }

    var body: some View {
        Section {
            Toggle("DEVICE_LINK_TOGGLE", isOn: isOn)
                .disabled(manager.phase == .requesting)
                .accessibilityIdentifier("device-link-toggle")
            switch manager.phase {
            case .requesting:
                Label("DEVICE_LINK_REQUESTING", systemImage: "hourglass").font(.footnote).foregroundStyle(.secondary)
            case .codeOpen(let code, let expiresAt):
                codeView(code, expiresAt)
            case .linked(_, let expiresAt):
                linkedView(expiresAt)
            case .hidden, .off:
                EmptyView()
            }
            if let notice = manager.notice {
                Label(noticeKey(notice), systemImage: "exclamationmark.triangle")
                    .font(.footnote).foregroundStyle(.orange)
                    .accessibilityIdentifier("device-link-notice")
            }
        } header: {
            Text("DEVICE_LINK_HEADER")
        } footer: {
            Text("DEVICE_LINK_FOOTER")
        }
        .accessibilityIdentifier("device-link-section")
        .task(id: manager.phase) { await manager.runPolling() }
    }

    private func codeView(_ code: String, _ expiresAt: Date) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("DEVICE_LINK_CODE_HINT").font(.footnote).foregroundStyle(.secondary)
            Text(code)
                .font(.system(.title, design: .monospaced, weight: .semibold))
                .textSelection(.enabled)
                .accessibilityLabel(String(format: String(localized: "DEVICE_LINK_CODE_LABEL"),
                                           code.filter { $0 != "-" }.map(String.init).joined(separator: " ")))
                .accessibilityIdentifier("device-link-code")
            HStack(spacing: 4) {
                Text("DEVICE_LINK_CODE_REMAINING")
                Text(timerInterval: Date.now...max(expiresAt, Date.now), countsDown: true).monospacedDigit()
            }
            .font(.footnote).foregroundStyle(.secondary)
            .accessibilityElement(children: .combine)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder private func linkedView(_ expiresAt: Date?) -> some View {
        if let expiresAt {
            Label(String(format: String(localized: "DEVICE_LINK_LINKED_UNTIL"), expiresAt.formatted(date: .abbreviated, time: .shortened)),
                  systemImage: "checkmark.circle").font(.footnote).foregroundStyle(.secondary)
                .accessibilityIdentifier("device-link-state")
        } else {
            Label("DEVICE_LINK_LINKED", systemImage: "checkmark.circle").font(.footnote).foregroundStyle(.secondary)
                .accessibilityIdentifier("device-link-state")
        }
    }

    private func noticeKey(_ notice: DeviceLinkNotice) -> LocalizedStringKey {
        switch notice {
        case .linkFull: "DEVICE_LINK_NOTICE_FULL"
        case .rateLimited: "DEVICE_LINK_NOTICE_RATE"
        case .needsPush: "DEVICE_LINK_NOTICE_PUSH"
        case .offline: "DEVICE_LINK_NOTICE_OFFLINE"
        case .failed: "DEVICE_LINK_NOTICE_FAILED"
        case .codeExpired: "DEVICE_LINK_NOTICE_EXPIRED"
        }
    }
}
