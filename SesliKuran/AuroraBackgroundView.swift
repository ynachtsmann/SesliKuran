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
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.95, green: 0.95, blue: 1.0), // Pearl White
                        Color(red: 0.9, green: 0.92, blue: 0.98)  // Soft Blue-Grey
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            }

            // Orb 1
            Circle()
                .fill(isDarkMode ?
                      Color(red: 0.5, green: 0.0, blue: 0.5).opacity(0.4) : // Dark: Purple
                      Color(red: 1.0, green: 0.7, blue: 0.8).opacity(0.4)   // Light: Pastel Pink
                )
                .frame(width: 300, height: 300)
                .blur(radius: 60)
                .offset(x: startAnimation ? -150 : 150, y: startAnimation ? -150 : 150)
                .animation(
                    Animation.easeInOut(duration: 10).repeatForever(autoreverses: true),
                    value: startAnimation
                )

            // Orb 2
            Circle()
                .fill(isDarkMode ?
                      Color(red: 0.0, green: 0.5, blue: 1.0).opacity(0.4) : // Dark: Blue
                      Color(red: 0.6, green: 0.8, blue: 1.0).opacity(0.4)   // Light: Sky Blue
                )
                .frame(width: 400, height: 400)
                .blur(radius: 60)
                .offset(x: startAnimation ? 100 : -100, y: startAnimation ? 200 : -200)
                .animation(
                    Animation.easeInOut(duration: 15).repeatForever(autoreverses: true),
                    value: startAnimation
                )

            // Orb 3
            Circle()
                .fill(isDarkMode ?
                      Color(red: 0.0, green: 0.8, blue: 0.8).opacity(0.3) : // Dark: Teal
                      Color(red: 0.7, green: 1.0, blue: 0.9).opacity(0.4)   // Light: Mint
                )
                .frame(width: 350, height: 350)
                .blur(radius: 50)
                .offset(x: startAnimation ? -100 : 200, y: startAnimation ? -250 : 100)
                .animation(
                    Animation.easeInOut(duration: 12).repeatForever(autoreverses: true),
                    value: startAnimation
                )
        }
        .edgesIgnoringSafeArea(.all)
        .onAppear {
            startAnimation.toggle()
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
