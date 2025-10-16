import Foundation

struct Alarm {
    let name: String
    let scheduledTime: TimeInterval
    let periodInMinutes: Double?

    // Converts the alarm to a dictionary that can be sent to the extension.
    func toJSON() -> [String: Any] {
        var dict: [String: Any] = [
            "name": name,
            "scheduledTime": scheduledTime * 1000,  // Convert to milliseconds for JS
        ]
        if let periodInMinutes = periodInMinutes {
            dict["periodInMinutes"] = periodInMinutes
        }
        return dict
    }
}

class AlarmsManager {
    private var alarms: [String: Alarm] = [:]
    private var timers: [String: Timer] = [:]

    // Callback to be triggered when an alarm fires.
    var onAlarm: ((Alarm) -> Void)?

    func create(name: String, alarmInfo: [String: Any]) {
        // If an alarm with the same name already exists, clear it first.
        if let existingTimer = timers[name] {
            existingTimer.invalidate()
            timers.removeValue(forKey: name)
        }

        let now = Date().timeIntervalSince1970
        var scheduledTime: TimeInterval = 0

        if let when = alarmInfo["when"] as? TimeInterval {
            scheduledTime = when / 1000  // Convert from milliseconds
        } else if let delayInMinutes = alarmInfo["delayInMinutes"] as? Double {
            scheduledTime = now + delayInMinutes * 60
        } else {
            // Default to now if no time is specified.
            scheduledTime = now
        }

        let periodInMinutes = alarmInfo["periodInMinutes"] as? Double

        let alarm = Alarm(
            name: name, scheduledTime: scheduledTime, periodInMinutes: periodInMinutes)
        alarms[name] = alarm

        let delay = scheduledTime - now
        let timer = Timer(
            fire: Date(timeIntervalSince1970: scheduledTime),
            interval: periodInMinutes != nil ? periodInMinutes! * 60 : 0,
            repeats: periodInMinutes != nil,
            block: { [weak self] _ in
                self?.onAlarm?(alarm)
                // If it's not a repeating alarm, invalidate it.
                if periodInMinutes == nil {
                    self?.timers[name]?.invalidate()
                    self?.timers.removeValue(forKey: name)
                }
            })

        RunLoop.main.add(timer, forMode: .common)
        timers[name] = timer
    }

    func get(name: String, completion: @escaping (Alarm?) -> Void) {
        completion(alarms[name])
    }

    func getAll(completion: @escaping ([Alarm]) -> Void) {
        completion(Array(alarms.values))
    }

    func clear(name: String, completion: @escaping (Bool) -> Void) {
        if let timer = timers[name] {
            timer.invalidate()
            timers.removeValue(forKey: name)
            alarms.removeValue(forKey: name)
            completion(true)
        } else {
            completion(false)
        }
    }

    func clearAll(completion: @escaping () -> Void) {
        for timer in timers.values {
            timer.invalidate()
        }
        timers.removeAll()
        alarms.removeAll()
        completion()
    }
}
