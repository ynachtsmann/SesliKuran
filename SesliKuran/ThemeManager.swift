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
            Task {
                await PersistenceManager.shared.updateTheme(isDarkMode: isDarkMode)
                // Update App Icon on main actor
                await MainActor.run {
                    self.updateAppIcon()
                }
            }
        }
    }
    
    init() {
        // Determine system preference (fallback for fresh install)
        let systemIsDark = UITraitCollection.current.userInterfaceStyle == .dark

        // Synchronously load the saved theme preference on startup
        let savedSettings = PersistenceManager.shared.loadSynchronously(systemDarkMode: systemIsDark)
        self._isDarkMode = Published(initialValue: savedSettings.isDarkMode)

        // Trigger initial icon check
        Task { @MainActor in
            self.updateAppIcon()
        }
    }

    // MARK: - Icon Management
    /// Updates the Home Screen App Icon based on the current theme.
    /// Note: This triggers a system alert to the user.
    /// Changed to public to allow external triggers (e.g. from App Lifecycle).
    func updateAppIcon() {
        // If Dark Mode: Use 'AppIcon-Dark'
        // If Light Mode: Use nil (reverts to Primary 'AppIcon')
        let targetIconName: String? = isDarkMode ? "AppIcon-Dark" : nil

        // Avoid redundant calls (although iOS handles this, it's safer to check)
        // We double check applicationState to ensure we don't fire this when backgrounded/inactive if avoidable
        if UIApplication.shared.alternateIconName != targetIconName {
             // Only attempt to change if the app is active, otherwise it might fail silently or error
             // However, checking applicationState here might prevent 'init' from working if called too early.
             // We will let the call proceed but log errors. The key is calling this AGAIN when active.
            UIApplication.shared.setAlternateIconName(targetIconName) { error in
                if let error = error {
                    print("Error setting alternate icon: \(error.localizedDescription)")
                } else {
                    print("App Icon updated to: \(targetIconName ?? "Default")")
                }
            }
        }
    }
}