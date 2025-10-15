import SwiftUI

struct TabSwitcherView: View {
    @EnvironmentObject private var store: BrowserStore
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack {
            // Dim background slightly
            Color.black.opacity(0.25)
                .ignoresSafeArea()
                .onTapGesture { appState.dismissTabSwitcher(commit: false) }

            // Centered switcher panel
            VStack(alignment: .leading, spacing: 12) {
                Text("Tabs")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(Array(store.tabs.enumerated()), id: \.element.id) { pair in
                            let idx = pair.offset
                            let tab = pair.element
                            VStack(spacing: 8) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color.white.opacity(0.08))
                                    faviconSquare(tab)
                                }
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(selectionStroke(for: idx), lineWidth: 2)
                                )
                                .frame(width: 64, height: 64)

                                Text(tab.title.isEmpty ? tab.urlString : tab.title)
                                    .font(.caption)
                                    .lineLimit(1)
                                    .frame(width: 96)
                                    .foregroundStyle(.primary)
                            }
                            .padding(8)
                            .background(highlight(for: idx))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
            .frame(maxWidth: 640)
            .padding(16)
            .background(.ultraThickMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: .black.opacity(0.25), radius: 24, x: 0, y: 12)
            .padding(24)
        }
        .onExitCommand { appState.dismissTabSwitcher(commit: false) }
    }

    private func highlight(for index: Int) -> Color {
        index == appState.tabSwitcherSelectedIndex ? Color.accentColor.opacity(0.12) : Color.clear
    }

    private func selectionStroke(for index: Int) -> Color {
        index == appState.tabSwitcherSelectedIndex ? Color.accentColor : Color.clear
    }

    @ViewBuilder
    private func faviconSquare(_ tab: BrowserTab) -> some View {
        #if os(macOS)
        if let icon = tab.favicon {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: 40, height: 40)
                .cornerRadius(8)
        } else {
            Image(systemName: "globe")
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(.secondary)
                .frame(width: 40, height: 40)
        }
        #else
        Image(systemName: "globe")
            .font(.system(size: 22, weight: .regular))
            .foregroundStyle(.secondary)
            .frame(width: 40, height: 40)
        #endif
    }
}
