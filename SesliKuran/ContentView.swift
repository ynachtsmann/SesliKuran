// MARK: - Imports
import SwiftUI
import UIKit // Added for UIVisualEffectView support
import AVFoundation

// MARK: - Main View
struct ContentView: View {
    // MARK: - Properties
    @StateObject private var audioManager = AudioManager()
    @StateObject private var themeManager = ThemeManager()
    @State private var showSlotSelection = false
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            ZStack(alignment: .topLeading) {
                // Living Background - Passed Theme
                AuroraBackgroundView(isDarkMode: themeManager.isDarkMode)
                
                // Main Content
                VStack(spacing: 20) {
                    headerSection
                    Spacer()
                    nowPlayingSection
                    controlSection
                    Spacer()
                }
                .padding()
                
                // Audio List Overlay (True Floating Cards)
                if showSlotSelection {
                    ZStack {
                        // Dimmed background for focus, but clearer than before
                        Color.black.opacity(0.3)
                            .edgesIgnoringSafeArea(.all)
                            .onTapGesture {
                                withAnimation {
                                    showSlotSelection = false
                                }
                            }

                        VStack {
                            Spacer()
                            // No background container here anymore - just the list
                            AudioListView(isShowing: $showSlotSelection) { selectedTrack in
                                audioManager.selectedTrack = selectedTrack
                                // MANUAL SELECTION: Always start from 0:00 (resumePlayback: false)
                                audioManager.loadAudio(track: selectedTrack, autoPlay: true, resumePlayback: false)
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showSlotSelection = false
                                }
                            }
                            .environmentObject(audioManager)
                            .environmentObject(themeManager)
                            .frame(height: UIScreen.main.bounds.height * 0.75)
                            .transition(.move(edge: .bottom))
                        }
                        .edgesIgnoringSafeArea(.bottom)
                    }
                    .zIndex(2)
                }
                
