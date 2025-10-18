import SwiftUI

@main
struct flowApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var store = BrowserStore()
    @StateObject private var extensionManager = ExtensionManager()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(store)
                .environmentObject(extensionManager)
                .onAppear {
                    // Provide BrowserStore to scripting host for background execution
                    ScriptingAPIHost.setStore(store)
                    extensionManager.loadExtensions()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            // Remove default "Close" (⌘W) so it doesn't close the window
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .windowArrangement) {}
            AppCommands(appState: appState, store: store, engine: WebEngine.shared)
        }
    }
}
