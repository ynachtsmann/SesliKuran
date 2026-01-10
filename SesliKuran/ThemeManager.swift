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
        return isDarkMode ? .white : Color(red: 0.3, green: 0.15, blue: 0.2) // Deep Warm Brown-Purple
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
        // Load initial state SYNCHRONOUSLY to prevent theme flash.
        // This is safe because it's a read-only op on startup.
        let settings = PersistenceManager.shared.loadSynchronously()
        self._isDarkMode = Published(initialValue: settings.isDarkMode)
    }
}