import SwiftUI

struct HistoryView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var store: BrowserStore
    @State private var query: String = ""

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Text("History")
                    .font(.title2).bold()
                Spacer()
                Button("Close") { isPresented = false }
                    .buttonStyle(.plain)
            }

            // Search
            TextField("Search history", text: $query)
                .textFieldStyle(.roundedBorder)

            // List
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
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
                                Text(Self.formatter.string(from: entry.date))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
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
            .frame(maxHeight: 400)
        }
        .padding(16)
        .frame(maxWidth: 640)
        .background(
            .regularMaterial,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .shadow(radius: 20)
        .onExitCommand { isPresented = false }
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

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }()
}

