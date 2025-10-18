import Foundation
#if os(macOS)
import AppKit
#endif

struct FontSettingsAPIHost {
    static func handle(method: String, params: [String: Any]) -> Any? {
        switch method {
        case "getFontList":
            return getFontList()
        default:
            return []
        }
    }

    static func getFontList() -> Any {
        #if os(macOS)
        let families = NSFontManager.shared.availableFontFamilies
        // Map families to Chrome-like objects: { fontId, displayName }
        let out: [[String: String]] = families.map { fam in
            ["fontId": fam, "displayName": fam]
        }
        return out
        #else
        return []
        #endif
    }
}

