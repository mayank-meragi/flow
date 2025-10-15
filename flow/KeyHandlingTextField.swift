import SwiftUI
#if os(macOS)
import AppKit

struct KeyHandlingTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String = ""
    var onEnter: (() -> Void)?
    var onArrowUp: (() -> Void)?
    var onArrowDown: (() -> Void)?
    var autoFocus: Bool = true

    func makeNSView(context: Context) -> NSTextField {
        let tf = NSTextField(string: text)
        tf.placeholderString = placeholder
        tf.isBezeled = false
        tf.isBordered = false
        tf.drawsBackground = false
        tf.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        tf.delegate = context.coordinator
        if autoFocus {
            DispatchQueue.main.async { tf.becomeFirstResponder() }
        }
        return tf
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text { nsView.stringValue = text }
        nsView.placeholderString = placeholder
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: KeyHandlingTextField
        init(_ parent: KeyHandlingTextField) { self.parent = parent }

        func controlTextDidChange(_ obj: Notification) {
            guard let tf = obj.object as? NSTextField else { return }
            parent.text = tf.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            switch commandSelector {
            case #selector(NSResponder.insertNewline(_:)):
                parent.onEnter?()
                return true
            case #selector(NSResponder.moveUp(_:)):
                parent.onArrowUp?()
                return true
            case #selector(NSResponder.moveDown(_:)):
                parent.onArrowDown?()
                return true
            default:
                return false
            }
        }
    }
}
#endif

