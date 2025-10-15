import SwiftUI

struct CommandBarView: View {
    @Binding var isPresented: Bool
    @State private var query: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.25)
                .ignoresSafeArea()
                .onTapGesture { isPresented = false }

            // Centered command bar
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Type a URL or command…", text: $query)
                        .textFieldStyle(.plain)
                        .focused($isFocused)
                        .onSubmit { handleSubmit() }
                }
                .padding(12)
            }
            .frame(maxWidth: 520)
            .background(.ultraThickMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: .black.opacity(0.25), radius: 24, x: 0, y: 12)
            .padding(24)
        }
        .onAppear { isFocused = true }
        .onExitCommand { isPresented = false }
    }

    private func handleSubmit() {
        // Close for now; wiring to actions can be added later
        isPresented = false
    }
}

