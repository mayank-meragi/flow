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
            CommandGroup(replacing: .windowArrangement) { }
            AppCommands(appState: appState, store: store, engine: WebEngine.shared)
        }
    }
}
