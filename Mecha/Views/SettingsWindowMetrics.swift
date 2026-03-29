import CoreGraphics
import Foundation

struct SettingsWindowMetrics {
    static let titleBarHeightRange: ClosedRange<CGFloat> = 28...32
    static let titleBarHeightFallback: CGFloat = 30

    static let trafficLightLeadingPadding: CGFloat = 16
    static let trafficLightTopPadding: CGFloat = 12
    static let trafficLightClusterWidth: CGFloat = 56
    static let trafficLightClearance: CGFloat = 24

    static let sidebarWidth: CGFloat = 256
    static let contentPadding: CGFloat = 32
    static let columnPadding: CGFloat = 24
    static let sectionSpacing: CGFloat = 24
    static let rowSpacing: CGFloat = 16
    static let controlLabelWidth: CGFloat = 152
    static let cardPadding: CGFloat = 24
    static let cardCornerRadius: CGFloat = 20
    static let dividerOpacity: CGFloat = 0.08

    let topSafeAreaInset: CGFloat

    var titleBarHeight: CGFloat {
        guard topSafeAreaInset > 0 else {
            return Self.titleBarHeightFallback
        }

        return min(max(topSafeAreaInset, Self.titleBarHeightRange.lowerBound), Self.titleBarHeightRange.upperBound)
    }

    var sidebarHeaderLeadingInset: CGFloat {
        Self.trafficLightLeadingPadding + Self.trafficLightClusterWidth + Self.trafficLightClearance
    }

    var chromeVerticalPadding: CGFloat {
        8
    }

    var chromeRowHeight: CGFloat {
        max(52, titleBarHeight + 20)
    }

    var footerHeight: CGFloat {
        56
    }
}
