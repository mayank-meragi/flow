import Foundation
import WebKit

final class MessagingCenter {
    private class WeakWebView {
        weak var webView: WKWebView?
        init(_ wv: WKWebView) { self.webView = wv }
    }

    private var background: WeakWebView?
    private var pages: [WeakWebView] = []
    private var portPeers: [String: WKWebView] = [:] // portId -> peer webview

    func registerBackground(_ webView: WKWebView) {
        background = WeakWebView(webView)
    }

    func registerPage(_ webView: WKWebView) {
        // Deduplicate by identity
        if pages.contains(where: { $0.webView === webView }) { return }
        pages.append(WeakWebView(webView))
        pages = pages.filter { $0.webView != nil }
    }

    private func dispatchOnMessage(to target: WKWebView, message: Any) {
        guard let data = try? JSONSerialization.data(withJSONObject: message, options: [.fragmentsAllowed]),
              let json = String(data: data, encoding: .utf8) else { return }
        let js = "window.flowBrowser.runtime.getEventListeners('runtime.onMessage').forEach(function(l){ try { l(\(json)); } catch(e){} });"
        DispatchQueue.main.async { target.evaluateJavaScript(js, completionHandler: nil) }
    }

    func sendMessage(from sender: WKWebView, message: Any) {
        // If sender is a page, deliver to background. If sender is background, broadcast to pages.
        if sender === background?.webView {
            // Background -> pages
            for page in pages {
                if let wv = page.webView, wv != sender { dispatchOnMessage(to: wv, message: message) }
            }
        } else {
            // Page -> background
            if let bg = background?.webView { dispatchOnMessage(to: bg, message: message) }
        }
    }

    func connect(from sender: WKWebView, portId: String, name: String?) {
        // Create peer mapping and fire onConnect on the other side with a created port
        if sender === background?.webView {
            // connect from background -> pages (broadcast connect)
            for page in pages {
                if let wv = page.webView {
                    portPeers[portId + "@" + hash(of: wv)] = sender
                    fireOnConnect(on: wv, portId: portId, name: name ?? "")
                }
            }
        } else {
            // connect from page -> background
            if let bg = background?.webView {
                portPeers[portId + "@" + hash(of: bg)] = sender
                fireOnConnect(on: bg, portId: portId, name: name ?? "")
            }
        }
    }

    func postPortMessage(from sender: WKWebView, portId: String, message: Any) {
        // Deliver to the peer registered via connect
        // Find the matching peer by trying both background and each page keys
        if sender === background?.webView {
            // Background sending; deliver to all pages that have this port
            for page in pages {
                if let wv = page.webView {
                    let key = portId + "@" + hash(of: wv)
                    if portPeers[key] === sender {
                        dispatchPortMessage(on: wv, portId: portId, message: message)
                    }
                }
            }
        } else {
            if let bg = background?.webView {
                let key = portId + "@" + hash(of: bg)
                if portPeers[key] === sender {
                    dispatchPortMessage(on: bg, portId: portId, message: message)
                }
            }
        }
    }

    func disconnectPort(portId: String) {
        // For now, just drop mappings. Disconnection event can be added later.
        portPeers = portPeers.filter { !$0.key.hasPrefix(portId + "@") }
    }

    private func fireOnConnect(on target: WKWebView, portId: String, name: String) {
        let js = "window.flowBrowser.runtime.getEventListeners('runtime.onConnect').forEach(function(l){ try { l(window.__flowCreatePort('" + portId + "','" + escapeForJS(name) + "')); } catch(e){} });"
        DispatchQueue.main.async { target.evaluateJavaScript(js, completionHandler: nil) }
    }

    private func dispatchPortMessage(on target: WKWebView, portId: String, message: Any) {
        guard let data = try? JSONSerialization.data(withJSONObject: message, options: [.fragmentsAllowed]),
              let json = String(data: data, encoding: .utf8) else { return }
        let js = "window.__flowDispatchPortMessage('" + portId + "', " + json + ");"
        DispatchQueue.main.async { target.evaluateJavaScript(js, completionHandler: nil) }
    }

    private func hash(of wv: WKWebView) -> String {
        return String(UInt(bitPattern: ObjectIdentifier(wv)))
    }

    private func escapeForJS(_ s: String) -> String {
        var out = s
        out = out.replacingOccurrences(of: "\\", with: "\\\\")
        out = out.replacingOccurrences(of: "'", with: "\\'")
        out = out.replacingOccurrences(of: "\"", with: "\\\"")
        out = out.replacingOccurrences(of: "\n", with: "\\n")
        out = out.replacingOccurrences(of: "\r", with: "\\r")
        return out
    }
}

