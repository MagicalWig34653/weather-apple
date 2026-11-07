import SwiftUI

/// Full DWD warning: headline, text and instruction exactly as delivered, with source line and the standing disclaimer.
struct WarningDetailView: View {
    let warning: ActiveWarning
    let placeNames: [String]
    let now: Date
    private typealias P = WarningPresentation

    var body: some View {
        List {
            Section {
                WarningLevelLabel(warning: warning)
                Text(warning.headline).font(.headline)
                    .accessibilityIdentifier("warning-headline")
                Text(P.timeRange(onset: warning.onset, expires: warning.expires, now: now))
                    .font(.subheadline)
                if let affects = P.affects(placeNames) { Text(affects).font(.subheadline).foregroundStyle(.secondary) }
            }
            Section {
                Text(warning.text).textSelection(.enabled).accessibilityIdentifier("warning-text")
            }
            if !warning.instruction.isEmpty {
                Section("WARN_SECTION_INSTRUCTION") {
                    Text(warning.instruction).textSelection(.enabled).accessibilityIdentifier("warning-instruction")
                }
            }
            Section {
                Text(P.sourceLine(sent: warning.sent, now: now)).font(.footnote)
                    .accessibilityIdentifier("warning-source")
                if let hint = P.languageHint(warningLang: warning.lang, appLang: WarnFeedStore.appLanguage()) {
                    Text(hint).font(.footnote).foregroundStyle(.secondary)
                }
                Label(P.disclaimer(), systemImage: "info.circle").font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("WARN_DETAIL_TITLE")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Symbol, color and words for the level plus the type: never color only.
struct WarningLevelLabel: View {
    let warning: ActiveWarning
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // At accessibility sizes the symbol sits above the words so they keep the full width.
        (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4)) : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))) {
            Image(systemName: WarningPresentation.levelSymbol(warning.severity))
                .foregroundStyle(WarnStyle.color(warning.severity))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(WarningPresentation.levelTitle(warning.severity)).font(.subheadline.weight(.semibold))
                Text(WarningPresentation.kindTitle(warning.kind)).font(.caption).foregroundStyle(.secondary)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
