import SwiftUI
import WebKit

struct ExtensionToolbarView: View {
    @EnvironmentObject var extensionManager: ExtensionManager
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var store: BrowserStore
    @State private var showingPopoverFor: String?  // Extension ID

    var body: some View {
        HStack {
            ForEach(Array(extensionManager.extensions.values), id: \.id) { ext in
                Button(action: {
                    if ext.manifest.action?.default_popup != nil {
                        showingPopoverFor = ext.id
                    }
                }) {
                    ExtensionIconView(extension: ext, size: 16)
                }
                .buttonStyle(.plain)
                .popover(
                    isPresented: Binding(
                        get: { showingPopoverFor == ext.id },
                        set: { if !$0 { showingPopoverFor = nil } }
                    ), arrowEdge: .bottom
                ) {
                    PopoverContent(extension: ext)
                }
                .contextMenu {
                    if let optionsPage = ext.manifest.options_page {
                        Button("Options") {
                            let optionsURL = ext.directoryURL.appendingPathComponent(optionsPage)
                            store.newTab(url: optionsURL.absoluteString)
                        }
                    }
                    Button("Manage extension") {
                        appState.openRightPanel(.extensions)
                    }
                    Divider()
                    Button(role: .destructive) {
                        extensionManager.remove(id: ext.id)
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                }
            }
        }
    }
}

struct PopoverContent: View {
    let `extension`: Extension

    var body: some View {
        if let popupFile = `extension`.manifest.action?.default_popup {
            let popupURL = `extension`.directoryURL.appendingPathComponent(popupFile)
            ExtensionPageWebView(extension: `extension`, url: popupURL)
                .frame(width: 400, height: 300)  // Default popup size
        } else {
            Text("No popup defined for this extension.")
        }
    }
}
