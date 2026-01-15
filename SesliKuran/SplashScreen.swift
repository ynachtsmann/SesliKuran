// MARK: - Imports
import SwiftUI

// MARK: - Splash Screen
struct SplashScreen: View {
    // MARK: - Properties
    @Binding var isAppReady: Bool
    @EnvironmentObject var audioManager: AudioManager
    @EnvironmentObject var themeManager: ThemeManager

    // Animation State
    @State private var isBreathing = false
    @State private var isBookOpen = false

    // MARK: - Body
    var body: some View {
        ZStack {
            // 0. Transparent Background to allow Root Aurora to show through
            Color.clear
                .ignoresSafeArea()

            // 1. Center Element (Icon + Text)
            VStack(spacing: 30) {
                ZStack {
                    // Holy Glow
                    Circle()
                        .fill(ThemeColors.primaryColor(isDarkMode: themeManager.isDarkMode))
                        .frame(width: 140, height: 140)
                        .blur(radius: 60)
                        .opacity(isBreathing ? 0.6 : 0.3)

                    // Book Icon
                    Image(systemName: isBookOpen ? "book.fill" : "book.closed.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100) // Fixed width for responsive scaling
                        .foregroundColor(ThemeColors.primaryColor(isDarkMode: themeManager.isDarkMode))
                        .contentTransition(.symbolEffect(.replace))
                        .shadow(color: ThemeColors.primaryColor(isDarkMode: themeManager.isDarkMode).opacity(0.8), radius: 10, x: 0, y: 0)
                }

                Text("Sesli Kuran")
                    .font(.system(.title, design: .serif).smallCaps())
                    .fontWeight(.bold)
                    .kerning(3)
                    .foregroundColor(ThemeColors.primaryColor(isDarkMode: themeManager.isDarkMode))
                    .shadow(color: ThemeColors.primaryColor(isDarkMode: themeManager.isDarkMode).opacity(0.3), radius: 10)
            }
            .scaleEffect(isBreathing ? 1.05 : 1.0)
            .animation(
                .easeInOut(duration: 2.5)
                .repeatForever(autoreverses: true),
                value: isBreathing
            )
            .onAppear {
                isBreathing = true
            }
        }
        .task {
            // Animate Book Opening - Using nanoseconds for maximum compatibility
            try? await Task.sleep(nanoseconds: 600 * 1_000_000)
            withAnimation(.spring(response: 0.7, dampingFraction: 0.6)) {
                isBookOpen = true
            }

            // Parallel Execution: Wait for BOTH data loading AND minimum branding time
            async let preparation: Void = audioManager.prepare()
            // Extended slightly to allow animation to complete gracefully
            async let minimumTime: Void = Task.sleep(nanoseconds: 2_000 * 1_000_000)

            // Wait for both to complete
            _ = try? await (preparation, minimumTime)

            // Smooth transition to ContentView
            withAnimation(.easeOut(duration: 0.8)) {
                isAppReady = true
            }
        }
    }
}

// MARK: - Preview
struct SplashScreen_Previews: PreviewProvider {
    static var previews: some View {
        SplashScreen(isAppReady: .constant(false))
            .environmentObject(ThemeManager())
            .environmentObject(AudioManager())
            .background(Color.black) // For preview visibility
    }
}
