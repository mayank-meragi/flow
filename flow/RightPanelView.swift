import SwiftUI

// Generic right panel container that can host arbitrary content
struct RightPanelContainer<Content: View>: View {
    let title: String
    @Binding var isPresented: Bool
    @ViewBuilder var content: Content

    var body: some View {
            VStack(spacing: 8) {
                // Header
                HStack {
                    Text(title)
                        .font(.headline)
                    Spacer()
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                }
                .padding([.top, .horizontal], 8)

                content
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
            }
    }
}

// History list used by the right panel
struct HistoryPanelContent: View {
    @EnvironmentObject var store: BrowserStore
    let onSelect: (HistoryEntry) -> Void
    @State private var query: String = ""

    var body: some View {
        VStack(spacing: 8) {
            TextField("Search history", text: $query)
                .textFieldStyle(.roundedBorder)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(filteredHistory) { entry in
                        Button(action: { onSelect(entry) }) {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "clock")
                                    .foregroundStyle(.secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.title.isEmpty ? entry.urlString : entry.title)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                    Text(entry.urlString)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                            }
                            .padding(8)
                            .background(
                                .ultraThinMaterial,
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(maxHeight: .infinity)
        }
    }

    private var filteredHistory: [HistoryEntry] {
        let all = store.allHistory
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return all }
        return all.filter { $0.title.localizedCaseInsensitiveContains(q) || $0.urlString.localizedCaseInsensitiveContains(q) }
    }
}
