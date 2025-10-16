import Foundation

// Represents a single message from messages.json
struct ExtensionMessage: Codable {
    let message: String
    let description: String?
    let placeholders: [String: Placeholder]?
}

// Represents a placeholder within a message
struct Placeholder: Codable {
    let content: String
    let example: String?
}

class I18nManager {
    private let extensionDirectory: URL
    private let defaultLocale: String
    private var messages: [String: ExtensionMessage] = [:]

    init(extensionDirectory: URL, defaultLocale: String?) {
        self.extensionDirectory = extensionDirectory
        // Per Chrome docs, default_locale defaults to "en" if not specified.
        self.defaultLocale = defaultLocale ?? "en"
        loadMessages()
    }

    private func loadMessages() {
        let localesURL = extensionDirectory.appendingPathComponent("_locales")
        guard FileManager.default.fileExists(atPath: localesURL.path) else {
            return
        }

        // Determine the best locale to use, with fallback.
        let preferredLocale = Locale.current.identifier.replacingOccurrences(of: "_", with: "-")
        let languageCode = Locale.current.languageCode ?? "en"

        let localeIdentifiersToTry = [
            preferredLocale,  // e.g., "en-US"
            languageCode,  // e.g., "en"
            self.defaultLocale,  // from manifest, or "en"
        ]

        for identifier in localeIdentifiersToTry {
            let messagesURL = localesURL.appendingPathComponent(identifier)
                .appendingPathComponent("messages.json")
            if let loadedMessages = loadMessages(from: messagesURL) {
                self.messages = loadedMessages
                // The first one we find is the best match, so we're done.
                return
            }
        }
    }

    private func loadMessages(from url: URL) -> [String: ExtensionMessage]? {
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        do {
            let decodedMessages = try JSONDecoder().decode(
                [String: ExtensionMessage].self, from: data)
            return decodedMessages
        } catch {
            print("Error decoding messages.json from \(url.path): \(error)")
            return nil
        }
    }

    func getMessage(key: String, substitutions: [Any]?) -> String? {
        guard let messageData = messages[key] else {
            return nil
        }

        var message = messageData.message

        // Handle standard $1, $2, etc. substitutions
        if let substitutions = substitutions {
            for (index, substitution) in substitutions.enumerated() {
                message = message.replacingOccurrences(
                    of: "$\(index + 1)", with: String(describing: substitution))
            }
        }

        // Handle named placeholders like $USER$
        if let placeholders = messageData.placeholders {
            for (name, placeholder) in placeholders {
                // The content of the placeholder tells us which substitution to use, e.g., "$1"
                let substitutionIndexString = placeholder.content.trimmingCharacters(
                    in: CharacterSet(charactersIn: "$"))
                if let substitutionIndex = Int(substitutionIndexString) {
                    if let substitutions = substitutions, substitutions.count >= substitutionIndex {
                        let substitution = substitutions[substitutionIndex - 1]
                        message = message.replacingOccurrences(
                            of: "$\(name)$", with: String(describing: substitution),
                            options: .caseInsensitive)
                    }
                }
            }
        }

        return message
    }
}
