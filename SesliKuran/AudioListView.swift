// MARK: - Imports
import SwiftUI

struct AudioListView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var audioManager: AudioManager
    @Binding var isShowing: Bool
    let onTrackSelected: (Surah) -> Void
    private let allSurahs = SurahData.allSurahs
    
    @State private var searchText = ""
    @AppStorage("Favorites") private var favoritesData: Data = Data()
    @State private var showFavoritesOnly = false

    var favorites: Set<Int> {
        get {
            (try? JSONDecoder().decode(Set<Int>.self, from: favoritesData)) ?? []
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                favoritesData = data
            }
        }
    }

    var filteredSurahs: [Surah] {
        var surahs = allSurahs

        if showFavoritesOnly {
            surahs = surahs.filter { favorites.contains($0.id) }
        }

        if !searchText.isEmpty {
            surahs = surahs.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.englishName.localizedCaseInsensitiveContains(searchText) ||
                "\($0.id)".contains(searchText)
            }
        }

        return surahs
    }
    
    var body: some View {
        NavigationView {
            VStack {
                Picker("Filter", selection: $showFavoritesOnly) {
                    Text("Alle").tag(false)
                    Text("Favoriten").tag(true)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()

                if filteredSurahs.isEmpty {
                    VStack(spacing: 20) {
                        Spacer()
                        Image(systemName: showFavoritesOnly ? "star.slash" : "magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text(showFavoritesOnly ? "Keine Favoriten" : "Keine Ergebnisse")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    ScrollViewReader { proxy in
                        List {
                            ForEach(filteredSurahs) { surah in
                                AudioTrackRow(
                                    surah: surah,
                                    isCurrentTrack: surah.id == audioManager.selectedTrack?.id,
                                    isFavorite: favorites.contains(surah.id),
                                    onTrackSelected: onTrackSelected,
                                    onToggleFavorite: {
                                        toggleFavorite(id: surah.id)
                                    }
                                )
                                .id(surah.id)
                            }
                        }
                        .listStyle(PlainListStyle())
                        .onAppear {
                            if let selectedId = audioManager.selectedTrack?.id {
                                proxy.scrollTo(selectedId, anchor: .center)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Surah Auswahl")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Suchen...")
            .background(Color(UIColor.systemBackground))
        }
    }
    
    private func toggleFavorite(id: Int) {
        var current = favorites
        if current.contains(id) {
            current.remove(id)
        } else {
            current.insert(id)
        }
        favorites = current
    }
}

struct AudioTrackRow: View {
    let surah: Surah
    let isCurrentTrack: Bool
    let isFavorite: Bool
    let onTrackSelected: (Surah) -> Void
    let onToggleFavorite: () -> Void
    
    var body: some View {
        HStack {
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
                }
            }
            .buttonStyle(PlainButtonStyle())

            Spacer()

            Button(action: onToggleFavorite) {
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .font(.title2)
                    .foregroundColor(isFavorite ? .yellow : .gray)
                    .padding(10)
                    .contentShape(Rectangle()) // Increase hit area
            }
            .buttonStyle(PlainButtonStyle())

            if isCurrentTrack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.accentColor)
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }
}
