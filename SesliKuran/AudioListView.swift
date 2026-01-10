// MARK: - Imports
import SwiftUI

struct AudioListView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var audioManager: AudioManager
    @Binding var isShowing: Bool
    let onTrackSelected: (Surah) -> Void
    private let allSurahs = SurahData.allSurahs
    
    @State private var loadedTracks: Int = 20
    @State private var isLoading = false
    
    var body: some View {
        VStack {
            // Header for List
            HStack {
                Text("Surah Liste")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(themeManager.isDarkMode ? .white : .black.opacity(0.8))

                Spacer()

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isShowing = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(themeManager.isDarkMode ? .white.opacity(0.8) : .gray)
                        .padding()
                }
            }
            .padding(.horizontal)
            .padding(.top, 20)
            
            ScrollView {
                // Changed from LazyVStack to standard VStack for more predictable card rendering if needed,
                // but LazyVStack is better for performance. Keeping LazyVStack but adding padding.
                LazyVStack(spacing: 16) { // Increased spacing for "Floating" feel
                    ForEach(allSurahs.prefix(loadedTracks)) { surah in
                        GlassyCardRow(
                            surah: surah,
                            isCurrentTrack: surah.id == audioManager.selectedTrack?.id,
                            isDarkMode: themeManager.isDarkMode,
                            onTrackSelected: onTrackSelected
                        )
                    }
                    
                    if loadedTracks < allSurahs.count {
                        Button(action: loadMoreTracks) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: themeManager.isDarkMode ? .white : .gray))
                            } else {
                                Text("Weitere Kapitel laden")
                                    .foregroundStyle(themeManager.isDarkMode ? .white.opacity(0.7) : .blue)
                                    .padding(.vertical, 10)
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .background(Color.clear)
    }
    
    private func loadMoreTracks() {
        guard !isLoading else { return }
        
        isLoading = true
        
        Task {
            // Modern Concurrency Sleep
            // Use 'try await' (without ?) to respect cancellation if view is dismissed
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5s

            // View update on MainActor
            withAnimation {
                loadedTracks = min(loadedTracks + 20, allSurahs.count)
                isLoading = false
            }
        }
    }
}

// Renamed and Redesigned as "Card"
struct GlassyCardRow: View {
    let surah: Surah
    let isCurrentTrack: Bool
    let isDarkMode: Bool
    let onTrackSelected: (Surah) -> Void
    
    var body: some View {
        Button(action: {
            onTrackSelected(surah)
        }) {
            HStack {
                // Surah Number
                ZStack {
                    Circle()
                        .fill(
                            isCurrentTrack ?
                            (isDarkMode ? Color.cyan.opacity(0.3) : Color.orange.opacity(0.3)) :
                            (isDarkMode ? Color.white.opacity(0.1) : Color.white.opacity(0.4))
                        )
                        .frame(width: 44, height: 44)

                    Text("\(surah.id)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(isDarkMode ? .white : .black.opacity(0.8))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(surah.name) - \(surah.germanName)")
                        .foregroundStyle(isDarkMode ? .white : .black.opacity(0.9))
                        .font(.headline)
                        .lineLimit(1)
                        .shadow(color: isCurrentTrack && isDarkMode ? .cyan : .clear, radius: 5)
                    
                    Text(surah.arabicName)
                        .font(.caption)
                        .foregroundStyle(isDarkMode ? .white.opacity(0.6) : .gray)
                }
                .padding(.leading, 8)

                Spacer()

                // Active Indicator
                if isCurrentTrack {
                    Image(systemName: "waveform.path.ecg")
                        .font(.body)
                        .foregroundStyle(isDarkMode ? .cyan : .orange)
                        .shadow(color: isDarkMode ? .cyan : .orange.opacity(0.5), radius: 3)
                }
            }
            .padding(16)
            .background(
                ZStack {
                    // Card Background
                    if isDarkMode {
                        // Increased opacity for better readability without container
                        Color(red: 0.1, green: 0.1, blue: 0.15).opacity(0.7)
                            .background(VisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialDark)))

                        // Neon border for active
                        if isCurrentTrack {
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(
                                    LinearGradient(
                                        gradient: Gradient(colors: [.cyan.opacity(0.6), .purple.opacity(0.6)]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        }
                    } else {
                        // Light Mode "Frost" Card - Warmer/Opaque
                        Color.white.opacity(0.8)
                            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
                    }
                }
            )
            .cornerRadius(20)
            // Subtle scale effect for active track
            .scaleEffect(isCurrentTrack ? 1.02 : 1.0)
            .animation(.spring(), value: isCurrentTrack)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
