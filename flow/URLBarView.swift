import SwiftUI
import WebKit

struct URLBarView: View {
    @EnvironmentObject private var store: BrowserStore
    @EnvironmentObject private var appState: AppState
    @State private var isEditing: Bool = false
    @State private var input: String = ""

    var body: some View {
        Group {
            if isEditing {
                editingField
            } else {
                displayField
            }
        }
        .onAppear { syncFromActive() }
        .onChange(of: store.active?.id) { _ in syncFromActive() }
        .onChange(of: store.active?.urlString ?? "") { _ in
            if !isEditing { syncFromActive() }
        }
        .onChange(of: appState.focusURLBarTick) { _ in
            input = store.active?.urlString ?? ""
            isEditing = true
        }
    }

    private var displayField: some View {
        HStack(spacing: 6) {
            Image(systemName: "globe")
                .foregroundStyle(.secondary)
            Text(hostText)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 6, style: .continuous)
        )
        .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .onTapGesture {
            input = store.active?.urlString ?? ""
            isEditing = true
        }
    }

    private var editingField: some View {
        HStack(spacing: 0) {
            #if os(macOS)
            KeyHandlingTextField(
                text: $input,
                placeholder: "Enter URL",
                onEnter: { commit() },
                onArrowUp: nil,
                onArrowDown: nil,
                autoFocus: true
            )
            .textFieldStyle(.plain)
            #else
            TextField("Enter URL", text: $input, onCommit: { commit() })
                .textFieldStyle(.plain)
            #endif
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 6, style: .continuous)
        )
    }

    private var hostText: String {
        if let url = store.active?.webView.url, let host = url.host, !host.isEmpty {
            return host
        }
        let s = store.active?.urlString ?? ""
        if let url = URL(string: s), let host = url.host, !host.isEmpty { return host }
        return s
    }

    private func syncFromActive() {
        input = store.active?.urlString ?? ""
    }

    private func commit() {
        guard let active = store.active else { isEditing = false; return }
        active.urlString = input
        active.loadCurrentURL()
        isEditing = false
    }
}
