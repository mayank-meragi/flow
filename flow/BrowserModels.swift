import SwiftUI
import WebKit
import Combine

final class BrowserTab: NSObject, ObservableObject, Identifiable {

    let id = UUID()
    let webView: WKWebView
    @Published var title: String
    @Published var urlString: String

    init(urlString: String) {
        self.urlString = urlString
        let config = WebEngine.shared.makeConfiguration()
        self.webView = WKWebView(frame: .zero, configuration: config)
        // Set a custom desktop Safari-like User-Agent as requested
        self.webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0.1 Safari/605.1.15"
        self.title = "New Tab"
        super.init()
        if let url = URL(string: BrowserTab.ensureScheme(urlString)) {
            webView.load(URLRequest(url: url))
        }
    }

    func loadCurrentURL() {
        if let url = URL(string: BrowserTab.ensureScheme(urlString)) {
            webView.load(URLRequest(url: url))
        }
    }

    static func ensureScheme(_ s: String) -> String {
        if s.hasPrefix("http://") || s.hasPrefix("https://") { return s }
        return "https://" + s
    }
}

final class BrowserStore: ObservableObject {
    @Published var tabs: [BrowserTab] = []
    @Published var activeTabID: UUID?

    var active: BrowserTab? {
        tabs.first { $0.id == activeTabID }
    }

    init() {
        let first = BrowserTab(urlString: "example.com")
        tabs = [first]
        activeTabID = first.id
    }

    @discardableResult
    func newTab(url: String = "example.com") -> UUID {
        let t = BrowserTab(urlString: url)
        tabs.append(t)
        activeTabID = t.id
        return t.id
    }

    func close(tabID: UUID) {
        if let idx = tabs.firstIndex(where: { $0.id == tabID }) {
            let removed = tabs.remove(at: idx)
            if removed.id == activeTabID {
                activeTabID = tabs.first?.id
            }
        }
    }

    func select(tabID: UUID) { activeTabID = tabID }

    func goBack() { active?.webView.goBack() }
    func goForward() { active?.webView.goForward() }
    func reload() { active?.webView.reload() }
    var canGoBack: Bool { active?.webView.canGoBack ?? false }
    var canGoForward: Bool { active?.webView.canGoForward ?? false }
}
