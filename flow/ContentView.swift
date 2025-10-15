import SwiftUI
import WebKit
#if os(macOS)
import AppKit
#endif

struct ContentView: View {
    @State private var mode: SidebarMode = .fixed
    @EnvironmentObject private var store: BrowserStore
    @EnvironmentObject private var appState: AppState
    @State private var hoverEdge = false
    @State private var hoverSidebar = false

    @State private var sidebarWidth: CGFloat = 240
        private let sidebarMinWidth: CGFloat = 200
        private let sidebarMaxWidth: CGFloat = 380
    @State private var panelWidth: CGFloat = 320
        private let panelMinWidth: CGFloat = 240
        private let panelMaxWidth: CGFloat = 520
    
    let contentPadding: CGFloat = 10

    var body: some View {
        ZStack(alignment: .leading) {
            // Background
            Color.gray
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .cornerRadius(16)
                .ignoresSafeArea(.all, edges: .top)

            TriPaneContainer(
                leftWidth: $sidebarWidth,
                rightWidth: $panelWidth,
                isLeftVisible: Binding(
                    get: { mode == .fixed },
                    set: { mode = $0 ? .fixed : .floating }
                ),
                isRightVisible: $appState.isRightPanelVisible,
                leftMin: sidebarMinWidth,
                leftMax: sidebarMaxWidth,
                rightMin: panelMinWidth,
                rightMax: panelMaxWidth,
                handleWidth: 8,
                animationDuration: 0.45
            ) {
                SidebarView(mode: $mode)
                    .environmentObject(store)
                    .padding([.top, .bottom, .leading], contentPadding)
                    .padding(.trailing, contentPadding/2)
                    .ignoresSafeArea(.all, edges: .top)
            } main: {
                mainContentView(trailingPadding: contentPadding / 2)
            } right: {
                if let item = appState.rightPanelItem, appState.isRightPanelVisible {
                    RightPanelContainer(title: panelTitle(for: item), isPresented: Binding(
                        get: { appState.isRightPanelVisible },
                        set: { newVal in if !newVal { closeRightPanelAnimated() } }
                    )) {
                        panelContent(for: item)
                    }
                    .ignoresSafeArea(.all, edges: .top)
                } else {
                    Color.clear
                }
            }

            // Floating sidebar overlay when in floating mode
            if mode == .floating && showFloatingSidebar {
                SidebarView(mode: $mode)
                    .environmentObject(store)
                    .frame(width: sidebarWidth)
                    .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 0)
                    .transition(.move(edge: .leading))
                    .zIndex(1)
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.2)) { hoverSidebar = hovering }
                    }
                    .ignoresSafeArea(.all, edges: .top)
            }

            // Hot zone at the leading edge to reveal the sidebar (floating mode only)
            if mode == .floating {
                Color.clear
                    .contentShape(Rectangle())
                    .frame(width: 8)
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.2)) { hoverEdge = hovering }
                    }
                    .ignoresSafeArea(.all, edges: .top)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: mode)
        .animation(.easeInOut(duration: 0.2), value: showFloatingSidebar)
        // Overlay: Command Bar centered over everything
        .overlay(alignment: .center) {
            if appState.showCommandBar {
                CommandBarView(isPresented: $appState.showCommandBar)
            }
        }
        // Overlay: Tab Switcher (appears above everything)
        .overlay(alignment: .center) {
            if appState.showTabSwitcher {
                TabSwitcherView()
            }
        }
        
        // Always-on modifier key monitor to detect Ctrl release
        .overlay(alignment: .topLeading) {
            ModifierKeyMonitor { flags in
                #if os(macOS)
                appState.setControlDown(flags.contains(.control))
                #endif
            }
            .frame(width: 0, height: 0)
        }
        .onAppear {
            hideNativeTrafficLights()
            appState.onTabSwitcherCommit = { idx in
                if store.tabs.indices.contains(idx) {
                    store.select(index: idx)
                }
            }
        }
    }

    private var showFloatingSidebar: Bool {
        mode == .floating && (hoverEdge || hoverSidebar)
    }

    // Extracted main content view for reuse inside splits
    @ViewBuilder
    private func mainContentView(trailingPadding: CGFloat) -> some View {
        Group {
            if let active = store.active {
                BrowserWebView(tab: active)
                    .id(active.id)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(radius: 5)
                    .padding(EdgeInsets(top: contentPadding, leading: mode == .fixed ? contentPadding/2 : contentPadding, bottom: contentPadding, trailing: trailingPadding))
            } else {
                Color.clear
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.all, edges: .top)
    }

    // MARK: - Right Panel Content Routing
    private func panelTitle(for item: RightPanelContent) -> String {
        switch item {
        case .history: return "History"
        }
    }

    @ViewBuilder
    private func panelContent(for item: RightPanelContent) -> some View {
        switch item {
        case .history:
            HistoryPanelContent { entry in
                store.navigateActive(to: entry.urlString)
                closeRightPanelAnimated()
            }
            .environmentObject(store)
        }
    }

    // MARK: - Right Panel Open/Close Animations
    private func closeRightPanelAnimated() {
        let dur = 0.45
        withAnimation(.easeInOut(duration: dur)) {
            appState.isRightPanelVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + dur) {
            appState.rightPanelItem = nil
        }
    }

#if os(macOS)
    private func hideNativeTrafficLights() {
        if let window = NSApplication.shared.windows.first {
            window.standardWindowButton(.closeButton)?.isHidden = true
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            window.standardWindowButton(.zoomButton)?.isHidden = true
        }
    }
#endif
}

// (Custom split layout in use; no NSSplitView helpers needed.)
