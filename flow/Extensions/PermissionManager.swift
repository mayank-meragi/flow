import Foundation

class PermissionManager {
    private let extensionId: String

    init(extensionId: String, initialPermissions: [String] = []) {
        self.extensionId = extensionId
        // Automatically grant permissions declared in the manifest upon installation
        grant(permissions: initialPermissions)
    }

    var grantedPermissions: [String] {
        return UserDefaults.standard.stringArray(forKey: permissionsStoreKey) ?? []
    }

    func hasPermission(for permission: String) -> Bool {
        return grantedPermissions.contains(permission)
    }

    func grant(permissions: [String]) {
        var currentPermissions = grantedPermissions
        for permission in permissions {
            if !currentPermissions.contains(permission) {
                currentPermissions.append(permission)
            }
        }
        UserDefaults.standard.set(currentPermissions, forKey: permissionsStoreKey)
    }

    func revoke(permissions: [String]) {
        var currentPermissions = grantedPermissions
        currentPermissions.removeAll { permissions.contains($0) }
        UserDefaults.standard.set(currentPermissions, forKey: permissionsStoreKey)
    }

    private var permissionsStoreKey: String {
        return "extension_permissions_\(extensionId)"
    }
}
