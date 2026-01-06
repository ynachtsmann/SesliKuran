// MARK: - Imports
import SwiftUI

// MARK: - Theme Manager
@MainActor
class ThemeManager: ObservableObject {
    private var isLoading = true

    @Published var isDarkMode: Bool = true {
        didSet {
            guard !isLoading else { return }
            // Update Persistence asynchronously
            Task {
                await PersistenceManager.shared.updateTheme(isDarkMode: isDarkMode)
            }
        }
    }
    
    init() {
        Task {
            let savedMode = await PersistenceManager.shared.getIsDarkMode()
            // Set property without triggering save logic if we handle logic carefully,
            // but didSet fires anyway. So we use the flag.
            self.isDarkMode = savedMode
            self.isLoading = false
        }
    }
}
