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
                    .foregroundColor(.white)

                Spacer()

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isShowing = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.8))
                        .padding()
                }
            }
            .padding(.horizontal)
            .padding(.top, 20)
            
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(allSurahs.prefix(loadedTracks)) { surah in
                        GlassyTrackRow(
                            surah: surah,
                            isCurrentTrack: surah.id == audioManager.selectedTrack?.id,
                            onTrackSelected: onTrackSelected
                        )
                    }
                    
                    if loadedTracks < allSurahs.count {
                        Button(action: loadMoreTracks) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Weitere Kapitel laden")
                                    .foregroundColor(.white.opacity(0.7))
                                    .padding(.vertical, 10)
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .background(Color.clear) // Transparent to let the blur from parent show
    }
    
    private func loadMoreTracks() {
        guard !isLoading else { return }
        
        isLoading = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation {
                loadedTracks = min(loadedTracks + 20, allSurahs.count)
                isLoading = false
            }
        }
    }
}

struct GlassyTrackRow: View {
    let surah: Surah
    let isCurrentTrack: Bool
    let onTrackSelected: (Surah) -> Void
    
    var body: some View {
        Button(action: {
            onTrackSelected(surah)
        }) {
            HStack {
                // Surah Number
                ZStack {
                    Circle()
                        .fill(isCurrentTrack ? Color.cyan.opacity(0.3) : Color.white.opacity(0.1))
                        .frame(width: 40, height: 40)

                    Text("\(surah.id)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(surah.name) - \(surah.germanName)")
                        .foregroundColor(isCurrentTrack ? .white : .white.opacity(0.9))
                        .font(.headline)
                        .lineLimit(1)
                        .shadow(color: isCurrentTrack ? .cyan : .clear, radius: isCurrentTrack ? 5 : 0)
                    
                    Text(surah.arabicName)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.leading, 8)

                Spacer()

                // Instead of a button, we use a subtle indicator if selected, or nothing if clean
                if isCurrentTrack {
                    Image(systemName: "waveform.path.ecg")
                        .font(.body)
                        .foregroundColor(.cyan)
                        .shadow(color: .cyan, radius: 5)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(isCurrentTrack ? Color.white.opacity(0.15) : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: isCurrentTrack ? [.cyan.opacity(0.5), .purple.opacity(0.5)] : [.white.opacity(0.1), .white.opacity(0.05)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle()) // Removes default button click opacity animation to keep it custom
    }
}
