import SwiftUI
import WebKit
#if os(macOS)
import AppKit
#endif

struct BrowserWebView: NSViewRepresentable {
    let tab: BrowserTab
    @EnvironmentObject private var store: BrowserStore
    @EnvironmentObject private var extensionManager: ExtensionManager

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        weak var tab: BrowserTab?
        weak var store: BrowserStore?
        weak var extensionManager: ExtensionManager?
        init(tab: BrowserTab, store: BrowserStore?, extensionManager: ExtensionManager?) {
            self.tab = tab; self.store = store; self.extensionManager = extensionManager
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            tab?.updateMetadata(from: webView)
            // If this is an extension options page, ensure the extension JS bridge exists.
            if let url = webView.url, let ext = findExtension(for: url) {
                // Inject the JS shim idempotently; the JS self-guards on __flowExtensionBridgeInstalled
                webView.evaluateJavaScript(ExtensionJSBridge.script, completionHandler: nil)
                // Note: message handler for "flowExtension" is installed in makeNSView.
                _ = ext // keep reference to avoid warnings; not used further here
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            // Could push error state if desired
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            // Optionally reload or mark state
        }
        // Handle JS bridge messages
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            switch message.name {
            case "flowOpenInNewTab":
                if let href = message.body as? String, !href.isEmpty {
                    print("[ExtBridge][Main] cmd+click open href=\(href)")
                    store?.newBackgroundTab(url: href)
                }
            case "flowExtension":
                print("[ExtBridge][Main] recv flowExtension body=\(String(describing: message.body))")
                handleExtensionMessage(message)
            default:
                break
            }
        }

        private func handleExtensionMessage(_ message: WKScriptMessage) {
            guard let body = message.body as? [String: Any] else { return }
            let api = body["api"] as? String ?? ""
            let method = body["method"] as? String ?? ""
            print("[ExtBridge][Main] parsed api=\(api) method=\(method)")
            if api == "tabs" {
                guard let cb = body["callbackId"] as? Int, let store = store, let webView = tab?.webView else { return }
                let params = body["params"] as? [String: Any] ?? [:]
                let result: Any?
                if method == "group" || method == "ungroup" {
                    result = TabGroupsAPIHost.handle(api: "tabs", method: method, params: params, store: store)
                } else {
                    result = TabsAPIHost.handle(method: method, params: params, store: store)
                }
                sendResponse(to: webView, callbackId: cb, result: result ?? NSNull())
                return
            }
            if api == "tabGroups" {
                guard let cb = body["callbackId"] as? Int, let store = store, let webView = tab?.webView else { return }
                let params = body["params"] as? [String: Any] ?? [:]
                let result = TabGroupsAPIHost.handle(api: api, method: method, params: params, store: store) ?? NSNull()
                sendResponse(to: webView, callbackId: cb, result: result)
                return
            }
            // Delegate supported APIs to extension implementation if we can resolve the owning extension
            guard let webView = tab?.webView, let url = webView.url, let ext = findExtension(for: url) else { return }
            print("[ExtBridge][Main] delegate to extension id=\(ext.id)")
            ext.handleAPICall(from: webView, message: message)
        }

        private func sendResponse(to webView: WKWebView, callbackId: Int, result: Any) {
            guard let jsonData = try? JSONSerialization.data(withJSONObject: result, options: [.fragmentsAllowed]),
                  let jsonString = String(data: jsonData, encoding: .utf8) else { return }
            print("[ExtBridge][Main] sendResponse cb=\(callbackId) json=\(jsonString)")
            let script = "window.flowExtensionCallbacks[\(callbackId)](\(jsonString)); delete window.flowExtensionCallbacks[\(callbackId)];"
            DispatchQueue.main.async { webView.evaluateJavaScript(script, completionHandler: nil) }
        }

        private func findExtension(for url: URL) -> Extension? {
            guard let extMgr = extensionManager else { return nil }
            for ext in extMgr.extensions.values {
                if url.path.hasPrefix(ext.directoryURL.path) {
                    return ext
                }
            }
            return nil
        }

