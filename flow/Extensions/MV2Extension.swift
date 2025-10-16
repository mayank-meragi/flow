import Foundation
import WebKit

class MV2Extension: Extension {
    let id: String
    let manifest: Manifest
    let runtime: APIRuntime = MV2APIRuntime()
    let directoryURL: URL

    init(manifest: Manifest, directoryURL: URL) {
        self.id = UUID().uuidString
        self.manifest = manifest
        self.directoryURL = directoryURL
    }

    func start() {}
    func stop() {}
    func handleAPICall(from webView: WKWebView, message: WKScriptMessage) {}
}
