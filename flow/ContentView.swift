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

    private let sidebarWidth: CGFloat = 240

    var body: some View {
        ZStack {
            // Background
            Color.blue
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea(.all, edges: .top)

            if mode == .fixed {
                // Standard split: sidebar consumes layout space
                HSplitView {
                    SidebarView(mode: $mode)
                        .environmentObject(store)
                        .ignoresSafeArea(.all, edges: .top)

                    Group {
                        if let active = store.active {
                            BrowserWebView(tab: active)
                                .id(active.id)
                        } else {
                            Color.black.opacity(0.02)
                        }
                    }
                    .ignoresSafeArea(.all, edges: .top)
                }
            } else {
                // Floating sidebar: main takes full space; sidebar overlays and slides in on hover
                ZStack(alignment: .leading) {
                    Group {
                        if let active = store.active {
                            BrowserWebView(tab: active)
                                .id(active.id)
                        } else {
                            Color.black.opacity(0.02)
                        }
                    }
                        .ignoresSafeArea(.all, edges: .top)

                    SidebarView(mode: $mode)
                        .environmentObject(store)
                        .frame(width: sidebarWidth)
                        .offset(x: showFloatingSidebar ? 0 : -sidebarWidth - 8)
                        .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 0)
                        .onHover { hovering in
                            withAnimation(.easeInOut(duration: 0.2)) { hoverSidebar = hovering }
                        }
                        .ignoresSafeArea(.all, edges: .top)

                    // Hot zone at the leading edge to reveal the sidebar
                    Color.clear
                        .contentShape(Rectangle())
                        .frame(width: 4)
                        .onHover { hovering in
                            withAnimation(.easeInOut(duration: 0.2)) { hoverEdge = hovering }
                        }
                        .ignoresSafeArea(.all, edges: .top)
                }
                .animation(.easeInOut(duration: 0.2), value: showFloatingSidebar)
            }
        }
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
