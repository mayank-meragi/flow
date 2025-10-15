import SwiftUI
#if os(macOS)
import AppKit
#endif

struct TriPaneContainer<Left: View, Main: View, Right: View>: View {
    @Binding var leftWidth: CGFloat
    @Binding var rightWidth: CGFloat
    @Binding var isLeftVisible: Bool
    @Binding var isRightVisible: Bool

    let leftMin: CGFloat
    let leftMax: CGFloat
    let rightMin: CGFloat
    let rightMax: CGFloat
    let handleWidth: CGFloat
    let animationDuration: Double

    @ViewBuilder var left: () -> Left
    @ViewBuilder var main: () -> Main
    @ViewBuilder var right: () -> Right

    @State private var leftAnimWidth: CGFloat = 0
    @State private var rightAnimWidth: CGFloat = 0
    @State private var leftDragStart: CGFloat?
    @State private var rightDragStart: CGFloat?
    #if os(macOS)
    @State private var leftCursorPushed = false
    @State private var rightCursorPushed = false
    #endif

    init(
        leftWidth: Binding<CGFloat>,
        rightWidth: Binding<CGFloat>,
        isLeftVisible: Binding<Bool>,
        isRightVisible: Binding<Bool>,
        leftMin: CGFloat,
        leftMax: CGFloat,
        rightMin: CGFloat,
        rightMax: CGFloat,
        handleWidth: CGFloat = 8,
        animationDuration: Double = 0.45,
        @ViewBuilder left: @escaping () -> Left,
        @ViewBuilder main: @escaping () -> Main,
        @ViewBuilder right: @escaping () -> Right
    ) {
        self._leftWidth = leftWidth
        self._rightWidth = rightWidth
        self._isLeftVisible = isLeftVisible
        self._isRightVisible = isRightVisible
        self.leftMin = leftMin
        self.leftMax = leftMax
        self.rightMin = rightMin
        self.rightMax = rightMax
        self.handleWidth = handleWidth
        self.animationDuration = animationDuration
        self.left = left
        self.main = main
        self.right = right
    }

    var body: some View {
        GeometryReader { proxy in
            let total = proxy.size.width

            HStack(spacing: 0) {
                // LEFT
                ZStack(alignment: .trailing) {
                    left()
                        .frame(width: leftAnimWidth)
                        .allowsHitTesting(leftAnimWidth > 0.5)

                    // Left drag handle
                    Rectangle().fill(Color.clear)
                        .contentShape(Rectangle())
                        .frame(width: handleWidth)
                        .zIndex(1)
                        #if os(macOS)
                        .onHover { hov in
                            if hov { if !leftCursorPushed { NSCursor.resizeLeftRight.push(); leftCursorPushed = true } }
                            else { if leftCursorPushed { NSCursor.pop(); leftCursorPushed = false } }
                        }
                        .onDisappear { if leftCursorPushed { NSCursor.pop(); leftCursorPushed = false } }
                        #endif
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { g in
                                    guard isLeftVisible else { return }
                                    if leftDragStart == nil { leftDragStart = leftWidth }
                                    let base = leftDragStart ?? leftWidth
                                    let next = snap(base + g.translation.width, min: leftMin, max: leftMax)
                                    var tx = Transaction(); tx.disablesAnimations = true
                                    withTransaction(tx) {
                                        leftWidth = next
                                        leftAnimWidth = next
                                    }
                                }
                                .onEnded { _ in leftDragStart = nil }
                        )
                }

                // MAIN (fills)
                main()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Right drag handle (between main and right)
                Rectangle().fill(Color.clear)
                    .contentShape(Rectangle())
                    .frame(width: handleWidth)
                    .zIndex(1)
                    .opacity(isRightVisible ? 1 : 0)
                    .allowsHitTesting(isRightVisible)
                    #if os(macOS)
                    .onHover { hov in
                        if hov { if !rightCursorPushed { NSCursor.resizeLeftRight.push(); rightCursorPushed = true } }
                        else { if rightCursorPushed { NSCursor.pop(); rightCursorPushed = false } }
                    }
                    .onDisappear { if rightCursorPushed { NSCursor.pop(); rightCursorPushed = false } }
                    #endif
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { g in
                                guard isRightVisible else { return }
                                if rightDragStart == nil { rightDragStart = rightWidth }
                                let base = rightDragStart ?? rightWidth
                                // dragging left increases right width? We want dragging left to increase, so subtract translation
                                let next = snap(base - g.translation.width, min: rightMin, max: rightMax)
                                var tx = Transaction(); tx.disablesAnimations = true
                                withTransaction(tx) {
                                    rightWidth = next
                                    rightAnimWidth = next
                                }
                            }
                            .onEnded { _ in rightDragStart = nil }
                    )

                // RIGHT
                right()
                    .frame(width: rightAnimWidth)
                    .allowsHitTesting(rightAnimWidth > 0.5)
            }
            .onAppear {
                leftAnimWidth = isLeftVisible ? snap(leftWidth, min: leftMin, max: leftMax) : 0
                rightAnimWidth = isRightVisible ? snap(rightWidth, min: rightMin, max: rightMax) : 0
            }
            .onChange(of: isLeftVisible) { vis in
                let target = vis ? snap(leftWidth, min: leftMin, max: leftMax) : 0
                withAnimation(.easeInOut(duration: animationDuration)) { leftAnimWidth = target }
            }
            .onChange(of: leftWidth) { val in
                // if visible and not dragging, keep anim width in sync without animation
                guard isLeftVisible else { return }
                var tx = Transaction(); tx.disablesAnimations = true
                withTransaction(tx) { leftAnimWidth = snap(val, min: leftMin, max: leftMax) }
            }
            .onChange(of: isRightVisible) { vis in
                let target = vis ? snap(rightWidth, min: rightMin, max: rightMax) : 0
                withAnimation(.easeInOut(duration: animationDuration)) { rightAnimWidth = target }
            }
            .onChange(of: rightWidth) { val in
                guard isRightVisible else { return }
                var tx = Transaction(); tx.disablesAnimations = true
                withTransaction(tx) { rightAnimWidth = snap(val, min: rightMin, max: rightMax) }
            }
        }
    }

    private func snap(_ v: CGFloat, min: CGFloat, max: CGFloat) -> CGFloat {
        let clamped = Swift.max(min, Swift.min(max, v))
        #if os(macOS)
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        return (clamped * scale).rounded() / scale
        #else
        return round(clamped)
        #endif
    }
}

