// MARK: - Imports
import SwiftUI

// MARK: - Splash Screen
struct SplashScreen: View {
    // MARK: - Properties
    @Binding var isAppReady: Bool

    // Animation State
    @State private var isBreathing = false

    // MARK: - Body
    var body: some View {
        ZStack {
            // 1. Animated Aurora Background (Forced Dark Mode for Neon Look)
            AuroraBackgroundView(isDarkMode: true)
                .edgesIgnoringSafeArea(.all)

            // 2. Center Element (Icon + Text)
            VStack(spacing: 20) {
                Image(systemName: "book.fill")
                    .font(.system(size: 80))
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
            // Logic: Simulate background task (e.g., loading JSON)
            // TODO: Load real JSON here
            try? await Task.sleep(nanoseconds: 2 * 1_000_000_000) // 2 seconds delay

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
