import Foundation

class MV3APIRuntime: APIRuntime {
    let networkHandler: NetworkHandler = DeclarativeNetRequestHandler()
    let storage: StorageAPI

    init(storageManager: StorageManager) {
        self.storage = StorageAPI(storageManager: storageManager)
    }
}
