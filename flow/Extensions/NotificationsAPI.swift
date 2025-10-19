import Foundation

class NotificationsAPI {
    private let extensionId: String
    private let manager: NotificationsManager

    init(extensionId: String, manager: NotificationsManager = .shared, onClicked: @escaping (String) -> Void, onClosed: @escaping (String, Bool) -> Void) {
        self.extensionId = extensionId
        self.manager = manager
        self.manager.registerHandlers(extensionId: extensionId, onClicked: onClicked, onClosed: onClosed)
    }

    func handleCall(method: String, params: [String: Any], completion: @escaping (Any?) -> Void) {
        switch method {
        case "create":
            let id = params["notificationId"] as? String
            let options = params["options"] as? [String: Any] ?? [:]
            manager.createNotification(extensionId: extensionId, desiredId: id, options: options) { nid in
                completion(nid)
            }
        default:
            completion(nil)
        }
    }
}

