import Foundation

class MV2APIRuntime: APIRuntime {
    let networkHandler: NetworkHandler = WebRequestAPIHandler()
    let storage: StorageAPI
    let permissions: PermissionsAPI

    init(
        storageManager: StorageManager, permissionManager: PermissionManager, extensionName: String
    ) {
        self.storage = StorageAPI(storageManager: storageManager)
        self.permissions = PermissionsAPI(
            permissionManager: permissionManager, extensionName: extensionName)
    }
}
