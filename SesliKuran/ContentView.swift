// MARK: - Imports
import SwiftUI
import AVFoundation

// MARK: - Main View
struct ContentView: View {
    // MARK: - Properties
    @StateObject private var audioManager = AudioManager()
    @StateObject private var themeManager = ThemeManager()
    @State private var showSlotSelection = false
    @State private var scrollOffset: CGFloat = 0
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            ZStack(alignment: .topLeading) {
                // Hintergrundfarbe
                Group {
                    if themeManager.isDarkMode {
                        Color.black.opacity(0.9)
                    } else {
                        Color.white
                    }
                }
                .edgesIgnoringSafeArea(.all)
                
                // Main Content
                VStack(spacing: 20) {
                    headerSection
                    Spacer()
                    nowPlayingSection
                    controlSection
                    Spacer()
                }
                .padding()
                
                // Audio List mit Animation vom Button
                if showSlotSelection {
                    GeometryReader { _ in
                        VStack {
                            AudioListView(isShowing: $showSlotSelection) { selectedTrack in
                                audioManager.selectedTrack = selectedTrack
                                audioManager.loadAudio(track: selectedTrack)
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showSlotSelection = false
                                }
                            }
                            .environmentObject(audioManager)  // Diese Zeile hinzufügen
                            .environmentObject(themeManager)
                        }
                        .frame(width: UIScreen.main.bounds.width * 0.8)
                        .background(themeManager.isDarkMode ? Color.black : Color.white)
                        .cornerRadius(15)
                        .shadow(radius: 10)
                        .offset(y: 60)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.1, anchor: .topLeading).combined(with: .opacity),
                            removal: .scale(scale: 0.1, anchor: .topLeading).combined(with: .opacity)
                        ))
                    }
                }
                
                // Loading Overlay
                if audioManager.isLoading {
                    LoadingView()
                        .environmentObject(themeManager)
                        .transition(.opacity)
                }
            }
            .navigationBarHidden(true)
            .preferredColorScheme(themeManager.isDarkMode ? .dark : .light)
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        HStack {
            Button(action: {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    showSlotSelection.toggle()
                }
            }) {
                Image(systemName: "music.note.list")
                    .font(.title2)
                    .foregroundColor(themeManager.isDarkMode ? .white : .blue)
                    .padding(10)
                    .background(
                        themeManager.isDarkMode ? Color.white.opacity(0.1) : Color.blue.opacity(0.1)
                    )
                    .clipShape(Circle())
            }
            
            Spacer()
            
            // Dark Mode Toggle
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    themeManager.isDarkMode.toggle()
                }
            }) {
                Image(systemName: themeManager.isDarkMode ? "sun.max.fill" : "moon.fill")
                    .font(.title2)
                    .foregroundColor(themeManager.isDarkMode ? .white : .blue)
                    .padding(10)
                    .background(
                        themeManager.isDarkMode ? Color.white.opacity(0.1) : Color.blue.opacity(0.1)
                    )
                    .clipShape(Circle())
            }
        }
    }
    
    // MARK: - Now Playing Section
    private var nowPlayingSection: some View {
        VStack(spacing: 15) {
            RoundedRectangle(cornerRadius: 20)
                .fill(themeManager.isDarkMode ? Color.white.opacity(0.1) : Color.blue.opacity(0.1))
                .frame(width: 250, height: 250)
                .overlay(
                    Image(systemName: "music.note")
                        .font(.system(size: 80))
                        .foregroundColor(themeManager.isDarkMode ? .white : .blue)
                )
            
            if let selectedTrack = audioManager.selectedTrack {
                Text("\(selectedTrack.name) - \(selectedTrack.germanName)")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(themeManager.isDarkMode ? .white : .primary)
                    .lineLimit(1)

                Text(selectedTrack.arabicName)
                    .font(.subheadline)
                    .foregroundColor(themeManager.isDarkMode ? .gray : .secondary)
            } else {
                Text("Kein Titel ausgewählt")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(themeManager.isDarkMode ? .white : .primary)
                    .lineLimit(1)
            }
            
            timeSliderView
        }
    }
    
    // MARK: - Time Slider
    private var timeSliderView: some View {
        VStack(spacing: 8) {
            Slider(value: $audioManager.currentTime,
                   in: 0...audioManager.duration,
                   onEditingChanged: { _ in
                audioManager.seek(to: audioManager.currentTime)
            })
            .accentColor(themeManager.isDarkMode ? .white : .blue)
            
            HStack {
                Text(timeString(time: audioManager.currentTime))
                Spacer()
                Text(timeString(time: audioManager.duration))
            }
            .font(.caption)
            .foregroundColor(themeManager.isDarkMode ? .white.opacity(0.7) : .gray)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Control Section
    private var controlSection: some View {
        HStack(spacing: 40) {
            Button(action: {
                audioManager.previousTrack()
            }) {
                Image(systemName: "backward.fill")
                    .font(.title)
                    .foregroundColor(themeManager.isDarkMode ? .white : .blue)
            }
            
            Button(action: {
                audioManager.playPause()
            }) {
                Image(systemName: audioManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 65))
                    .foregroundColor(themeManager.isDarkMode ? .white : .blue)
            }
            
            Button(action: {
                audioManager.nextTrack()
            }) {
                Image(systemName: "forward.fill")
                    .font(.title)
                    .foregroundColor(themeManager.isDarkMode ? .white : .blue)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(themeManager.isDarkMode ? Color.white.opacity(0.1) : Color.blue.opacity(0.1))
                .shadow(radius: 5)
        )
    }
    
    // MARK: - Helper Methods
    private func timeString(time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Preview
#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif
