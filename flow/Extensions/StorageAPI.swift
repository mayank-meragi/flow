import Foundation

class StorageAPI {
    private let storageManager: StorageManager

    init(storageManager: StorageManager) {
        self.storageManager = storageManager
    }

    func handleCall(
        area: String,
        method: String,
        params: [String: Any],
        completion: @escaping (Any?, [String: StorageChange]?) -> Void
    ) {
        var changes: [String: StorageChange]?

        switch (area, method) {
        // Local Storage
        case ("local", "get"):
            let keys = params["keys"] as? [String] ?? []
            let result = storageManager.getLocal(keys: keys)
            completion(result, nil)
        case ("local", "set"):
            let items = params["items"] as? [String: Any] ?? [:]
            changes = storageManager.setLocal(items: items)
            completion(nil, changes)
        case ("local", "remove"):
            let keys = params["keys"] as? [String] ?? []
            changes = storageManager.removeLocal(keys: keys)
            completion(nil, changes)
        case ("local", "clear"):
            changes = storageManager.clearLocal()
            completion(nil, changes)

        // Session Storage
        case ("session", "get"):
            let keys = params["keys"] as? [String] ?? []
            let result = storageManager.getSession(keys: keys)
            completion(result, nil)
        case ("session", "set"):
            let items = params["items"] as? [String: Any] ?? [:]
            changes = storageManager.setSession(items: items)
            completion(nil, changes)
        case ("session", "remove"):
            let keys = params["keys"] as? [String] ?? []
            changes = storageManager.removeSession(keys: keys)
            completion(nil, changes)
        case ("session", "clear"):
            changes = storageManager.clearSession()
            completion(nil, changes)

        default:
            print("Unknown storage call: \(area).\(method)")
            completion(nil, nil)
        }
    }
}
