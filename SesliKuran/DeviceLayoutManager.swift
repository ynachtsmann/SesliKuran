import SwiftUI
import UIKit

// MARK: - Layout Configuration
/// Defines the specific layout constants for the current device environment.
struct LayoutConfig {
    let sidePadding: CGFloat
    let landscapeSideMargin: CGFloat
    let artScaleFactor: CGFloat
    let controlSpacing: CGFloat
    let splitViewRatio: CGFloat // e.g., 0.45 means 45% for Art, 55% for Controls

    static let standard = LayoutConfig(
        sidePadding: 20,
        landscapeSideMargin: 48, // Generous margin for Notches/Dynamic Island
        artScaleFactor: 0.7,
        controlSpacing: 20,
        splitViewRatio: 0.45
    )

    static let iPad = LayoutConfig(
        sidePadding: 40,
        landscapeSideMargin: 60,
        artScaleFactor: 0.6,
        controlSpacing: 40,
        splitViewRatio: 0.4 // 40% Art, 60% Controls for more breathing room
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
    /// Note: While the device type (iPad/iPhone) is constant, the orientation
    /// is handled dynamically by the View's GeometryReader.
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

    /// Returns the safe area padding to use for the "Buttons sticking out" fix.
    /// Adds extra margin in landscape to avoid corners/notches.
    func safeAreaInsets(for geometry: GeometryProxy, isLandscape: Bool) -> EdgeInsets {
        let base = geometry.safeAreaInsets
        let config = self.config

        // In Landscape, enforce a minimum side margin to prevent corner clipping.
        // We use the maximum of the actual safe area (notch) and our custom margin
        // to ensure content is never hidden behind the Dynamic Island or rounded corners.
        let maxSafeArea = max(base.leading, base.trailing)
        let horizontalPadding = isLandscape ? max(maxSafeArea, config.landscapeSideMargin) : base.leading

        return EdgeInsets(
            top: base.top,
            leading: horizontalPadding,
            bottom: base.bottom,
            trailing: horizontalPadding // Symmetry for aesthetic balance
        )
    }
}
