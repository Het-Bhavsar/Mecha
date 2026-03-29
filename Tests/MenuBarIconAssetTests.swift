import AppKit

@main
struct MenuBarIconAssetTests {
    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() {
            fputs("Assertion failed: \(message)\n", stderr)
            exit(1)
        }
    }

    static func main() {
        expect(MenuBarIconAsset.renderSize.width == 20, "menu bar icon should render at 20pt width for stronger menu bar presence")
        expect(MenuBarIconAsset.renderSize.height == 20, "menu bar icon should render at 20pt height for stronger menu bar presence")

        let sourceImage = NSImage(size: NSSize(width: 64, height: 64))
        let configuredImage = MenuBarIconAsset.configure(image: sourceImage)

        expect(configuredImage !== sourceImage, "menu bar icon configuration should return a copy")
        expect(configuredImage.isTemplate == false, "menu bar icon should render as a full-color asset")
        expect(configuredImage.size.width == MenuBarIconAsset.renderSize.width, "menu bar icon width should match the render size")
        expect(configuredImage.size.height == MenuBarIconAsset.renderSize.height, "menu bar icon height should match the render size")
    }
}
