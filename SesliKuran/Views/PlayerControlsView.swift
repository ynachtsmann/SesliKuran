// MARK: - Imports
import SwiftUI

// MARK: - Preference Key for Width Sync
struct WidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Player Controls View
// Grouping the Active Controls to isolate updates
struct PlayerControlsView: View, Equatable {
    // MARK: - Properties
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var audioManager: AudioManager

    // State to track the width of the control buttons
    @State private var controlWidth: CGFloat = 0

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
                // FORCE SYNC: Limit slider width to exactly match the buttons below
                .frame(width: controlWidth > 0 ? controlWidth : nil)

            ControlSectionView(scale: scale, availableWidth: availableWidth)
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .preference(key: WidthPreferenceKey.self, value: geo.size.width)
                    }
                )
        }
        // Capture the preference change to update state
        .onPreferenceChange(WidthPreferenceKey.self) { width in
            self.controlWidth = width
        }
        // Force the entire container to respect the available width
        .frame(width: availableWidth)
    }
}
