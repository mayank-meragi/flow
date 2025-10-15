import SwiftUI

struct SidebarView: View {
    @Binding var mode: SidebarMode
    @EnvironmentObject var store: BrowserStore

    var body: some View {
        VStack(spacing: 8) {
            // Top controls row
            HStack {
            HStack(spacing: 8) {
                CustomTrafficButton(type: .close)
                CustomTrafficButton(type: .minimize)
                CustomTrafficButton(type: .zoom)
                Button(action: toggleMode) {
                    Image(systemName: mode == .fixed ? "sidebar.left" : "sidebar.right")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.primary)
                            .opacity(0.9)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                HStack(spacing: 10) {
                    Button(action: store.goBack) {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(!store.canGoBack)
                    Button(action: store.goForward) {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(!store.canGoForward)
                    Button(action: store.reload) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)

            // URL bar
            HStack(spacing: 8) {
                TextField("Enter URL", text: Binding(
                    get: { store.active?.urlString ?? "" },
                    set: { store.active?.urlString = $0 }
                ), onCommit: {
                    store.active?.loadCurrentURL()
                })
                .textFieldStyle(.roundedBorder)
                .disabled(store.active == nil)
            }
            .padding(.horizontal, 8)

            // Tabs list
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(store.tabs) { tab in
                        TabRow(tab: tab,
                               isActive: store.active?.id == tab.id,
                               select: { store.select(tabID: tab.id) },
                               close: { store.close(tabID: tab.id) })
                    }
                    Button(action: { store.newTab() }) {
                        HStack {
                            Image(systemName: "plus")
                            Text("New Tab")
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
                .padding(8)
            }

            Spacer()
        }
        .background(Color.red)
        .frame(minWidth: 200, idealWidth: 260, maxWidth: 380)
    }

    private func toggleMode() {
        mode = (mode == .fixed) ? .floating : .fixed
    }
}

private struct TabRow: View {
    @ObservedObject var tab: BrowserTab
    let isActive: Bool
    let select: () -> Void
    let close: () -> Void

    var body: some View {
        Button(action: select) {
            HStack(spacing: 8) {
                faviconView
                Text(tab.title.isEmpty ? tab.urlString : tab.title)
                    .lineLimit(1)
                    .foregroundColor(isActive ? .white : .white.opacity(0.85))
                Spacer()
                Button(role: .destructive, action: close) {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.7))
            }
            .padding(8)
            .background(isActive ? Color.white.opacity(0.2) : Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var faviconView: some View {
        #if os(macOS)
        if let icon = tab.favicon {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: 16, height: 16)
                .cornerRadius(3)
        } else {
            Image(systemName: "globe")
                .foregroundStyle(.white.opacity(0.8))
                .frame(width: 16, height: 16)
        }
        #else
        Image(systemName: "globe")
            .foregroundStyle(.white.opacity(0.8))
            .frame(width: 16, height: 16)
        #endif
    }
}
