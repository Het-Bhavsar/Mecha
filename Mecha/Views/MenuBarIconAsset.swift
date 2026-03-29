import AppKit

enum MenuBarIconAsset {
    static let resourceName = "menubar_orange_transparent"
    static let renderSize = NSSize(width: 20, height: 20)

    static func configure(image: NSImage) -> NSImage {
        let configuredImage = (image.copy() as? NSImage) ?? image
        configuredImage.isTemplate = false
        configuredImage.size = renderSize
        return configuredImage
    }

    static func bundledImage() -> NSImage? {
        guard let image = NSImage(named: resourceName) else {
            return nil
        }
        return configure(image: image)
    }
}
