import SwiftUI
import WebKit

// A WKWebView tailored for rendering extension pages (popup/options) with a
// Chrome API shim and a message bridge to native Swift handlers.
struct ExtensionPageWebView: NSViewRepresentable {
    let `extension`: Extension
    let url: URL
    @EnvironmentObject private var store: BrowserStore

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        weak var ext: Extension?
        weak var store: BrowserStore?
        weak var hostedWebView: WKWebView?

        init(ext: Extension, store: BrowserStore?) {
            self.ext = ext
            self.store = store
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            decisionHandler(.allow)
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "flowExtension", let body = message.body as? [String: Any] else { return }
            let api = body["api"] as? String ?? ""
            let method = body["method"] as? String ?? ""

            if api == "tabs" {
                handleTabsAPI(from: hostedWebView, body: body)
                return
            }

            // Delegate remaining APIs to the extension's runtime (storage, permissions, alarms, i18n)
            if let ext = ext, let webView = hostedWebView {
                ext.handleAPICall(from: webView, message: message)
            }
        }

        private func handleTabsAPI(from webView: WKWebView?, body: [String: Any]) {
            guard let webView = webView else { return }
            guard let method = body["method"] as? String, let callbackId = body["callbackId"] as? Int else { return }

            switch method {
            case "create":
                let params = body["params"] as? [String: Any] ?? [:]
                let urlString = (params["url"] as? String) ?? "about:blank"
                let active = (params["active"] as? Bool) ?? true
                let tabId: UUID? = active ? store?.newTab(url: urlString) : store?.newBackgroundTab(url: urlString)
                let result: [String: Any] = [
                    "id": tabId?.uuidString ?? UUID().uuidString,
                    "url": urlString,
                    "active": active
                ]
                sendResponse(to: webView, callbackId: callbackId, result: result)
            default:
                // For unimplemented tabs methods, respond with null
                if let callbackId = body["callbackId"] as? Int {
                    sendResponse(to: webView, callbackId: callbackId, result: NSNull())
                }
            }
        }

        private func sendResponse(to webView: WKWebView, callbackId: Int, result: Any) {
            guard let jsonData = try? JSONSerialization.data(withJSONObject: result, options: []),
                  let jsonString = String(data: jsonData, encoding: .utf8) else { return }
            let script = "window.flowExtensionCallbacks[\(callbackId)](\(jsonString)); delete window.flowExtensionCallbacks[\(callbackId)];"
            DispatchQueue.main.async { webView.evaluateJavaScript(script, completionHandler: nil) }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(ext: `extension`, store: store) }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let ucc = WKUserContentController()
        let script = WKUserScript(source: ExtensionJSBridge.script, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        ucc.addUserScript(script)
        ucc.add(context.coordinator, name: "flowExtension")
        config.userContentController = ucc

        // Reasonable defaults
        let pagePrefs = WKWebpagePreferences()
        pagePrefs.allowsContentJavaScript = true
        pagePrefs.preferredContentMode = .desktop
        config.defaultWebpagePreferences = pagePrefs
        config.preferences.javaScriptEnabled = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        context.coordinator.hostedWebView = webView
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        // Reload if URL changes
        if nsView.url != url {
            nsView.load(URLRequest(url: url))
        }
    }
}
