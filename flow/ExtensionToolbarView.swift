import SwiftUI
import WebKit

struct ExtensionToolbarView: View {
    @EnvironmentObject var extensionManager: ExtensionManager
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
            }
        }
    }
}

struct PopoverContent: View {
    let `extension`: Extension

    var body: some View {
        if let popupFile = `extension`.manifest.action?.default_popup {
            let popupURL = `extension`.directoryURL.appendingPathComponent(popupFile)
            WebView(url: popupURL)
                .frame(width: 400, height: 300)  // Default popup size
        } else {
            Text("No popup defined for this extension.")
        }
    }
}

struct WebView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        let request = URLRequest(url: url)
        webView.load(request)
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        nsView.load(request)
    }
}
