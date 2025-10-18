import Foundation
import WebKit

protocol Extension: AnyObject {
    var id: String { get }
    var manifest: Manifest { get }
    var runtime: APIRuntime { get }
    var directoryURL: URL { get }

    func start()
    func stop()
    func handleAPICall(from webView: WKWebView, message: WKScriptMessage)
    func registerPageWebView(_ webView: WKWebView)
}

extension Extension {
    func registerPageWebView(_ webView: WKWebView) {
        // Default no-op for implementations that do not support messaging yet.
    }
}
