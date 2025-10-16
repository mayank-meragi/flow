import SwiftUI

struct ExtensionIconView: View {
    let `extension`: Extension
    let size: CGFloat
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "puzzlepiece.extension")
            }
        }
        .frame(width: size, height: size)
        .onAppear(perform: loadIcon)
    }

    private func loadIcon() {
        let iconSize = Int(size)
        let actionIconPath = `extension`.manifest.action?.default_icon?.path(for: iconSize)
        let rootIconPath = `extension`.manifest.icons?.path(for: iconSize)
        let fallbackIconPath = `extension`.manifest.icons?.path(for: 48)  // A common fallback size

        guard let iconPath = actionIconPath ?? rootIconPath ?? fallbackIconPath else {
            return
        }

        let iconURL = `extension`.directoryURL.appendingPathComponent(iconPath)
        self.image = NSImage(contentsOf: iconURL)
    }
}
