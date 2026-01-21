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
                        // Force drag state end to prevent stuck UI at 00:00.
                        // We dispatch to next runloop to ensure 'isDragging' binding is cleanly updated
                        // before we trigger seek, allowing 'onChange' to resume updates.
                        DispatchQueue.main.async {
                            isDragging = false
                            audioManager.seek(to: sliderValue)
                        }
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
                // Live Scrubbing: Show slider value while dragging, otherwise actual player time
                Text(timeString(time: isDragging ? sliderValue : audioManager.currentTime))
                    .monospacedDigit()
                Spacer()
                // Show "--:--" if duration is 0 (loading/failed), otherwise formatted duration
                Text(audioManager.duration > 0 ? timeString(time: audioManager.duration) : "--:--")
                    .monospacedDigit()
            }
            .font(.system(size: 12 * scale, weight: .medium)) // Improved font size
            // Colors match the Accent Color (Next Button)
            .foregroundStyle(ThemeColors.primaryColor(isDarkMode: themeManager.isDarkMode))
        }
    }

    // MARK: - Helper Methods
    private func timeString(time: TimeInterval) -> String {
        // Robust handling for NaN or Infinite values
        guard time.isFinite, !time.isNaN else {
            return "00:00"
        }
        // Prevent negative time display
        let validTime = max(time, 0)

        let minutes = Int(validTime) / 60
        let seconds = Int(validTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