                // Loading Overlay
                if audioManager.isLoading {
                    LoadingView()
                        .environmentObject(themeManager)
                        .transition(.opacity)
                }
            }
            .navigationBarHidden(true)
            .alert(isPresented: $audioManager.showError) {
                Alert(
                    title: Text("Fehler"),
                    message: Text(audioManager.errorMessage ?? "Unbekannter Fehler"),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        HStack {
            GlassyButton(
                iconName: "music.note.list",
                action: {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        showSlotSelection.toggle()
                    }
                },
                isDarkMode: themeManager.isDarkMode
            )
            .accessibilityLabel("Liste anzeigen")
            .accessibilityHint("Zeigt die Liste aller Surahs an.")
            
            Spacer()
            
            // Functional Theme Toggle
            GlassyButton(
                iconName: themeManager.isDarkMode ? "moon.stars.fill" : "sun.max.fill",
                action: {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        themeManager.isDarkMode.toggle()
                    }
                },
                isDarkMode: themeManager.isDarkMode
            )
            .accessibilityLabel(themeManager.isDarkMode ? "In den hellen Modus wechseln" : "In den dunklen Modus wechseln")
        }
    }
    
    // MARK: - Now Playing Section
    private var nowPlayingSection: some View {
        VStack(spacing: 25) {
            // Cover Art / Futuristic Typography
            ZStack {
                Circle()
                    .fill(themeManager.isDarkMode ? Color.white.opacity(0.05) : Color.white.opacity(0.3))
                    .frame(width: 280, height: 280)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: themeManager.isDarkMode ? [.cyan.opacity(0.5), .purple.opacity(0.5)] : [.orange.opacity(0.4), .pink.opacity(0.4)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                    .shadow(
                        color: themeManager.isDarkMode ? .cyan.opacity(0.3) : .orange.opacity(0.2),
                        radius: 20, x: 0, y: 0
                    )

                if let selectedTrack = audioManager.selectedTrack {
                    VStack(spacing: 5) {
                        Text("\(selectedTrack.id)")
                            .font(.system(size: 80, weight: .thin, design: .rounded))
                            .foregroundColor(themeManager.isDarkMode ? .white : .black.opacity(0.8))
                            .shadow(color: themeManager.isDarkMode ? .white.opacity(0.8) : .clear, radius: 10)

                        Text("SURAH")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .tracking(5)
                            .foregroundColor(themeManager.isDarkMode ? .white.opacity(0.7) : .gray)
                    }
                } else {
                    Image(systemName: "music.quarternote.3")
                        .font(.system(size: 80))
                        .foregroundColor(themeManager.isDarkMode ? .white.opacity(0.5) : .gray.opacity(0.5))
                }
            }
            .padding(.bottom, 20)
            
            // Text Info
            // Defensive Coding: Handle nil selectedTrack gracefully
            if let selectedTrack = audioManager.selectedTrack {
                VStack(spacing: 8) {
                    Text("\(selectedTrack.name) - \(selectedTrack.germanName)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(themeManager.isDarkMode ? .white : .black.opacity(0.8))
                        .lineLimit(1)
                        .shadow(radius: themeManager.isDarkMode ? 5 : 0)

                    Text(selectedTrack.arabicName)
                        .font(.title3)
                        .foregroundColor(themeManager.isDarkMode ? .white.opacity(0.8) : .gray)
                }
            } else {
                // Placeholder State - Never Crash
                VStack(spacing: 8) {
                    Text("Wähle eine Surah")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(themeManager.isDarkMode ? .white.opacity(0.8) : .gray)

                    Text("---")
                        .font(.title3)
                        .foregroundColor(themeManager.isDarkMode ? .white.opacity(0.5) : .gray.opacity(0.5))
                }
            }
            
            // Slider
            timeSliderView
                .padding(.top, 10)
        }
    }
    
    // MARK: - Time Slider
    private var timeSliderView: some View {
        VStack(spacing: 8) {
            NeumorphicSlider(
                value: $audioManager.currentTime,
                inRange: 0...max(audioManager.duration, 0.01), // Prevent 0 range
                onEditingChanged: { _ in
                    audioManager.seek(to: audioManager.currentTime)
                },
                isDarkMode: themeManager.isDarkMode
            )
            .padding(.horizontal)
            
            HStack {
                Text(timeString(time: audioManager.currentTime))
                Spacer()
                Text(timeString(time: audioManager.duration))
            }
            .font(.caption)
            .foregroundColor(themeManager.isDarkMode ? .white.opacity(0.6) : .gray)
            .padding(.horizontal)
        }
    }
    
    // MARK: - Control Section
    private var controlSection: some View {
        HStack(spacing: 40) {
            Button(action: {
                audioManager.previousTrack()
            }) {
                Image(systemName: "backward.end.fill")
                    .font(.title2)
                    .foregroundColor(themeManager.isDarkMode ? .white : .black.opacity(0.7))
            }
            .accessibilityLabel("Vorherige Surah")
            
            GlassyControlButton(
                iconName: audioManager.isPlaying ? "pause.fill" : "play.fill",
                action: { audioManager.togglePlayPause() }, // FIX: renamed playPause to togglePlayPause
                size: 35,
                isDarkMode: themeManager.isDarkMode
            )
            .accessibilityLabel(audioManager.isPlaying ? "Pause" : "Wiedergabe")
            
            Button(action: {
                audioManager.nextTrack()
            }) {
                Image(systemName: "forward.end.fill")
                    .font(.title2)
                    .foregroundColor(themeManager.isDarkMode ? .white : .black.opacity(0.7))
            }
            .accessibilityLabel("Nächste Surah")
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 40)
        .background(
            Capsule()
                .fill(themeManager.isDarkMode ? Color.white.opacity(0.05) : Color.white.opacity(0.5))
                .overlay(
                    Capsule()
                        .stroke(themeManager.isDarkMode ? Color.white.opacity(0.1) : Color.white.opacity(0.4), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Helper Methods
    private func timeString(time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// Helper for Blur
struct VisualEffectView: UIViewRepresentable {
    var effect: UIVisualEffect?
    func makeUIView(context: UIViewRepresentableContext<Self>) -> UIVisualEffectView { UIVisualEffectView() }
    func updateUIView(_ uiView: UIVisualEffectView, context: UIViewRepresentableContext<Self>) { uiView.effect = effect }
}

// MARK: - Preview
#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif
