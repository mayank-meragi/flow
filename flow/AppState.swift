import Combine
import SwiftUI

enum RightPanelContent {
    case history
    case extensions
    // future: bookmarks, downloads, etc.
}

final class AppState: ObservableObject {
    @Published var showCommandBar: Bool = false
    @Published var showTabSwitcher: Bool = false
    @Published var tabSwitcherSelectedIndex: Int = 0
    @Published var rightPanelItem: RightPanelContent? = nil
    @Published var isRightPanelVisible: Bool = false
    // Triggers focusing the URL bar when incremented
    @Published var focusURLBarTick: Int = 0
    @Published var sidebarMode: SidebarMode = .fixed

    // Commit target when ctrl is released
    var onTabSwitcherCommit: ((Int) -> Void)?

    private(set) var isControlDown: Bool = false

    func beginTabSwitching(currentIndex: Int) {
        tabSwitcherSelectedIndex = currentIndex
        showTabSwitcher = true
    }

    func stepTabSwitching(count: Int, total: Int) {
        guard total > 0 else { return }
        let next = tabSwitcherSelectedIndex + count
        tabSwitcherSelectedIndex = ((next % total) + total) % total
    }

    func dismissTabSwitcher(commit: Bool) {
        if commit { onTabSwitcherCommit?(tabSwitcherSelectedIndex) }
        showTabSwitcher = false
    }

    // Invoked from modifier key monitor
    func setControlDown(_ down: Bool) {
        guard down != isControlDown else { return }
        isControlDown = down
        if !down, showTabSwitcher {
            // Commit selection when ctrl is released
            onTabSwitcherCommit?(tabSwitcherSelectedIndex)
            showTabSwitcher = false
        }
    }

    // Right Panel control
    func openRightPanel(_ item: RightPanelContent) {
        rightPanelItem = item
        isRightPanelVisible = true
    }
    func closeRightPanel() {
        isRightPanelVisible = false
        rightPanelItem = nil
    }

    // Sidebar control
    func toggleSidebarMode() {
        sidebarMode = (sidebarMode == .fixed) ? .floating : .fixed
    }

    // Request URL bar focus
    func focusURLBar() { focusURLBarTick &+= 1 }
}
