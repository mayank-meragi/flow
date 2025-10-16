import Foundation

class PermissionsAPI {
    private let permissionManager: PermissionManager
    private let extensionName: String

    init(permissionManager: PermissionManager, extensionName: String) {
        self.permissionManager = permissionManager
        self.extensionName = extensionName
    }

    func handleCall(method: String, params: [String: Any], completion: @escaping (Any?) -> Void) {
        switch method {
        case "getAll":
            let allPermissions = permissionManager.grantedPermissions
            completion(["permissions": allPermissions])

        case "contains":
            guard let permissions = params["permissions"] as? [String] else {
                completion(false)
                return
            }
            let hasAll = permissions.allSatisfy { permissionManager.hasPermission(for: $0) }
            completion(hasAll)

        case "request":
            guard let permissionsToRequest = params["permissions"] as? [String] else {
                completion(false)
                return
            }

            let request = PermissionRequest(
                extensionName: self.extensionName,
                permissions: permissionsToRequest
            ) { granted in
                if granted {
                    self.permissionManager.grant(permissions: permissionsToRequest)
                }
                completion(granted)
            }

            NotificationCenter.default.post(
                name: .requestPermission, object: nil, userInfo: ["request": request])

        default:
            print("Unknown permissions call: \(method)")
            completion(nil)
        }
    }
}
