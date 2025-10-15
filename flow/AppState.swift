import SwiftUI
import Combine

final class AppState: ObservableObject {
    @Published var showCommandBar: Bool = false
}
