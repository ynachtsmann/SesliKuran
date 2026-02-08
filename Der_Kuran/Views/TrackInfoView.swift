// MARK: - Imports
import SwiftUI

// MARK: - Track Info View
struct TrackInfoView: View {
    // MARK: - Properties
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var audioManager: AudioManager

    let scale: CGFloat

    // MARK: - Body
    var body: some View {
        // Defensive Coding: Handle nil selectedTrack gracefully
        Group {
            if let selectedTrack = audioManager.selectedTrack {
                VStack(spacing: 8 * scale) {
                    Text("\(selectedTrack.name) - \(selectedTrack.germanName)")
                        .font(.system(size: 22 * scale, weight: .bold)) // Replaces .title2
                        .foregroundStyle(themeManager.isDarkMode ? .white : .black.opacity(0.8))
                        .lineLimit(1)
                        .shadow(radius: themeManager.isDarkMode ? 5 : 0)
                        .minimumScaleFactor(0.8) // Allow text to shrink slightly on smaller screens

                    Text(selectedTrack.arabicName)
                        .font(.system(size: 20 * scale)) // Replaces .title3
                        .foregroundStyle(themeManager.isDarkMode ? .white.opacity(0.8) : .gray)
                }
            } else {
                // Placeholder State - Never Crash
                VStack(spacing: 8 * scale) {
                    Text("Wähle eine Surah")
                        .font(.system(size: 22 * scale, weight: .semibold)) // Replaces .title2
                        .foregroundStyle(themeManager.isDarkMode ? .white.opacity(0.8) : .gray)

                    Text("---")
                        .font(.system(size: 20 * scale)) // Replaces .title3
                        .foregroundStyle(themeManager.isDarkMode ? .white.opacity(0.5) : .gray.opacity(0.5))
                }
            }
        }
    }
}
