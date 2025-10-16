import Foundation
import WebKit

class MV3Extension: Extension {
    let id: String
    let manifest: Manifest
    let runtime: APIRuntime
    let directoryURL: URL
    let storageManager: StorageManager

    init(manifest: Manifest, directoryURL: URL) {
        let id = UUID().uuidString
        self.id = id
        self.manifest = manifest
        self.directoryURL = directoryURL
        self.storageManager = StorageManager(extensionId: id)
        self.runtime = MV3APIRuntime(storageManager: self.storageManager)
    }

    func start() {}
    func stop() {}

    func handleAPICall(from webView: WKWebView, message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
            let api = body["api"] as? String,
            let method = body["method"] as? String,
            let params = body["params"] as? [String: Any],
            let callbackId = body["callbackId"] as? Int
        else {
            print("Invalid API call message format")
            return
        }

        switch api {
        case "storage":
            guard let area = body["area"] as? String else { return }

            runtime.storage.handleCall(area: area, method: method, params: params) { result in
                self.sendResponse(to: webView, callbackId: callbackId, result: result)
            }

        default:
            print("Unknown API: \(api)")
        }
    }

    private func sendResponse(to webView: WKWebView, callbackId: Int, result: Any?) {
        let resultData: Any
        if let result = result {
            resultData = result
        } else {
            resultData = NSNull()
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: resultData, options: []),
            let jsonString = String(data: jsonData, encoding: .utf8)
        else {
            // Handle error: could not serialize result
            return
        }

        let script =
            "window.flowExtensionCallbacks[\(callbackId)](\(jsonString)); delete window.flowExtensionCallbacks[\(callbackId)];"

        DispatchQueue.main.async {
            webView.evaluateJavaScript(script)
        }
    }
}
