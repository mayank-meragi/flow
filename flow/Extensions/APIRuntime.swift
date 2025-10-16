import Foundation

protocol APIRuntime {
    var networkHandler: NetworkHandler { get }
    var storage: StorageAPI { get }
    var permissions: PermissionsAPI { get }
    var alarms: AlarmsAPI { get }
    var i18n: I18nAPI { get }
}
