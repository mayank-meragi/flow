import Foundation
import WebKit

class MV3Extension: Extension {
    let id: String
    let manifest: Manifest
    let runtime: APIRuntime
    let directoryURL: URL
    let storageManager: StorageManager
    let permissionManager: PermissionManager
    let alarmsManager: AlarmsManager
    let i18nManager: I18nManager
    let contextMenusManager = ContextMenusManager()
    private var backgroundHost: BackgroundWorkerHost?
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
        self.runtime = MV3APIRuntime(
            storageManager: self.storageManager,
            permissionManager: self.permissionManager,
            alarmsManager: self.alarmsManager,
            i18nManager: self.i18nManager,
            extensionName: manifest.name ?? "Unknown Extension"
        )

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
        // Start background worker if present
        if let bg = manifest.background, let sw = bg.service_worker, !sw.isEmpty {
            let host = BackgroundWorkerHost(ext: self, scriptRelativePath: sw)
            self.backgroundHost = host
            host.start()
            // Register background context for messaging
            if let wv = host.webView {
                messaging.registerBackground(wv)
            }
        }
        // Register keyboard shortcuts from manifest commands
        registerCommands()
    }
    func stop() {}

    // Emit a contextMenus.onClicked event into the background context
    func emitContextMenuClicked(info: [String: Any], tab: [String: Any]?) {
        guard let bg = backgroundHost?.webView else { return }
        let infoJSON: String = {
            if let data = try? JSONSerialization.data(withJSONObject: info, options: [.fragmentsAllowed]),
               let s = String(data: data, encoding: .utf8) { return s }
            return "{}"
        }()
        let tabJSON: String = {
            if let tab = tab,
               let data = try? JSONSerialization.data(withJSONObject: tab, options: [.fragmentsAllowed]),
               let s = String(data: data, encoding: .utf8) { return s }
            return "null"
        }()
        let js = "(function(){ try { var ls = window.flowBrowser.runtime.getEventListeners('contextMenus.onClicked'); var info = \(infoJSON); var tab = \(tabJSON); (ls||[]).forEach(function(l){ try { l(info, tab); } catch(e){} }); } catch(e){} })()"
        DispatchQueue.main.async { bg.evaluateJavaScript(js, completionHandler: nil) }
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
        case "tabs":
            // Route background tabs.* calls via host
            if let store = ScriptingAPIHost.getStore() {
                if method == "sendMessage" {
                    let _ = TabsAPIHost.sendMessage(params: params, store: store)
                    self.sendResponse(to: webView, callbackId: callbackId, result: NSNull())
                } else {
                    let result = TabsAPIHost.handle(method: method, params: params, store: store)
                    self.sendResponse(to: webView, callbackId: callbackId, result: result)
                }
            } else {
                self.sendResponse(to: webView, callbackId: callbackId, result: NSNull())
            }
            
        case "windows":
            if let store = ScriptingAPIHost.getStore() {
                let result = WindowsAPIHost.handle(method: method, params: params, store: store)
                self.sendResponse(to: webView, callbackId: callbackId, result: result)
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

        case "scripting":
            if method == "executeScript" {
                ScriptingAPIHost.executeScript(ext: self, params: params) { result in
                    self.sendResponse(to: webView, callbackId: callbackId, result: result)
                }
            } else {
                self.sendResponse(to: webView, callbackId: callbackId, result: NSNull())
            }

        case "contextMenus":
            let result = ContextMenusAPIHost.handle(ext: self, method: method, params: params)
            self.sendResponse(to: webView, callbackId: callbackId, result: result)

        case "fontSettings":
            let result = FontSettingsAPIHost.handle(method: method, params: params)
            self.sendResponse(to: webView, callbackId: callbackId, result: result)

        default:
            print("Unknown API: \(api)")
        }
    }

    func registerPageWebView(_ webView: WKWebView) {
        messaging.registerPage(webView)
    }

    // Broadcast tabs.* events into the background context
    func broadcastTabsEvent(name: String, payload: [String: Any]) {
        guard let bg = backgroundHost?.webView else { return }
        broadcastEvent(to: bg, name: name, payload: payload)
    }

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
            guard let portId = params["portId"] as? String else {
                completion(NSNull()); return
            }
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

    // MARK: - Commands
    private func registerCommands() {
        guard let cmds = manifest.commands, !cmds.isEmpty else { return }
        KeyCommandCenter.shared.install()
        for (name, def) in cmds {
            guard let combo = def.suggested_key?.default else { continue }
            if let parsed = Self.parseShortcut(combo) {
                KeyCommandCenter.shared.register(key: parsed.key, modifiers: parsed.modifiers) { [weak self] in
                    self?.emitCommand(name)
                }
            }
        }
    }

    private static func parseShortcut(_ s: String) -> (key: String, modifiers: NSEvent.ModifierFlags)? {
        #if os(macOS)
        let parts = s.split(separator: "+").map { String($0).trimmingCharacters(in: .whitespaces).lowercased() }
        var mods: NSEvent.ModifierFlags = []
        var key: String?
        for p in parts {
            switch p {
            case "cmd", "command", "meta": mods.insert(.command)
            case "alt", "option": mods.insert(.option)
            case "shift": mods.insert(.shift)
            case "ctrl", "control": mods.insert(.control)
            default:
                if key == nil, let ch = p.first, p.count == 1 { key = String(ch) }
            }
        }
        guard let k = key else { return nil }
        return (k, mods)
        #else
        return nil
        #endif
    }

    func emitCommand(_ name: String) {
        guard let bg = backgroundHost?.webView else { return }
        let safe = name.replacingOccurrences(of: "'", with: "\\'")
        let js = "(function(){ try { var ls = window.flowBrowser.runtime.getEventListeners('commands.onCommand'); (ls||[]).forEach(function(l){ try { l('" + safe + "'); } catch(e){} }); } catch(e){} })()"
        DispatchQueue.main.async { bg.evaluateJavaScript(js, completionHandler: nil) }
    }
}
