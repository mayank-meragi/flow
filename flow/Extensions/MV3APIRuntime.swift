import Foundation

class MV3APIRuntime: APIRuntime {
    let networkHandler: NetworkHandler = DeclarativeNetRequestHandler()
}