        #if os(macOS)
        private func buildExtensionMenuItems() -> [NSMenuItem] {
            guard let extMgr = extensionManager else { return [] }
            var items: [NSMenuItem] = []
            for ext in extMgr.extensions.values {
                guard let mv3 = ext as? MV3Extension else { continue }
                let registry = mv3.contextMenusManager
                if registry.items.isEmpty { continue }
                let values = Array(registry.items.values)
                let byParent: [String?: [ContextMenusManager.Item]] = Dictionary(grouping: values, by: { $0.parentId })
                for root in (byParent[nil] ?? []) {
                    let rootItem = NSMenuItem(title: root.title ?? "", action: nil, keyEquivalent: "")
                    if let children = byParent[root.id], !children.isEmpty {
                        let submenu = NSMenu(title: root.title ?? "")
                        for child in children {
                            let mi = NSMenuItem(title: child.title ?? "", action: #selector(onExtensionMenuClicked(_:)), keyEquivalent: "")
                            mi.target = self
                            mi.representedObject = [
                                "extensionId": mv3.id,
                                "menuItemId": child.id
                            ]
                            submenu.addItem(mi)
                        }
                        rootItem.submenu = submenu
                    } else {
                        rootItem.action = #selector(onExtensionMenuClicked(_:))
                        rootItem.target = self
                        rootItem.representedObject = [
                            "extensionId": mv3.id,
                            "menuItemId": root.id
                        ]
                    }
                    items.append(rootItem)
                }
            }
            return items
        }

        // NSMenuDelegate: rebuild menu on demand
        func menuNeedsUpdate(_ menu: NSMenu) {
            menu.removeAllItems()
            let items = buildExtensionMenuItems()
            for item in items { menu.addItem(item) }
        }

        @objc private func onExtensionMenuClicked(_ sender: NSMenuItem) {
            guard
                let info = sender.representedObject as? [String: Any],
                let extId = info["extensionId"] as? String,
                let menuItemId = info["menuItemId"] as? String,
                let store = store,
                let tab = tab
            else { return }

            // Resolve extension instance
            guard let mv3 = extensionManager?.extensions[extId] as? MV3Extension else { return }

            // Build onClicked info and tab payloads
            let pageUrl = tab.urlString
            let infoPayload: [String: Any] = [
                "menuItemId": menuItemId,
                "frameId": 0,
                "pageUrl": pageUrl,
                "frameUrl": pageUrl
            ]
            let idx = store.tabs.firstIndex(where: { $0.id == tab.id }) ?? 0
            let tabPayload: [String: Any] = [
                "id": tab.id.uuidString,
                "index": idx,
                "active": tab.id == store.activeTabID,
                "pinned": tab.isPinned,
                "url": tab.urlString,
                "title": tab.title
            ]

            mv3.emitContextMenuClicked(info: infoPayload, tab: tabPayload)
        }
        #endif
    }

// moved to file scope at bottom for valid declaration

    func makeCoordinator() -> Coordinator { Coordinator(tab: tab, store: store, extensionManager: extensionManager) }

    func makeNSView(context: Context) -> WKWebView {
        let view = tab.webView
        view.navigationDelegate = context.coordinator
        view.uiDelegate = context.coordinator
        #if os(macOS)
        // Override default WebKit menu with extension-provided items
        let menu = NSMenu()
        menu.delegate = context.coordinator
        view.menu = menu
        #endif
        // Inject Cmd+Click handler script and message bridge only once per tab/webview
        if tab.didInstallCmdClickBridge == false {
            let js = """
            (function(){
              if (window.__flowCmdClickInstalled) return; window.__flowCmdClickInstalled = true;
              document.addEventListener('click', function(e){
                try {
                  let el = e.target;
                  while (el && el.tagName !== 'A') el = el.parentElement;
                  if (!el || !el.href) return;
                  if (e.metaKey) {
                    window.webkit.messageHandlers.flowOpenInNewTab.postMessage(el.href);
                    e.preventDefault();
                    e.stopPropagation();
                  }
                } catch (err) { /* swallow */ }
              }, true);
            })();
            """
            let script = WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: false)
            view.configuration.userContentController.addUserScript(script)
            view.configuration.userContentController.add(context.coordinator, name: "flowOpenInNewTab")
            tab.didInstallCmdClickBridge = true
        }
        // Install extension message handler and content runtime bridge (for content scripts)
        if tab.didInstallExtensionBridge == false {
            // JS handler for all worlds to reach native
            view.configuration.userContentController.add(context.coordinator, name: "flowExtension")
            // Provide a minimal chrome.* + runtime messaging shim in page contexts so content scripts can talk to background
            let extBridge = WKUserScript(source: ExtensionJSBridge.script, injectionTime: .atDocumentStart, forMainFrameOnly: false)
            view.configuration.userContentController.addUserScript(extBridge)
            tab.didInstallExtensionBridge = true
        }
        // Register this tab's webview as a messaging page for each loaded extension
        for ext in extensionManager.extensions.values {
            if let mv3 = ext as? MV3Extension {
                mv3.registerPageWebView(view)
            }
        }
        // Install content scripts for MAIN/ISOLATED worlds with proper matches/run_at/all_frames/match_about_blank
        if tab.didInstallContentScripts == false {
            let mgr = extensionManager
            for ext in mgr.extensions.values {
                    // Only MV3 for now
                    if let mv3 = ext as? MV3Extension, let csets = mv3.manifest.content_scripts {
                        for cs in csets {
                            let world = (cs.world ?? "").uppercased()
                            let runAt = (cs.run_at ?? "document_idle").lowercased()
                            let injectionTime: WKUserScriptInjectionTime
                            if runAt == "document_start" {
                                injectionTime = .atDocumentStart
                            } else if runAt == "document_idle" || runAt == "document_end" {
                                injectionTime = .atDocumentEnd
                            } else {
                                continue
                            }
                            let allFrames = cs.all_frames ?? false
                            if let files = cs.js {
                                // Ensure runtime bridge exists in the respective world for content scripts
                                if world == "ISOLATED" {
                                    if #available(macOS 11.0, *) {
                                        let contentWorld = WKContentWorld.world(name: "Flow-Ext-\(ext.id)")
                                        let bridge = WKUserScript(
                                            source: ExtensionJSBridge.script,
                                            injectionTime: .atDocumentStart,
                                            forMainFrameOnly: !allFrames,
                                            in: contentWorld
                                        )
                                        view.configuration.userContentController.addUserScript(bridge)
                                    }
                                }
                                for file in files {
                                    let scriptURL = mv3.directoryURL.appendingPathComponent(file)
                                    guard let source = try? String(contentsOf: scriptURL, encoding: .utf8) else {
                                        print("[ContentScripts] Failed to read \(scriptURL.path)")
                                        continue
                                    }
                                    // Wrap source with a URL-matching guard honoring matches and match_about_blank
                                    let wrapped = buildContentScriptWrappedSource(
                                        original: source,
                                        matches: cs.matches,
                                        matchAboutBlank: cs.match_about_blank ?? false
                                    )
                                    if world == "MAIN" {
                                        let userScript = WKUserScript(
                                            source: wrapped,
                                            injectionTime: injectionTime,
                                            forMainFrameOnly: !allFrames
                                        )
                                        view.configuration.userContentController.addUserScript(userScript)
                                    } else if world == "ISOLATED" {
                                        if #available(macOS 11.0, *) {
                                            let contentWorld = WKContentWorld.world(name: "Flow-Ext-\(ext.id)")
                                            let userScript = WKUserScript(
                                                source: wrapped,
                                                injectionTime: injectionTime,
                                                forMainFrameOnly: !allFrames,
                                                in: contentWorld
                                            )
                                            view.configuration.userContentController.addUserScript(userScript)
                                        } else {
                                            // Fallback: inject in main world if isolated worlds are unavailable
                                            let userScript = WKUserScript(
                                                source: wrapped,
                                                injectionTime: injectionTime,
                                                forMainFrameOnly: !allFrames
                                            )
                                            view.configuration.userContentController.addUserScript(userScript)
                                        }
                                    }
                                }
                            }
                        }
                    }
            }
            tab.didInstallContentScripts = true
        }
        return view
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        // If external state updates require loading, do it here.
        // We currently drive loads from SidebarView via BrowserTab.loadCurrentURL().
    }
}

#if os(macOS)
// macOS-only conformance must be declared at file scope
extension BrowserWebView.Coordinator: NSMenuDelegate {}
#endif

// MARK: - Content Script URL Matching Wrapper

private func escapeForRegex(_ s: String) -> String {
    // Escape characters with special meaning in regex
    let specials: Set<Character> = ["\\", "/", ".", "+", "?", "^", "$", "{", "}", "(", ")", "|", "[", "]"]
    var out = ""
    for ch in s {
        if specials.contains(ch) { out.append("\\") }
        out.append(ch)
    }
    return out
}

private func matchPatternToRegex(_ pattern: String) -> String? {
    if pattern == "<all_urls>" {
        return "^(?:https?|file|ftp|ws|wss):\\/\\/"
    }
    // Expect scheme://host/path
    guard let schemeSplit = pattern.range(of: "://") else { return nil }
    let schemePart = String(pattern[..<schemeSplit.lowerBound])
    let rest = String(pattern[schemeSplit.upperBound...])

    let schemeRegex: String
    if schemePart == "*" {
        schemeRegex = "(?:http|https)"
    } else {
        schemeRegex = escapeForRegex(schemePart)
    }

    let firstSlash = rest.firstIndex(of: "/")
    let hostPart = firstSlash.map { String(rest[..<$0]) } ?? rest
    let pathPart = firstSlash.map { String(rest[$0...]) } ?? "/"

    // Host regex
    let hostRegex: String
    if hostPart == "*" {
        hostRegex = "[^/]*"
    } else if hostPart.hasPrefix("*.") {
        let suffix = String(hostPart.dropFirst(2))
        hostRegex = "(?:[^/]+\\.)?" + escapeForRegex(suffix)
    } else {
        hostRegex = escapeForRegex(hostPart)
    }

    // Path regex ("*" -> ".*")
    var pr = ""
    for ch in pathPart {
        if ch == "*" { pr.append(".*") }
        else if "\\.+?^${}()|[]".contains(ch) {
            pr.append("\\\(ch)")
        } else {
            pr.append(ch)
        }
    }
    let pathRegex = pr.isEmpty ? "(?:/.*)?" : pr

    return "^" + schemeRegex + ":\\/\\/" + hostRegex + pathRegex
}

private func buildContentScriptWrappedSource(original: String, matches: [String], matchAboutBlank: Bool) -> String {
    // Build an array of regex strings from match patterns
    var regexes: [String] = []
    for p in matches {
        if let r = matchPatternToRegex(p) {
            regexes.append(r)
        }
    }
    // Fallback to block nothing if no valid patterns
    let regexArrayLiteral = regexes.map { "/\($0)/" }.joined(separator: ", ")
    let aboutBlankFlag = matchAboutBlank ? "true" : "false"
    let prefix = """
    (() => {
        const __flowMatchRegexes = [\(regexArrayLiteral)];
        const __flowMatchAboutBlank = \(aboutBlankFlag);
        function __flowUrlMatches(u) {
            if (!u) return false;
            try { const s = String(u); return __flowMatchRegexes.some(r => r.test(s)); } catch { return false; }
        }
        (function(){
            const href = location.href;
            if (href.startsWith('about:')) {
                if (!__flowMatchAboutBlank) return;
                const ref = document.referrer || '';
                if (!__flowUrlMatches(ref)) return;
            } else {
                if (!__flowUrlMatches(href)) return;
            }
        })();
    """
    let suffix = "\n})();\n"
    return prefix + original + suffix
}
