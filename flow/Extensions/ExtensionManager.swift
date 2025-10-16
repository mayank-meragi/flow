import Combine
import Foundation

class ExtensionManager: ObservableObject {
    @Published private(set) var extensions = [String: Extension]()

    // The designated directory for extensions. This can be configured.
    private let extensionsDirectory: URL

    init() {
        // For now, let's assume a directory within Application Support
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!
        self.extensionsDirectory = appSupport.appendingPathComponent("Flow/Extensions")
        createExtensionsDirectoryIfNeeded()
    }

    private func createExtensionsDirectoryIfNeeded() {
        try? FileManager.default.createDirectory(
            at: extensionsDirectory, withIntermediateDirectories: true, attributes: nil)
    }

    func loadExtensions() {
        let fileManager = FileManager.default
        guard
            let enumerator = fileManager.enumerator(
                at: extensionsDirectory, includingPropertiesForKeys: nil,
                options: [.skipsSubdirectoryDescendants, .skipsHiddenFiles])
        else { return }

        for case let dirURL as URL in enumerator {
            if dirURL.hasDirectoryPath {
                loadExtension(from: dirURL)
            }
        }
    }

    private func loadExtension(from directory: URL) {
        let manifestURL = directory.appendingPathComponent("manifest.json")
        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            print("manifest.json not found in \(directory.path)")
            return
        }

        do {
            let data = try Data(contentsOf: manifestURL)
            let manifest = try JSONDecoder().decode(Manifest.self, from: data)

            // Factory logic
            switch manifest.manifest_version {
            case 3:
                let newExtension = MV3Extension(manifest: manifest, directoryURL: directory)
                extensions[newExtension.id] = newExtension
                print("Loaded MV3 extension: \(manifest.name ?? "Unknown")")
            case 2:
                let newExtension = MV2Extension(manifest: manifest, directoryURL: directory)
                extensions[newExtension.id] = newExtension
                print("Loaded MV2 extension: \(manifest.name ?? "Unknown")")
            default:
                print(
                    "Unsupported manifest version: \(manifest.manifest_version) for \(manifest.name ?? "Unknown")"
                )
            }
        } catch {
            print("Failed to load extension from \(directory.path): \(error)")
        }
    }

    public func remove(id: String) {
        guard let ext = extensions[id] else { return }

        do {
            if FileManager.default.fileExists(atPath: ext.directoryURL.path) {
                try FileManager.default.removeItem(at: ext.directoryURL)
            }
            extensions.removeValue(forKey: id)
            print("Removed extension: \(ext.manifest.name ?? "Unknown")")
        } catch {
            print("Failed to remove extension \(id): \(error)")
        }
    }

    func loadUnpacked(from sourceURL: URL) {
        let fileManager = FileManager.default
        let destinationURL = extensionsDirectory.appendingPathComponent(sourceURL.lastPathComponent)

        do {
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
            loadExtension(from: destinationURL)
        } catch {
            print("Failed to load unpacked extension: \(error)")
        }
    }
}
