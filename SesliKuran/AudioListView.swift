// MARK: - Imports
import SwiftUI

struct AudioListView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var audioManager: AudioManager
    @Binding var isShowing: Bool
    let onTrackSelected: (Surah) -> Void
    private let allSurahs = SurahData.allSurahs
    
    var body: some View {
        NavigationView {
            List(allSurahs) { surah in
                AudioTrackRow(
                    surah: surah,
                    isDarkMode: themeManager.isDarkMode,
                    isCurrentTrack: surah.id == audioManager.selectedTrack?.id,
                    onTrackSelected: onTrackSelected
                )
                .listRowBackground(themeManager.isDarkMode ? Color.black : Color.white)
            }
            .listStyle(.plain)
            .background(themeManager.isDarkMode ? Color.black : Color.white)
            .navigationTitle("Suren Auswahl")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Schließen") {
                        isShowing = false
                    }
                    .foregroundColor(themeManager.isDarkMode ? .white : .blue)
                }
            }
        }
        .accentColor(themeManager.isDarkMode ? .white : .blue)
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
                        .foregroundColor(isDarkMode ? .white : .primary)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Text(surah.englishName)
                        .font(.caption)
                        .foregroundColor(isDarkMode ? .gray : .secondary)
                }
                Spacer()
                if isCurrentTrack {
                    Image(systemName: "music.note")
                        .font(.title2)
                        .foregroundColor(isDarkMode ? .white : .blue)
                }
            }
            .padding(.vertical, 5)
        }
    }
}
