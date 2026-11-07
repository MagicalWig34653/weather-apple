import SwiftUI
import UIKit

/// Display rules for the push installation ID shown for data-subject access requests.
/// Only the UUID is ever shown or copied, never the installation secret or any token.
enum InstallationIDDisplay {
    /// Lowercase UUID string, or nil if the value is missing or not a UUID.
    static func validated(_ raw: String?) -> String? {
        guard let raw, let uuid = UUID(uuidString: raw) else { return nil }
        return uuid.uuidString.lowercased()
    }
}

struct InstallationIDRow: View {
    let installationID: String
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("PUSH_INSTALLATION_ID_TITLE").font(.subheadline)
            Text(installationID)
                .font(.footnote.monospaced())
                .textSelection(.enabled)
                .accessibilityIdentifier("push-installation-id")
            Text("PUSH_INSTALLATION_ID_HINT").font(.footnote).foregroundStyle(.secondary)
            Button {
                UIPasteboard.general.string = installationID
                copied = true
            } label: {
                Label(copied ? "PUSH_INSTALLATION_ID_COPIED" : "PUSH_INSTALLATION_ID_COPY",
                      systemImage: copied ? "checkmark" : "doc.on.doc")
            }
            .accessibilityIdentifier("push-installation-id-copy")
        }
        .accessibilityElement(children: .contain)
        .contextMenu {
            Button("PUSH_INSTALLATION_ID_COPY", systemImage: "doc.on.doc") {
                UIPasteboard.general.string = installationID
            }
        }
    }
}
