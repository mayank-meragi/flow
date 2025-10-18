import Foundation
import WebKit

// Host-side implementation of a subset of chrome.tabs APIs bridged from JS.
// Returns JSON-serializable results (Dictionary/Array/Null) suitable for direct
// injection into evaluateJavaScript.
struct TabsAPIHost {
    static func handle(method: String, params: [String: Any], store: BrowserStore) -> Any? {
        print("[TabsAPI] handle method=\(method) params=\(params)")
        switch method {
        case "create":
            let res = create(params: params, store: store)
            print("[TabsAPI] create -> \(String(describing: res))")
            return res
        case "query":
            let res = query(params: params, store: store)
            print("[TabsAPI] query -> count=\(((res as? [[String: Any]])?.count ?? 0))")
            return res
        case "update":
            let res = update(params: params, store: store)
            print("[TabsAPI] update -> \(String(describing: res))")
            return res
        case "remove":
            let res = remove(params: params, store: store)
            print("[TabsAPI] remove -> ok")
            return res
        case "reload":
            let res = reload(params: params, store: store)
            print("[TabsAPI] reload -> ok")
            return res
        case "get":
            let res = get(params: params, store: store)
            print("[TabsAPI] get -> \(String(describing: res))")
            return res
        case "getCurrent":
            let res = getCurrent(store: store)
            print("[TabsAPI] getCurrent -> \(String(describing: res))")
            return res
        case "duplicate":
            let res = duplicate(params: params, store: store)
            print("[TabsAPI] duplicate -> \(String(describing: res))")
            return res
        case "sendMessage":
            let res = sendMessage(params: params, store: store)
            print("[TabsAPI] sendMessage -> ok")
            return res
        default:
            print("[TabsAPI] unimplemented method=\(method)")
            return NSNull()
        }
    }

