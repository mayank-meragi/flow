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
    @State private var dragStartWidth: CGFloat? = nil
        private let sidebarMinWidth: CGFloat = 200
        private let sidebarMaxWidth: CGFloat = 380
    
    let contentPadding: CGFloat = 10

    var body: some View {
        ZStack(alignment: .leading) {
            // Background
            Color.gray
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .cornerRadius(16)
                .ignoresSafeArea(.all, edges: .top)

            // Main content with optional fixed sidebar (custom split layout)
            HStack(spacing: 0) {
                if mode == .fixed {
                    ZStack(alignment: .trailing) {
                        SidebarView(mode: $mode)
                            .environmentObject(store)
                            .padding([.top, .bottom, .leading], contentPadding)
                            .padding(.trailing, contentPadding/2)
                            .frame(width: sidebarWidth)
                            .ignoresSafeArea(.all, edges: .top)
                            .transition(.move(edge: .leading))

                        // Invisible drag handle to resize (acts like hidden divider)
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .frame(width: 6)
                            .gesture(
                                DragGesture(minimumDistance: 1)
                                    .onChanged { value in
                                        if dragStartWidth == nil { dragStartWidth = sidebarWidth }
                                        let base = dragStartWidth ?? sidebarWidth
                                        let newWidth = min(max(base + value.translation.width, sidebarMinWidth), sidebarMaxWidth)
                                        if abs(newWidth - sidebarWidth) > 0.1 {
                                            sidebarWidth = newWidth
                                        }
                                    }
                                    .onEnded { _ in
                                        dragStartWidth = nil
                                    }
                            )
                    }
                }

                Group {
                    if let active = store.active {
                        BrowserWebView(tab: active)
                            .id(active.id)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .shadow(radius: 5)
                            .padding(
                                mode == .fixed
                                ? EdgeInsets(top: contentPadding, leading: contentPadding/2, bottom: contentPadding, trailing: contentPadding)
                                : EdgeInsets(top: contentPadding, leading: contentPadding, bottom: contentPadding, trailing: contentPadding)
                            )
                    } else {
                        Color.clear
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea(.all, edges: .top)
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
                Color.red
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
        // Overlay: History
        .overlay(alignment: .center) {
            if appState.showHistory {
                HistoryView(isPresented: $appState.showHistory)
                    .environmentObject(store)
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
