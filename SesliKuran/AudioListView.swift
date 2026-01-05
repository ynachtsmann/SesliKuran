// MARK: - Imports
import SwiftUI

struct AudioListView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var audioManager: AudioManager
    @Binding var isShowing: Bool
    let onTrackSelected: (Surah) -> Void
    
    @State private var searchText = ""
    @State private var loadedTracks: Int = 20
    @State private var isLoading = false
    
    private var filteredSurahs: [Surah] {
        if searchText.isEmpty {
            return SurahData.allSurahs
        } else {
            return SurahData.allSurahs.filter { surah in
                let searchContent = "\(surah.id) \(surah.name) \(surah.germanName) \(surah.arabicName)"
                return searchContent.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                // Background matching the theme roughly or just clear
                (themeManager.isDarkMode ? Color(red: 0.1, green: 0.1, blue: 0.12) : Color.white)
                    .edgesIgnoringSafeArea(.all)

                VStack(spacing: 0) {
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField("Suche (z.B. 'Yasin' oder '36')", text: $searchText)
                            .foregroundColor(themeManager.isDarkMode ? .white : .black)

                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(10)
                    .background(themeManager.isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                    .cornerRadius(12)
                    .padding()
                    
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            // Favorites Section
                            if searchText.isEmpty && !audioManager.favorites.isEmpty {
                                HStack {
                                    Text("Favoriten")
                                        .font(.headline)
                                        .foregroundColor(themeManager.isDarkMode ? .gray : .gray)
                                        .padding(.horizontal)
                                    Spacer()
                                }
                                .padding(.top, 10)

                                ForEach(SurahData.allSurahs.filter { audioManager.favorites.contains($0.id) }) { surah in
                                    GlassyCardRow(
                                        surah: surah,
                                        isCurrentTrack: surah.id == audioManager.selectedTrack?.id,
                                        isFavorite: true,
                                        isDarkMode: themeManager.isDarkMode,
                                        onTrackSelected: onTrackSelected,
                                        onToggleFavorite: { audioManager.toggleFavorite(surahId: surah.id) }
                                    )
                                }

                                Divider()
                                    .background(themeManager.isDarkMode ? Color.white.opacity(0.2) : Color.black.opacity(0.1))
                                    .padding(.vertical)
                            }

                            // All Surahs List
                            if searchText.isEmpty {
                                HStack {
                                    Text("Alle Suren")
                                        .font(.headline)
                                        .foregroundColor(themeManager.isDarkMode ? .gray : .gray)
                                        .padding(.horizontal)
                                    Spacer()
                                }
                            }

                            ForEach(filteredSurahs.prefix(searchText.isEmpty ? loadedTracks : filteredSurahs.count)) { surah in
                                GlassyCardRow(
                                    surah: surah,
                                    isCurrentTrack: surah.id == audioManager.selectedTrack?.id,
                                    isFavorite: audioManager.favorites.contains(surah.id),
                                    isDarkMode: themeManager.isDarkMode,
                                    onTrackSelected: onTrackSelected,
                                    onToggleFavorite: { audioManager.toggleFavorite(surahId: surah.id) }
                                )
                            }

                            // Load More (only if not searching)
                            if searchText.isEmpty && loadedTracks < SurahData.allSurahs.count {
                                Button(action: loadMoreTracks) {
                                    if isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: themeManager.isDarkMode ? .white : .gray))
                                            .padding()
                                    } else {
                                        Text("Mehr laden")
                                            .font(.subheadline)
                                            .foregroundColor(themeManager.isDarkMode ? .white.opacity(0.6) : .blue.opacity(0.8))
                                            .padding()
                                    }
                                }
                            }

                            // Spacer for bottom safe area
                            Spacer().frame(height: 50)
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Surah Auswahl")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Schließen") {
                        isShowing = false
                    }
                    .foregroundColor(themeManager.isDarkMode ? .white : .blue)
                }
            }
        }
    }
    
    private func loadMoreTracks() {
        guard !isLoading else { return }
        
        isLoading = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            loadedTracks = min(loadedTracks + 20, SurahData.allSurahs.count)
            isLoading = false
        }
    }
}

// Updated Card Row with Favorite Button
struct GlassyCardRow: View {
    let surah: Surah
    let isCurrentTrack: Bool
    let isFavorite: Bool
    let isDarkMode: Bool
    let onTrackSelected: (Surah) -> Void
    let onToggleFavorite: () -> Void
    
    var body: some View {
        HStack {
            // Play Selection Area
            Button(action: { onTrackSelected(surah) }) {
                HStack {
                    // Number Badge
                    ZStack {
                        Circle()
                            .fill(
                                isCurrentTrack ?
                                (isDarkMode ? Color.cyan.opacity(0.3) : Color.orange.opacity(0.3)) :
                                (isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                            )
                            .frame(width: 44, height: 44)

                        Text("\(surah.id)")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(isDarkMode ? .white : .black.opacity(0.8))
                    }

                    // Text Info
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(surah.name) - \(surah.germanName)")
                            .foregroundColor(isDarkMode ? .white : .black.opacity(0.9))
                            .font(.headline)
                            .lineLimit(1)

                        Text(surah.arabicName)
                            .font(.caption)
                            .foregroundColor(isDarkMode ? .white.opacity(0.6) : .gray)
                    }
                    .padding(.leading, 8)
                }
            }
            .buttonStyle(PlainButtonStyle()) // Important for nested buttons

            Spacer()

            // Actions Area
            HStack(spacing: 15) {
                // Favorite Button
                Button(action: onToggleFavorite) {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .foregroundColor(isFavorite ? .red : (isDarkMode ? .white.opacity(0.3) : .gray.opacity(0.4)))
                        .font(.system(size: 20))
                }
                .buttonStyle(PlainButtonStyle())

                // Playing Indicator
                if isCurrentTrack {
                    Image(systemName: "waveform")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(isDarkMode ? .cyan : .orange)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isDarkMode ? Color.white.opacity(0.05) : Color.white)
                .shadow(color: Color.black.opacity(isDarkMode ? 0 : 0.05), radius: 5, x: 0, y: 2)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isCurrentTrack ? (isDarkMode ? Color.cyan.opacity(0.5) : Color.orange.opacity(0.5)) : Color.clear,
                            lineWidth: 1
                        )
                )
        )
    }
}
