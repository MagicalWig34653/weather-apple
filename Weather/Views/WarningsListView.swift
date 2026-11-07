import SwiftUI

/// Sheet with the official warnings: list (default, the accessible form) or map; "my places" or all of Germany.
struct WarningsListView: View {
    let feed: WarnFeedStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var scope: WarnScope
    @State private var showMap = false
    @State private var now = Date()
    private typealias P = WarningPresentation

    init(feed: WarnFeedStore) {
        self.feed = feed
        _scope = State(initialValue: WarnScope.defaultScope(hasPlaces: feed.hasPlaces && feed.hasAnyCells))
    }

    private var shown: [ActiveWarning] { scope == .mine ? feed.relevantWarnings(now: now) : feed.allWarnings(now: now) }

    private var content: P.Content {
        P.content(scope: scope, hasData: feed.fetchedAt != nil, isLoading: feed.state == .loading || feed.state == .idle,
                  hasPlaces: feed.hasPlaces, hasAnyCells: feed.hasAnyCells, count: shown.count)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                controls
                if showMap, content == .list || content == .empty { map } else { list }
            }
            .navigationTitle("WARN_VIEW_TITLE")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("WARN_DONE") { dismiss() } }
            }
        }
        .task {
            await feed.refresh()
            while !Task.isCancelled {
                now = Date()
                try? await Task.sleep(for: .seconds(30))
            }
        }
        .accessibilityIdentifier("warnings-sheet")
    }

    private var controls: some View {
        VStack(spacing: 8) {
            picker("WARN_SCOPE_MINE", "WARN_SCOPE_ALL", isFirst: scope == .mine, id: "warn-scope") { scope = $0 ? .mine : .all }
            picker("WARN_MODE_LIST", "WARN_MODE_MAP", isFirst: !showMap, id: "warn-mode") { showMap = !$0 }
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
    }

    @ViewBuilder private func picker(_ first: LocalizedStringKey, _ second: LocalizedStringKey, isFirst: Bool, id: String,
                                     set: @escaping (Bool) -> Void) -> some View {
        let binding = Binding(get: { isFirst }, set: set)
        Picker(selection: binding) {
            Text(first).tag(true)
            Text(second).tag(false)
        } label: { Text(first) }
        .pickerStyle(.segmented)
        .accessibilityIdentifier(id)
    }

    private var statusNotices: some View {
        VStack(alignment: .leading, spacing: 4) {
            if case .failed = feed.state { Label(P.failedNotice(), systemImage: "wifi.exclamationmark").accessibilityIdentifier("warn-failed") }
            if let staleness = feed.staleness(now: now), let notice = P.staleNotice(staleness) {
                Label(notice, systemImage: "clock.badge.exclamationmark").accessibilityIdentifier("warn-stale")
            }
            if let fetchedAt = feed.fetchedAt {
                Text(P.standLine(fetchedAt: fetchedAt, now: now)).foregroundStyle(.secondary)
                    .accessibilityIdentifier("warn-stand")
            }
        }
        .font(.footnote)
    }

    private var disclaimer: some View {
        Label(P.disclaimer(), systemImage: "info.circle").font(.footnote).foregroundStyle(.secondary)
            .accessibilityIdentifier("warn-disclaimer")
    }

    private var list: some View {
        List {
            Section { statusNotices }
            if let text = P.contentText(content, scope: scope) {
                Section {
                    Text(text).accessibilityIdentifier("warn-empty")
                    if content == .unavailable {
                        Button("WARN_RETRY") { Task { await feed.refresh(force: true) } }
                    }
                }
            } else {
                Section {
                    ForEach(shown) { warning in
                        NavigationLink {
                            WarningDetailView(warning: warning, placeNames: feed.placeNames(for: warning), now: now)
                        } label: { row(warning) }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(P.accessibilityLabel(for: warning, now: now))
                        .accessibilityHint(P.affects(feed.placeNames(for: warning)) ?? "")
                        .accessibilityIdentifier("warning-row")
                    }
                }
            }
            Section { disclaimer }
        }
        .refreshable { await feed.refresh(force: true) }
    }

    private func row(_ warning: ActiveWarning) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            WarningLevelLabel(warning: warning)
            Text(warning.headline).font(.headline)
            Text(P.timeRange(onset: warning.onset, expires: warning.expires, now: now)).font(.subheadline)
            Text(warning.text).font(.subheadline).foregroundStyle(.secondary).lineLimit(dynamicTypeSize.isAccessibilitySize ? 4 : 3)
            if let affects = P.affects(feed.placeNames(for: warning)) { Text(affects).font(.footnote) }
            Text(P.sourceLine(sent: warning.sent, now: now)).font(.footnote).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private var map: some View {
        VStack(spacing: 0) {
            WarnMapView(severityByCell: WarnOverlayModel.maxSeverityByCell(shown))
            VStack(alignment: .leading, spacing: 6) {
                statusNotices
                Text("WARN_MAP_LEGEND").font(.caption).foregroundStyle(.secondary)
                disclaimer
            }
            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