    private static func onMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread { block() } else { DispatchQueue.main.async { block() } }
    }

    // MARK: - Methods

    private static func create(params: [String: Any], store: BrowserStore) -> Any? {
        let urlString = (params["url"] as? String) ?? "about:blank"
        let active = (params["active"] as? Bool) ?? true
        print("[TabsAPI] create url=\(urlString) active=\(active)")
        let id: UUID = active ? (store.newTab(url: urlString)) : (store.newBackgroundTab(url: urlString))
        return toDict(forID: id, store: store)
    }

    private static func query(params: [String: Any], store: BrowserStore) -> Any? {
        let activeFilter = params["active"] as? Bool
        let pinnedFilter = params["pinned"] as? Bool
        var urlPatterns: [String] = []
        if let s = params["url"] as? String { urlPatterns = [s] }
        if let arr = params["url"] as? [String] { urlPatterns = arr }

        let results: [[String: Any]] = store.tabs.enumerated().compactMap { (idx, t) in
            if let a = activeFilter {
                let isActive = (t.id == store.activeTabID)
                if isActive != a { return nil }
            }
            if let p = pinnedFilter, t.isPinned != p { return nil }
            if !urlPatterns.isEmpty {
                if TabsAPIHost.matches(url: t.urlString, patterns: urlPatterns) == false { return nil }
            }
            return toDict(tab: t, index: idx, store: store)
        }
        print("[TabsAPI] query filters active=\(String(describing: activeFilter)) pinned=\(String(describing: pinnedFilter)) urlPatterns=\(urlPatterns)")
        return results
    }

    private static func update(params: [String: Any], store: BrowserStore) -> Any? {
        let updateProps = params["updateProperties"] as? [String: Any] ?? [:]
        let tabIdString = params["tabId"] as? String
        let target: (BrowserTab, Int)? = {
            if let s = tabIdString, let (tab, idx) = findTab(idString: s, store: store) { return (tab, idx) }
            if let active = store.active, let idx = store.tabs.firstIndex(where: { $0.id == active.id }) { return (active, idx) }
            return nil
        }()
        guard let (tab, idx) = target else { return NSNull() }

        if let url = updateProps["url"] as? String, !url.isEmpty {
            print("[TabsAPI] update load url=\(url) for tab=\(tab.id) main=\(Thread.isMainThread)")
            onMain {
                tab.urlString = url
                tab.loadCurrentURL()
            }
        }
        if let active = updateProps["active"] as? Bool {
            print("[TabsAPI] update set active=\(active) for tab=\(tab.id) main=\(Thread.isMainThread)")
            if active {
                onMain { store.select(tabID: tab.id) }
            }
        }
        if let pinned = updateProps["pinned"] as? Bool {
            print("[TabsAPI] update set pinned=\(pinned) for tab=\(tab.id) main=\(Thread.isMainThread)")
            onMain { tab.isPinned = pinned }
        }
        return toDict(tab: tab, index: idx, store: store)
    }

    private static func remove(params: [String: Any], store: BrowserStore) -> Any? {
        func close(id: UUID) { store.close(tabID: id) }
        if let s = params["tabId"] as? String, let uuid = UUID(uuidString: s) {
            print("[TabsAPI] remove tabId=\(s)")
            close(id: uuid)
            return NSNull()
        }
        if let arr = params["tabIds"] as? [String] {
            print("[TabsAPI] remove tabIds=\(arr)")
            for s in arr { if let uuid = UUID(uuidString: s) { close(id: uuid) } }
            return NSNull()
        }
        return NSNull()
    }

    private static func reload(params: [String: Any], store: BrowserStore) -> Any? {
        if let s = params["tabId"] as? String, let uuid = UUID(uuidString: s), let tab = store.tabs.first(where: { $0.id == uuid }) {
            print("[TabsAPI] reload tabId=\(s) main=\(Thread.isMainThread)")
            onMain { tab.webView.reload() }
            return NSNull()
        }
        if let active = store.active {
            print("[TabsAPI] reload active tab=\(active.id) main=\(Thread.isMainThread)")
            onMain { active.webView.reload() }
        }
        return NSNull()
    }

    private static func get(params: [String: Any], store: BrowserStore) -> Any? {
        guard let s = params["tabId"] as? String, let (tab, idx) = findTab(idString: s, store: store) else { return NSNull() }
        let d = toDict(tab: tab, index: idx, store: store)
        print("[TabsAPI] getCurrent -> id=\(String(describing: d["id"]))")
        return d
    }

    private static func getCurrent(store: BrowserStore) -> Any? {
        guard let tab = store.active, let idx = store.tabs.firstIndex(where: { $0.id == tab.id }) else { return NSNull() }
        return toDict(tab: tab, index: idx, store: store)
    }

    private static func duplicate(params: [String: Any], store: BrowserStore) -> Any? {
        guard let s = params["tabId"] as? String, let (tab, _) = findTab(idString: s, store: store) else { return NSNull() }
        let newId = store.newTab(url: tab.urlString)
        let d = toDict(forID: newId, store: store)
        print("[TabsAPI] duplicate created id=\(String(describing: d["id"])) from=\(tab.id)")
        return d
    }

    static func sendMessage(params: [String: Any], store: BrowserStore) -> Any? {
        guard let s = params["tabId"] as? String, let (tab, _) = findTab(idString: s, store: store) else { return NSNull() }
        let message = params["message"] ?? NSNull()
        // Dispatch message into target tab by firing a CustomEvent listened by the content bridge
        guard let data = try? JSONSerialization.data(withJSONObject: message, options: [.fragmentsAllowed]),
              let json = String(data: data, encoding: .utf8) else { return NSNull() }
        let js = "(function(){ try { var ev=new CustomEvent('__flowRuntimeMessage',{detail: \(json)}); document.dispatchEvent(ev); } catch(e){} })()"
        DispatchQueue.main.async { tab.webView.evaluateJavaScript(js, completionHandler: nil) }
        return NSNull()
    }

    // MARK: - Helpers

    private static func findTab(idString: String, store: BrowserStore) -> (BrowserTab, Int)? {
        guard let uuid = UUID(uuidString: idString) else { return nil }
        guard let idx = store.tabs.firstIndex(where: { $0.id == uuid }) else { return nil }
        return (store.tabs[idx], idx)
    }

    private static func toDict(forID id: UUID, store: BrowserStore) -> [String: Any] {
        guard let idx = store.tabs.firstIndex(where: { $0.id == id }) else {
            return ["id": id.uuidString]
        }
        return toDict(tab: store.tabs[idx], index: idx, store: store)
    }

    private static func toDict(tab: BrowserTab, index: Int, store: BrowserStore) -> [String: Any] {
        var d: [String: Any] = [
            "id": tab.id.uuidString,
            "index": index,
            "active": tab.id == store.activeTabID,
            "pinned": tab.isPinned,
            "url": tab.urlString,
            "title": tab.title
        ]
        if let fid = tab.folderID {
            let gid = TabGroupIDMap.shared.groupId(for: fid)
            d["groupId"] = gid
        } else {
            d["groupId"] = -1
        }
        return d
    }

    // MARK: - URL pattern matching (simple glob support)

    private static func matches(url: String, patterns: [String]) -> Bool {
        for p in patterns {
            if match(url: url, pattern: p) { return true }
        }
        return false
    }

    private static func match(url: String, pattern: String) -> Bool {
        // Special token
        if pattern == "<all_urls>" {
            // Accept common schemes
            return url.range(of: "^(?:https?|file|ftp|ws|wss)://", options: [.regularExpression, .caseInsensitive]) != nil
        }
        // Convert simple wildcard glob to regex. Escape then replace \* -> .*, \? -> .
        let escaped = NSRegularExpression.escapedPattern(for: pattern)
        let regexPattern = "^" + escaped
            .replacingOccurrences(of: "\\*", with: ".*")
            .replacingOccurrences(of: "\\?", with: ".") + "$"
        do {
            let re = try NSRegularExpression(pattern: regexPattern, options: [.caseInsensitive])
            let range = NSRange(location: 0, length: (url as NSString).length)
            return re.firstMatch(in: url, options: [], range: range) != nil
        } catch {
            // Fallback to exact compare on regex failure
            return url == pattern
        }
    }
}
