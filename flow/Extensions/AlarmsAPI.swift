import Foundation

class AlarmsAPI {
    private let alarmsManager: AlarmsManager

    init(alarmsManager: AlarmsManager) {
        self.alarmsManager = alarmsManager
    }

    func handleCall(method: String, params: [String: Any], completion: @escaping (Any?) -> Void) {
        switch method {
        case "create":
            guard let name = params["name"] as? String,
                let alarmInfo = params["alarmInfo"] as? [String: Any]
            else {
                completion(nil)
                return
            }
            alarmsManager.create(name: name, alarmInfo: alarmInfo)
            completion(nil)

        case "get":
            guard let name = params["name"] as? String else {
                completion(nil)
                return
            }
            alarmsManager.get(name: name) { alarm in
                completion(alarm?.toJSON())
            }

        case "getAll":
            alarmsManager.getAll { alarms in
                let result = alarms.map { $0.toJSON() }
                completion(result)
            }

        case "clear":
            if let name = params["name"] as? String {
                alarmsManager.clear(name: name) { wasCleared in
                    completion(wasCleared)
                }
            } else {
                // The API allows calling clear() with no arguments to clear all.
                alarmsManager.clearAll {
                    completion(true)  // The docs don't specify a return value, but true seems reasonable.
                }
            }

        case "clearAll":
            alarmsManager.clearAll {
                completion(true)
            }

        default:
            print("Unknown alarms call: \(method)")
            completion(nil)
        }
    }
}
