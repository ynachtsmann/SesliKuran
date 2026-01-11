// MARK: - Imports
import SwiftUI

struct AudioListView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var audioManager: AudioManager
    @Binding var isShowing: Bool
    let onTrackSelected: (Surah) -> Void
    private let allSurahs = SurahData.allSurahs
    
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
            
            // Added explicit Safe Area Padding to the Header if needed,
            // but the parent container in ContentView handles the edges now.
            // We just ensure the list content itself has breathing room.

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(allSurahs) { surah in
                            GlassyCardRow(
                                surah: surah,
                                isCurrentTrack: surah.id == audioManager.selectedTrack?.id,
                                isDarkMode: themeManager.isDarkMode,
                                onTrackSelected: onTrackSelected
                            )
                            .id(surah.id)
                        }
                    }
                    .padding(.horizontal) // Side padding for cards
                    .padding(.bottom, 20) // Bottom padding for scrolling
                    .padding(.top, 10)
                }
                .onAppear {
                    if let selectedId = audioManager.selectedTrack?.id {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation {
                                proxy.scrollTo(selectedId, anchor: .center)
                            }
                        }
                    }
                }
                .onChange(of: isShowing) { showing in
                    if showing, let selectedId = audioManager.selectedTrack?.id {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation {
                                proxy.scrollTo(selectedId, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
        .background(Color.clear)
        // Ensure no safe area bleed internally
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
                            ThemeColors.primaryColor(isDarkMode: isDarkMode).opacity(0.3) :
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
                        .shadow(color: isCurrentTrack && isDarkMode ? ThemeColors.primaryColor(isDarkMode: true) : .clear, radius: 5)
                    
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
                        .foregroundStyle(ThemeColors.primaryColor(isDarkMode: isDarkMode))
                        .shadow(color: ThemeColors.primaryColor(isDarkMode: isDarkMode).opacity(isDarkMode ? 1.0 : 0.5), radius: 3)
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
                                        gradient: Gradient(colors: ThemeColors.gradientColors(isDarkMode: true).map { $0.opacity(0.6) }),
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
