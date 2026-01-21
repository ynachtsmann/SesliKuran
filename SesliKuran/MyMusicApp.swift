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
                // 0. Global Background (Persistent & Seamless)
                // Hoisted to Root to ensure no animation resets during navigation/transitions
                AuroraBackgroundView(isDarkMode: themeManager.isDarkMode)
                    .edgesIgnoringSafeArea(.all)
                    .zIndex(0)

                // 1. Main Content (Always loaded to ensure layout is ready)
                ContentView()
                    .environmentObject(themeManager)
                    .environmentObject(audioManager)
                    .opacity(isAppReady ? 1 : 0) // Hide until ready to prevent visual glitches behind splash
                    .zIndex(1)

                // 2. Splash Screen Overlay
                // We do NOT remove this view from the hierarchy immediately using 'if'
                // to ensure the transition out is handled gracefully by the Splash's internal logic or transition.
                // However, the user request says "Layer 2 (Top): SplashScreen".
                // And to remove it when ready.

                if !isAppReady {
                    SplashScreen(isAppReady: $isAppReady)
                        .environmentObject(audioManager)
                        .environmentObject(themeManager)
                        .transition(.opacity.animation(.easeInOut(duration: 0.5)))
                        .zIndex(2)
                }
            }
            // Force the System UI Status Bar (Battery, Signal, Time) to match the App Theme
            .preferredColorScheme(themeManager.isDarkMode ? .dark : .light)
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                // App is now active
                break
            case .background, .inactive:
                // Mission Critical: Ensure Persistence Flush
                // We explicitly trigger a save to guarantee state is captured even for short sessions.
                audioManager.saveCurrentPosition()

                // Safety: Reset scrubbing state to prevent UI freeze on return
                audioManager.cancelScrubbing()

                print("App Lifecycle: Transition to \(newPhase) - Data integrity secured.")
            @unknown default:
                break
            }
        }
    }
}
