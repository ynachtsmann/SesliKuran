// MARK: - Imports
import SwiftUI

// MARK: - Splash Screen
struct SplashScreen: View {
    // MARK: - Properties
    @Binding var isAppReady: Bool
    @EnvironmentObject var audioManager: AudioManager

    // Animation State
    @State private var isBreathing = false

    // MARK: - Body
    var body: some View {
        ZStack {
            // 0. Solid Background Fallback (Safety Layer)
            Color("LaunchBackgroundColor")
                .ignoresSafeArea()

            // 1. Animated Aurora Background (Forced Dark Mode for Neon Look)
            AuroraBackgroundView(isDarkMode: true)
                .edgesIgnoringSafeArea(.all)

            // 2. Center Element (Icon + Text)
            VStack(spacing: 20) {
                Image(systemName: "book.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100) // Fixed width for responsive scaling
                    .foregroundStyle(.white)

                Text("Sesli Kuran")
                    .font(.title.bold()) // Elegant, bold font
                    .foregroundStyle(.white)
            }
            .scaleEffect(isBreathing ? 1.05 : 1.0)
            .opacity(isBreathing ? 1.0 : 0.8)
            .animation(
                .easeInOut(duration: 1.5)
                .repeatForever(autoreverses: true),
                value: isBreathing
            )
            .onAppear {
                isBreathing = true
            }
        }
        .task {
            // Parallel Execution: Wait for BOTH data loading AND minimum branding time
            // using async let

            async let preparation: Void = audioManager.prepare()
            async let minimumTime: Void = Task.sleep(for: .milliseconds(1500)) // 1.5s

            // Wait for both to complete
            _ = try? await (preparation, minimumTime)

            // Smooth transition to ContentView
            withAnimation {
                isAppReady = true
            }
        }
    }
}

// MARK: - Preview
struct SplashScreen_Previews: PreviewProvider {
    static var previews: some View {
        SplashScreen(isAppReady: .constant(false))
    }
}
