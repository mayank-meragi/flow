import WebKit
import Combine

final class WebEngine: ObservableObject {
    static let shared = WebEngine()

    let processPool = WKProcessPool()
    let userContentController = WKUserContentController() // legacy (unused by per-webview setup)
    let dataStore: WKWebsiteDataStore = .default()

    // Debug toggle: when true, do not attach content rules
    @Published var contentRulesDisabled: Bool = false

    private init() {}

    func makeConfiguration() -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        config.processPool = processPool
        config.websiteDataStore = dataStore
        // Use a fresh content controller per webview so we can attach per-tab handlers
        config.userContentController = WKUserContentController()
        // Ensure modern desktop behavior and JS enabled
        let pagePrefs = WKWebpagePreferences()
        pagePrefs.allowsContentJavaScript = true
        pagePrefs.preferredContentMode = .desktop
        config.defaultWebpagePreferences = pagePrefs

        // Belt-and-suspenders: legacy preference flag
        config.preferences.javaScriptEnabled = true
        // Ensure site-specific quirks are enabled (public in recent WebKit; KVC-safe)
        config.preferences.setValue(true, forKey: "siteSpecificQuirksModeEnabled")

        // Use the system default Safari-like User-Agent (avoid custom tokens)
        config.applicationNameForUserAgent = nil

        // Explicitly opt out of App-Bound Domains navigation limits for general browsing
        if #available(macOS 11.0, *) {
            config.limitsNavigationsToAppBoundDomains = false
        }
        return config
    }

    // MARK: - Diagnostics
    var appBoundDomainsInInfoPlist: [String] {
        if let arr = Bundle.main.object(forInfoDictionaryKey: "WKAppBoundDomains") as? [String] {
            return arr
        }
        return []
    }

    // MARK: - Data Management
    func clearSiteData(forDomains domains: [String],
                       types: Set<String> = WKWebsiteDataStore.allWebsiteDataTypes(),
                       completion: @escaping () -> Void) {
        dataStore.fetchDataRecords(ofTypes: types) { records in
            let targets = records.filter { record in
                domains.contains { domain in record.displayName.contains(domain) }
            }
            if targets.isEmpty {
                completion()
                return
            }
            if #available(macOS 12.0, *) {
                self.dataStore.removeData(ofTypes: types, for: targets) {
                    completion()
                }
            } else {
                // Fallback: clear broadly if targeted removal is unavailable
                self.dataStore.removeData(ofTypes: types, modifiedSince: .distantPast) {
                    completion()
                }
            }
        }
    }
}
