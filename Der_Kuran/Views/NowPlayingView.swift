// MARK: - Imports
import SwiftUI

// MARK: - Now Playing View
struct NowPlayingView: View {
    // MARK: - Properties
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var audioManager: AudioManager

    let size: CGFloat
    let scale: CGFloat

    // MARK: - Body
    var body: some View {
        ZStack {
            Circle()
                .fill(themeManager.isDarkMode ? Color.white.opacity(0.05) : Color.white.opacity(0.3))
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: ThemeColors.gradientColors(isDarkMode: themeManager.isDarkMode)),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2 * scale
                        )
                )
                .shadow(
                    color: ThemeColors.primaryColor(isDarkMode: themeManager.isDarkMode).opacity(0.3),
                    radius: 20 * scale, x: 0, y: 0
                )

            if let selectedTrack = audioManager.selectedTrack {
                VStack(spacing: 5 * scale) {
                    Text("\(selectedTrack.id)")
                        .font(.system(size: size * 0.3, weight: .thin, design: .rounded))
                        .foregroundStyle(themeManager.isDarkMode ? .white : .black.opacity(0.8))
                        .shadow(color: themeManager.isDarkMode ? .white.opacity(0.8) : .clear, radius: 10 * scale)

                    Text("SURAH")
                        .font(.system(size: size * 0.05, weight: .bold, design: .monospaced))
                        .tracking(5 * scale)
                        .foregroundStyle(themeManager.isDarkMode ? .white.opacity(0.7) : .gray)
                }
            } else {
                Image(systemName: "music.quarternote.3")
                    .font(.system(size: size * 0.3))
                    .foregroundStyle(themeManager.isDarkMode ? .white.opacity(0.5) : .gray.opacity(0.5))
            }
        }
        // Strict Aspect Ratio to prevent oval stretching
        .aspectRatio(1, contentMode: .fit)
    }
}
