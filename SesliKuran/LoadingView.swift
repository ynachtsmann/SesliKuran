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
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                
                Text("Wird geladen...")
                    .foregroundColor(.white)
                    .font(.headline)
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Material.ultraThinMaterial)
            )
            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
        }
    }
}
