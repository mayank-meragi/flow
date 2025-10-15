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
    @State private var panelAnimatedWidth: CGFloat = 0
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

            // Main content using CustomHSplit on both sides
            Group {
                if mode == .fixed {
                    // OUTER split: left sidebar vs rest
                    CustomHSplit(leadingWidth: $sidebarWidth, minWidth: sidebarMinWidth, maxWidth: sidebarMaxWidth, dragHandleWidth: 8, suppressImplicitAnimations: false) {
                        SidebarView(mode: $mode)
                            .environmentObject(store)
                            .padding([.top, .bottom, .leading], contentPadding)
                            .padding(.trailing, contentPadding/2)
                            .ignoresSafeArea(.all, edges: .top)
                            .transition(.move(edge: .leading))
                    } trailing: {
                        // INNER split (only when right panel is open): main content vs right panel
                        if let item = appState.rightPanelItem {
                            GeometryReader { proxy in
                                let total = proxy.size.width
                                let minLeading = max(0, total - panelMaxWidth)
                                let maxLeading = max(0, total - panelMinWidth)
                                let leadingBinding = Binding<CGFloat>(
                                    get: { max(minLeading, min(maxLeading, total - panelAnimatedWidth)) },
                                    set: { newLeading in
                                        let clampedLeading = min(max(newLeading, minLeading), maxLeading)
                                        let newPanel = total - clampedLeading
                                        let clampedPanel = min(max(newPanel, panelMinWidth), panelMaxWidth)
                                        if abs(clampedPanel - panelWidth) > 0.5 {
                                            // dragging – update both the target and animated widths without animation
                                            var tx = Transaction(); tx.disablesAnimations = true
                                            withTransaction(tx) {
                                                panelWidth = clampedPanel
                                                panelAnimatedWidth = clampedPanel
                                            }
                                        }
                                    }
                                )

                                CustomHSplit(leadingWidth: leadingBinding, minWidth: minLeading, maxWidth: maxLeading, dragHandleWidth: 8, suppressImplicitAnimations: false) {
                                    mainContentView(trailingPadding: contentPadding/2)
                                } trailing: {
                                    RightPanelContainer(title: panelTitle(for: item), isPresented: Binding(
                                        get: { appState.rightPanelItem != nil },
                                        set: { newVal in if !newVal { closeRightPanelAnimated() } }
                                    )) {
                                        panelContent(for: item)
                                    }
                                }
                            }
                            .onAppear { openRightPanelAnimated() }
                        } else {
                            // No right panel: just main content
                            mainContentView(trailingPadding: contentPadding)
                        }
                    }
                    .animation(nil, value: sidebarWidth)
                } else {
                    // Floating sidebar mode: no left split, optional right split
                    if let item = appState.rightPanelItem {
                        GeometryReader { proxy in
                            let total = proxy.size.width
                            let minLeading = max(0, total - panelMaxWidth)
                            let maxLeading = max(0, total - panelMinWidth)
                            let leadingBinding = Binding<CGFloat>(
                                get: { max(minLeading, min(maxLeading, total - panelAnimatedWidth)) },
                                set: { newLeading in
                                    let clampedLeading = min(max(newLeading, minLeading), maxLeading)
                                    let newPanel = total - clampedLeading
                                    let clampedPanel = min(max(newPanel, panelMinWidth), panelMaxWidth)
                                    if abs(clampedPanel - panelWidth) > 0.5 {
                                        var tx = Transaction(); tx.disablesAnimations = true
                                        withTransaction(tx) {
                                            panelWidth = clampedPanel
                                            panelAnimatedWidth = clampedPanel
                                        }
                                    }
                                }
                            )

                            CustomHSplit(leadingWidth: leadingBinding, minWidth: minLeading, maxWidth: maxLeading, dragHandleWidth: 8, suppressImplicitAnimations: true) {
                                mainContentView(trailingPadding: contentPadding/2)
                            } trailing: {
                                RightPanelContainer(title: panelTitle(for: item), isPresented: Binding(
                                    get: { appState.rightPanelItem != nil },
                                    set: { newVal in if !newVal { closeRightPanelAnimated() } }
                                )) {
                                    panelContent(for: item)
                                }
                            }
                        }
                        .onAppear { openRightPanelAnimated() }
                    } else {
                        mainContentView(trailingPadding: contentPadding)
                    }
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
            panelAnimatedWidth = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + dur) {
            appState.closeRightPanel()
        }
    }

    private func openRightPanelAnimated() {
        let dur = 0.45
        let target = max(panelWidth, panelMinWidth)
        panelAnimatedWidth = 0
        withAnimation(.easeInOut(duration: dur)) {
            panelAnimatedWidth = target
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
