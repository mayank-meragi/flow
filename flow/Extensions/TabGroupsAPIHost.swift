import Foundation

// Maps BrowserStore TabFolder UUIDs to numeric groupIds exposed to extensions.
final class TabGroupIDMap {
    static let shared = TabGroupIDMap()
    private var idForFolder: [UUID: Int] = [:]
    private var folderForId: [Int: UUID] = [:]
    private var nextId: Int = 1

    private init() {}

    func groupId(for folderID: UUID) -> Int {
        if let id = idForFolder[folderID] { return id }
        let id = nextId
        nextId &+= 1
        idForFolder[folderID] = id
        folderForId[id] = folderID
        return id
    }

    func folderID(for groupId: Int) -> UUID? { folderForId[groupId] }

    func removeMapping(for folderID: UUID) {
        if let gid = idForFolder.removeValue(forKey: folderID) {
            folderForId.removeValue(forKey: gid)
        }
    }
}

struct TabGroupsAPIHost {
    static func handle(api: String, method: String, params: [String: Any], store: BrowserStore) -> Any? {
        print("[TabGroupsAPI] api=\(api) method=\(method) params=\(params)")
        switch (api, method) {
        case ("tabs", "group"):
            return group(params: params, store: store)
        case ("tabs", "ungroup"):
            return ungroup(params: params, store: store)
        case ("tabGroups", "query"):
            return query(params: params, store: store)
        case ("tabGroups", "update"):
            return update(params: params, store: store)
        case ("tabGroups", "get"):
            return get(params: params, store: store)
        default:
            print("[TabGroupsAPI] unimplemented api/method = \(api).\(method)")
            return NSNull()
        }
    }

    private static func onMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread { block() } else { DispatchQueue.main.async { block() } }
    }

    // tabs.group({ tabIds: [string], groupId?: number }) -> number
    private static func group(params: [String: Any], store: BrowserStore) -> Any? {
        let ids: [String] = (params["tabIds"] as? [String]) ?? []
        let providedGroupId = params["groupId"] as? Int

        let folderID: UUID = {
            if let gid = providedGroupId, let fid = TabGroupIDMap.shared.folderID(for: gid) {
                return fid
            } else {
                // Create new folder
                let name = "Group \(store.folders.count + 1)"
                let palette = ["#5E81AC", "#A3BE8C", "#EBCB8B", "#D08770", "#BF616A", "#B48EAD", "#88C0D0"]
                let color = palette.randomElement() ?? "#5E81AC"
                let fid = store.createFolder(name: name, colorHex: color, pinned: false)
                return fid
            }
        }()

        onMain {
            for s in ids {
                if let uuid = UUID(uuidString: s) {
                    store.assign(tabID: uuid, toFolder: folderID)
                }
            }
        }
        let gid = TabGroupIDMap.shared.groupId(for: folderID)
        return gid
    }

    // tabs.ungroup(tabIds)
    private static func ungroup(params: [String: Any], store: BrowserStore) -> Any? {
        if let s = params["tabId"] as? String, let uuid = UUID(uuidString: s) {
            onMain { store.assign(tabID: uuid, toFolder: nil) }
            return NSNull()
        }
        if let arr = params["tabIds"] as? [String] {
            onMain {
                for s in arr { if let uuid = UUID(uuidString: s) { store.assign(tabID: uuid, toFolder: nil) } }
            }
        }
        return NSNull()
    }

    // tabGroups.query({ pinned?, collapsed?, title?, color? })
    private static func query(params: [String: Any], store: BrowserStore) -> Any? {
        let pinnedFilter = params["pinned"] as? Bool
        let collapsedFilter = params["collapsed"] as? Bool
        let titleFilter = params["title"] as? String
        let colorFilter = params["color"] as? String

        let groups = store.folders.compactMap { f -> [String: Any]? in
            if let p = pinnedFilter, f.isPinned != p { return nil }
            if let c = collapsedFilter, f.isCollapsed != c { return nil }
            if let t = titleFilter, !f.name.localizedCaseInsensitiveContains(t) { return nil }
            if let col = colorFilter, f.colorHex.caseInsensitiveCompare(col) != .orderedSame { return nil }
            let gid = TabGroupIDMap.shared.groupId(for: f.id)
            return [
                "id": gid,
                "title": f.name,
                "color": f.colorHex,
                "collapsed": f.isCollapsed,
                "pinned": f.isPinned
            ]
        }
        return groups
    }

    // tabGroups.update(groupId, { title?, color?, collapsed?, pinned? })
    private static func update(params: [String: Any], store: BrowserStore) -> Any? {
        guard let gid = params["groupId"] as? Int, let fid = TabGroupIDMap.shared.folderID(for: gid) else { return NSNull() }
        let props = params["updateProperties"] as? [String: Any] ?? [:]
        if let title = props["title"] as? String { onMain { store.renameFolder(id: fid, to: title) } }
        if let color = props["color"] as? String { onMain {
            if let idx = store.folders.firstIndex(where: { $0.id == fid }) {
                store.folders[idx].colorHex = color
                // Force publish and persist
                store.folders = store.folders
                store.saveState()
            }
        } }
        if let collapsed = props["collapsed"] as? Bool { onMain { store.setFolderCollapsed(id: fid, collapsed: collapsed) } }
        if let pinned = props["pinned"] as? Bool { onMain { store.setFolderPinned(id: fid, pinned: pinned) } }
        return get(params: ["groupId": gid], store: store)
    }

    // tabGroups.get(groupId)
    private static func get(params: [String: Any], store: BrowserStore) -> Any? {
        guard let gid = params["groupId"] as? Int, let fid = TabGroupIDMap.shared.folderID(for: gid) else { return NSNull() }
        guard let f = store.folders.first(where: { $0.id == fid }) else { return NSNull() }
        return [
            "id": gid,
            "title": f.name,
            "color": f.colorHex,
            "collapsed": f.isCollapsed,
            "pinned": f.isPinned
        ]
    }
}
