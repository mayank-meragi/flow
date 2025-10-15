import SwiftUI
#if os(macOS)
import AppKit
#endif

enum TrafficButtonType {
    case close, minimize, zoom
}

struct CustomTrafficButton: View {
    let type: TrafficButtonType
    @State private var isHovered = false

    var body: some View {
        Button(action: performAction) {
            Circle()
                .fill(buttonColor)
                .frame(width: 12, height: 12)
                .overlay {
                    if isHovered {
                        Image(systemName: buttonSymbol)
                            .font(.system(size: 6, weight: .bold))
                            .foregroundColor(.black.opacity(0.6))
                    }
                }
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            isHovered = hovering
        }
    }

    var buttonColor: Color {
        switch type {
        case .close:
            return Color(red: 0.93, green: 0.42, blue: 0.37)
        case .minimize:
            return Color(red: 0.96, green: 0.75, blue: 0.31)
        case .zoom:
            return Color(red: 0.38, green: 0.77, blue: 0.33)
        }
    }

    var buttonSymbol: String {
        switch type {
        case .close:
            return "xmark"
        case .minimize:
            return "minus"
        case .zoom:
            return "plus"
        }
    }

    func performAction() {
        #if os(macOS)
        guard let window = NSApplication.shared.windows.first else { return }
        switch type {
        case .close:
            window.close()
        case .minimize:
            window.miniaturize(nil)
        case .zoom:
            window.zoom(nil)
        }
        #endif
    }
}

