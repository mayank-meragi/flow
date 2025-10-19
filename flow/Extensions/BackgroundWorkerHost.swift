import Foundation
import WebKit

// Hosts a service-worker-like background context for MV3 extensions by
// running their background/index.js inside an offscreen WKWebView.
final class BackgroundWorkerHost: NSObject, WKScriptMessageHandler, WKNavigationDelegate, WKUIDelegate {
    private(set) var webView: WKWebView!
    private weak var ext: Extension?
    private let scriptRelativePath: String

    init(ext: Extension, scriptRelativePath: String) {
        self.ext = ext
        self.scriptRelativePath = scriptRelativePath
        super.init()
        configureWebView()
    }

    private func configureWebView() {
        let config = WKWebViewConfiguration()
        let ucc = WKUserContentController()

        // Inject background bridge at document start
        let bridge = WKUserScript(source: BackgroundJSBridge.script, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        ucc.addUserScript(bridge)
        ucc.add(self, name: "flowExtension")
        config.userContentController = ucc

        // Preferences
        let pagePrefs = WKWebpagePreferences()
        pagePrefs.allowsContentJavaScript = true
        pagePrefs.preferredContentMode = .desktop
        config.defaultWebpagePreferences = pagePrefs
        config.preferences.javaScriptEnabled = true

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = self
        wv.uiDelegate = self
        self.webView = wv
    }

    func start() {
        guard let ext = ext else { return }
        // Ensure baseURL ends with a trailing slash so relative URLs resolve
        // within the extension directory rather than its parent.
        var baseURL = ext.directoryURL
        #if compiler(>=5.7)
        if #available(macOS 13.0, *) {
            if baseURL.hasDirectoryPath == false {
                baseURL.append(path: "", directoryHint: .isDirectory)
            }
        } else {
            baseURL = baseURL.appendingPathComponent("", isDirectory: true)
        }
        #else
        baseURL = baseURL.appendingPathComponent("", isDirectory: true)
        #endif

        // Try to inline the background script (avoids file URL loading issues).
        let scriptURL = baseURL.appendingPathComponent(scriptRelativePath)
        let inlineJS: String? = try? String(contentsOf: scriptURL, encoding: .utf8)

        // Minimal HTML shell that loads the extension's background script.
        let html: String
        if let js = inlineJS {
            let safe = js.replacingOccurrences(of: "</script>", with: "<\\/script>")
            html = """
            <!doctype html>
            <meta charset=\"utf-8\">
            <title>Flow Background Worker</title>
            <script>
              // Mark and add basic diagnostics from the background world
              window.__flowBackground = true;
              (function(){
                function post(msg){ try { window.webkit.messageHandlers.flowExtension.postMessage(msg); } catch(e) {} }
                document.addEventListener('DOMContentLoaded', function(){
                  post({ api: 'debug', method: 'bgDomReady', href: location.href, inline: true });
                }, { once: true });
                post({ api: 'debug', method: 'bgInline', src: '\(scriptRelativePath)' });
              })();
            </script>
            <script>\n\(safe)\n</script>
            """
        } else {
            html = """
            <!doctype html>
            <meta charset=\"utf-8\">
            <title>Flow Background Worker</title>
            <script>
              window.__flowBackground = true;
              (function(){
                function post(msg){ try { window.webkit.messageHandlers.flowExtension.postMessage(msg); } catch(e) {} }
                document.addEventListener('DOMContentLoaded', function(){
                  post({ api: 'debug', method: 'bgDomReady', href: location.href, inline: false });
                }, { once: true });
                post({ api: 'debug', method: 'bgInlineFail', src: '\(scriptRelativePath)' });
              })();
            </script>
            <script src=\"\(scriptRelativePath)\" defer
              onload=\"try{window.webkit.messageHandlers.flowExtension.postMessage({api:'debug',method:'bgScriptLoad',ok:true,src:this.src});}catch(e){}\"
              onerror=\"try{window.webkit.messageHandlers.flowExtension.postMessage({api:'debug',method:'bgScriptLoad',ok:false,src:this.src});}catch(e){}\"
            ></script>
            """
        }

        webView.loadHTMLString(html, baseURL: baseURL)
        print("[BackgroundWorkerHost] Started for script: \(scriptRelativePath) at base: \(baseURL.path)")
    }

