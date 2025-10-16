import SwiftUI

struct ExtensionsPanelView: View {
    @EnvironmentObject var extensionManager: ExtensionManager
    @State private var isDeveloperModeOn: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle("Developer mode", isOn: $isDeveloperModeOn)
                .padding(.horizontal)

            if isDeveloperModeOn {
                Button("Load unpacked") {
                    openExtensionFolder()
                }
                .padding(.horizontal)
            }

            // List of extensions
            ScrollView {
                if extensionManager.extensions.isEmpty {
                    Text("No extensions installed.")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(extensionManager.extensions.values), id: \.id) { ext in
                            ExtensionRowView(extension: ext, isDeveloperModeOn: isDeveloperModeOn)
                        }
                    }
                    .padding()
                }
            }

            Spacer()
        }
    }

    private func openExtensionFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK {
            if let url = panel.url {
                extensionManager.loadUnpacked(from: url)
            }
        }
    }
}

struct ExtensionRowView: View {
    @EnvironmentObject var extensionManager: ExtensionManager
    @EnvironmentObject var store: BrowserStore
    let `extension`: Extension
    let isDeveloperModeOn: Bool
    @State private var isEnabled: Bool = true

    var body: some View {
        HStack {
            ExtensionIconView(extension: `extension`, size: 48)

            VStack(alignment: .leading) {
                Text(`extension`.manifest.name ?? "Unknown")
                    .font(.headline)
                Text("Version \(`extension`.manifest.version ?? "Unknown")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                if isDeveloperModeOn {
                    Text("ID: \(`extension`.id)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Toggle("", isOn: $isEnabled)
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(8)
        .contextMenu {
            if let optionsPage = `extension`.manifest.options_page {
                Button("Options") {
                    let optionsURL = `extension`.directoryURL.appendingPathComponent(optionsPage)
                    store.newTab(url: optionsURL.absoluteString)
                }
            }
            Button(role: .destructive) {
                extensionManager.remove(id: `extension`.id)
            } label: {
                Label("Remove Extension", systemImage: "trash")
            }
        }
    }
}
