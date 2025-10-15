import SwiftUI
import Combine

final class AppState: ObservableObject {
    @Published var showCommandBar: Bool = false
    @Published var showTabSwitcher: Bool = false
    @Published var showHistory: Bool = false
    @Published var tabSwitcherSelectedIndex: Int = 0

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
}
