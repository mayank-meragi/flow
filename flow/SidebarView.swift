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

                Button(action: { store.active?.loadCurrentURL() }) {
                    Image(systemName: "arrow.right.circle.fill")
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)

            // Tabs list
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(store.tabs) { tab in
                        Button(action: { store.select(tabID: tab.id) }) {
                            HStack {
                                Text(tab.title.isEmpty ? tab.urlString : tab.title)
                                    .lineLimit(1)
                                    .foregroundColor(store.active?.id == tab.id ? .white : .white.opacity(0.85))
                                Spacer()
                                Button(role: .destructive, action: { store.close(tabID: tab.id) }) {
                                    Image(systemName: "xmark.circle.fill")
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.white.opacity(0.7))
                            }
                            .padding(8)
                            .background(store.active?.id == tab.id ? Color.white.opacity(0.2) : Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
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
