import SwiftUI
import WebKit

struct CommandBarView: View {
    @Binding var isPresented: Bool
    @State private var query: String = ""
    // Focus handled by KeyHandlingTextField
    @EnvironmentObject private var store: BrowserStore
    @State private var selectionIndex: Int = 0
    private let maxVisibleRows: Int = 5
    private let estimatedRowHeight: CGFloat = 46

    private struct CommandItem: Identifiable {
        let id = UUID()
        let title: String
        let subtitle: String?
        let isEnabled: Bool
        let action: () -> Void
        let keywords: [String]
    }

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.25)
                .ignoresSafeArea()
                .onTapGesture { isPresented = false }

            // Centered command bar
            VStack(spacing: 0) {
                // Input row
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    #if os(macOS)
                    KeyHandlingTextField(text: $query,
                                          placeholder: "Type a URL or command…",
                                          onEnter: { runCurrentCommand() },
                                          onArrowUp: { handleMoveCommand(.up) },
                                          onArrowDown: { handleMoveCommand(.down) },
                                          autoFocus: true)
                        .frame(maxWidth: .infinity)
                    #else
                    TextField("Type a URL or command…", text: $query)
                        .textFieldStyle(.plain)
                        .onSubmit { runCurrentCommand() }
                    #endif
                }
                .padding(12)

                Divider()

                // Results list
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(filteredCommands.enumerated()), id: \.element.id) { pair in
                                let idx = pair.offset
                                let item = pair.element
                                Button(action: { perform(item) }) {
                                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                                        Image(systemName: iconName(for: item))
                                            .foregroundStyle(item.isEnabled ? Color.accentColor : Color.secondary)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.title)
                                                .foregroundStyle(item.isEnabled ? .primary : .secondary)
                                            if let subtitle = item.subtitle, !subtitle.isEmpty {
                                                Text(subtitle)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        Spacer()
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 12)
                                    .background(idx == selectionIndex ? Color.accentColor.opacity(0.12) : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                }
                                .id(item.id)
                                .buttonStyle(.plain)
                                .disabled(!item.isEnabled)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .onChange(of: selectionIndex) { _ in
                        guard filteredCommands.indices.contains(selectionIndex) else { return }
                        let id = filteredCommands[selectionIndex].id
                        withAnimation { proxy.scrollTo(id, anchor: .center) }
                    }
                }
                .frame(maxHeight: resultsMaxHeight)
            }
            .frame(maxWidth: 560)
            .glassEffect(.regular.tint(.white.opacity(0.12)).interactive(), in: RoundedRectangle(cornerRadius: 16))
            .padding(24)
        }
        .onAppear { }
        .onExitCommand { isPresented = false }
        // Arrow keys handled by KeyHandlingTextField delegate
        .onChange(of: query) { _ in selectionIndex = 0 }
    }

    // MARK: - Commands
    private var baseCommands: [CommandItem] {
        let canBack = store.canGoBack
        let canFwd = store.canGoForward
        let activeHost = store.active?.webView.url?.host ?? ""
        return [
            CommandItem(title: "New Tab", subtitle: nil, isEnabled: true, action: { _ = store.newTab() }, keywords: ["new", "tab", "create"]),
            CommandItem(title: "Close Tab", subtitle: nil, isEnabled: store.active != nil, action: {
                if let id = store.active?.id { store.close(tabID: id) }
            }, keywords: ["close", "tab", "delete"]),
            CommandItem(title: "Reload", subtitle: activeHost, isEnabled: store.active != nil, action: { store.reload() }, keywords: ["reload", "refresh", "cmd r"]),
            CommandItem(title: "Back", subtitle: activeHost, isEnabled: canBack, action: { store.goBack() }, keywords: ["back", "previous", "history"]),
            CommandItem(title: "Forward", subtitle: activeHost, isEnabled: canFwd, action: { store.goForward() }, keywords: ["forward", "next", "history"])
        ]
    }

    private var filteredCommands: [CommandItem] {
        var cmds: [CommandItem] = []
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            // Primary dynamic command: open new tab with the entry
            let openTitle = "Open New Tab: \(trimmed)"
            cmds.append(CommandItem(title: openTitle, subtitle: nil, isEnabled: true, action: { store.newTab(url: trimmed) }, keywords: [trimmed, "open", "url"]))
        }

        if trimmed.isEmpty { return cmds + baseCommands }
        let q = trimmed.lowercased()
        let matches = baseCommands.filter { item in
            item.title.lowercased().contains(q) || item.keywords.contains(where: { $0.lowercased().contains(q) })
        }
        return cmds + matches
    }

    private func runCurrentCommand() {
        guard filteredCommands.indices.contains(selectionIndex) else { isPresented = false; return }
        perform(filteredCommands[selectionIndex])
    }

    private func perform(_ item: CommandItem) {
        guard item.isEnabled else { return }
        item.action()
        isPresented = false
        query = ""
    }

    private func iconName(for item: CommandItem) -> String {
        switch item.title {
        case _ where item.title.hasPrefix("Open New Tab:"): return "plus.square.on.square"
        case "New Tab": return "plus"
        case "Close Tab": return "xmark"
        case "Reload": return "arrow.clockwise"
        case "Back": return "chevron.left"
        case "Forward": return "chevron.right"
        default: return "rectangle.and.text.magnifyingglass"
        }
    }

    private var resultsMaxHeight: CGFloat {
        CGFloat(min(filteredCommands.count, maxVisibleRows)) * estimatedRowHeight
    }

    private func handleMoveCommand(_ direction: MoveCommandDirection) {
        switch direction {
        case .down:
            selectionIndex = min(selectionIndex + 1, max(filteredCommands.count - 1, 0))
        case .up:
            selectionIndex = max(selectionIndex - 1, 0)
        default:
            break
        }
    }
}