    func stop() {
        webView.stopLoading()
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
    }

    // MARK: WKScriptMessageHandler
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "flowExtension" else { return }
        if let body = message.body as? [String: Any] {
            let api = body["api"] as? String ?? ""
            let method = body["method"] as? String ?? ""
            let cb = body["callbackId"] as? Int
            print("[BackgroundWorkerHost] recv api=\(api) method=\(method) cb=\(String(describing: cb)) bodyKeys=\(Array(body.keys))")
            if api == "debug" && method == "onMessageDispatch" {
                let listCount = body["listCount"] ?? "?"
                let senderUrl = body["senderUrl"] ?? "?"
                print("[BackgroundWorkerHost] debug onMessageDispatch listeners=\(listCount) senderUrl=\(senderUrl)")
                return
            } else if api == "debug" && method == "onMessageAdded" {
                let count = body["count"] ?? "?"
                print("[BackgroundWorkerHost] debug onMessageAdded total=\(count)")
                return
            } else if api == "debug" && method == "bgProbe" {
                print("[BackgroundWorkerHost] probe count=\(body["count"] ?? "?") hasMessenger=\(body["hasMessenger"] ?? "?") hasExtension=\(body["hasExtension"] ?? "?") hasChrome=\(body["hasChrome"] ?? "?") hasOnMessage=\(body["hasOnMessage"] ?? "?") href=\(body["href"] ?? "?")")
                return
            } else if api == "debug" && method == "bgScriptLoad" {
                let ok = body["ok"] ?? "?"
                let src = body["src"] ?? "?"
                print("[BackgroundWorkerHost] script load result ok=\(ok) src=\(src)")
                return
            } else if api == "debug" && method == "bgDomReady" {
                print("[BackgroundWorkerHost] DOM ready href=\(body["href"] ?? "?")")
                return
            } else if api == "debug" && method == "onMessageSendResponseCalled" {
                let t = body["type"] ?? "?"
                let has = body["hasPayload"] ?? "?"
                let ptype = body["payloadType"] ?? "?"
                print("[BackgroundWorkerHost] onMessageSendResponseCalled type=\(t) hasPayload=\(has) payloadType=\(ptype)")
                return
            } else if api == "debug" && method == "onMessageNoResponse" {
                print("[BackgroundWorkerHost] onMessageNoResponse type=\(body["type"] ?? "?")")
                return
            } else if api == "debug" && method == "onMessageNoListeners" {
                print("[BackgroundWorkerHost] onMessageNoListeners type=\(body["type"] ?? "?")")
                return
            } else if api == "debug" && method == "onMessageListenerInvoked" {
                print("[BackgroundWorkerHost] onMessageListenerInvoked index=\(body["index"] ?? "?")")
                return
            } else if api == "debug" && method == "onMessageListenerError" {
                print("[BackgroundWorkerHost] onMessageListenerError index=\(body["index"] ?? "?")")
                return
            } else if api == "debug" && method == "onMessageDispatchError" {
                print("[BackgroundWorkerHost] onMessageDispatchError error=\(body["error"] ?? "?")")
                return
            } else if api == "debug" && method == "diag" {
                let label = body["label"] ?? "?"
                if let types = body["types"] as? [String: Any] {
                    let chromeType = types["chrome"] ?? "?"
                    let runtimeType = types["runtime"] ?? "?"
                    let onMsgType = types["onMessage"] ?? "?"
                    let addType = types["addListener"] ?? "?"
                    let count = types["listenerCount"] ?? "?"
                    let href = types["href"] ?? "?"
                    print("[BackgroundWorkerHost] diag \(label): chrome=\(chromeType) runtime=\(runtimeType) onMessage=\(onMsgType) addListener=\(addType) listenerCount=\(count) href=\(href)")
                } else {
                    print("[BackgroundWorkerHost] diag \(label)")
                }
                return
            } else if api == "debug" && method == "messengerPatched" {
                print("[BackgroundWorkerHost] messengerPatched")
                return
            } else if api == "debug" && method == "messengerMessage" {
                print("[BackgroundWorkerHost] messengerMessage type=\(body["msgType"] ?? "?") sender=\(body["senderUrl"] ?? "?") allowed0=\(body["allowed0"] ?? "?")")
                return
            } else if api == "debug" && method == "collectStart" {
                print("[BackgroundWorkerHost] collectStart")
                return
            } else if api == "debug" && method == "collectDone" {
                print("[BackgroundWorkerHost] collectDone")
                return
            } else if api == "debug" && method == "collectSync" {
                print("[BackgroundWorkerHost] collectSync")
                return
            } else if api == "debug" && method == "collectError" {
                print("[BackgroundWorkerHost] collectError error=\(body["error"] ?? "?")")
                return
            } else if api == "debug" && method == "collectThrow" {
                print("[BackgroundWorkerHost] collectThrow error=\(body["error"] ?? "?")")
                return
            }
        } else {
            print("[BackgroundWorkerHost] recv non-dictionary message: \(String(describing: message.body))")
        }
        // Delegate to the extension runtime (storage, permissions, alarms, i18n)
        if let ext = ext, let wv = webView {
            // Intercept background -> native response for runtime.sendMessage
            if let body = message.body as? [String: Any],
               let api = body["api"] as? String, api == "runtime",
               let method = body["method"] as? String, method == "deliverMessageResponse",
               let ext = ext as? MV3Extension {
                let params = body["params"] as? [String: Any] ?? body
                if let cb = params["callbackId"] as? Int {
                    var summary = ""
                    if let dict = params["response"] as? [String: Any] {
                        summary = "keys=" + Array(dict.keys).joined(separator: ",")
                    } else if let arr = params["response"] as? [Any] {
                        summary = "arrayCount=\(arr.count)"
                    } else if let resp = params["response"] {
                        summary = "type=\(type(of: resp))"
                    } else {
                        summary = "type=nil"
                    }
                    print("[BackgroundWorkerHost] deliverMessageResponse cb=\(cb) \(summary)")
                }
                ext.handleRuntimeDeliverMessageResponse(params)
                return
            } else {
                ext.handleAPICall(from: wv, message: message)
            }
        }
    }

    // MARK: WKNavigationDelegate
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Probe background globals and listener count
        let probe = "(function(){ try { var ls=(window.flowBrowser&&window.flowBrowser.runtime&&window.flowBrowser.runtime.getEventListeners)?window.flowBrowser.runtime.getEventListeners('runtime.onMessage'):null; var count=(ls&&ls.length)||0; var hasMessenger=typeof Messenger !== 'undefined'; var hasExtension=typeof Extension !== 'undefined'; var hasChrome=typeof chrome !== 'undefined'; var hasOnMsg=!!(chrome&&chrome.runtime&&chrome.runtime.onMessage); var url=location.href; if (window.webkit&&window.webkit.messageHandlers&&window.webkit.messageHandlers.flowExtension){ window.webkit.messageHandlers.flowExtension.postMessage({ api:'debug', method:'bgProbe', count: count, hasMessenger: hasMessenger, hasExtension: hasExtension, hasChrome: hasChrome, hasOnMessage: hasOnMsg, href: url }); } } catch(e){} })()"
        webView.evaluateJavaScript(probe, completionHandler: nil)

        // Install a safety listener if Dark Reader didn't attach one yet
        let installSafety = "(function(){ try { if ((window.flowBrowser&&window.flowBrowser.runtime&&window.flowBrowser.runtime.getEventListeners&&window.flowBrowser.runtime.getEventListeners('runtime.onMessage')||[]).length===0 && typeof Messenger !== 'undefined' && chrome && chrome.runtime && chrome.runtime.onMessage && chrome.runtime.onMessage.addListener) { chrome.runtime.onMessage.addListener(function(msg, sender, sendResponse){ try { Messenger.onUIMessage(msg, sendResponse); } catch(e){} }); } } catch(e){} })()"
        webView.evaluateJavaScript(installSafety, completionHandler: nil)
    }
}
