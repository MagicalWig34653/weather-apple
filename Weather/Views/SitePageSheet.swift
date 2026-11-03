import SwiftUI
import WebKit

/// The three pages served by the Showers backend that open as a bottom sheet inside the app.
enum SitePage: String, Identifiable, CaseIterable {
    case privacy, support, about

    var id: String { rawValue }

    var url: URL {
        switch self {
        case .privacy: RadarBackendConfig.privacyPolicyURL
        case .support: RadarBackendConfig.supportURL
        case .about: RadarBackendConfig.marketingURL
        }
    }

    var title: String {
        switch self {
        case .privacy: "Datenschutzerklärung"
        case .support: "Support"
        case .about: "Über Showers"
        }
    }

    /// Only pages on the page's own host stay inside the sheet; everything else goes to the browser.
    func allowsInSheet(_ target: URL) -> Bool {
        target.scheme == "https" && target.host == url.host
    }

    enum NavigationDecision: Equatable { case allow, openExternally, cancel }

    /// Applies the host rule to every navigation, including `.other` (redirects, scripted loads). Only taps on
    /// main-frame links may leave the sheet (to the browser, web links and mail only); everything else is cancelled.
    func navigationDecision(for target: URL, isLinkActivated: Bool, isMainFrame: Bool) -> NavigationDecision {
        if allowsInSheet(target) { return .allow }
        if isLinkActivated, isMainFrame, ["https", "http", "mailto"].contains(target.scheme?.lowercased() ?? "") { return .openExternally }
        return .cancel
    }

    /// A main-frame response must come from the page's own https host (a redirect elsewhere is refused).
    func allowsResponse(from responseURL: URL?, isMainFrame: Bool) -> Bool {
        guard isMainFrame else { return true }
        guard let responseURL else { return false }
        return allowsInSheet(responseURL)
    }
}

/// Bottom sheet showing a backend page. Privacy choice: an ephemeral WKWebView (no cookies, no persistent
/// website data, no JavaScript) instead of SFSafariViewController, so nothing is shared with Safari or kept.
struct SitePageSheet: View {
    let page: SitePage
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var state: SitePageState = .loading
    @State private var reload = 0

    var body: some View {
        NavigationStack {
            ZStack {
                SiteWebView(page: page, reload: reload, state: $state, openExternally: { openURL($0) })
                    .opacity(state == .loaded ? 1 : 0)
                    .accessibilityHidden(state != .loaded)
                switch state {
                case .loading:
                    ProgressView("Seite wird geladen …")
                case .failed:
                    errorView
                case .loaded:
                    EmptyView()
                }
            }
            .navigationTitle(page.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Im Browser öffnen") { openURL(page.url) }
                        .accessibilityIdentifier("site-open-browser")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }.accessibilityIdentifier("site-close")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier("site-sheet-\(page.rawValue)")
    }

    private var errorView: some View {
        ContentUnavailableView {
            Label("Seite nicht erreichbar", systemImage: "wifi.slash")
        } description: {
            Text("Die Seite „\(page.title)“ liegt auf dem Showers-Server und konnte gerade nicht geladen werden. Prüfe deine Internetverbindung oder öffne sie im Browser.")
        } actions: {
            Button("Erneut versuchen") { state = .loading; reload += 1 }
                .accessibilityIdentifier("site-retry")
            Button("Im Browser öffnen") { openURL(page.url) }
        }
        .accessibilityIdentifier("site-error")
    }
}

enum SitePageState: Equatable { case loading, loaded, failed }

private struct SiteWebView: UIViewRepresentable {
    let page: SitePage
    let reload: Int
    @Binding var state: SitePageState
    let openExternally: (URL) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.isOpaque = false
        view.backgroundColor = .clear
        view.load(request)
        context.coordinator.loadedReload = reload
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        context.coordinator.parent = self
        if context.coordinator.loadedReload != reload {
            context.coordinator.loadedReload = reload
            view.load(request)
        }
    }

    private var request: URLRequest {
        URLRequest(url: page.url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var parent: SiteWebView
        var loadedReload = 0
        init(_ parent: SiteWebView) { self.parent = parent }

        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction) async -> WKNavigationActionPolicy {
            guard let target = action.request.url else { return .cancel }
            switch parent.page.navigationDecision(for: target, isLinkActivated: action.navigationType == .linkActivated,
                                                  isMainFrame: action.targetFrame?.isMainFrame ?? true) {
            case .allow: return .allow
            case .openExternally: parent.openExternally(target); return .cancel
            case .cancel: return .cancel
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor response: WKNavigationResponse) async -> WKNavigationResponsePolicy {
            if let http = response.response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                parent.state = .failed
                return .cancel
            }
            if !parent.page.allowsResponse(from: response.response.url, isMainFrame: response.isForMainFrame) {
                parent.state = .failed
                return .cancel
            }
            return .allow
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { parent.state = .loaded }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { fail(error) }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { fail(error) }

        private func fail(_ error: Error) {
            if (error as NSError).code == NSURLErrorCancelled { return }
            parent.state = .failed
        }
    }
}

extension View {
    /// Presents a backend page as a bottom sheet.
    func sitePageSheet(_ page: Binding<SitePage?>) -> some View {
        sheet(item: page) { SitePageSheet(page: $0) }
    }
}

/// Row that opens a backend page in the sheet (replaces the browser `Link`).
struct SitePageButton: View {
    let page: SitePage
    @Binding var selection: SitePage?

    var body: some View {
        Button { selection = page } label: {
            HStack {
                Text(page.title).foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.up").font(.footnote).foregroundStyle(.tertiary).accessibilityHidden(true)
            }
        }
        .accessibilityHint("Öffnet die Seite unten in der App")
        .accessibilityAddTraits(.isLink)
        .accessibilityIdentifier("site-link-\(page.rawValue)")
    }
}
