// MARK: - Imports
import SwiftUI

// MARK: - Splash Screen
struct SplashScreen: View {
    // MARK: - Properties
    // Calculated background color to match Native Launch Screen (#0D0D1A)
    // Matches Aurora top gradient start: R=0.05, G=0.05, B=0.1
    private let launchBackgroundColor = Color("LaunchBackgroundColor")

    // MARK: - Body
    var body: some View {
        ZStack {
            // 1. Solid Base Color (Matches Native Launch Screen to prevent flashes)
            launchBackgroundColor
                .edgesIgnoringSafeArea(.all)

            // 2. Animated Aurora Background (Forced Dark Mode)
            AuroraBackgroundView(isDarkMode: true)
                .transition(.opacity) // Seamless fade in if needed

            // 3. Splash Image
            // Uses "splash" from Assets.xcassets (to be added by user)
            Image("splash")
                .resizable()
                .scaledToFit()
                // Limit size on iPad/Tablets so it doesn't overwhelm
                .frame(maxWidth: 500, maxHeight: 500)
                .padding()
        }
        .edgesIgnoringSafeArea(.all) // Ensure full screen coverage
    }
}

// MARK: - Preview
struct SplashScreen_Previews: PreviewProvider {
    static var previews: some View {
        SplashScreen()
    }
}
