import SwiftUI

struct RightPanelView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var store: BrowserStore
    @State private var query: String = ""

    var body: some View {
            VStack(spacing: 8) {
                // Header
                HStack {
                    Spacer()
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                }
                .padding([.top, .horizontal], 8)

                // History search
                TextField("Search history", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, 8)

                // History list
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(filteredHistory) { entry in
                            Button(action: { open(entry) }) {
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
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(8)
                }
            }
    }

    private var filteredHistory: [HistoryEntry] {
        let all = store.allHistory
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return all }
        return all.filter { $0.title.localizedCaseInsensitiveContains(q) || $0.urlString.localizedCaseInsensitiveContains(q) }
    }

    private func open(_ entry: HistoryEntry) {
        store.navigateActive(to: entry.urlString)
        isPresented = false
    }
}

