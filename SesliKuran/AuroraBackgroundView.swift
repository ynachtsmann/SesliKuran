import SwiftUI

struct AuroraBackgroundView: View {
    @State private var startAnimation = false
    var isDarkMode: Bool

    var body: some View {
        ZStack {
            // Base Background
            if isDarkMode {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.05, green: 0.05, blue: 0.1), // Deep Space Black
                        Color(red: 0.1, green: 0.1, blue: 0.2)
                    ]),
                    startPoint: startAnimation ? .topLeading : .topTrailing,
                    endPoint: startAnimation ? .bottomTrailing : .bottomLeading
                )
                .animation(.easeInOut(duration: 10).repeatForever(autoreverses: true), value: startAnimation)
            } else {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.98, green: 0.94, blue: 0.90), // Warm Peach/Sand base
                        Color(red: 0.95, green: 0.92, blue: 0.96)  // Soft Warm Lilac
                    ]),
                    startPoint: startAnimation ? .topLeading : .topTrailing,
                    endPoint: startAnimation ? .bottomTrailing : .bottomLeading
                )
                .animation(.easeInOut(duration: 10).repeatForever(autoreverses: true), value: startAnimation)
            }

            // Orb 1 - Top Left/Right movement
            Circle()
                .fill(isDarkMode ?
                      Color(red: 0.5, green: 0.0, blue: 0.5).opacity(0.4) : // Dark: Purple
                      Color(red: 1.0, green: 0.6, blue: 0.4).opacity(0.3)   // Light: Warm Orange/Peach
                )
                .frame(width: 300, height: 300)
                .blur(radius: 60)
                .offset(x: startAnimation ? -100 : 100, y: startAnimation ? -100 : 50)
                .scaleEffect(startAnimation ? 1.1 : 0.8)
                .animation(
                    Animation.easeInOut(duration: 7).repeatForever(autoreverses: true),
                    value: startAnimation
                )

            // Orb 2 - Bottom movement
            Circle()
                .fill(isDarkMode ?
                      Color(red: 0.0, green: 0.5, blue: 1.0).opacity(0.4) : // Dark: Blue
                      Color(red: 1.0, green: 0.4, blue: 0.6).opacity(0.3)   // Light: Warm Pink
                )
                .frame(width: 400, height: 400)
                .blur(radius: 60)
                .offset(x: startAnimation ? 50 : -50, y: startAnimation ? 150 : -50)
                .scaleEffect(startAnimation ? 1.0 : 1.2)
                .animation(
                    Animation.easeInOut(duration: 11).repeatForever(autoreverses: true),
                    value: startAnimation
                )

            // Orb 3 - Middle/Random
            Circle()
                .fill(isDarkMode ?
                      Color(red: 0.0, green: 0.8, blue: 0.8).opacity(0.3) : // Dark: Teal
                      Color(red: 1.0, green: 0.8, blue: 0.6).opacity(0.3)   // Light: Warm Gold
                )
                .frame(width: 350, height: 350)
                .blur(radius: 50)
                .offset(x: startAnimation ? -50 : 150, y: startAnimation ? -100 : 100)
                .scaleEffect(startAnimation ? 1.1 : 0.9)
                .rotationEffect(.degrees(startAnimation ? 0 : 360))
                .animation(
                    Animation.easeInOut(duration: 9).repeatForever(autoreverses: true),
                    value: startAnimation
                )
        }
        .edgesIgnoringSafeArea(.all)
        .onAppear {
            // Slight delay ensures the view is fully mounted before triggering animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                startAnimation.toggle()
            }
        }
    }
}

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
