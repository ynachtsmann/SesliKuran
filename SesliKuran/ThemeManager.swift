// MARK: - Imports
import SwiftUI

// MARK: - Theme Manager
// Central Source of Truth for App Theme
@MainActor
class ThemeManager: ObservableObject {
    @Published var isDarkMode: Bool = true {
        didSet {
            // Only save if changed (simple debounce)
            // Note: We don't check 'isLoading' here because we want manual toggles to save.
            // The initial load sets this property, which might trigger a save,
            // but saving the same value is harmless and fast via the actor.
            Task {
                await PersistenceManager.shared.updateTheme(isDarkMode: isDarkMode)
            }
        }
    }
    
    init() {
        // Load initial state asynchronously
        Task {
            // We use 'load()' which is efficient
            let settings = await PersistenceManager.shared.load()
            self.isDarkMode = settings.isDarkMode
        }
    }
}
