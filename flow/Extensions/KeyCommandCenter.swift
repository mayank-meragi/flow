import Foundation
#if os(macOS)
import AppKit
#endif

// Central registry for keyboard shortcuts declared by extensions (manifest commands)
final class KeyCommandCenter {
    static let shared = KeyCommandCenter()
    private init() {}

    struct Entry {
        let key: String // lowercased, e.g., "d"
        let modifiers: NSEvent.ModifierFlags
        let handler: () -> Void
    }

    #if os(macOS)
    private var localMonitor: Any?
    #endif
    private var entries: [Entry] = []

    func install() {
        #if os(macOS)
        guard localMonitor == nil else { return }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            if self.handle(event: event) { return nil }
            return event
        }
        #endif
    }

    func uninstall() {
        #if os(macOS)
        if let m = localMonitor { NSEvent.removeMonitor(m); localMonitor = nil }
        #endif
        entries.removeAll()
    }

    func register(key: String, modifiers: NSEvent.ModifierFlags, handler: @escaping () -> Void) {
        let normalizedKey = key.lowercased()
        entries.append(Entry(key: normalizedKey, modifiers: modifiers, handler: handler))
    }

    func clearForExtension(_ predicate: (Entry) -> Bool) {
        entries.removeAll(where: predicate)
    }

    #if os(macOS)
    private func handle(event: NSEvent) -> Bool {
        guard let chars = event.charactersIgnoringModifiers?.lowercased(), !chars.isEmpty else { return false }
        let key = String(chars.prefix(1))
        for e in entries {
            if e.key == key && modifiersMatch(event.modifierFlags, e.modifiers) {
                e.handler()
                return true
            }
        }
        return false
    }

    private func modifiersMatch(_ actual: NSEvent.ModifierFlags, _ expected: NSEvent.ModifierFlags) -> Bool {
        // Compare only the subset of modifiers we care about
        let mask: NSEvent.ModifierFlags = [.command, .option, .shift, .control]
        return actual.intersection(mask) == expected.intersection(mask)
    }
    #endif
}

