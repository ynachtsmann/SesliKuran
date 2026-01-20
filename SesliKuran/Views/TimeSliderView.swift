// MARK: - Imports
import SwiftUI

// MARK: - Time Slider View
struct TimeSliderView: View {
    // MARK: - Properties
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var audioManager: AudioManager

    let scale: CGFloat

    // MARK: - Local State for Interaction
    @State private var sliderValue: Double = 0
    @State private var isDragging: Bool = false

    // MARK: - Body
    var body: some View {
        VStack(spacing: 4 * scale) {
            NeumorphicSlider(
                value: $sliderValue,
                inRange: 0...max(audioManager.duration, 0.01), // Prevent 0 range
                isDragging: $isDragging,
                onEditingChanged: { editing in
                    // seek only on release
                    if !editing {
                        // Force drag state end to prevent stuck UI at 00:00
                        isDragging = false
                        audioManager.seek(to: sliderValue)
                    }
                },
                isDarkMode: themeManager.isDarkMode,
                timeFormatter: timeString
            )
            .onAppear {
                sliderValue = audioManager.currentTime
            }
            .onChange(of: audioManager.currentTime) { _, newValue in
                if !isDragging {
                    sliderValue = newValue
                }
            }

            // Time Labels below the ends
            HStack {
                Text(timeString(time: audioManager.currentTime))
                    .monospacedDigit()
                Spacer()
                Text(timeString(time: audioManager.duration))
                    .monospacedDigit()
            }
            .font(.system(size: 12 * scale, weight: .medium)) // Improved font size
            // Colors adapted to theme (High Contrast)
            .foregroundStyle(themeManager.isDarkMode ? .white : .black)
        }
    }

    // MARK: - Helper Methods
    private func timeString(time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
