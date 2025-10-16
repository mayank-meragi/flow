import SwiftUI

@main
struct flowApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var store = BrowserStore()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(store)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            // Remove default "Close" (⌘W) so it doesn't close the window
            CommandGroup(replacing: .newItem) { }
            CommandGroup(replacing: .windowArrangement) { }
            AppCommands(appState: appState, store: store, engine: WebEngine.shared)
        }
    }
}
