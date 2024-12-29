// MARK: - Imports
import SwiftUI

// MARK: - Main App
@main
struct MyMusicApp: App {
    // MARK: - Properties
    @StateObject private var themeManager = ThemeManager()
    
    // MARK: - Body
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(themeManager)
        }
    }
}
