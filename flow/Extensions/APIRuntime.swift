import Foundation

protocol APIRuntime {
    var networkHandler: NetworkHandler { get }
    var storage: StorageAPI { get }
    var permissions: PermissionsAPI { get }
}
