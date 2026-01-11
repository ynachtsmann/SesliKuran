import SwiftUI
import UIKit

// MARK: - Layout Configuration
/// Defines the specific layout constants for the current device environment.
struct LayoutConfig {
    /// The minimum distance from the screen edge (inside the Safe Area).
    let contentMargin: CGFloat

    /// Extra margin for Landscape mode to clear dynamic islands/notches comfortably.
    let landscapeSideMargin: CGFloat

    /// Scale factor for the Art/Circle.
    let artScaleFactor: CGFloat

    /// Spacing between control elements.
    let controlSpacing: CGFloat

    /// Ratio for Split View (e.g., 0.45 = 45% Left, 55% Right).
    let splitViewRatio: CGFloat

    /// Standard iPhone Configuration
    static let standard = LayoutConfig(
        contentMargin: 20,
        landscapeSideMargin: 48,
        artScaleFactor: 0.7,
        controlSpacing: 20,
        splitViewRatio: 0.45
    )

    /// Standard iPad Configuration
    static let iPad = LayoutConfig(
        contentMargin: 40,
        landscapeSideMargin: 60,
        artScaleFactor: 0.6,
        controlSpacing: 40,
        splitViewRatio: 0.4
    )
}

// MARK: - Device Layout Manager
/// Central source of truth for device-specific layout logic.
/// "Startup Check" pattern: Determines the device capabilities once on load.
final class DeviceLayoutManager {
    static let shared = DeviceLayoutManager()

    let isIPad: Bool

    private init() {
        self.isIPad = UIDevice.current.userInterfaceIdiom == .pad
    }

    /// Returns the appropriate configuration based on the current device.
    var config: LayoutConfig {
        return isIPad ? .iPad : .standard
    }

    /// dynamicScale replacement that respects the device type more intelligently.
    /// Returns a multiplier to scale fonts and buttons.
    func adaptiveScale(in size: CGSize) -> CGFloat {
        if isIPad {
            // iPad: Gentle scaling, don't blow everything up
            let baseWidth: CGFloat = 768.0 // iPad Mini width
            let minDimension = min(size.width, size.height)
            return max(1.0, min(minDimension / baseWidth, 1.5))
        } else {
            // iPhone: Aggressive scaling to fit small screens
            let baseWidth: CGFloat = 390.0
            let minDimension = min(size.width, size.height)
            return max(0.8, min(minDimension / baseWidth, 1.3))
        }
    }

    /// Calculates the strict padding required to create a "Safe Container" window.
    /// This ensures no content touches the screen edges, notches, or home indicators.
    func safeContainerPadding(for geometry: GeometryProxy, isLandscape: Bool) -> EdgeInsets {
        let safeArea = geometry.safeAreaInsets
        let config = self.config

        // Horizontal: Ensure we clear the notch/dynamic island + have a pleasant margin.
        // In Landscape, the notch is on the side, so we need a larger minimum margin.
        let horizontalBase = isLandscape ? max(safeArea.leading, safeArea.trailing) : 0
        // If landscape, use the larger landscape margin. If portrait, use standard content margin.
        let horizontalExtra = isLandscape ? config.landscapeSideMargin : config.contentMargin

        // We take the MAX of the physical safe area or our designed margin to be safe.
        // Actually, we want (Safe Area + Margin).
        // Let's allow the Safe Area to handle the "Hardware" part, and add our "Design" margin on top.

        let top = safeArea.top + (isLandscape ? 10 : config.contentMargin) // Less top padding in landscape to save height
        let bottom = safeArea.bottom + (isLandscape ? 10 : config.contentMargin)

        // For sides:
        // In Landscape: The Safe Area ALREADY excludes the notch.
        // We just need to add our aesthetic margin on top of that.
        let leading = safeArea.leading + (isLandscape ? 10 : config.contentMargin)
        let trailing = safeArea.trailing + (isLandscape ? 10 : config.contentMargin)

        return EdgeInsets(
            top: top,
            leading: leading,
            bottom: bottom,
            trailing: trailing
        )
    }
}
