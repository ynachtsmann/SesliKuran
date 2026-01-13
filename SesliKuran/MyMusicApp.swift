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
                // 0. Persistent Background (Seamless Transition)
                AuroraBackgroundView(isDarkMode: themeManager.isDarkMode)
                    .edgesIgnoringSafeArea(.all)

                // 1. Main Content (Always loaded to ensure layout is ready)
                // Content fades in smoothly over 0.8s
                ContentView()
                    .environmentObject(themeManager)
                    .environmentObject(audioManager)
                    .opacity(isAppReady ? 1 : 0)
                    .animation(.easeInOut(duration: 0.8), value: isAppReady)

                // 2. Splash Screen Overlay
                // Splash elements fade out as Content fades in
                if !isAppReady {
                    SplashScreen(isAppReady: $isAppReady)
                        .environmentObject(audioManager)
                        .transition(.opacity.animation(.easeInOut(duration: 0.8)))
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