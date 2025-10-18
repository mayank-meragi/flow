import Foundation

struct ContextMenusAPIHost {
    static func handle(ext: MV3Extension, method: String, params: [String: Any]) -> Any? {
        switch method {
        case "create":
            let props = params["createProperties"] as? [String: Any] ?? [:]
            let id = ext.contextMenusManager.create(props: props)
            return id
        case "removeAll":
            ext.contextMenusManager.removeAll()
            return NSNull()
        case "remove":
            if let id = params["menuItemId"] as? String {
                ext.contextMenusManager.remove(id: id)
            } else if let n = params["menuItemId"] as? Int {
                ext.contextMenusManager.remove(id: String(n))
            }
            return NSNull()
        default:
            print("[ContextMenusAPI] unimplemented method=\(method)")
            return NSNull()
        }
    }
}

