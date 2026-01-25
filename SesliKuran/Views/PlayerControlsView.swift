// MARK: - Imports
import SwiftUI

// MARK: - Player Controls View
// Grouping the Active Controls to isolate updates
struct PlayerControlsView: View, Equatable {
    // MARK: - Properties
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var audioManager: AudioManager

    let scale: CGFloat
    let availableWidth: CGFloat
    let isLandscape: Bool

    // MARK: - Equatable
    // If the layout parameters (scale, width) haven't changed, we don't need to rebuild the view structure.
    // However, since we observe AudioManager, the body WILL be re-evaluated when currentTime changes.
    // The key benefit is that this view is ISOLATED from the parent ContentView.
    static func == (lhs: PlayerControlsView, rhs: PlayerControlsView) -> Bool {
        return lhs.scale == rhs.scale &&
               lhs.availableWidth == rhs.availableWidth &&
               lhs.isLandscape == rhs.isLandscape
    }

    // MARK: - Body
    var body: some View {
        VStack(spacing: 20 * scale) {
            TimeSliderView(scale: scale)
                // Conditional Padding:
                // - Landscape: Use 40 * scale to strictly align with the ControlSectionView buttons.
                // - Portrait: Use standard padding (nil = default) to restore original look.
                .horizontalPadding(isLandscape ? 40 * scale : nil)

            ControlSectionView(scale: scale, availableWidth: availableWidth)
        }
        // Force the entire container to respect the available width
        .frame(width: availableWidth)
    }
}

// MARK: - Helpers
extension View {
    /// Applies specific horizontal padding if value is provided, otherwise applies default system padding.
    @ViewBuilder
    func horizontalPadding(_ value: CGFloat?) -> some View {
        if let value = value {
            self.padding(.horizontal, value)
        } else {
            self.padding(.horizontal)
        }
    }
}
