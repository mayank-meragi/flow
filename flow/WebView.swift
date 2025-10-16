import SwiftUI
import WebKit

struct BrowserWebView: NSViewRepresentable {
    let tab: BrowserTab
    @EnvironmentObject private var store: BrowserStore

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        weak var tab: BrowserTab?
        weak var store: BrowserStore?
        init(tab: BrowserTab, store: BrowserStore?) { self.tab = tab; self.store = store }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            tab?.updateMetadata(from: webView)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            // Could push error state if desired
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            // Optionally reload or mark state
        }
        // Handle JS bridge messages
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "flowOpenInNewTab" else { return }
            if let href = message.body as? String, !href.isEmpty {
                // Open in background to mimic browser Cmd+Click behavior
                store?.newBackgroundTab(url: href)
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(tab: tab, store: store) }

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
        return view
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        // If external state updates require loading, do it here.
        // We currently drive loads from SidebarView via BrowserTab.loadCurrentURL().
    }
}
