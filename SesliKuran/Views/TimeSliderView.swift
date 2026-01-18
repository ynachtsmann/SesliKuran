// MARK: - Imports
import SwiftUI

// MARK: - Time Slider View
struct TimeSliderView: View {
    // MARK: - Properties
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var audioManager: AudioManager

    let scale: CGFloat

    // MARK: - Body
    var body: some View {
        VStack(spacing: 4 * scale) {
            NeumorphicSlider(
                value: $audioManager.currentTime,
                inRange: 0...max(audioManager.duration, 0.01), // Prevent 0 range
                onEditingChanged: { _ in
                    audioManager.seek(to: audioManager.currentTime)
                },
                isDarkMode: themeManager.isDarkMode
            )

            // Time Labels below the ends
            HStack {
                Text(timeString(time: audioManager.currentTime))
                    .monospacedDigit()
                Spacer()
                Text(timeString(time: audioManager.duration))
                    .monospacedDigit()
            }
            .font(.system(size: 12 * scale, weight: .medium)) // Improved font size
            .foregroundStyle(themeManager.isDarkMode ? .white.opacity(0.6) : .gray)
        }
    }

    // MARK: - Helper Methods
    private func timeString(time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
