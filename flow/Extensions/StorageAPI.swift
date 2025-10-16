import Foundation

class StorageAPI {
    private let storageManager: StorageManager

    init(storageManager: StorageManager) {
        self.storageManager = storageManager
    }

    func handleCall(
        area: String, method: String, params: [String: Any], completion: @escaping (Any?) -> Void
    ) {
        switch (area, method) {
        // Local Storage
        case ("local", "get"):
            let keys = params["keys"] as? [String] ?? []
            let result = storageManager.getLocal(keys: keys)
            completion(result)
        case ("local", "set"):
            let items = params["items"] as? [String: Any] ?? [:]
            storageManager.setLocal(items: items)
            completion(nil)
        case ("local", "remove"):
            let keys = params["keys"] as? [String] ?? []
            storageManager.removeLocal(keys: keys)
            completion(nil)
        case ("local", "clear"):
            storageManager.clearLocal()
            completion(nil)

        // Session Storage
        case ("session", "get"):
            let keys = params["keys"] as? [String] ?? []
            let result = storageManager.getSession(keys: keys)
            completion(result)
        case ("session", "set"):
            let items = params["items"] as? [String: Any] ?? [:]
            storageManager.setSession(items: items)
            completion(nil)
        case ("session", "remove"):
            let keys = params["keys"] as? [String] ?? []
            storageManager.removeSession(keys: keys)
            completion(nil)
        case ("session", "clear"):
            storageManager.clearSession()
            completion(nil)

        default:
            print("Unknown storage call: \(area).\(method)")
            completion(nil)
        }
    }
}
