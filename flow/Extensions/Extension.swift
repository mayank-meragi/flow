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
}
