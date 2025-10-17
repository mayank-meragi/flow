import SwiftUI
import WebKit

struct BrowserWebView: NSViewRepresentable {
    let tab: BrowserTab
    @EnvironmentObject private var store: BrowserStore
    @EnvironmentObject private var extensionManager: ExtensionManager

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        weak var tab: BrowserTab?
        weak var store: BrowserStore?
        weak var extensionManager: ExtensionManager?
        init(tab: BrowserTab, store: BrowserStore?, extensionManager: ExtensionManager?) {
            self.tab = tab; self.store = store; self.extensionManager = extensionManager
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            tab?.updateMetadata(from: webView)
            // If this is an extension options page, ensure the extension JS bridge exists.
            if let url = webView.url, let ext = findExtension(for: url) {
                // Inject the JS shim idempotently; the JS self-guards on __flowExtensionBridgeInstalled
                webView.evaluateJavaScript(ExtensionJSBridge.script, completionHandler: nil)
                // Note: message handler for "flowExtension" is installed in makeNSView.
                _ = ext // keep reference to avoid warnings; not used further here
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            // Could push error state if desired
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            // Optionally reload or mark state
        }
        // Handle JS bridge messages
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            switch message.name {
            case "flowOpenInNewTab":
                if let href = message.body as? String, !href.isEmpty {
                    store?.newBackgroundTab(url: href)
                }
            case "flowExtension":
                handleExtensionMessage(message)
            default:
                break
            }
        }

        private func handleExtensionMessage(_ message: WKScriptMessage) {
            guard let body = message.body as? [String: Any] else { return }
            let api = body["api"] as? String ?? ""
            if api == "tabs" {
                handleTabsAPI(from: tab?.webView, body: body)
                return
            }
            // Delegate supported APIs to extension implementation if we can resolve the owning extension
            guard let webView = tab?.webView, let url = webView.url, let ext = findExtension(for: url) else { return }
            ext.handleAPICall(from: webView, message: message)
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
                sendResponse(to: webView, callbackId: callbackId, result: NSNull())
            }
        }

        private func sendResponse(to webView: WKWebView, callbackId: Int, result: Any) {
            guard let jsonData = try? JSONSerialization.data(withJSONObject: result, options: []),
                  let jsonString = String(data: jsonData, encoding: .utf8) else { return }
            let script = "window.flowExtensionCallbacks[\(callbackId)](\(jsonString)); delete window.flowExtensionCallbacks[\(callbackId)];"
            DispatchQueue.main.async { webView.evaluateJavaScript(script, completionHandler: nil) }
        }

        private func findExtension(for url: URL) -> Extension? {
            guard let extMgr = extensionManager else { return nil }
            for ext in extMgr.extensions.values {
                if url.path.hasPrefix(ext.directoryURL.path) {
                    return ext
                }
            }
            return nil
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(tab: tab, store: store, extensionManager: extensionManager) }

    func makeNSView(context: Context) -> WKWebView {
        let view = tab.webView
        view.navigationDelegate = context.coordinator
        view.uiDelegate = context.coordinator
        // Inject Cmd+Click handler script and message bridge only once per tab/webview
        if tab.didInstallCmdClickBridge == false {
            let js = """
            (function(){
              if (window.__flowCmdClickInstalled) return; window.__flowCmdClickInstalled = true;
              document.addEventListener('click', function(e){
                try {
                  let el = e.target;
                  while (el && el.tagName !== 'A') el = el.parentElement;
                  if (!el || !el.href) return;
                  if (e.metaKey) {
                    window.webkit.messageHandlers.flowOpenInNewTab.postMessage(el.href);
                    e.preventDefault();
                    e.stopPropagation();
                  }
                } catch (err) { /* swallow */ }
              }, true);
            })();
            """
            let script = WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: false)
            view.configuration.userContentController.addUserScript(script)
            view.configuration.userContentController.add(context.coordinator, name: "flowOpenInNewTab")
            tab.didInstallCmdClickBridge = true
        }
        // Install extension message handler to receive calls from extension options pages
        if tab.didInstallExtensionBridge == false {
            view.configuration.userContentController.add(context.coordinator, name: "flowExtension")
            tab.didInstallExtensionBridge = true
        }
        return view
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        // If external state updates require loading, do it here.
        // We currently drive loads from SidebarView via BrowserTab.loadCurrentURL().
    }
}
