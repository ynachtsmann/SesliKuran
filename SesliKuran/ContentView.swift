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
    
    // MARK: - Layout Management
    // Centralized Layout Manager for Device-Specific Constants
    private let layoutManager = DeviceLayoutManager.shared

    // MARK: - Body
    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            // Use Manager's adaptive scale
            let scale = layoutManager.adaptiveScale(in: geometry.size)
            let config = layoutManager.config

            // Calculate Safe Container Padding (Safe Area + Margins)
            let containerPadding = layoutManager.safeContainerPadding(for: geometry, isLandscape: isLandscape)

            ZStack {
                // Layer 1: Living Background (Edges Ignored)
                AuroraBackgroundView(isDarkMode: themeManager.isDarkMode)
                    .edgesIgnoringSafeArea(.all)

                // Layer 2: Main Content Container (Strictly Windowed)
                // We do NOT use edgesIgnoringSafeArea here.
                // We apply explicit padding to create the "Safe Window".
                ZStack {
                    if isLandscape {
                        // LANDSCAPE LAYOUT (Split View)
                        HStack(spacing: 0) {
                            // Left Side: Art (Centered vertically)
                            ZStack {
                                nowPlayingSection(geometry: geometry, isLandscape: true, scale: scale)
                            }
                            // Use Split Ratio from Config
                            .frame(width: (geometry.size.width - containerPadding.leading - containerPadding.trailing) * config.splitViewRatio)
                            .frame(maxHeight: .infinity)

                            // Right Side: Controls & Info
                            VStack(spacing: config.controlSpacing * scale) {
                                // Header inside the right pane for better ergonomics
                                headerSection(scale: scale)

                                Spacer()

                                trackInfoSection(scale: scale)

                                timeSliderView(scale: scale)
                                    .padding(.horizontal)

                                controlSection(scale: scale, geometry: geometry)

                                Spacer()
                            }
                            // Remaining width for controls
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    } else {
                        // PORTRAIT LAYOUT (Original VStack)
                        VStack(spacing: config.controlSpacing * scale) {
                            headerSection(scale: scale)
                            Spacer()

                            nowPlayingSection(geometry: geometry, isLandscape: false, scale: scale)

                            trackInfoSection(scale: scale)

                            timeSliderView(scale: scale)
                                .padding(.horizontal)

                            controlSection(scale: scale, geometry: geometry)
                            Spacer()
                        }
                    }
                }
                .padding(containerPadding) // Apply the strict "Window" padding
                .frame(width: geometry.size.width, height: geometry.size.height) // Match Geometry Size

                // Layer 3: Audio List Overlay (True Floating Cards)
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
                            // The List View itself
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
                            // Constrain height to avoid taking over full screen on iPad
                            .frame(height: isLandscape ? geometry.size.height * 0.8 : geometry.size.height * 0.75)
                            .frame(maxWidth: isLandscape ? 600 : .infinity) // Limit width on iPad/Landscape
                            .background(
                                RoundedRectangle(cornerRadius: 24)
                                    .fill(themeManager.isDarkMode ? Color.black.opacity(0.8) : Color.white.opacity(0.95))
                                    .shadow(radius: 20)
                            )
                            // Ensure it respects the container padding too, so it doesn't hit edges
                            .padding(.bottom, containerPadding.bottom)
                            .padding(.horizontal, isLandscape ? 0 : containerPadding.leading)
                        }
                    }
                    .zIndex(2)
                    .transition(.move(edge: .bottom))
                }

                // Layer 4: Loading Overlay
                if audioManager.isLoading {
                    LoadingView()
                        .environmentObject(themeManager)
                        .transition(.opacity)
                        .zIndex(3)
                }
            }
            .alert(isPresented: $audioManager.showError) {
                Alert(
                    title: Text("Fehler"),
                    message: Text(audioManager.errorMessage ?? "Unbekannter Fehler"),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
        .edgesIgnoringSafeArea(.all) // Ensure GeometryReader covers the full screen (Edge-to-Edge)
    }
    
    // MARK: - Header Section
    private func headerSection(scale: CGFloat) -> some View {
        HStack {
            GlassyButton(
                iconName: "music.note.list",
                action: {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        showSlotSelection.toggle()
                    }
                },
                size: 20 * scale,
                padding: 12 * scale,
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
                size: 20 * scale,
                padding: 12 * scale,
                isDarkMode: themeManager.isDarkMode
            )
            .accessibilityLabel(themeManager.isDarkMode ? "In den hellen Modus wechseln" : "In den dunklen Modus wechseln")
        }
    }
    
    // MARK: - Now Playing Section (Art)
    private func nowPlayingSection(geometry: GeometryProxy, isLandscape: Bool, scale: CGFloat) -> some View {
        // Dynamic Sizing logic via Manager
        let config = layoutManager.config

        // Calculate available space in the container (roughly)
        let dimension = min(geometry.size.width, geometry.size.height)
        let scaleFactor = isLandscape ? config.artScaleFactor * 0.8 : config.artScaleFactor // Slightly smaller in split view
        let size = dimension * scaleFactor

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
                            lineWidth: 2 * scale
                        )
                )
                .shadow(
                    color: ThemeColors.primaryColor(isDarkMode: themeManager.isDarkMode).opacity(0.3),
                    radius: 20 * scale, x: 0, y: 0
                )

            if let selectedTrack = audioManager.selectedTrack {
                VStack(spacing: 5 * scale) {
                    Text("\(selectedTrack.id)")
                        .font(.system(size: size * 0.3, weight: .thin, design: .rounded))
                        .foregroundStyle(themeManager.isDarkMode ? .white : .black.opacity(0.8))
                        .shadow(color: themeManager.isDarkMode ? .white.opacity(0.8) : .clear, radius: 10 * scale)

                    Text("SURAH")
                        .font(.system(size: size * 0.05, weight: .bold, design: .monospaced))
                        .tracking(5 * scale)
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
    }

    // MARK: - Track Info Section
    private func trackInfoSection(scale: CGFloat) -> some View {
        // Defensive Coding: Handle nil selectedTrack gracefully
        Group {
            if let selectedTrack = audioManager.selectedTrack {
                VStack(spacing: 8 * scale) {
                    Text("\(selectedTrack.name) - \(selectedTrack.germanName)")
                        .font(.system(size: 22 * scale, weight: .bold)) // Replaces .title2
                        .foregroundStyle(themeManager.isDarkMode ? .white : .black.opacity(0.8))
                        .lineLimit(1)
                        .shadow(radius: themeManager.isDarkMode ? 5 : 0)
                        .minimumScaleFactor(0.8) // Allow text to shrink slightly on smaller screens

                    Text(selectedTrack.arabicName)
                        .font(.system(size: 20 * scale)) // Replaces .title3
                        .foregroundStyle(themeManager.isDarkMode ? .white.opacity(0.8) : .gray)
                }
            } else {
                // Placeholder State - Never Crash
                VStack(spacing: 8 * scale) {
                    Text("Wähle eine Surah")
                        .font(.system(size: 22 * scale, weight: .semibold)) // Replaces .title2
                        .foregroundStyle(themeManager.isDarkMode ? .white.opacity(0.8) : .gray)

                    Text("---")
                        .font(.system(size: 20 * scale)) // Replaces .title3
                        .foregroundStyle(themeManager.isDarkMode ? .white.opacity(0.5) : .gray.opacity(0.5))
                }
            }
        }
    }
    
    // MARK: - Time Slider
    private func timeSliderView(scale: CGFloat) -> some View {
        VStack(spacing: 4 * scale) {
            NeumorphicSlider(
                value: $audioManager.currentTime,
                inRange: 0...max(audioManager.duration, 0.01), // Prevent 0 range
                onEditingChanged: { _ in
                    audioManager.seek(to: audioManager.currentTime)
                },
                isDarkMode: themeManager.isDarkMode
            )
            
            // Time Labels below the ends
            HStack {
                Text(timeString(time: audioManager.currentTime))
                    .monospacedDigit()
                Spacer()
                Text(timeString(time: audioManager.duration))
                    .monospacedDigit()
            }
            .font(.system(size: 11 * scale, weight: .medium)) // Slightly smaller font
            .foregroundStyle(themeManager.isDarkMode ? .white.opacity(0.6) : .gray)
        }
    }
    
    // MARK: - Control Section
    private func controlSection(scale: CGFloat, geometry: GeometryProxy) -> some View {
        // Dynamic Spacing based on screen width
        let dynamicSpacing = geometry.size.width * 0.1 // 10% of screen width

        return HStack(spacing: dynamicSpacing) {
            Button(action: {
                audioManager.previousTrack()
            }) {
                Image(systemName: "backward.end.fill")
                    .font(.system(size: 22 * scale)) // Replaces .title2
                    .foregroundStyle(ThemeColors.buttonForeground(isDarkMode: themeManager.isDarkMode))
            }
            .accessibilityLabel("Vorherige Surah")
            
            GlassyControlButton(
                iconName: audioManager.isPlaying ? "pause.fill" : "play.fill",
                action: { audioManager.togglePlayPause() },
                size: 35 * scale,
                isDarkMode: themeManager.isDarkMode
            )
            .accessibilityLabel(audioManager.isPlaying ? "Pause" : "Wiedergabe")
            
            Button(action: {
                audioManager.nextTrack()
            }) {
                Image(systemName: "forward.end.fill")
                    .font(.system(size: 22 * scale)) // Replaces .title2
                    .foregroundStyle(ThemeColors.buttonForeground(isDarkMode: themeManager.isDarkMode))
            }
            .accessibilityLabel("Nächste Surah")
        }
        .padding(.vertical, 20 * scale)
        .padding(.horizontal, 40 * scale)
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
            .environmentObject(AudioManager())
            .environmentObject(ThemeManager())
    }
}
#endif
