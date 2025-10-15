import SwiftUI
#if os(macOS)
import AppKit
#endif

/// A fully custom, divider-less horizontal split view.
/// - leadingWidth: bound width for the leading pane.
/// - minWidth/maxWidth: clamps for the leading pane during drag.
/// - dragHandleWidth: invisible area at the split boundary used for resizing.
struct CustomHSplit<Leading: View, Trailing: View>: View {
    @Binding var leadingWidth: CGFloat
    var minWidth: CGFloat
    var maxWidth: CGFloat
    var dragHandleWidth: CGFloat = 8
    var suppressImplicitAnimations: Bool = true
    var animationDuration: Double = 0.25
    var leading: () -> Leading
    var trailing: () -> Trailing

    @State private var dragStartWidth: CGFloat?
    #if os(macOS)
    @State private var cursorPushed: Bool = false
    #endif

    init(
        leadingWidth: Binding<CGFloat>,
        minWidth: CGFloat,
        maxWidth: CGFloat,
        dragHandleWidth: CGFloat = 8,
        suppressImplicitAnimations: Bool = true,
        animationDuration: Double = 0.25,
        @ViewBuilder leading: @escaping () -> Leading,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self._leadingWidth = leadingWidth
        self.minWidth = minWidth
        self.maxWidth = maxWidth
        self.dragHandleWidth = dragHandleWidth
        self.suppressImplicitAnimations = suppressImplicitAnimations
        self.animationDuration = animationDuration
        self.leading = leading
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: 0) {
            ZStack(alignment: .trailing) {
                leading()
                    .frame(width: leadingWidth)

                // Invisible drag handle: no divider visuals
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .frame(width: dragHandleWidth)
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
                                if dragStartWidth == nil { dragStartWidth = leadingWidth }
                                let base = dragStartWidth ?? leadingWidth
                                let next = base + value.translation.width
                                let clamped = min(max(next, minWidth), maxWidth)
                                let snapped = snapToPixel(clamped)
                                var tx = Transaction()
                                tx.disablesAnimations = true
                                withTransaction(tx) {
                                    leadingWidth = snapped
                                }
                            }
                            .onEnded { _ in
                                dragStartWidth = nil
                            }
                    )
            }

            trailing()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .animation(suppressImplicitAnimations ? nil : .easeInOut(duration: animationDuration), value: leadingWidth)
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
