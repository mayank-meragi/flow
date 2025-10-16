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
    let options_page: String?
    let permissions: [String]?
    let host_permissions: [String]?

    enum CodingKeys: String, CodingKey {
        case name, version, manifest_version, description, icons, options_page, permissions,
            host_permissions
        case action  // MV3 key
        case browser_action  // MV2 key
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        version = try container.decode(String.self, forKey: .version)
        manifest_version = try container.decode(Int.self, forKey: .manifest_version)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        icons = try container.decodeIfPresent(IconSet.self, forKey: .icons)
        options_page = try container.decodeIfPresent(String.self, forKey: .options_page)
        permissions = try container.decodeIfPresent([String].self, forKey: .permissions)
        host_permissions = try container.decodeIfPresent([String].self, forKey: .host_permissions)

        // Handle action vs browser_action
        if let actionValue = try? container.decodeIfPresent(Action.self, forKey: .action) {
            action = actionValue
        } else if let browserActionValue = try? container.decodeIfPresent(
            Action.self, forKey: .browser_action)
        {
            action = browserActionValue
        } else {
            action = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(version, forKey: .version)
        try container.encode(manifest_version, forKey: .manifest_version)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(icons, forKey: .icons)
        try container.encodeIfPresent(options_page, forKey: .options_page)
        try container.encodeIfPresent(permissions, forKey: .permissions)
        try container.encodeIfPresent(host_permissions, forKey: .host_permissions)
        try container.encodeIfPresent(action, forKey: .action)
    }
}

struct Action: Codable {
    let default_popup: String?
    let default_title: String?
    let default_icon: IconSet?
}
