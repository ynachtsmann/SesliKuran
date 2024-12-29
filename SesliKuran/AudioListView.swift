// MARK: - Imports
import SwiftUI

struct AudioListView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var audioManager: AudioManager
    @Binding var isShowing: Bool
    let onTrackSelected: (String) -> Void
    private let audioTracks = (1...115).map { "Audio \($0)" }
    
    @State private var loadedTracks: Int = 10
    @State private var isLoading = false
    
    var body: some View {
        VStack {
            VStack(spacing: 10) {
                HStack {
                    Spacer()
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isShowing = false
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(themeManager.isDarkMode ? .white : .gray)
                            .padding()
                    }
                }
            }
            
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(audioTracks.prefix(loadedTracks), id: \.self) { track in
                        AudioTrackRow(
                            track: track,
                            isDarkMode: themeManager.isDarkMode,
                            isCurrentTrack: track == audioManager.selectedTrack,
                            onTrackSelected: onTrackSelected
                        )
                    }
                    
                    if loadedTracks < audioTracks.count {
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
        .background(themeManager.isDarkMode ? Color.black : Color.white)
        .edgesIgnoringSafeArea(.bottom)
    }
    
    private func loadMoreTracks() {
        guard !isLoading else { return }
        
        isLoading = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation {
                loadedTracks = min(loadedTracks + 5, audioTracks.count)
                isLoading = false
            }
        }
    }
}

struct AudioTrackRow: View {
    let track: String
    let isDarkMode: Bool
    let isCurrentTrack: Bool
    let onTrackSelected: (String) -> Void
    
    var body: some View {
        Button(action: {
            onTrackSelected(track)
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(track)
                        .foregroundColor(isDarkMode ? .white : .primary)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Text("Kapitel \(track.replacingOccurrences(of: "Audio ", with: ""))")
                        .font(.caption)
                        .foregroundColor(isDarkMode ? .gray : .secondary)
                }
                Spacer()
                Image(systemName: isCurrentTrack ? "pause.circle.fill" : "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(isDarkMode ? .white : .blue)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isCurrentTrack ?
                          (isDarkMode ? Color.blue.opacity(0.3) : Color.blue.opacity(0.2)) :
                          (isDarkMode ? Color.gray.opacity(0.2) : Color.blue.opacity(0.1)))
            )
        }
    }
}
