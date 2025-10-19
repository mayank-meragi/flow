import Foundation

enum HostPermissions {
    // Public: check if the given URL string matches any of the host permission patterns
    static func isAllowed(urlString: String, patterns: [String]) -> Bool {
        guard let url = URL(string: urlString), let scheme = url.scheme, let host = url.host else {
            return false
        }
        let normalized = urlString
        for p in patterns {
            if match(normalized, pattern: p, scheme: scheme, host: host) { return true }
        }
        return false
    }

    private static func match(_ url: String, pattern: String, scheme: String, host: String) -> Bool {
        if pattern == "<all_urls>" {
            return url.range(of: "^(?:https?|file|ftp|ws|wss)://", options: [.regularExpression, .caseInsensitive]) != nil
        }
        guard let re = regex(fromMatchPattern: pattern) else { return false }
        let range = NSRange(location: 0, length: (url as NSString).length)
        return re.firstMatch(in: url, options: [], range: range) != nil
    }

    // Convert a match pattern like "https://*.example.com/*" into a regex
    private static func regex(fromMatchPattern pattern: String) -> NSRegularExpression? {
        // Expect scheme://host/path
        guard let schemeSplit = pattern.range(of: "://") else { return nil }
        let schemePart = String(pattern[..<schemeSplit.lowerBound])
        let rest = String(pattern[schemeSplit.upperBound...])

        let schemeRegex: String
        if schemePart == "*" {
            schemeRegex = "(?:http|https)"
        } else {
            schemeRegex = NSRegularExpression.escapedPattern(for: schemePart)
        }

        let firstSlash = rest.firstIndex(of: "/")
        let hostPart = firstSlash.map { String(rest[..<$0]) } ?? rest
        let pathPart = firstSlash.map { String(rest[$0...]) } ?? "/"

        // Host regex
        let hostRegex: String
        if hostPart == "*" {
            hostRegex = "[^/]*"
        } else if hostPart.hasPrefix("*.") {
            let suffix = String(hostPart.dropFirst(2))
            hostRegex = "(?:[^/]+\\.)?" + NSRegularExpression.escapedPattern(for: suffix)
        } else {
            hostRegex = NSRegularExpression.escapedPattern(for: hostPart)
        }

        // Path regex: convert '*' -> '.*' and escape regex specials
        var pr = ""
        for ch in pathPart {
            if ch == "*" { pr.append(".*") }
            else if "\\.+?^${}()|[]".contains(ch) { pr.append("\\\(ch)") }
            else { pr.append(ch) }
        }
        let pathRegex = pr.isEmpty ? "(?:/.*)?" : pr

        let patternString = "^" + schemeRegex + "://" + hostRegex + pathRegex
        return try? NSRegularExpression(pattern: patternString, options: [.caseInsensitive])
    }
}

