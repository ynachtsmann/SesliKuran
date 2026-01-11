// MARK: - Imports
import SwiftUI
import UIKit // Added for UIVisualEffectView support
import AVFoundation

// MARK: - Main View
struct ContentView: View {
    // MARK: - Properties
    @EnvironmentObject var audioManager: AudioManager
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var showSlotSelection = false
    
    // MARK: - Body
    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height

            NavigationView {
                ZStack(alignment: .topLeading) {
                    // Living Background - Passed Theme
                    AuroraBackgroundView(isDarkMode: themeManager.isDarkMode)
                        .edgesIgnoringSafeArea(.all)

                    // Main Content Container
                    Group {
                        if isLandscape {
                            // LANDSCAPE LAYOUT (Split View)
                            HStack(spacing: 0) {
                                // Left Side: Art (Centered vertically)
                                ZStack {
                                    nowPlayingSection(geometry: geometry, isLandscape: true)
                                }
                                .frame(width: geometry.size.width * 0.45, height: geometry.size.height)

                                // Right Side: Controls & Info
                                VStack(spacing: 20) {
                                    // Header inside the right pane for better ergonomics
                                    headerSection
                                        .padding(.top, 10)

                                    Spacer()

                                    trackInfoSection

                                    timeSliderView
                                        .padding(.horizontal)

                                    controlSection

                                    Spacer()
                                }
                                .frame(width: geometry.size.width * 0.55, height: geometry.size.height)
                                .padding(.trailing, geometry.safeAreaInsets.trailing > 0 ? geometry.safeAreaInsets.trailing : 20)
                                .padding(.leading, 10)
                            }
                        } else {
                            // PORTRAIT LAYOUT (Original VStack)
                            VStack(spacing: 20) {
                                headerSection
                                Spacer()

                                nowPlayingSection(geometry: geometry, isLandscape: false)

                                trackInfoSection

                                timeSliderView
                                    .padding(.horizontal)

                                controlSection
                                Spacer()
                            }
                            .padding()
                            // Safe Area Handling for iPad/iPhone
                            .padding(.top, geometry.safeAreaInsets.top)
                            .padding(.bottom, geometry.safeAreaInsets.bottom > 0 ? 0 : 20)
                        }
                    }

                    // Audio List Overlay (True Floating Cards)
                    if showSlotSelection {
                        ZStack {
                            // Dimmed background for focus
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
                                // Modern Layout: Use GeometryReader height instead of UIScreen
                                .frame(height: geometry.size.height * 0.75)
                                .transition(.move(edge: .bottom))
                            }
                            .edgesIgnoringSafeArea(.bottom)
                        }
                        .zIndex(2)
                    }

                    // Loading Overlay
                    if audioManager.isLoading {
                        LoadingView()
                            // themeManager is automatically inherited, but explicit injection is safe
                            .environmentObject(themeManager)
                            .transition(.opacity)
                    }
                }
                .toolbar(.hidden, for: .navigationBar)
                .alert(isPresented: $audioManager.showError) {
                    Alert(
                        title: Text("Fehler"),
                        message: Text(audioManager.errorMessage ?? "Unbekannter Fehler"),
                        dismissButton: .default(Text("OK"))
                    )
                }
            }
            .navigationViewStyle(StackNavigationViewStyle()) // Force stack on iPad
        }
        .edgesIgnoringSafeArea(.all) // Ensure GeometryReader covers the full screen (Edge-to-Edge)
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
    
    // MARK: - Now Playing Section (Art)
    private func nowPlayingSection(geometry: GeometryProxy, isLandscape: Bool) -> some View {
        // Dynamic Sizing logic:
        // Landscape: Constrain by height primarily (to fit in left pane)
        // Portrait: Constrain by width primarily
        let dimension = isLandscape ? geometry.size.height : geometry.size.width
        let scaleFactor = isLandscape ? 0.65 : 0.7
        let size = min(dimension * scaleFactor, 350)

        return ZStack {
            Circle()
                .fill(themeManager.isDarkMode ? Color.white.opacity(0.05) : Color.white.opacity(0.3))
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: ThemeColors.gradientColors(isDarkMode: themeManager.isDarkMode)),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(
                    color: ThemeColors.primaryColor(isDarkMode: themeManager.isDarkMode).opacity(0.3),
                    radius: 20, x: 0, y: 0
                )

            if let selectedTrack = audioManager.selectedTrack {
                VStack(spacing: 5) {
                    Text("\(selectedTrack.id)")
                        .font(.system(size: size * 0.3, weight: .thin, design: .rounded))
                        .foregroundStyle(themeManager.isDarkMode ? .white : .black.opacity(0.8))
                        .shadow(color: themeManager.isDarkMode ? .white.opacity(0.8) : .clear, radius: 10)

                    Text("SURAH")
                        .font(.system(size: size * 0.05, weight: .bold, design: .monospaced))
                        .tracking(5)
                        .foregroundStyle(themeManager.isDarkMode ? .white.opacity(0.7) : .gray)
                }
            } else {
                Image(systemName: "music.quarternote.3")
                    .font(.system(size: size * 0.3))
                    .foregroundStyle(themeManager.isDarkMode ? .white.opacity(0.5) : .gray.opacity(0.5))
            }
        }
        // Strict Aspect Ratio to prevent oval stretching
        .aspectRatio(1, contentMode: .fit)
        .padding(.bottom, isLandscape ? 0 : 20) // Remove bottom padding in landscape to center it better
    }

    // MARK: - Track Info Section
    private var trackInfoSection: some View {
        // Defensive Coding: Handle nil selectedTrack gracefully
        Group {
            if let selectedTrack = audioManager.selectedTrack {
                VStack(spacing: 8) {
                    Text("\(selectedTrack.name) - \(selectedTrack.germanName)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(themeManager.isDarkMode ? .white : .black.opacity(0.8))
                        .lineLimit(1)
                        .shadow(radius: themeManager.isDarkMode ? 5 : 0)
                        .minimumScaleFactor(0.8) // Allow text to shrink slightly on smaller screens

                    Text(selectedTrack.arabicName)
                        .font(.title3)
                        .foregroundStyle(themeManager.isDarkMode ? .white.opacity(0.8) : .gray)
                }
            } else {
                // Placeholder State - Never Crash
                VStack(spacing: 8) {
                    Text("Wähle eine Surah")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(themeManager.isDarkMode ? .white.opacity(0.8) : .gray)

                    Text("---")
                        .font(.title3)
                        .foregroundStyle(themeManager.isDarkMode ? .white.opacity(0.5) : .gray.opacity(0.5))
                }
            }
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
            // .padding(.horizontal) // Handled by parent now
            
            HStack {
                Text(timeString(time: audioManager.currentTime))
                Spacer()
                Text(timeString(time: audioManager.duration))
            }
            .font(.caption)
            .foregroundStyle(themeManager.isDarkMode ? .white.opacity(0.6) : .gray)
            // .padding(.horizontal) // Handled by parent now
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
                    .foregroundStyle(ThemeColors.buttonForeground(isDarkMode: themeManager.isDarkMode))
            }
            .accessibilityLabel("Vorherige Surah")
            
            GlassyControlButton(
                iconName: audioManager.isPlaying ? "pause.fill" : "play.fill",
                action: { audioManager.togglePlayPause() },
                size: 35,
                isDarkMode: themeManager.isDarkMode
            )
            .accessibilityLabel(audioManager.isPlaying ? "Pause" : "Wiedergabe")
            
            Button(action: {
                audioManager.nextTrack()
            }) {
                Image(systemName: "forward.end.fill")
                    .font(.title2)
                    .foregroundStyle(ThemeColors.buttonForeground(isDarkMode: themeManager.isDarkMode))
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
        // Prevent button spread on iPad
        .fixedSize(horizontal: true, vertical: false)
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
            .environmentObject(AudioManager())
            .environmentObject(ThemeManager())
    }
}
#endif
