import SwiftUI
#if os(macOS)
import AppKit
#endif

struct SidebarView: View {
  @Binding var mode: SidebarMode
  @EnvironmentObject var store: BrowserStore
  @EnvironmentObject var appState: AppState
  @Namespace private var glassNS

  var body: some View {
    GlassEffectContainer {
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
                .foregroundStyle(.primary)
            }
            .disabled(!store.canGoBack)

            Button(action: store.goForward) {
              Image(systemName: "chevron.right")
                .foregroundStyle(.primary)
            }
            .disabled(!store.canGoForward)

            Button(action: store.reload) {
              Image(systemName: "arrow.clockwise")
                .foregroundStyle(.primary)
            }
            Button(action: { appState.openRightPanel(.history) }) {
              Image(systemName: "clock")
                .foregroundStyle(.primary)
            }
          }
          .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)

        // URL bar
        HStack(spacing: 8) {
          URLBarView()
            .disabled(store.active == nil)
        }
        .padding(.horizontal, 8)

        // Tabs list + Folders
        ScrollView {
          VStack(alignment: .leading, spacing: 4) {
            // Group: pinned items (pinned tabs without folder + pinned folders)
            let pinnedTabs = store.tabs.filter { $0.isPinned && $0.folderID == nil }
            let pinnedFolders = store.folders.filter { $0.isPinned }
            let unpinnedFolders = store.folders.filter { !$0.isPinned }
            let ungroupedTabs = store.tabs.filter { !$0.isPinned && $0.folderID == nil }

            // Pinned tabs
            ForEach(pinnedTabs) { tab in
              TabRow(
                tab: tab,
                isActive: store.active?.id == tab.id,
                select: { store.select(tabID: tab.id) },
                close: { store.close(tabID: tab.id) }
              )
              .glassEffect(
                store.active?.id == tab.id
                ? .regular
                : .identity,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
              )
              .glassEffectID(tab.id.uuidString, in: glassNS)
            }

            // Pinned folders
            ForEach(pinnedFolders) { folder in
              FolderSection(folder: folder)
                .environmentObject(store)
            }

            if (!pinnedTabs.isEmpty || !pinnedFolders.isEmpty) && (!unpinnedFolders.isEmpty || !ungroupedTabs.isEmpty) {
              Divider()
                .padding(.vertical, 6)
                .opacity(0.6)
            }

            // Unpinned folders
            ForEach(unpinnedFolders) { folder in
              FolderSection(folder: folder)
                .environmentObject(store)
            }

            // Ungrouped tabs
            ForEach(ungroupedTabs) { tab in
              TabRow(
                tab: tab,
                isActive: store.active?.id == tab.id,
                select: { store.select(tabID: tab.id) },
                close: { store.close(tabID: tab.id) }
              )
              .glassEffect(
                store.active?.id == tab.id
                ? .regular
                : .identity,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
              )
              .glassEffectID(tab.id.uuidString, in: glassNS)
            }

            Button(action: { appState.showCommandBar = true }) {
              HStack {
                Image(systemName: "plus")
                Text("New Tab")
              }
              .padding(8)
              .frame(maxWidth: .infinity, alignment: .leading)
              // Fallback/soft background when not using glass:
              .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: 6, style: .continuous)
              )
              .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
          }
          .padding(8)
        }

        Spacer()
      }
      // Clear glass with a subtle tint to lift contrast on busy backdrops
      .glassEffect(
        mode == .fixed ? .identity : .regular.interactive().tint(.white.opacity(0.12)),
        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
      )
      .glassEffectID("sidebar-container", in: glassNS)
      .frame(minWidth: 200, idealWidth: 260, maxWidth: 380)
    }
  }

  private func toggleMode() {
    let newMode: SidebarMode = (mode == .fixed) ? .floating : .fixed
    withAnimation(.easeInOut(duration: 0.25)) {
      mode = newMode
    }
  }
}

private struct FolderSection: View {
  let folder: TabFolder
  @EnvironmentObject var store: BrowserStore
  private let lineWidth: CGFloat = 2
  private let gutter: CGFloat = 8

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(spacing: 6) {
        Circle()
          .fill(colorFromHex(folder.colorHex))
          .frame(width: 10, height: 10)
        Text(folder.name)
          .font(.subheadline)
          .foregroundStyle(.secondary)
        Spacer()
        Image(systemName: "chevron.right")
          .rotationEffect(.degrees(isCollapsed ? 0 : 90))
          .foregroundStyle(.secondary)
          .font(.system(size: 11, weight: .semibold))
      }
      .contextMenu {
        if folder.isPinned {
          Button(action: { store.setFolderPinned(id: folder.id, pinned: false) }) {
            Label("Unpin Folder", systemImage: "pin.slash")
          }
        } else {
          Button(action: { store.setFolderPinned(id: folder.id, pinned: true) }) {
            Label("Pin Folder", systemImage: "pin")
          }
        }
        Divider()
        if isCollapsed {
          Button("Expand") { store.setFolderCollapsed(id: folder.id, collapsed: false) }
        } else {
          Button("Collapse") { store.setFolderCollapsed(id: folder.id, collapsed: true) }
        }
      }
      .padding(.horizontal, 4)
      .contentShape(Rectangle())
      .onTapGesture { store.toggleFolderCollapsed(id: folder.id) }

