import SwiftUI
#if os(macOS)
import AppKit
#endif

struct RightPanelDragHandle: View {
    @Binding var width: CGFloat
    let minWidth: CGFloat
    let maxWidth: CGFloat
    @State private var dragStart: CGFloat?
    #if os(macOS)
    @State private var cursorPushed = false
    #endif

    private let handleWidth: CGFloat = 8

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .contentShape(Rectangle())
            .frame(width: handleWidth)
            .zIndex(1)
            #if os(macOS)
            .onHover { hovering in
                if hovering {
                    if !cursorPushed { NSCursor.resizeLeftRight.push(); cursorPushed = true }
                } else {
                    if cursorPushed { NSCursor.pop(); cursorPushed = false }
                }
            }
            .onDisappear {
                if cursorPushed { NSCursor.pop(); cursorPushed = false }
            }
            #endif
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if dragStart == nil { dragStart = width }
                        let base = dragStart ?? width
                        // Dragging left decreases width (negative translation)
                        var next = base - value.translation.width
                        next = min(max(next, minWidth), maxWidth)
                        var tx = Transaction(); tx.disablesAnimations = true
                        withTransaction(tx) { width = snapToPixel(next) }
                    }
                    .onEnded { _ in dragStart = nil }
            )
    }

    private func snapToPixel(_ value: CGFloat) -> CGFloat {
        #if os(macOS)
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        return (value * scale).rounded() / scale
        #else
        return round(value)
        #endif
    }
}
