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
                header
                if showMap, content == .list || content == .empty { map } else { list }
            }
            .navigationTitle("WARN_VIEW_TITLE")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) { modeButton }
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

    /// List/map switch as a small symbol button next to "Fertig".
    private var modeButton: some View {
        Button { showMap.toggle() } label: {
            Label(showMap ? "WARN_MODE_LIST" : "WARN_MODE_MAP", systemImage: showMap ? "list.bullet" : "map")
                .labelStyle(.iconOnly)
        }
        .accessibilityHint(Text("WARN_MODE_HINT"))
        .accessibilityIdentifier("warn-mode")
    }

    /// The only visible filter (compact) with the data state as a quiet footnote below.
    private var header: some View {
        VStack(spacing: 6) {
            Picker(selection: Binding(get: { scope == .mine }, set: { scope = $0 ? .mine : .all })) {
                Text("WARN_SCOPE_MINE").tag(true)
                Text("WARN_SCOPE_ALL").tag(false)
            } label: { Text("WARN_SCOPE_MINE") }
            .pickerStyle(.segmented)
            .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : 240)
            .accessibilityIdentifier("warn-scope")
            statusNotices
        }
        .padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 8)
        .frame(maxWidth: .infinity)
    }

    private var statusNotices: some View {
        VStack(spacing: 2) {
            if case .failed = feed.state, feed.fetchedAt != nil {
                Label(P.failedNotice(), systemImage: "wifi.exclamationmark").foregroundStyle(.orange)
                    .accessibilityIdentifier("warn-failed")
            }
            if let staleness = feed.staleness(now: now), let notice = P.staleNotice(staleness) {
                Label(notice, systemImage: "clock.badge.exclamationmark").foregroundStyle(.orange)
                    .accessibilityIdentifier("warn-stale")
            }
            if let fetchedAt = feed.fetchedAt {
                Text(P.standLine(fetchedAt: fetchedAt, now: now)).foregroundStyle(.secondary)
                    .accessibilityIdentifier("warn-stand")
            }
        }
        .font(.footnote)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .multilineTextAlignment(.center)
    }

    private var disclaimer: some View {
        Text(P.disclaimer()).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            .frame(maxWidth: .infinity).padding(.horizontal, 8)
            .accessibilityIdentifier("warn-disclaimer")
    }

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                if let text = P.contentText(content, scope: scope) {
                    emptyState(text)
                } else {
                    ForEach(P.groups(shown, scope: scope, placeNames: feed.placeNames(for:))) { group in
                        if let title = group.title {
                            Text(title).font(.title3.weight(.semibold)).padding(.top, 8).padding(.horizontal, 4)
                                .accessibilityAddTraits(.isHeader)
                                .accessibilityIdentifier("warn-group-header")
                        }
                        ForEach(group.warnings) { warning in
                            NavigationLink {
                                WarningDetailView(warning: warning, placeNames: feed.placeNames(for: warning), now: now)
                            } label: { WarningCard(warning: warning, now: now, showsPlaces: scope == .all ? feed.placeNames(for: warning) : []) }
                            .buttonStyle(.plain)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(P.accessibilityLabel(for: warning, now: now))
                            .accessibilityAddTraits(.isButton)
                            .accessibilityIdentifier("warning-row")
                        }
                    }
                }
                disclaimer.padding(.top, 20).padding(.bottom, 8)
            }
            .padding(.horizontal, 16)
        }
        .background(Color(.systemGroupedBackground))
        .refreshable { await feed.refresh(force: true) }
    }

    /// Calm, centered state. The feed states stay apart: loading, unavailable (never "no warnings"), no place, empty.
    private func emptyState(_ text: String) -> some View {
        VStack(spacing: 12) {
            if content == .loading { ProgressView().controlSize(.large) } else {
                Image(systemName: P.contentSymbol(content)).font(.system(size: 40, weight: .light))
                    .foregroundStyle(content == .unavailable ? Color.orange : Color.secondary).accessibilityHidden(true)
            }
            Text(text).font(.headline).multilineTextAlignment(.center).accessibilityIdentifier("warn-empty")
            if let detail = P.contentDetail(content) {
                Text(detail).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            if content == .unavailable {
                Button("WARN_RETRY") { Task { await feed.refresh(force: true) } }.buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity).padding(.top, 56).padding(.horizontal, 12)
    }

    private var map: some View {
        VStack(spacing: 0) {
            WarnMapView(severityByCell: WarnOverlayModel.maxSeverityByCell(shown))
            VStack(alignment: .leading, spacing: 6) {
                Text("WARN_MAP_LEGEND").font(.caption).foregroundStyle(.secondary)
                disclaimer
            }
            .padding(12).frame(maxWidth: .infinity, alignment: .leading).background(.regularMaterial)
        }
    }
}


/// One warning: type symbol, headline, level as word plus digit plus color, period, preview, source line.
private struct WarningCard: View {
    let warning: ActiveWarning
    let now: Date
    let showsPlaces: [String]
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme
    private typealias P = WarningPresentation

    private var tint: Color { WarnStyle.color(warning.severity) }

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10)) : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
        layout {
            Image(systemName: P.kindSymbol(warning.kind)).font(.system(size: 20)).foregroundStyle(tint)
                .frame(width: 40, height: 40).background(tint.opacity(0.18), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Label { Text(P.levelTitle(warning.severity)).font(.subheadline.weight(.semibold)) } icon: {
                    Image(systemName: P.levelSymbol(warning.severity)).foregroundStyle(tint)
                }
                Text(warning.headline).font(.headline)
                Text(P.timeRange(onset: warning.onset, expires: warning.expires, now: now)).font(.subheadline)
                Text(warning.text).font(.subheadline).foregroundStyle(.secondary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
                if let affects = P.affects(showsPlaces) { Text(affects).font(.footnote) }
                Text(P.sourceLine(sent: warning.sent, now: now)).font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if !dynamicTypeSize.isAccessibilitySize {
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                    .padding(.top, 14).accessibilityHidden(true)
            }
        }
        .padding(14)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color(.secondarySystemGroupedBackground))
                RoundedRectangle(cornerRadius: 20, style: .continuous).fill(tint.opacity(colorScheme == .dark ? 0.16 : 0.10))
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(tint.opacity(0.45), lineWidth: warning.severity >= 3 ? 2 : 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
