import SwiftUI
import WebKit

struct BrowserWebView: NSViewRepresentable {
    let tab: BrowserTab

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        weak var tab: BrowserTab?
        init(tab: BrowserTab) { self.tab = tab }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard let tab = tab else { return }
            tab.title = webView.title ?? tab.urlString
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            // Could push error state if desired
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            // Optionally reload or mark state
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(tab: tab) }

    func makeNSView(context: Context) -> WKWebView {
        let view = tab.webView
        view.navigationDelegate = context.coordinator
        view.uiDelegate = context.coordinator
        return view
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        // If external state updates require loading, do it here.
        // We currently drive loads from SidebarView via BrowserTab.loadCurrentURL().
    }
}
