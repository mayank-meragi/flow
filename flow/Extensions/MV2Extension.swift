import Foundation
import WebKit

class MV2Extension: Extension {
    let id: String
    let manifest: Manifest
    lazy var runtime: APIRuntime = {
        let notificationsAPI = NotificationsAPI(extensionId: id, onClicked: { [weak self] notifId in
            self?.emitNotificationClicked(notifId)
        }, onClosed: { [weak self] notifId, byUser in
            self?.emitNotificationClosed(notifId: notifId, byUser: byUser)
        })
        return MV2APIRuntime(
            storageManager: self.storageManager,
            permissionManager: self.permissionManager,
            alarmsManager: self.alarmsManager,
            i18nManager: self.i18nManager,
            extensionName: self.manifest.name ?? "Unknown Extension",
            notificationsAPI: notificationsAPI
        )
    }()
    let directoryURL: URL
    let storageManager: StorageManager
    let permissionManager: PermissionManager
    let alarmsManager: AlarmsManager
    let i18nManager: I18nManager
    private var backgroundHost: BackgroundPageHost?
    private let messaging = MessagingCenter()

    init(manifest: Manifest, directoryURL: URL) {
        let id = UUID().uuidString
        self.id = id
        self.manifest = manifest
        self.directoryURL = directoryURL
        self.storageManager = StorageManager(extensionId: id)
        let allPermissions = (manifest.permissions ?? []) + (manifest.host_permissions ?? [])
        self.permissionManager = PermissionManager(
            extensionId: id, initialPermissions: allPermissions)
        self.alarmsManager = AlarmsManager()
        self.i18nManager = I18nManager(
            extensionDirectory: directoryURL, defaultLocale: manifest.default_locale)
        let notificationsAPI = NotificationsAPI(extensionId: id, onClicked: { [weak self] notifId in
            self?.emitNotificationClicked(notifId)
        }, onClosed: { [weak self] notifId, byUser in
            self?.emitNotificationClosed(notifId: notifId, byUser: byUser)
        })
        // Weak self to avoid retain cycles
        self.alarmsManager.onAlarm = { [weak self] alarm in
            // This is tricky. We don't know which webView to broadcast to.
            // For now, we can't fully implement this part without a way to
            // access all active views for this extension.
            // This will be revisited when a proper event broadcasting mechanism is in place.
            print("Alarm fired: \(alarm.name). Broadcasting not yet implemented.")
        }
    }

    func start() {
        // Start persistent background page if present
        if let bg = manifest.background, let page = bg.page, !page.isEmpty {
            let host = BackgroundPageHost(ext: self, pageRelativePath: page)
            self.backgroundHost = host
            host.start()
            if let wv = host.webView { messaging.registerBackground(wv) }
        }
    }
    func stop() {}
    
    // Broadcast tabs.* events into the background context
    func broadcastTabsEvent(name: String, payload: [String: Any]) {
        guard let bg = backgroundHost?.webView else { return }
        broadcastEvent(to: bg, name: name, payload: payload)
    }

    func handleAPICall(from webView: WKWebView, message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
            let api = body["api"] as? String,
            let method = body["method"] as? String,
            let params = body["params"] as? [String: Any],
            let callbackId = body["callbackId"] as? Int
        else {
            print("Invalid API call message format")
            return
        }

        switch api {
        case "notifications":
            runtime.notifications.handleCall(method: method, params: params) { result in
                self.sendResponse(to: webView, callbackId: callbackId, result: result)
            }
        case "network":
            if method == "fetch" {
                handleNetworkFetch(params: params) { result in
                    self.sendResponse(to: webView, callbackId: callbackId, result: result)
                }
            } else {
                self.sendResponse(to: webView, callbackId: callbackId, result: NSNull())
            }
        case "storage":
            guard let area = body["area"] as? String else { return }

            runtime.storage.handleCall(area: area, method: method, params: params) {
                result, changes in
                self.sendResponse(to: webView, callbackId: callbackId, result: result)

                if let changes = changes, !changes.isEmpty {
                    let changesJSON = changes.mapValues { $0.toJSON() }
                    self.broadcastEvent(
                        to: webView,
                        name: "storage.onChanged",
                        payload: ["changes": changesJSON, "area": area]
                    )
                }
            }

        case "permissions":
            runtime.permissions.handleCall(method: method, params: params) { result in
                self.sendResponse(to: webView, callbackId: callbackId, result: result)
            }

        case "alarms":
            runtime.alarms.handleCall(method: method, params: params) { result in
                self.sendResponse(to: webView, callbackId: callbackId, result: result)
            }

        case "i18n":
            runtime.i18n.handleCall(method: method, params: params) { result in
                self.sendResponse(to: webView, callbackId: callbackId, result: result)
            }

        case "runtime":
            self.handleRuntimeCall(from: webView, method: method, params: params) { result in
                self.sendResponse(to: webView, callbackId: callbackId, result: result)
            }

        default:
            print("Unknown API: \(api)")
        }
    }

