import SwiftUI
#if os(macOS)
import AppKit
#endif

struct ModifierKeyMonitor: View {
    var onChange: (NSEvent.ModifierFlags) -> Void
    var body: some View {
        #if os(macOS)
        ModifierKeyMonitorRepresentable(onChange: onChange)
        #else
        Color.clear
        #endif
    }
}

#if os(macOS)
private final class ModifierKeyObserverView: NSView {
    var onChange: ((NSEvent.ModifierFlags) -> Void)?
    private var localMonitor: Any?
    private var globalMonitor: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if localMonitor == nil {
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
                self?.onChange?(event.modifierFlags)
                return event
            }
        }
        if globalMonitor == nil {
            globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
                self?.onChange?(event.modifierFlags)
            }
        }
    }

    deinit {
        if let m = localMonitor { NSEvent.removeMonitor(m) }
        if let m = globalMonitor { NSEvent.removeMonitor(m) }
    }
}

private struct ModifierKeyMonitorRepresentable: NSViewRepresentable {
    var onChange: (NSEvent.ModifierFlags) -> Void

    func makeNSView(context: Context) -> ModifierKeyObserverView {
        let v = ModifierKeyObserverView()
        v.onChange = onChange
        return v
    }

    func updateNSView(_ nsView: ModifierKeyObserverView, context: Context) {
        nsView.onChange = onChange
    }
}
#endif

