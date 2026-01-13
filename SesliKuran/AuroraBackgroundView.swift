import SwiftUI

struct AuroraBackgroundView: View {
    @State private var startAnimation = false
    var isDarkMode: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                // MARK: - 1. Solid Base Layer
                // Ensures we never see a "white screen" glitch.
                if isDarkMode {
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.02, green: 0.02, blue: 0.05), // Deepest Black/Blue
                            Color(red: 0.05, green: 0.05, blue: 0.15)  // Dark Navy
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                } else {
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.98, green: 0.96, blue: 0.92), // Warm Cream
                            Color(red: 0.96, green: 0.94, blue: 0.98)  // Very Soft Lilac
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }

                // MARK: - 2. Drifting Orbs
                // Large, soft blurs that move slowly across the screen.

                // Orb 1: Primary Accent (Purple/Orange) - Moves Top-Left <-> Bottom-Right
                Circle()
                    .fill(isDarkMode ?
                          Color(red: 0.4, green: 0.1, blue: 0.6).opacity(0.3) : // Deep Purple
                          Color(red: 1.0, green: 0.7, blue: 0.4).opacity(0.3)   // Warm Peach
                    )
                    .frame(width: proxy.size.width * 0.8, height: proxy.size.width * 0.8)
                    .blur(radius: 80)
                    .offset(
                        x: startAnimation ? proxy.size.width * 0.4 : -proxy.size.width * 0.4,
                        y: startAnimation ? proxy.size.height * 0.3 : -proxy.size.height * 0.3
                    )
                    .animation(
                        .easeInOut(duration: 20).repeatForever(autoreverses: true),
                        value: startAnimation
                    )

                // Orb 2: Secondary Accent (Blue/Pink) - Moves Bottom-Left <-> Top-Right
                Circle()
                    .fill(isDarkMode ?
                          Color(red: 0.1, green: 0.3, blue: 0.7).opacity(0.25) : // Deep Blue
                          Color(red: 1.0, green: 0.5, blue: 0.7).opacity(0.25)   // Warm Pink
                    )
                    .frame(width: proxy.size.width * 0.9, height: proxy.size.width * 0.9)
                    .blur(radius: 90)
                    .offset(
                        x: startAnimation ? -proxy.size.width * 0.3 : proxy.size.width * 0.3,
                        y: startAnimation ? -proxy.size.height * 0.2 : proxy.size.height * 0.4
                    )
                    .animation(
                        .easeInOut(duration: 25).repeatForever(autoreverses: true),
                        value: startAnimation
                    )

                // Orb 3: Highlight (Cyan/Gold) - Moves Top <-> Bottom (Center)
                Circle()
                    .fill(isDarkMode ?
                          Color(red: 0.0, green: 0.6, blue: 0.7).opacity(0.2) : // Cyan
                          Color(red: 1.0, green: 0.85, blue: 0.6).opacity(0.3)  // Gold
                    )
                    .frame(width: proxy.size.width * 0.7, height: proxy.size.width * 0.7)
                    .blur(radius: 70)
                    .offset(
                        x: startAnimation ? 50 : -50, // Slight horizontal drift
                        y: startAnimation ? proxy.size.height * 0.3 : -proxy.size.height * 0.3
                    )
                    .animation(
                        .easeInOut(duration: 18).repeatForever(autoreverses: true),
                        value: startAnimation
                    )
            }
            .ignoresSafeArea() // Ensure full coverage including notch/home bar
        }
        .onAppear {
            // Trigger animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation {
                    startAnimation = true
                }
            }
        }
    }
}

// MARK: - Preview
struct AuroraBackgroundView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            AuroraBackgroundView(isDarkMode: true)
                .previewDisplayName("Dark Mode")
            AuroraBackgroundView(isDarkMode: false)
                .previewDisplayName("Light Mode")
        }
    }
}
