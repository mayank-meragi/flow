import SwiftUI
import WebKit
#if os(macOS)
import AppKit
#endif

struct AppCommands: Commands {
    @ObservedObject var appState: AppState
    @ObservedObject var store: BrowserStore
    @ObservedObject var engine: WebEngine

    var body: some Commands {
        CommandMenu("Flow") {
            Button("Open Command Bar") { appState.showCommandBar.toggle() }
                .keyboardShortcut("t", modifiers: [.command])
        }

        CommandMenu("Tabs") {
            Button("Next Tab (Switcher)") { tabSwitcherNext() }
                .keyboardShortcut(.tab, modifiers: [.control])
            Button("Previous Tab (Switcher)") { tabSwitcherPrevious() }
                .keyboardShortcut(.tab, modifiers: [.control, .shift])
            Divider()
            Button("Close Current Tab") {
                if let active = store.active, active.isPinned == false {
                    store.close(tabID: active.id)
                }
            }
            .keyboardShortcut("w", modifiers: [.command])
            .disabled(store.active?.isPinned ?? true)
        }

        CommandMenu("Navigation") {
            Button("Focus URL Bar") { appState.focusURLBar() }
                .keyboardShortcut("l", modifiers: [.command])
        }

        CommandMenu("Debug") {
            Button("Show User-Agent") { showUserAgent() }
            Toggle("Disable Content Rules", isOn: $engine.contentRulesDisabled)
            Divider()
            Button("Show App-Bound Domains Status") { showAppBoundDomainsStatus() }
            Button("Clear Cookies (Current Site)") { clearCookiesForCurrentSite() }
            Button("Clear Cache (Current Site)") { clearCacheForCurrentSite() }
            Button("Clear Cookies + Cache (Current Site)") { clearAllDataForCurrentSite() }
        }
    }

    private func showUserAgent() {
        guard let webView = store.active?.webView else { return }
        webView.evaluateJavaScript("navigator.userAgent") { result, _ in
            #if os(macOS)
            let ua = (result as? String) ?? "Unavailable"
            let alert = NSAlert()
            alert.messageText = "Current User-Agent"
            alert.informativeText = ua
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
            #endif
        }
    }

    private func showAppBoundDomainsStatus() {
        #if os(macOS)
        let domains = engine.appBoundDomainsInInfoPlist
        let alert = NSAlert()
        alert.messageText = "App-Bound Domains"
        if domains.isEmpty {
            alert.informativeText = "WKAppBoundDomains not found in Info.plist. General browsing should not be restricted by App-Bound Domains."
        } else {
            alert.informativeText = "WKAppBoundDomains present (\(domains.count)):\n\n\(domains.joined(separator: "\n"))\n\nNote: This can restrict WebKit APIs for non-bound domains and cause simplified UIs. Consider removing this key for general browsing or using a separate configuration."
        }
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
        #endif
    }

    private func currentHost() -> String? {
        store.active?.webView.url?.host
    }

    private func showInfo(_ title: String, _ message: String) {
        #if os(macOS)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
        #endif
    }

    private func clearCookiesForCurrentSite() {
        guard let host = currentHost() else {
            showInfo("No Active Site", "Open a page first to clear its cookies.")
            return
        }
        let types: Set<String> = [WKWebsiteDataTypeCookies]
        engine.clearSiteData(forDomains: [host], types: types) {
            showInfo("Cleared Cookies", "Removed cookies for: \(host)")
        }
    }

    private func clearCacheForCurrentSite() {
        guard let host = currentHost() else {
            showInfo("No Active Site", "Open a page first to clear its cache.")
            return
        }
        let types: Set<String> = [WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache]
        engine.clearSiteData(forDomains: [host], types: types) {
            showInfo("Cleared Cache", "Removed cache for: \(host)")
        }
    }

    private func clearAllDataForCurrentSite() {
        guard let host = currentHost() else {
            showInfo("No Active Site", "Open a page first to clear its data.")
            return
        }
        engine.clearSiteData(forDomains: [host]) {
            showInfo("Cleared Cookies + Cache", "Removed data for: \(host)")
        }
    }
}

extension AppCommands {
    private func tabSwitcherNext() {
        let total = store.tabs.count
        guard total > 0 else { return }
        let currentIdx = store.activeIndex ?? 0
        if appState.showTabSwitcher == false { appState.beginTabSwitching(currentIndex: currentIdx) }
        appState.stepTabSwitching(count: 1, total: total)
    }

    private func tabSwitcherPrevious() {
        let total = store.tabs.count
        guard total > 0 else { return }
        let currentIdx = store.activeIndex ?? 0
        if appState.showTabSwitcher == false { appState.beginTabSwitching(currentIndex: currentIdx) }
        appState.stepTabSwitching(count: -1, total: total)
    }
}
