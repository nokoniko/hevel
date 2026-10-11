import SwiftUI

/// Geometry of the physical notch (or the synthetic pill on notch-less screens),
/// plus the size the island grows to when expanded.
struct NotchMetrics {
    var notchWidth: CGFloat
    var notchHeight: CGFloat
    var hasNotch: Bool
    /// Settings → Island size: how far the pop-out reaches and how big its content is.
    var scale: CGFloat = 1

    static let scaleRange: ClosedRange<CGFloat> = 0.8...1.3

    var collapsedSidePadding: CGFloat { 30 * scale }   // content peeking on each side of the notch when playing
    var collapsedWidth: CGFloat { notchWidth + collapsedSidePadding * 2 }
    var collapsedCornerRadius: CGFloat { 11 }  // roughly matches the notch's own corners
    var bottomExtension: CGFloat { 1 }         // extra px so the pill's bottom lines up with the notch
    var restHeight: CGFloat { notchHeight + bottomExtension }

    /// Content sizes follow the scale but never outgrow the notch's height.
    var artworkSize: CGFloat { min(notchHeight - 4, (notchHeight - 10) * scale) }
    var ringSize: CGFloat { min(notchHeight - 2, (notchHeight - 6) * scale) }
    func symbolSize(_ base: CGFloat) -> CGFloat { base * scale }

    /// The low-battery alert grows out below the notch, like the iPhone's.
    var alertWidth: CGFloat { min(canvasWidth - glowMargin * 2, max(380, notchWidth + 200)) }
    var alertContentHeight: CGFloat { 66 }
    var alertHeight: CGFloat { notchHeight + alertContentHeight }
    var alertCornerRadius: CGFloat { 30 }

    /// The fixed canvas the panel uses. It's larger than the collapsed pop-out so
    /// there's always room around it; click-through keeps the extra area from
    /// blocking anything, so the panel never resizes.
    private var canvasWidth: CGFloat { 412 + glowMargin * 2 }
    private var canvasHeight: CGFloat { 146 + glowMargin + 18 }

    /// Extra room around the pop-out so nothing is clipped.
    var glowMargin: CGFloat { 45 }

    /// The size the hosting view (and panel) is built at.
    var maxWindowSize: CGSize { CGSize(width: canvasWidth, height: canvasHeight) }
}
