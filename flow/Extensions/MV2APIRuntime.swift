import Foundation

class MV2APIRuntime: APIRuntime {
    let networkHandler: NetworkHandler = WebRequestAPIHandler()
    let storage: StorageAPI
    let permissions: PermissionsAPI
    let alarms: AlarmsAPI
    let i18n: I18nAPI
    let notifications: NotificationsAPI

    init(
        storageManager: StorageManager,
        permissionManager: PermissionManager,
        alarmsManager: AlarmsManager,
        i18nManager: I18nManager,
        extensionName: String,
        notificationsAPI: NotificationsAPI
    ) {
        self.storage = StorageAPI(storageManager: storageManager)
        self.permissions = PermissionsAPI(
            permissionManager: permissionManager, extensionName: extensionName)
        self.alarms = AlarmsAPI(alarmsManager: alarmsManager)
        self.i18n = I18nAPI(i18nManager: i18nManager)
        self.notifications = notificationsAPI
    }
}
