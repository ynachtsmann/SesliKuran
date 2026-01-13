// MARK: - Imports
import SwiftUI

// MARK: - Theme Colors
struct ThemeColors {
    // Gradient for Buttons, Sliders, Active Elements
    static func gradientColors(isDarkMode: Bool) -> [Color] {
        // Light Mode: Warm Peach/Gold/Pink
        // Dark Mode: Cyberpunk Cyan/Blue/Purple
        return isDarkMode ? [.cyan, .blue, .purple] : [Color.orange, Color.pink]
    }

    // Primary Accent Color (for glows, single-color icons)
    static func primaryColor(isDarkMode: Bool) -> Color {
        return isDarkMode ? .cyan : .orange
    }

    // Secondary Accent Color
    static func secondaryColor(isDarkMode: Bool) -> Color {
        return isDarkMode ? .purple : .pink
    }

    // Foreground Color for Interactive Elements (Buttons, Icons)
    // Replaces harsh black with White (Dark Mode) or Deep Warm Brown/Purple (Light Mode)
    static func buttonForeground(isDarkMode: Bool) -> Color {
        // Updated to match Primary Color (Cyan for Dark, Orange for Light)
        return isDarkMode ? .cyan : .orange
    }
}

// MARK: - Theme Manager
// Central Source of Truth for App Theme
@MainActor
class ThemeManager: ObservableObject {
    @Published var isDarkMode: Bool = true {
        didSet {
            // Only save if changed (simple debounce)
            // Note: We don't check 'isLoading' here because we want manual toggles to save.
            Task {
                await PersistenceManager.shared.updateTheme(isDarkMode: isDarkMode)
            }
        }
    }
    
    init() {
        // Synchronously load the saved theme preference on startup
        let savedSettings = PersistenceManager.shared.loadSynchronously()
        self._isDarkMode = Published(initialValue: savedSettings.isDarkMode)
    }
}