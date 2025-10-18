import Foundation
import WebKit

// Hosts a service-worker-like background context for MV3 extensions by
// running their background/index.js inside an offscreen WKWebView.
final class BackgroundWorkerHost: NSObject, WKScriptMessageHandler, WKNavigationDelegate, WKUIDelegate {
    private(set) var webView: WKWebView!
    private weak var ext: Extension?
    private let scriptRelativePath: String

    init(ext: Extension, scriptRelativePath: String) {
        self.ext = ext
        self.scriptRelativePath = scriptRelativePath
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

        // Minimal HTML shell that loads the extension's background script.
        let html = """
        <!doctype html>
        <meta charset=\"utf-8\">
        <title>Flow Background Worker</title>
        <script>window.__flowBackground = true;</script>
        <script src=\"
        """ + scriptRelativePath + """
        \" defer></script>
        """

        webView.loadHTMLString(html, baseURL: baseURL)
        print("[BackgroundWorkerHost] Started for script: \(scriptRelativePath) at base: \(baseURL.path)")
    }

    func stop() {
        webView.stopLoading()
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
    }

    // MARK: WKScriptMessageHandler
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "flowExtension" else { return }
        // Delegate to the extension runtime (storage, permissions, alarms, i18n)
        if let ext = ext, let wv = webView {
            ext.handleAPICall(from: wv, message: message)
        }
    }
}
