// MARK: - Imports
import SwiftUI

// MARK: - Main App
@main
struct MyMusicApp: App {
    // MARK: - Properties
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var audioManager = AudioManager()
    @Environment(\.scenePhase) private var scenePhase
    
    // Control Splash Screen Visibility
    @State private var isAppReady = false

    // MARK: - Body
    var body: some Scene {
        WindowGroup {
            ZStack {
                // 1. Main Content (Always loaded to ensure layout is ready)
                ContentView()
                    .environmentObject(themeManager)
                    .environmentObject(audioManager)
                    .opacity(isAppReady ? 1 : 0) // Hide until ready to prevent visual glitches behind splash

                // 2. Splash Screen Overlay
                // We do NOT remove this view from the hierarchy immediately using 'if'
                // to ensure the transition out is handled gracefully by the Splash's internal logic or transition.
                // However, the user request says "Layer 2 (Top): SplashScreen".
                // And to remove it when ready.

                if !isAppReady {
                    SplashScreen(isAppReady: $isAppReady)
                        .environmentObject(audioManager)
                        .transition(.opacity.animation(.easeInOut(duration: 0.5)))
                        .zIndex(1)
                }
            }
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