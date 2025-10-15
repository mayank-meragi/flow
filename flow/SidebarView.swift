import SwiftUI

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
          TextField("Enter URL", text: Binding(
            get: { store.active?.urlString ?? "" },
            set: { store.active?.urlString = $0 }
          ), onCommit: {
            store.active?.loadCurrentURL()
          })
          .textFieldStyle(.roundedBorder)
          .disabled(store.active == nil)
          .foregroundStyle(.primary)
        }
        .padding(.horizontal, 8)

        // Tabs list
        ScrollView {
          VStack(alignment: .leading, spacing: 4) {
            ForEach(store.tabs) { tab in
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
          .foregroundStyle(.primary)

        Spacer()

        Button(role: .destructive, action: close) {
          Image(systemName: "xmark.circle.fill")
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
      }
      .padding(8)
      .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
        .foregroundStyle(.secondary)
        .frame(width: 16, height: 16)
    }
    #else
    Image(systemName: "globe")
      .foregroundStyle(.secondary)
      .frame(width: 16, height: 16)
    #endif
  }
}
