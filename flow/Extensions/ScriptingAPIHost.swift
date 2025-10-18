import Foundation
import WebKit

// Host-side implementation of chrome.scripting.executeScript used by MV3 background.
// Minimal support to satisfy Dark Reader usage:
// - target: { tabId, frameIds?: [0], allFrames?: false }
// - files: [string] OR func: string + args: []
// - world: 'MAIN' is supported; others ignored for now
struct ScriptingAPIHost {
    private class WeakStore { weak var store: BrowserStore?; init(_ s: BrowserStore) { self.store = s } }
    private static var _store: WeakStore?

    static func setStore(_ store: BrowserStore) { _store = WeakStore(store) }

    static func getStore() -> BrowserStore? { return _store?.store }

    static func executeScript(ext: MV3Extension, params: [String: Any], completion: @escaping (Any?) -> Void) {
        guard let store = _store?.store else { completion([]); return }
        // Resolve target tab
        let tabIdRaw = (params["target"] as? [String: Any])?["tabId"]
        let tab: BrowserTab? = {
            if let s = tabIdRaw as? String, let uuid = UUID(uuidString: s) {
                return store.tabs.first { $0.id == uuid }
            }
            if let n = tabIdRaw as? Int {
                // Allow mapping integers to index for convenience
                if store.tabs.indices.contains(n) { return store.tabs[n] }
            }
            return store.active
        }()
        guard let targetTab = tab else { completion([]); return }

        // Build JS to evaluate
        if let files = params["files"] as? [String], !files.isEmpty {
            var bundle = ""
            for f in files {
                let url = ext.directoryURL.appendingPathComponent(f.hasPrefix("/") ? String(f.dropFirst()) : f)
                if let src = try? String(contentsOf: url, encoding: .utf8) { bundle.append(src + "\n") }
            }
            DispatchQueue.main.async {
                targetTab.webView.evaluateJavaScript(bundle) { _, _ in
                    // Return an empty results array
                    completion([])
                }
            }
            return
        }

        if let funcSource = params["func"] as? String {
            let args = (params["args"] as? [Any]) ?? []
            let argsJSON: String = {
                if let data = try? JSONSerialization.data(withJSONObject: args, options: [.fragmentsAllowed]),
                   let s = String(data: data, encoding: .utf8) { return s }
                return "[]"
            }()
            // Call the function with apply(null, args)
            let js = "(\(funcSource)).apply(null, \(argsJSON))"
            DispatchQueue.main.async {
                targetTab.webView.evaluateJavaScript(js) { result, _ in
                    // Return array with one result entry
                    let out: [[String: Any]]
                    if let r = result { out = [["result": r]] } else { out = [["result": NSNull()]] }
                    completion(out)
                }
            }
            return
        }

        // Default: nothing to execute
        completion([])
    }
}
