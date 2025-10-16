import Foundation

struct URLManager {
    // DuckDuckGo query format
    static let searchBase = "https://www.duckduckgo.com/?q="

    // Public: Resolve a user-entered string into a URL to load.
    // Rules:
    // - If it looks like a URL without scheme, add https://
    // - If it does not look like a URL (or contains spaces), treat as a search term
    static func resolve(input: String) -> URL? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // If already a valid absolute URL, return it
        if let url = URL(string: trimmed), let scheme = url.scheme, !scheme.isEmpty {
            return url
        }

        // If contains spaces, treat as search
        if trimmed.contains(where: { $0.isWhitespace }) {
            return makeSearchURL(query: trimmed)
        }

        // Heuristic: domain-like or localhost/IP → add https
        if looksLikeHost(trimmed) {
            let withScheme = "https://" + trimmed
            if let url = URL(string: withScheme) { return url }
        }

        // Fallback to search
        return makeSearchURL(query: trimmed)
    }

    // Update the visible string to a pretty form derived from a real URL
    static func displayString(from url: URL?) -> String {
        url?.absoluteString ?? ""
    }

    private static func makeSearchURL(query: String) -> URL? {
        var allowed = CharacterSet.urlQueryAllowed
        // Space becomes + for many engines; here percent-encode cleanly
        let encoded = query.addingPercentEncoding(withAllowedCharacters: allowed) ?? query
        return URL(string: searchBase + encoded)
    }

    private static func looksLikeHost(_ s: String) -> Bool {
        if s.lowercased() == "localhost" { return true }
        if s.contains(".") { return true }
        // IPv4
        if s.split(separator: ".").count == 4, s.split(separator: ".").allSatisfy({ !$0.isEmpty && $0.allSatisfy { $0.isNumber } }) {
            return true
        }
        // IPv6 (very loose check)
        if s.contains(":") { return true }
        return false
    }
}
