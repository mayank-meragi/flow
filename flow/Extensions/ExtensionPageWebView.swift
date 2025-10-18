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
            let cb = body["callbackId"] as? Int
            print("[ExtBridge][Popup] recv api=\(api) method=\(method) cb=\(String(describing: cb)) body=\(body)")

            if api == "tabs" {
                guard let cb = body["callbackId"] as? Int, let store = store, let webView = hostedWebView else { return }
                let params = body["params"] as? [String: Any] ?? [:]
                let method = body["method"] as? String ?? ""
                let result: Any?
                if method == "group" || method == "ungroup" {
                    result = TabGroupsAPIHost.handle(api: "tabs", method: method, params: params, store: store)
                } else {
                    result = TabsAPIHost.handle(method: method, params: params, store: store)
                }
                sendResponse(to: webView, callbackId: cb, result: result ?? NSNull())
                return
            }
            if api == "tabGroups" {
                guard let cb = body["callbackId"] as? Int, let store = store, let webView = hostedWebView else { return }
                let params = body["params"] as? [String: Any] ?? [:]
                let method = body["method"] as? String ?? ""
                let result = TabGroupsAPIHost.handle(api: api, method: method, params: params, store: store) ?? NSNull()
                sendResponse(to: webView, callbackId: cb, result: result)
                return
            }

            // Delegate remaining APIs to the extension's runtime (storage, permissions, alarms, i18n)
            if let ext = ext, let webView = hostedWebView {
                ext.handleAPICall(from: webView, message: message)
            }
        }

        private func sendResponse(to webView: WKWebView, callbackId: Int, result: Any) {
            guard let jsonData = try? JSONSerialization.data(withJSONObject: result, options: [.fragmentsAllowed]),
                  let jsonString = String(data: jsonData, encoding: .utf8) else { return }
            print("[ExtBridge][Popup] sendResponse cb=\(callbackId) json=\(jsonString)")
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
        `extension`.registerPageWebView(webView)
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
