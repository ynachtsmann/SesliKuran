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
                if !isAppReady {
                    SplashScreen()
                        .transition(.opacity.animation(.easeInOut(duration: 0.5)))
                        .zIndex(1) // Ensure it sits on top
                }
            }
            .onAppear {
                // Simulate loading / Wait for Persistence
                // AudioManager loads synchronously on init, so data is likely ready.
                // We add a deliberate delay to allow the Aurora animation to start
                // and to ensure a smooth transition without flashing.
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation {
                        isAppReady = true
                    }
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