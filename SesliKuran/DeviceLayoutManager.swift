import SwiftUI
import UIKit

// MARK: - Layout Configuration
/// Defines the specific layout constants for the current device environment.
struct LayoutConfig: Equatable {
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
        landscapeSideMargin: 56, // Aggressive margin to clear notch/island
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

        // Defensive: If safeArea is reported as 0 (due to edgesIgnoringSafeArea on parent),
        // we MUST enforce a hard minimum based on the device config.

        // Use the MAX of the actual safe area OR our hardcoded margin.
        // This guarantees that even if the system reports 0, we still have 56pt (or similar) padding.

        // Side Padding Logic:
        // In Landscape: Ensure we clear the Notch/Island (usually ~47pt). We use 56pt to be safe.
        // In Portrait: Standard content margin (20pt).
        let minSideMargin: CGFloat = isLandscape ? config.landscapeSideMargin : config.contentMargin

        let finalLeading = max(safeArea.leading + config.contentMargin, minSideMargin)
        let finalTrailing = max(safeArea.trailing + config.contentMargin, minSideMargin)

        // Vertical Padding Logic:
        // Top: Usually ~47pt on iPhone X+, but check safe area.
        // Bottom: Home bar needs clearance (~34pt).
        // If system reports 0, we default to 20pt margin to avoid sticking to edge.
        let safeTop = safeArea.top > 0 ? safeArea.top : (isLandscape ? 20 : 47)
        let safeBottom = safeArea.bottom > 0 ? safeArea.bottom : 20

        let finalTop = safeTop + 10 // Add a little breathing room
        let finalBottom = safeBottom + 10

        return EdgeInsets(
            top: finalTop,
            leading: finalLeading,
            bottom: finalBottom,
            trailing: finalTrailing
        )
    }
}
