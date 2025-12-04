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
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(allSurahs.prefix(loadedTracks)) { surah in
                        AudioTrackRow(
                            surah: surah,
                            isDarkMode: themeManager.isDarkMode,
                            isCurrentTrack: surah.id == audioManager.selectedTrack?.id,
                            onTrackSelected: onTrackSelected
                        )
                    }
                    
                    if loadedTracks < allSurahs.count {
                        Button(action: loadMoreTracks) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(
                                        tint: themeManager.isDarkMode ? .white : .blue
                                    ))
                            } else {
                                Text("Weitere Kapitel laden")
                                    .foregroundColor(themeManager.isDarkMode ? .white : .blue)
                            }
                        }
                        .padding()
                    }
                }
                .padding()
            }
        }
        .background(Color(UIColor.systemBackground))
        .navigationTitle("Surah Auswahl")
        .navigationBarTitleDisplayMode(.inline)
        }
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

struct AudioTrackRow: View {
    let surah: Surah
    let isDarkMode: Bool
    let isCurrentTrack: Bool
    let onTrackSelected: (Surah) -> Void
    
    var body: some View {
        Button(action: {
            onTrackSelected(surah)
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(surah.id). \(surah.name)")
                        .foregroundColor(.primary)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Text(surah.englishName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: isCurrentTrack ? "pause.circle.fill" : "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(isCurrentTrack ? .accentColor : .blue)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isCurrentTrack ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
            )
        }
        .foregroundColor(.primary)
    }
}
