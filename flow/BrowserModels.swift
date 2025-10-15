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
    @Published var isPinned: Bool = false
    // Whether content has been loaded at least once in this session
    @Published var isLoaded: Bool = false
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
        // Defer loading by default; pinned tabs will be eagerly loaded by the store.
    }

    // Update metadata (title + favicon) after navigation finishes
    func updateMetadata(from webView: WKWebView) {
        self.title = webView.title ?? self.urlString
        if let currentURL = webView.url?.absoluteString, !currentURL.isEmpty {
            appendHistoryIfNeeded(urlString: currentURL, title: self.title)
        }
        self.isLoaded = true
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

    // Load if not already loaded
    func ensureLoaded() {
        if !isLoaded {
            loadCurrentURL()
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
    private var cancellables: Set<AnyCancellable> = []

    var active: BrowserTab? { tabs.first { $0.id == activeTabID } }

    init() {
        // Try restoring persisted state, otherwise start empty
        if let state = Self.loadState() {
            restore(from: state)
        } else {
            tabs = []
            activeTabID = nil
        }
        // Save when the active tab changes
        $activeTabID
            .sink { [weak self] _ in self?.saveState() }
            .store(in: &cancellables)
    }

    @discardableResult
    func newTab(url: String) -> UUID {
        let t = BrowserTab(urlString: url)
        attachObservers(to: t)
        tabs.append(t)
        activeTabID = t.id
        // New active tab: ensure it starts loading
        t.ensureLoaded()
        saveState()
        return t.id
    }

    func close(tabID: UUID) {
        if let idx = tabs.firstIndex(where: { $0.id == tabID }) {
            let removed = tabs.remove(at: idx)
            if removed.id == activeTabID { activeTabID = tabs.first?.id }
            saveState()
        }
    }

    func select(tabID: UUID) {
        activeTabID = tabID
        // Lazy-load non-pinned tabs when selected
        if let tab = tabs.first(where: { $0.id == tabID }) {
            tab.ensureLoaded()
        }
    }
    
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
        saveState()
    }
}

struct HistoryEntry: Identifiable, Hashable, Codable {
    let id = UUID()
    let urlString: String
    let title: String
    let date: Date
}

// MARK: - Persistence

private struct PersistedTab: Codable {
    let id: UUID
    let urlString: String
    let title: String
    let history: [HistoryEntry]
    let isPinned: Bool
}

private struct PersistedState: Codable {
    let tabs: [PersistedTab]
    let activeTabID: UUID?
}

extension BrowserStore {
    private static var stateURL: URL? {
        #if os(macOS)
        let fm = FileManager.default
        let appSupport = try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let dir = appSupport?.appendingPathComponent("flow", isDirectory: true)
        if let dir, !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir?.appendingPathComponent("state.json")
        #else
        return nil
        #endif
    }

    fileprivate static func loadState() -> PersistedState? {
        guard let url = stateURL, let data = try? Data(contentsOf: url) else { return nil }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return try? dec.decode(PersistedState.self, from: data)
    }

    func saveState() {
        guard let url = Self.stateURL else { return }
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted]
        enc.dateEncodingStrategy = .iso8601
        let tabsPayload: [PersistedTab] = tabs.map { t in
            PersistedTab(id: t.id, urlString: t.urlString, title: t.title, history: t.history, isPinned: t.isPinned)
        }
        let payload = PersistedState(tabs: tabsPayload, activeTabID: activeTabID)
        if let data = try? enc.encode(payload) {
            try? data.write(to: url, options: .atomic)
        }
    }

    private func restore(from state: PersistedState) {
        var created: [BrowserTab] = []
        for s in state.tabs {
            let t = BrowserTab(urlString: s.urlString)
            t.history = s.history
            t.title = s.title
            t.isPinned = s.isPinned
            // Force identity to match persisted ID for active selection
            // Note: BrowserTab.id is let, so we can't override it; instead, we select by index below.
            created.append(t)
        }
        tabs = created
        // Try to match active by URL fallback if IDs differ
        if let aid = state.activeTabID, let idx = state.tabs.firstIndex(where: { $0.id == aid }), tabs.indices.contains(idx) {
            activeTabID = tabs[idx].id
        } else {
            activeTabID = tabs.first?.id
        }
        // Observe tabs for changes
        tabs.forEach { attachObservers(to: $0) }
        // Eager-load pinned tabs in the background
        tabs.filter { $0.isPinned }.forEach { $0.ensureLoaded() }
        // Ensure the active tab is loaded so it's ready immediately
        if let active = self.active { active.ensureLoaded() }
        // Persist immediately to normalize IDs mapping
        saveState()
    }

    private func attachObservers(to tab: BrowserTab) {
        tab.$title
            .sink { [weak self] _ in self?.saveState() }
            .store(in: &cancellables)
        tab.$urlString
            .sink { [weak self] _ in self?.saveState() }
            .store(in: &cancellables)
        tab.$history
            .sink { [weak self] _ in self?.saveState() }
            .store(in: &cancellables)
        tab.$isPinned
            .sink { [weak self, weak tab] newVal in
                // Persist pin changes and ensure pinned tabs are loaded
                if newVal { tab?.ensureLoaded() }
                self?.saveState()
            }
            .store(in: &cancellables)
    }
}
