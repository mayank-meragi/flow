import Foundation

class MV2APIRuntime: APIRuntime {
    let networkHandler: NetworkHandler = WebRequestAPIHandler()
    let storage: StorageAPI

    init(storageManager: StorageManager) {
        self.storage = StorageAPI(storageManager: storageManager)
    }
}
