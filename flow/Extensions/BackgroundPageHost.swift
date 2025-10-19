import Foundation
import WebKit

// Hosts a persistent MV2 background page (background.html) in an offscreen WKWebView.
final class BackgroundPageHost: NSObject, WKScriptMessageHandler, WKNavigationDelegate, WKUIDelegate {
    private(set) var webView: WKWebView!
    private weak var ext: Extension?
    private let pageRelativePath: String

    init(ext: Extension, pageRelativePath: String) {
        self.ext = ext
        self.pageRelativePath = pageRelativePath
        super.init()
        configureWebView()
    }

    private func configureWebView() {
        let config = WKWebViewConfiguration()
        let ucc = WKUserContentController()

        // Inject background bridge at document start
        let bridge = WKUserScript(source: BackgroundJSBridge.script, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        ucc.addUserScript(bridge)
        ucc.add(self, name: "flowExtension")
        config.userContentController = ucc

        // Preferences
        let pagePrefs = WKWebpagePreferences()
        pagePrefs.allowsContentJavaScript = true
        pagePrefs.preferredContentMode = .desktop
        config.defaultWebpagePreferences = pagePrefs
        config.preferences.javaScriptEnabled = true

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = self
        wv.uiDelegate = self
        self.webView = wv
    }

    func start() {
        guard let ext = ext else { return }
        let baseURL = ext.directoryURL
        let pageURL = baseURL.appendingPathComponent(pageRelativePath)
        // Load directly from file URL to allow relative script/css loads
        if pageURL.isFileURL {
            webView.loadFileURL(pageURL, allowingReadAccessTo: baseURL)
        } else {
            webView.load(URLRequest(url: pageURL))
        }
        print("[BackgroundPageHost] Started for page: \(pageRelativePath) at base: \(baseURL.path)")
    }

    func stop() {
        webView.stopLoading()
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
    }

    // MARK: WKScriptMessageHandler
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "flowExtension" else { return }
        if let ext = ext, let wv = webView {
            ext.handleAPICall(from: wv, message: message)
        }
    }
}

