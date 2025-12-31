import SwiftUI

struct AuroraBackgroundView: View {
    @State private var startAnimation = false

    var body: some View {
        ZStack {
            // Deep base background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.1), // Very dark blue/black
                    Color(red: 0.1, green: 0.1, blue: 0.2)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)

            // Orb 1 - Purple/Pink
            Circle()
                .fill(Color(red: 0.5, green: 0.0, blue: 0.5).opacity(0.4))
                .frame(width: 300, height: 300)
                .blur(radius: 60)
                .offset(x: startAnimation ? -150 : 150, y: startAnimation ? -150 : 150)
                .animation(
                    Animation.easeInOut(duration: 10).repeatForever(autoreverses: true),
                    value: startAnimation
                )

            // Orb 2 - Cyan/Blue
            Circle()
                .fill(Color(red: 0.0, green: 0.5, blue: 1.0).opacity(0.4))
                .frame(width: 400, height: 400)
                .blur(radius: 60)
                .offset(x: startAnimation ? 100 : -100, y: startAnimation ? 200 : -200)
                .animation(
                    Animation.easeInOut(duration: 15).repeatForever(autoreverses: true),
                    value: startAnimation
                )

            // Orb 3 - Teal/Greenish
            Circle()
                .fill(Color(red: 0.0, green: 0.8, blue: 0.8).opacity(0.3))
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
        AuroraBackgroundView()
    }
}
