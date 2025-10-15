import SwiftUI
import WebKit
import Combine
#if os(macOS)
import AppKit
#endif

final class BrowserTab: NSObject, ObservableObject, Identifiable {
    let id = UUID()
    let webView: WKWebView
    @Published var title: String
    @Published var urlString: String
    @Published var history: [HistoryEntry] = []
    #if os(macOS)
    @Published var favicon: NSImage?
    #endif

    init(urlString: String) {
        self.urlString = urlString
        let config = WebEngine.shared.makeConfiguration()
        self.webView = WKWebView(frame: .zero, configuration: config)
        // Custom desktop UA (as requested earlier)
        self.webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0.1 Safari/605.1.15"
        self.title = "New Tab"
        super.init()
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, let url = URL(string: BrowserTab.ensureScheme(trimmed)) {
            webView.load(URLRequest(url: url))
        }
    }

    // Update metadata (title + favicon) after navigation finishes
    func updateMetadata(from webView: WKWebView) {
        self.title = webView.title ?? self.urlString
        if let currentURL = webView.url?.absoluteString, !currentURL.isEmpty {
            appendHistoryIfNeeded(urlString: currentURL, title: self.title)
        }
        #if os(macOS)
        fetchFavicon(from: webView)
        #endif
    }

    #if os(macOS)
    private func fetchFavicon(from webView: WKWebView) {
        // Raw string avoids Swift escaping; query common icon links
        let script = #"(() => { const links = Array.from(document.querySelectorAll('link[rel*="icon"], link[rel="shortcut icon"], link[rel="apple-touch-icon"]')); const hrefs = links.map(l => l.href); return hrefs[0] || ''; })()"#
        webView.evaluateJavaScript(script) { [weak self] result, _ in
            guard let self = self else { return }
            var iconURL: URL?
            if let href = result as? String, !href.isEmpty { iconURL = URL(string: href) }
            if iconURL == nil, let pageURL = webView.url {
                var comps = URLComponents(url: pageURL, resolvingAgainstBaseURL: false)
                comps?.path = "/favicon.ico"
                comps?.query = nil
                comps?.fragment = nil
                iconURL = comps?.url
            }
            guard let url = iconURL else { return }
            URLSession.shared.dataTask(with: url) { data, _, _ in
                #if os(macOS)
                if let data = data, let image = NSImage(data: data) {
                    DispatchQueue.main.async { self.favicon = image }
                }
                #endif
            }.resume()
        }
    }
    #endif

    func loadCurrentURL() {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, let url = URL(string: BrowserTab.ensureScheme(trimmed)) {
            webView.load(URLRequest(url: url))
        }
    }

    private func appendHistoryIfNeeded(urlString: String, title: String) {
        // Deduplicate consecutive entries for the same URL
        if let last = history.last, last.urlString == urlString { return }
        history.append(HistoryEntry(urlString: urlString, title: title, date: Date()))
    }

    static func ensureScheme(_ s: String) -> String {
        if s.hasPrefix("http://") || s.hasPrefix("https://") { return s }
        return "https://" + s
    }
}

final class BrowserStore: ObservableObject {
    @Published var tabs: [BrowserTab] = []
    @Published var activeTabID: UUID?

    var active: BrowserTab? { tabs.first { $0.id == activeTabID } }

    init() {
        // Start with no tabs; main view remains empty until user opens one
        tabs = []
        activeTabID = nil
    }

    @discardableResult
    func newTab(url: String) -> UUID {
        let t = BrowserTab(urlString: url)
        tabs.append(t)
        activeTabID = t.id
        return t.id
    }

    func close(tabID: UUID) {
        if let idx = tabs.firstIndex(where: { $0.id == tabID }) {
            let removed = tabs.remove(at: idx)
            if removed.id == activeTabID { activeTabID = tabs.first?.id }
        }
    }

    func select(tabID: UUID) { activeTabID = tabID }
    
    // Helpers for tab indexing and selection by index
    var activeIndex: Int? { tabs.firstIndex(where: { $0.id == activeTabID }) }
    func select(index: Int) {
        guard tabs.indices.contains(index) else { return }
        activeTabID = tabs[index].id
    }

    func goBack() { active?.webView.goBack() }
    func goForward() { active?.webView.goForward() }
    func reload() { active?.webView.reload() }
    var canGoBack: Bool { active?.webView.canGoBack ?? false }
    var canGoForward: Bool { active?.webView.canGoForward ?? false }

    // Aggregated history across tabs (most recent first)
    var allHistory: [HistoryEntry] {
        tabs.flatMap { $0.history }.sorted { $0.date > $1.date }
    }

    func navigateActive(to urlString: String) {
        guard let active = active else { return }
        active.urlString = urlString
        active.loadCurrentURL()
    }
}

struct HistoryEntry: Identifiable, Hashable {
    let id = UUID()
    let urlString: String
    let title: String
    let date: Date
}
