// MARK: - Imports
import SwiftUI

// MARK: - Header View
struct HeaderView: View {
    // MARK: - Properties
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var showSlotSelection: Bool
    let scale: CGFloat

    // MARK: - Body
    var body: some View {
        HStack {
            GlassyButton(
                iconName: "music.note.list",
                action: {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        showSlotSelection.toggle()
                    }
                },
                size: 20 * scale,
                padding: 12 * scale,
                isDarkMode: themeManager.isDarkMode
            )
            .accessibilityLabel("Liste anzeigen")
            .accessibilityHint("Zeigt die Liste aller Surahs an.")

            Spacer()

            // Functional Theme Toggle
            GlassyButton(
                iconName: themeManager.isDarkMode ? "moon.stars.fill" : "sun.max.fill",
                action: {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        themeManager.isDarkMode.toggle()
                    }
                },
                size: 20 * scale,
                padding: 12 * scale,
                isDarkMode: themeManager.isDarkMode
            )
            .accessibilityLabel(themeManager.isDarkMode ? "In den hellen Modus wechseln" : "In den dunklen Modus wechseln")
        }
    }
}
