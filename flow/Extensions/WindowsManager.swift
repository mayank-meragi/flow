import Foundation

// Tracks pseudo-windows created via chrome.windows.* APIs.
// We model each created window as a single tab in the BrowserStore and
// return Chrome-like window payloads for getAll/update/create.
final class WindowsManager {
    static let shared = WindowsManager()
    private init() {}

    private var nextId: Int = 1
    // windowId -> tab UUID
    private var windows: [Int: UUID] = [:]

    func createWindow(type: String?, url: String, store: BrowserStore) -> [String: Any] {
        let tabId = store.newTab(url: url)
        let winId = allocateId()
        windows[winId] = tabId
        return buildWindowDict(id: winId, type: type ?? "normal", store: store)
    }

    func updateWindow(id: Int, updateInfo: [String: Any], store: BrowserStore) -> [String: Any]? {
        guard let tabId = windows[id] else { return nil }
        // Focus window: select the associated tab
        if let focused = updateInfo["focused"] as? Bool, focused {
            store.select(tabID: tabId)
        }
        return buildWindowDict(id: id, type: "popup", store: store)
    }

    func getAll(populate: Bool, windowTypes: [String]?, store: BrowserStore) -> [[String: Any]] {
        // Clean up entries whose tabs were closed
        windows = windows.filter { (_, tabId) in store.tabs.contains { $0.id == tabId } }
        return windows.compactMap { (id, _) in
            // Filter by type if requested; we return popup type for created windows
            if let types = windowTypes, !types.isEmpty, types.contains("popup") == false { return nil }
            return buildWindowDict(id: id, type: "popup", store: store)
        }
    }

    // MARK: - Helpers

    private func allocateId() -> Int { defer { nextId += 1 }; return nextId }

    private func buildWindowDict(id: Int, type: String, store: BrowserStore) -> [String: Any] {
        var tabsArray: [[String: Any]] = []
        if let tabId = windows[id], let tab = store.tabs.first(where: { $0.id == tabId }) {
            let idx = store.tabs.firstIndex(where: { $0.id == tab.id }) ?? 0
            let tabDict: [String: Any] = [
                "id": tab.id.uuidString,
                "index": idx,
                "active": tab.id == store.activeTabID,
                "pinned": tab.isPinned,
                "url": tab.urlString,
                "title": tab.title,
                "windowId": id
            ]
            tabsArray = [tabDict]
        }
        return [
            "id": id,
            "focused": true,
            "type": type,
            "tabs": tabsArray
        ]
    }
}

