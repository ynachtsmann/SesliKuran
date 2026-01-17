// MARK: - Imports
import SwiftUI
import UIKit

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
            Task { @MainActor in
                await PersistenceManager.shared.updateTheme(isDarkMode: isDarkMode)
                updateAppIcon(isDark: isDarkMode)
            }
        }
    }
    
    init() {
        // Determine system preference (fallback for fresh install)
        let systemIsDark = UITraitCollection.current.userInterfaceStyle == .dark

        // Synchronously load the saved theme preference on startup
        let savedSettings = PersistenceManager.shared.loadSynchronously(systemDarkMode: systemIsDark)
        self._isDarkMode = Published(initialValue: savedSettings.isDarkMode)

        // Initial icon check (delayed slightly to ensure window is active)
        Task { @MainActor in
            // Check if icon needs update on launch (e.g. if system reset it or it's out of sync)
            let currentIcon = UIApplication.shared.alternateIconName
            if savedSettings.isDarkMode && currentIcon != "AppIcon-Dark" {
                updateAppIcon(isDark: true)
            } else if !savedSettings.isDarkMode && currentIcon != nil {
                updateAppIcon(isDark: false)
            }
        }
    }

    // MARK: - App Icon Management
    private func updateAppIcon(isDark: Bool) {
        let iconName = isDark ? "AppIcon-Dark" : nil

        // Check if change is actually needed to avoid unnecessary alerts
        if UIApplication.shared.alternateIconName != iconName {
            UIApplication.shared.setAlternateIconName(iconName) { error in
                if let error = error {
                    print("Error setting alternate icon: \(error.localizedDescription)")
                }
            }
        }
    }
}