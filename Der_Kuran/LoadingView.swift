// MARK: - Imports
import SwiftUI

// MARK: - Loading View
struct LoadingView: View {
    // MARK: - Properties
    @EnvironmentObject private var themeManager: ThemeManager
    
    // MARK: - Body
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: themeManager.isDarkMode ? .white : .blue))
                    .scaleEffect(1.5)
                
                Text("Wird geladen...")
                    .foregroundStyle(themeManager.isDarkMode ? .white : .primary)
                    .font(.headline)
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(themeManager.isDarkMode ? Color.black.opacity(0.8) : Color.white.opacity(0.8))
            )
            .shadow(radius: 10)
        }
    }
}
