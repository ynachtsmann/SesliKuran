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

    // MARK: - Equatable
    // If the layout parameters (scale, width) haven't changed, we don't need to rebuild the view structure.
    // However, since we observe AudioManager, the body WILL be re-evaluated when currentTime changes.
    // The key benefit is that this view is ISOLATED from the parent ContentView.
    static func == (lhs: PlayerControlsView, rhs: PlayerControlsView) -> Bool {
        return lhs.scale == rhs.scale && lhs.availableWidth == rhs.availableWidth
    }

    // MARK: - Body
    var body: some View {
        VStack(spacing: 20 * scale) {
            TimeSliderView(scale: scale)
                .padding(.horizontal)

            ControlSectionView(scale: scale, availableWidth: availableWidth)
        }
    }
}
