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
                // Living Background
                AuroraBackgroundView()
                
                // Main Content
                VStack(spacing: 20) {
                    headerSection
                    Spacer()
                    nowPlayingSection
                    controlSection
                    Spacer()
                }
                .padding()
                
                // Audio List Overlay (Glass Sheet)
                if showSlotSelection {
                    ZStack {
                        // Dimmed background
                        Color.black.opacity(0.4)
                            .edgesIgnoringSafeArea(.all)
                            .onTapGesture {
                                withAnimation {
                                    showSlotSelection = false
                                }
                            }

                        VStack {
                            Spacer()
                            AudioListView(isShowing: $showSlotSelection) { selectedTrack in
                                audioManager.selectedTrack = selectedTrack
                                audioManager.loadAudio(track: selectedTrack)
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showSlotSelection = false
                                }
                            }
                            .environmentObject(audioManager)
                            .environmentObject(themeManager)
                            .frame(height: UIScreen.main.bounds.height * 0.7)
                            .background(
                                VisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
                                    .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
                            )
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
                    message: Text(audioManager.errorMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
        .preferredColorScheme(.dark) // Force Dark mode preference for this futuristic theme
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        HStack {
            GlassyButton(iconName: "music.note.list", action: {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    showSlotSelection.toggle()
                }
            })
            
            Spacer()
            
            // Reusing theme manager for legacy logic, but UI is strictly futuristic now.
            // Keeping the toggle but maybe it changes accent colors or intensity in future?
            // For now, let's keep it as a "Settings" placeholder or similar, or just Mode toggle.
            GlassyButton(iconName: themeManager.isDarkMode ? "sun.max.fill" : "moon.fill", action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    themeManager.isDarkMode.toggle()
                }
            })
        }
    }
    
    // MARK: - Now Playing Section
    private var nowPlayingSection: some View {
        VStack(spacing: 25) {
            // Cover Art / Futuristic Typography
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 280, height: 280)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [.cyan.opacity(0.5), .purple.opacity(0.5)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                    .shadow(color: .cyan.opacity(0.3), radius: 20, x: 0, y: 0)

                if let selectedTrack = audioManager.selectedTrack {
                    // Placeholder for future Image logic:
                    // Image("Surah_\(selectedTrack.id)")

                    VStack(spacing: 5) {
                        Text("\(selectedTrack.id)")
                            .font(.system(size: 80, weight: .thin, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: .white.opacity(0.8), radius: 10)

                        Text("SURAH")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .tracking(5)
                            .foregroundColor(.white.opacity(0.7))
                    }
                } else {
                    Image(systemName: "music.quarternote.3")
                        .font(.system(size: 80))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .padding(.bottom, 20)
            
            // Text Info
            if let selectedTrack = audioManager.selectedTrack {
                VStack(spacing: 8) {
                    Text("\(selectedTrack.name) - \(selectedTrack.germanName)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .shadow(radius: 5)

                    Text(selectedTrack.arabicName)
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.8))
                }
            } else {
                Text("Wähle eine Surah")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white.opacity(0.8))
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
                }
            )
            .padding(.horizontal)
            
            HStack {
                Text(timeString(time: audioManager.currentTime))
                Spacer()
                Text(timeString(time: audioManager.duration))
            }
            .font(.caption)
            .foregroundColor(.white.opacity(0.6))
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
                    .foregroundColor(.white)
            }
            
            GlassyControlButton(
                iconName: audioManager.isPlaying ? "pause.fill" : "play.fill",
                action: { audioManager.playPause() },
                size: 35
            )
            
            Button(action: {
                audioManager.nextTrack()
            }) {
                Image(systemName: "forward.end.fill")
                    .font(.title2)
                    .foregroundColor(.white)
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 40)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.05))
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
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