      if !isCollapsed {
        HStack(alignment: .top, spacing: gutter) {
          Rectangle()
            .fill(colorFromHex(folder.colorHex).opacity(0.6))
            .frame(width: lineWidth)
            .padding(.leading, 2)
          VStack(alignment: .leading, spacing: 4) {
            ForEach(folderTabs) { tab in
              TabRow(
                tab: tab,
                isActive: store.active?.id == tab.id,
                select: { store.select(tabID: tab.id) },
                close: { store.close(tabID: tab.id) }
              )
            }
          }
        }
        .padding(.leading, 4)
      }
    }
    .padding(.vertical, 2)
  }

  private var folderTabs: [BrowserTab] {
    store.tabs.filter { $0.folderID == folder.id }
  }

  private var isCollapsed: Bool { folder.isCollapsed }

  private func colorFromHex(_ hex: String) -> Color {
    var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
    if s.hasPrefix("#") { s.removeFirst() }
    guard s.count == 6, let val = Int(s, radix: 16) else { return .gray }
    let r = Double((val >> 16) & 0xFF) / 255.0
    let g = Double((val >> 8) & 0xFF) / 255.0
    let b = Double(val & 0xFF) / 255.0
    return Color(red: r, green: g, blue: b)
  }
}

private struct TabRow: View {
  @ObservedObject var tab: BrowserTab
  let isActive: Bool
  let select: () -> Void
  let close: () -> Void
  @State private var isHovering: Bool = false
  @EnvironmentObject var store: BrowserStore

  var body: some View {
    Button(action: select) {
      HStack(spacing: 8) {
        faviconView

        Text(tab.title.isEmpty ? tab.urlString : tab.title)
          .lineLimit(1)
          .foregroundStyle(.primary)

        Spacer()
        if isHovering && !tab.isPinned {
          Button(role: .destructive, action: close) {
            Image(systemName: "xmark.circle")
              .foregroundStyle(.secondary)
          }
          .buttonStyle(.plain)
          .transition(.opacity)
        }
      }
      .padding(8)
      .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
      .background(
        (isHovering && !isActive) ? Color.accentColor.opacity(0.10) : Color.clear,
        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
      )
    }
    .buttonStyle(.plain)
    // Dull sleeping (not-yet-loaded) tabs slightly when inactive
    .opacity(tab.isLoaded || isActive ? 1.0 : 0.6)
    .onHover { hovering in
      withAnimation(.easeInOut(duration: 0.15)) { isHovering = hovering }
    }
    .contextMenu {
      if tab.isPinned {
        Button(action: { tab.isPinned = false }) {
          Label("Unpin Tab", systemImage: "pin.slash")
        }
      } else {
        Button(action: { tab.isPinned = true }) {
          Label("Pin Tab", systemImage: "pin")
        }
      }
      Divider()
      Menu("Add to Folder") {
        ForEach(store.folders) { folder in
          Button(action: { store.assign(tabID: tab.id, toFolder: folder.id) }) {
            Label(folder.name, systemImage: (tab.folderID == folder.id) ? "checkmark" : "folder")
          }
        }
        Divider()
        Button("New Folder…") {
          createFolderPromptAndAssign()
        }
        if tab.folderID != nil {
          Button("Remove from Folder") {
            store.assign(tabID: tab.id, toFolder: nil)
          }
        }
      }
    }
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
        .foregroundStyle(.secondary)
        .frame(width: 16, height: 16)
    }
    #else
    Image(systemName: "globe")
      .foregroundStyle(.secondary)
      .frame(width: 16, height: 16)
    #endif
  }
  #if os(macOS)
  private func createFolderPromptAndAssign() {
    let alert = NSAlert()
    alert.messageText = "New Folder"
    alert.informativeText = "Enter a name for the folder."
    let input = NSTextField(string: "")
    input.placeholderString = "Folder name"
    input.frame = NSRect(x: 0, y: 0, width: 240, height: 24)
    alert.accessoryView = input
    alert.addButton(withTitle: "Create")
    alert.addButton(withTitle: "Cancel")
    let response = alert.runModal()
    if response == .alertFirstButtonReturn {
      let name = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
      let finalName = name.isEmpty ? "New Folder" : name
      let palette = ["#5E81AC", "#A3BE8C", "#EBCB8B", "#D08770", "#BF616A", "#B48EAD", "#88C0D0"]
      let color = palette.randomElement() ?? "#5E81AC"
      let folderID = store.createFolder(name: finalName, colorHex: color)
      store.assign(tabID: tab.id, toFolder: folderID)
    }
  }
  #endif
}
