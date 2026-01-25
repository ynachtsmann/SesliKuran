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

    @State private var controlWidth: CGFloat = 0

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
                .frame(width: controlWidth > 0 ? controlWidth : nil)

            ControlSectionView(scale: scale, availableWidth: availableWidth)
                .background(
                    GeometryReader { geometry in
                        Color.clear.preference(key: ControlWidthPreferenceKey.self, value: geometry.size.width)
                    }
                )
        }
        .onPreferenceChange(ControlWidthPreferenceKey.self) { width in
            controlWidth = width
        }
    }
}

// MARK: - Preference Key
struct ControlWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
