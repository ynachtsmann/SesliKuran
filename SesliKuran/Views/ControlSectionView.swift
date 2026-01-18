// MARK: - Imports
import SwiftUI

// MARK: - Control Section View
struct ControlSectionView: View {
    // MARK: - Properties
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var audioManager: AudioManager

    let scale: CGFloat
    let availableWidth: CGFloat

    // MARK: - Body
    var body: some View {
        // Dynamic Spacing based on available width (pane width in landscape)
        // We use a conservative 10% of the PANE width to prevent buttons flying apart
        let dynamicSpacing = availableWidth * 0.1

        return HStack(spacing: dynamicSpacing) {
            Button(action: {
                audioManager.previousTrack()
            }) {
                Image(systemName: "backward.end.fill")
                    .font(.system(size: 22 * scale)) // Replaces .title2
                    .foregroundStyle(ThemeColors.buttonForeground(isDarkMode: themeManager.isDarkMode))
            }
            .accessibilityLabel("Vorherige Surah")

            GlassyControlButton(
                iconName: audioManager.isPlaying ? "pause.fill" : "play.fill",
                action: { audioManager.togglePlayPause() },
                size: 35 * scale,
                isDarkMode: themeManager.isDarkMode
            )
            .accessibilityLabel(audioManager.isPlaying ? "Pause" : "Wiedergabe")

            Button(action: {
                audioManager.nextTrack()
            }) {
                Image(systemName: "forward.end.fill")
                    .font(.system(size: 22 * scale)) // Replaces .title2
                    .foregroundStyle(ThemeColors.buttonForeground(isDarkMode: themeManager.isDarkMode))
            }
            .accessibilityLabel("Nächste Surah")
        }
        .padding(.vertical, 20 * scale)
        .padding(.horizontal, 40 * scale)
        .background(
            Capsule()
                .fill(themeManager.isDarkMode ? Color.white.opacity(0.05) : Color.white.opacity(0.5))
                .overlay(
                    Capsule()
                        .stroke(themeManager.isDarkMode ? Color.white.opacity(0.1) : Color.white.opacity(0.4), lineWidth: 1)
                )
        )
    }
}
