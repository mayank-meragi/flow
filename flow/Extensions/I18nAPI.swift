import Foundation

class I18nAPI {
    private let i18nManager: I18nManager

    init(i18nManager: I18nManager) {
        self.i18nManager = i18nManager
    }

    func handleCall(method: String, params: [String: Any], completion: @escaping (Any?) -> Void) {
        switch method {
        case "getMessage":
            guard let key = params["key"] as? String else {
                completion(nil)
                return
            }
            let substitutions = params["substitutions"] as? [Any]
            let message = i18nManager.getMessage(key: key, substitutions: substitutions)
            completion(message)

        default:
            print("Unknown i18n call: \(method)")
            completion(nil)
        }
    }
}
