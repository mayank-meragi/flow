import Foundation

final class ContextMenusManager {
    struct Item {
        let id: String
        var parentId: String?
        var title: String?
        var enabled: Bool
        var contexts: [String]?
    }

    private(set) var items: [String: Item] = [:]

    func create(props: [String: Any]) -> String {
        let id: String = {
            if let s = props["id"] as? String { return s }
            if let n = props["id"] as? Int { return String(n) }
            return UUID().uuidString
        }()
        let parentId: String? = {
            if let s = props["parentId"] as? String { return s }
            if let n = props["parentId"] as? Int { return String(n) }
            return nil
        }()
        let title = props["title"] as? String
        let enabled = (props["enabled"] as? Bool) ?? true
        let contexts = props["contexts"] as? [String]
        let item = Item(id: id, parentId: parentId, title: title, enabled: enabled, contexts: contexts)
        items[id] = item
        return id
    }

    func removeAll() {
        items.removeAll()
    }

    func remove(id: String) {
        // Remove item and any children referencing it as parent
        items.removeValue(forKey: id)
        let childIds = items.values.filter { $0.parentId == id }.map { $0.id }
        for child in childIds { items.removeValue(forKey: child) }
    }
}

