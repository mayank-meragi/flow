import Foundation

// Minimal host-side implementation of chrome.windows used by popup/options flows.
// This implementation maps window operations onto the single BrowserStore context
// and opens URLs in tabs. It does not create real OS-level popup windows yet.
struct WindowsAPIHost {
    static func handle(method: String, params: [String: Any], store: BrowserStore) -> Any? {
        switch method {
        case "getAll":
            return getAll(params: params, store: store)
        case "update":
            return update(params: params, store: store)
        case "create":
            return create(params: params, store: store)
        default:
            print("[WindowsAPI] unimplemented method=\(method)")
            return NSNull()
        }
    }

    private static func getAll(params: [String: Any], store: BrowserStore) -> Any? {
        let populate = (params["populate"] as? Bool) ?? false
        let windowTypes = params["windowTypes"] as? [String]
        let out = WindowsManager.shared.getAll(populate: populate, windowTypes: windowTypes, store: store)
        return out
    }

    private static func update(params: [String: Any], store: BrowserStore) -> Any? {
        let windowId = params["windowId"] as? Int ?? -1
        let updateInfo = params["updateInfo"] as? [String: Any] ?? [:]
        let win = WindowsManager.shared.updateWindow(id: windowId, updateInfo: updateInfo, store: store)
        return win ?? NSNull()
    }

    private static func create(params: [String: Any], store: BrowserStore) -> Any? {
        let createData = params
        let url = (createData["url"] as? String) ?? "about:blank"
        let type = (createData["type"] as? String) ?? "normal"
        // Open as a new tab and register as a pseudo-window
        let win = WindowsManager.shared.createWindow(type: type, url: url, store: store)
        return win
    }
}
