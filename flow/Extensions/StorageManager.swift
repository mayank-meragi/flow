import Foundation

// Represents the changes for a single key in storage.
struct StorageChange {
    let oldValue: Any?
    let newValue: Any?

    func toJSON() -> [String: Any?] {
        return ["oldValue": oldValue, "newValue": newValue]
    }
}

class StorageManager {
    private let extensionId: String
    private var sessionData: [String: Any] = [:]

    init(extensionId: String) {
        self.extensionId = extensionId
    }

    // MARK: - Local Storage (UserDefaults)

    func getLocal(keys: [String]) -> [String: Any] {
        let store = UserDefaults.standard.dictionary(forKey: localStoreKey) ?? [:]
        if keys.isEmpty {
            return store
        }
        return store.filter { keys.contains($0.key) }
    }

    func setLocal(items: [String: Any]) -> [String: StorageChange] {
        var changes: [String: StorageChange] = [:]
        var store = UserDefaults.standard.dictionary(forKey: localStoreKey) ?? [:]
        for (key, value) in items {
            let oldValue = store[key]
            // Note: Comparing complex values might not work as expected.
            // For simplicity, we consider any 'set' as a change.
            if !areEqual(oldValue, value) {
                changes[key] = StorageChange(oldValue: oldValue, newValue: value)
            }
            store[key] = value
        }
        UserDefaults.standard.set(store, forKey: localStoreKey)
        return changes
    }

    func removeLocal(keys: [String]) -> [String: StorageChange] {
        var changes: [String: StorageChange] = [:]
        var store = UserDefaults.standard.dictionary(forKey: localStoreKey) ?? [:]
        for key in keys {
            if let oldValue = store.removeValue(forKey: key) {
                changes[key] = StorageChange(oldValue: oldValue, newValue: nil)
            }
        }
        UserDefaults.standard.set(store, forKey: localStoreKey)
        return changes
    }

    func clearLocal() -> [String: StorageChange] {
        var changes: [String: StorageChange] = [:]
        if let oldStore = UserDefaults.standard.dictionary(forKey: localStoreKey) {
            for (key, value) in oldStore {
                changes[key] = StorageChange(oldValue: value, newValue: nil)
            }
        }
        UserDefaults.standard.removeObject(forKey: localStoreKey)
        return changes
    }

    // MARK: - Session Storage (In-Memory)

    func getSession(keys: [String]) -> [String: Any] {
        if keys.isEmpty {
            return sessionData
        }
        return sessionData.filter { keys.contains($0.key) }
    }

    func setSession(items: [String: Any]) -> [String: StorageChange] {
        var changes: [String: StorageChange] = [:]
        for (key, value) in items {
            let oldValue = sessionData[key]
            if !areEqual(oldValue, value) {
                changes[key] = StorageChange(oldValue: oldValue, newValue: value)
            }
            sessionData[key] = value
        }
        return changes
    }

    func removeSession(keys: [String]) -> [String: StorageChange] {
        var changes: [String: StorageChange] = [:]
        for key in keys {
            if let oldValue = sessionData.removeValue(forKey: key) {
                changes[key] = StorageChange(oldValue: oldValue, newValue: nil)
            }
        }
        return changes
    }

    func clearSession() -> [String: StorageChange] {
        let oldData = sessionData
        sessionData.removeAll()
        return oldData.mapValues { StorageChange(oldValue: $0, newValue: nil) }
    }

    // MARK: - Private

    private var localStoreKey: String {
        return "extension_local_storage_\(extensionId)"
    }
}

// Basic equality check for Any. This is a simplification.
// A robust implementation would need to handle different types, collections, etc.
private func areEqual(_ lhs: Any?, _ rhs: Any?) -> Bool {
    switch (lhs, rhs) {
    case (let lhs as any Equatable, let rhs as any Equatable):
        // This will fail for different types, e.g. Int vs Double
        return lhs.isEqual(rhs)
    default:
        return false
    }
}

extension Equatable {
    func isEqual(_ other: any Equatable) -> Bool {
        guard let other = other as? Self else {
            return false
        }
        return self == other
    }
}