    private func sendResponse(to webView: WKWebView, callbackId: Int, result: Any?) {
        let resultData: Any
        if let result = result {
            resultData = result
        } else {
            resultData = NSNull()
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: resultData, options: [.fragmentsAllowed]),
            let jsonString = String(data: jsonData, encoding: .utf8)
        else {
            // Handle error: could not serialize result
            return
        }

        let script =
            "window.flowExtensionCallbacks[\(callbackId)](\(jsonString)); delete window.flowExtensionCallbacks[\(callbackId)];"

        DispatchQueue.main.async {
            webView.evaluateJavaScript(script)
        }
    }

    private func broadcastEvent(to webView: WKWebView, name: String, payload: [String: Any]) {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload, options: []),
            let jsonString = String(data: jsonData, encoding: .utf8)
        else {
            print("Error serializing event payload")
            return
        }

        // This is a simplified event dispatch. A real implementation would need a more robust
        // event listener system in the JS context.
        let script =
            "window.flowBrowser.runtime.getEventListeners('\(name)').forEach(l => l(\(jsonString)))"

        DispatchQueue.main.async {
            webView.evaluateJavaScript(script)
        }
    }

    // MARK: - Network (MV2 host-permissions enforced fetch)
    private func handleNetworkFetch(params: [String: Any], completion: @escaping (Any?) -> Void) {
        guard let urlString = params["url"] as? String else { completion(["_error": "Invalid URL"]); return }

        // Evaluate against host permissions. Support MV2 style host wildcards inside permissions as well.
        var patterns: [String] = []
        if let hostPerms = manifest.host_permissions { patterns.append(contentsOf: hostPerms) }
        if let perms = manifest.permissions {
            for p in perms { if p == "<all_urls>" || p.contains("://") { patterns.append(p) } }
        }
        if patterns.isEmpty || HostPermissions.isAllowed(urlString: urlString, patterns: patterns) == false {
            completion(["_error": "Host not permitted by host_permissions"])
            return
        }

        // Build request
        let opts = params["options"] as? [String: Any] ?? [:]
        var request = URLRequest(url: URL(string: urlString)!)
        request.httpMethod = (opts["method"] as? String) ?? "GET"
        if let headers = opts["headers"] as? [String: Any] {
            for (k, v) in headers {
                if let s = v as? String { request.setValue(s, forHTTPHeaderField: k) }
            }
        }
        if let body = opts["body"] as? String { request.httpBody = body.data(using: .utf8) }

        // Perform via URLSession (bypasses WebView CORS)
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(["_error": error.localizedDescription])
                return
            }
            let http = response as? HTTPURLResponse
            let status = http?.statusCode ?? 0
            var headersOut: [String: String] = [:]
            if let all = http?.allHeaderFields {
                for (k, v) in all { headersOut[String(describing: k)] = String(describing: v) }
            }
            let bodyText: String = {
                if let d = data, let s = String(data: d, encoding: .utf8) { return s }
                return ""
            }()
            let result: [String: Any] = [
                "ok": (200...299).contains(status),
                "status": status,
                "statusText": HTTPURLResponse.localizedString(forStatusCode: status),
                "url": urlString,
                "headers": headersOut,
                "bodyText": bodyText
            ]
            completion(result)
        }
        task.resume()
    }

    // MARK: - Runtime Messaging (MV2)
    private func handleRuntimeCall(from webView: WKWebView, method: String, params: [String: Any], completion: (Any?) -> Void) {
        switch method {
        case "sendMessage":
            let message = params["message"] ?? NSNull()
            messaging.sendMessage(from: webView, message: message)
            completion(NSNull())
        case "connect":
            let name = params["name"] as? String
            let portId = params["portId"] as? String ?? UUID().uuidString
            messaging.connect(from: webView, portId: portId, name: name)
            completion(["portId": portId])
        case "postPortMessage":
            guard let portId = params["portId"] as? String else { completion(NSNull()); return }
            let message = params["message"] ?? NSNull()
            messaging.postPortMessage(from: webView, portId: portId, message: message)
            completion(NSNull())
        case "disconnectPort":
            if let portId = params["portId"] as? String { messaging.disconnectPort(portId: portId) }
            completion(NSNull())
        default:
            completion(NSNull())
        }
    }

    func registerPageWebView(_ webView: WKWebView) {
        messaging.registerPage(webView)
    }

    // MARK: - Notifications event emitters
    private func emitNotificationClicked(_ notificationId: String) {
        guard let bg = backgroundHost?.webView else { return }
        let js = "(function(){ try { var ls=window.flowBrowser.runtime.getEventListeners('notifications.onClicked')||[]; ls.forEach(function(l){ try { l('" + notificationId + "'); } catch(e){} }); } catch(e){} })()"
        DispatchQueue.main.async { bg.evaluateJavaScript(js, completionHandler: nil) }
    }
    private func emitNotificationClosed(notifId: String, byUser: Bool) {
        guard let bg = backgroundHost?.webView else { return }
        let byUserStr = byUser ? "true" : "false"
        let js = "(function(){ try { var ls=window.flowBrowser.runtime.getEventListeners('notifications.onClosed')||[]; ls.forEach(function(l){ try { l('" + notifId + "', " + byUserStr + "); } catch(e){} }); } catch(e){} })()"
        DispatchQueue.main.async { bg.evaluateJavaScript(js, completionHandler: nil) }
    }
}
