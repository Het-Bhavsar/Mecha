import Foundation

@main
struct SettingsWindowMetricsTests {
    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() {
            fputs("Assertion failed: \(message)\n", stderr)
            exit(1)
        }
    }

    static func main() {
        let defaultMetrics = SettingsWindowMetrics(topSafeAreaInset: 0)
        expect(defaultMetrics.titleBarHeight == 30, "Fallback title bar height should be 30pt")
        expect(SettingsWindowMetrics.titleBarHeightRange.contains(defaultMetrics.titleBarHeight), "Fallback title bar height must stay within the native range")
        expect(SettingsWindowMetrics.trafficLightLeadingPadding == 16, "Traffic lights should use a 16pt leading inset")
        expect(SettingsWindowMetrics.trafficLightTopPadding == 12, "Traffic lights should use a 12pt top inset")
        expect(SettingsWindowMetrics.sidebarWidth == 256, "Sidebar width should follow the planned native width")
        expect(SettingsWindowMetrics.contentPadding == 32, "Content padding should follow the 8pt grid")
        expect(defaultMetrics.sidebarHeaderLeadingInset == 96, "Sidebar branding should clear the traffic lights by 96pt")
        expect(defaultMetrics.chromeVerticalPadding == 8, "Chrome rows should use a compact 8pt vertical padding")
        expect(defaultMetrics.chromeRowHeight == 52, "Chrome rows should stay compact enough to avoid a second faux title bar")

        let compressedMetrics = SettingsWindowMetrics(topSafeAreaInset: 20)
        expect(compressedMetrics.titleBarHeight == 28, "Title bar height should clamp to the lower bound")

        let expandedMetrics = SettingsWindowMetrics(topSafeAreaInset: 40)
        expect(expandedMetrics.titleBarHeight == 32, "Title bar height should clamp to the upper bound")
    }
}
