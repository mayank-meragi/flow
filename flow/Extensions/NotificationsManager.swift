import Foundation
import UserNotifications

final class NotificationsManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationsManager()
    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    struct Handlers {
        let onClicked: (String) -> Void
        let onClosed: (String, Bool) -> Void
    }

    // extensionId -> handlers
    private var handlers: [String: Handlers] = [:]
    // delivered notification identifier -> (extensionId, chromeNotificationId)
    private var idMap: [String: (String, String)] = [:]

    func registerHandlers(extensionId: String, onClicked: @escaping (String) -> Void, onClosed: @escaping (String, Bool) -> Void) {
        handlers[extensionId] = Handlers(onClicked: onClicked, onClosed: onClosed)
    }

    private func ensureAuthorization(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional: completion(true)
            case .denied: completion(false)
            case .notDetermined:
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    completion(granted)
                }
            @unknown default:
                completion(false)
            }
        }
    }

    func createNotification(extensionId: String, desiredId: String?, options: [String: Any], completion: @escaping (String) -> Void) {
        ensureAuthorization { granted in
            guard granted else { completion(desiredId ?? UUID().uuidString); return }
            let content = UNMutableNotificationContent()
            content.title = options["title"] as? String ?? ""
            content.body = options["message"] as? String ?? ""
            if let subtitle = options["contextMessage"] as? String, !subtitle.isEmpty {
                content.subtitle = subtitle
            }
            // iconUrl not directly supported; could be added via attachment in future
            let chromeId = desiredId ?? UUID().uuidString
            content.userInfo = [
                "extensionId": extensionId,
                "chromeNotificationId": chromeId
            ]
            let requestId = UUID().uuidString
            let request = UNNotificationRequest(identifier: requestId, content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request) { [weak self] _ in
                guard let self = self else { return }
                self.idMap[requestId] = (extensionId, chromeId)
                DispatchQueue.main.async { completion(chromeId) }
            }
        }
    }

    // MARK: UNUserNotificationCenterDelegate
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let rid = response.notification.request.identifier
        if let (extId, chromeId) = idMap[rid], let h = handlers[extId] {
            if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
                h.onClicked(chromeId)
            } else if response.actionIdentifier == UNNotificationDismissActionIdentifier {
                h.onClosed(chromeId, true)
            }
        }
        completionHandler()
    }
}
