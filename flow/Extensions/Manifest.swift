import Foundation

// An enum to represent an icon set, which can be a single path or a dictionary of paths.
enum IconSet: Codable {
    case single(String)
    case dictionary([String: String])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let stringValue = try? container.decode(String.self) {
            self = .single(stringValue)
            return
        }
        if let dictValue = try? container.decode([String: String].self) {
            self = .dictionary(dictValue)
            return
        }
        throw DecodingError.typeMismatch(
            IconSet.self,
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Expected a string or a dictionary of strings for icon set."))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .single(let path):
            try container.encode(path)
        case .dictionary(let dict):
            try container.encode(dict)
        }
    }

    // Helper to get a specific icon size
    func path(for size: Int) -> String? {
        switch self {
        case .single(let path):
            // If it's a single icon, it's used for all sizes
            return path
        case .dictionary(let dict):
            return dict["\(size)"]
        }
    }
}

// Contains all Codable models for manifest.json.
struct Manifest: Codable {
    let name: String
    let version: String
    let manifest_version: Int
    let description: String?
    let icons: IconSet?
    let action: Action?
}

struct Action: Codable {
    let default_popup: String?
    let default_title: String?
    let default_icon: IconSet?
}
