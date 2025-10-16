import Foundation

class StorageManager {
    private let extensionId: String
    private var sessionData: [String: Any] = [:]

    init(extensionId: String) {
        self.extensionId = extensionId
    }

    // MARK: - Local Storage (UserDefaults)

    func getLocal(keys: [String]) -> [String: Any] {
        let store = UserDefaults.standard.dictionary(forKey: localStoreKey) ?? [:]
        return store.filter { keys.contains($0.key) }
    }

    func setLocal(items: [String: Any]) {
        var store = UserDefaults.standard.dictionary(forKey: localStoreKey) ?? [:]
        for (key, value) in items {
            store[key] = value
        }
        UserDefaults.standard.set(store, forKey: localStoreKey)
    }

    func removeLocal(keys: [String]) {
        var store = UserDefaults.standard.dictionary(forKey: localStoreKey) ?? [:]
        for key in keys {
            store.removeValue(forKey: key)
        }
        UserDefaults.standard.set(store, forKey: localStoreKey)
    }

    func clearLocal() {
        UserDefaults.standard.removeObject(forKey: localStoreKey)
    }

    // MARK: - Session Storage (In-Memory)

    func getSession(keys: [String]) -> [String: Any] {
        return sessionData.filter { keys.contains($0.key) }
    }

    func setSession(items: [String: Any]) {
        for (key, value) in items {
            sessionData[key] = value
        }
    }

    func removeSession(keys: [String]) {
        for key in keys {
            sessionData.removeValue(forKey: key)
        }
    }

    func clearSession() {
        sessionData.removeAll()
    }

    // MARK: - Private

    private var localStoreKey: String {
        return "extension_local_storage_\(extensionId)"
    }
}
