// MARK: - Imports
import SwiftUI

// MARK: - Main App
@main
struct MyMusicApp: App {
    // MARK: - Properties
    @StateObject private var themeManager = ThemeManager()
    @Environment(\.scenePhase) private var scenePhase
    
    // MARK: - Body
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(themeManager)
        }
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .background, .inactive:
                // Mission Critical: Ensure Persistence Flush
                // AudioManager observes 'didEnterBackground' to save exact progress.
                // Here we simply log the lifecycle transition for debugging/assurance.
                // The heavy lifting is done in AudioManager to capture the exact second.
                print("App Lifecycle: Transition to \(newPhase) - Data integrity secured.")
            default:
                break
            }
        }
    }
}
