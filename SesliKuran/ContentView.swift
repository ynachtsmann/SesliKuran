// MARK: - Imports
import SwiftUI
import UIKit // Added for UIVisualEffectView support (though now in separate file, kept for safety if used elsewhere or implicitly)
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
        // Outer GeometryReader primarily for screen size
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            // Use Manager's adaptive scale
            let scale = layoutManager.adaptiveScale(in: geometry.size)
            let config = layoutManager.config

            // Calculate Safe Container Padding (Strict Mode)
            let containerPadding = layoutManager.safeContainerPadding(for: geometry, isLandscape: isLandscape)

            ZStack {
                // Layer 1: Removed Local Background (Provided by Root/MyMusicApp)
                // AuroraBackgroundView is now hosted in MyMusicApp.swift for seamless transitions.

                // Layer 2: Main Content Container (Strictly Windowed)
                // We apply explicit padding to create the "Safe Window".
                // This ZStack acts as the "Safe Area" where all controls live.
                InnerContentView(
                    showSlotSelection: $showSlotSelection,
                    isLandscape: isLandscape,
                    scale: scale,
                    geometrySize: geometry.size,
                    config: config,
                    containerPadding: containerPadding
                )
                .equatable() // Optimization: Prevent redraw if layout params don't change
                .frame(width: geometry.size.width, height: geometry.size.height) // Match Geometry Size

                // Layer 3: Audio List Overlay (True Floating Modal)
                if showSlotSelection {
                    ZStack {
                        // Dimmed background for focus
                        Color.black.opacity(0.4)
                            .edgesIgnoringSafeArea(.all)
                            .onTapGesture {
                                withAnimation {
                                    showSlotSelection = false
                                }
                            }

                        // The List Card
                        VStack {
                            // The List View itself
                            AudioListView(isShowing: $showSlotSelection) { selectedTrack in
                                audioManager.selectedTrack = selectedTrack
                                // MANUAL SELECTION: Always start from 0:00 (resumePlayback: false)
                                audioManager.loadAudio(track: selectedTrack, autoPlay: true)
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showSlotSelection = false
                                }
                            }
                            .environmentObject(audioManager)
                            .environmentObject(themeManager)
                        }
                        // 80% Requirement: Force size relative to screen
                        .frame(
                            width: geometry.size.width * 0.8,
                            height: geometry.size.height * 0.8
                        )
                        .background(Color.clear)
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                    }
                    .zIndex(2)
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
}

// MARK: - Inner Content View (Optimization)
// This view extracts the layout logic so it can be Equatable.
// It DOES NOT observe AudioManager directly, so it won't redraw on every time tick.
// The child views (like PlayerControlsView) will observe AudioManager independently.
struct InnerContentView: View, Equatable {
    @Binding var showSlotSelection: Bool
    let isLandscape: Bool
    let scale: CGFloat
    let geometrySize: CGSize
    let config: LayoutConfig
    let containerPadding: EdgeInsets

    // Equatable Conformance
    static func == (lhs: InnerContentView, rhs: InnerContentView) -> Bool {
        return lhs.isLandscape == rhs.isLandscape &&
               lhs.scale == rhs.scale &&
               lhs.geometrySize == rhs.geometrySize &&
               lhs.config == rhs.config &&
               lhs.containerPadding == rhs.containerPadding &&
               lhs.showSlotSelection == rhs.showSlotSelection
    }

    var body: some View {
        ZStack(alignment: .top) {
            if isLandscape {
                // LANDSCAPE LAYOUT (Split View)
                // Using a GeometryReader here to strictly enforce the split ratio
                GeometryReader { innerGeo in
                    HStack(spacing: 0) {
                        // Left Side: Art (Centered vertically)
                        ZStack {
                            // Context-Aware Sizing: Use the SPLIT container size, not global screen
                            let containerWidth = innerGeo.size.width * config.splitViewRatio
                            let containerHeight = innerGeo.size.height
                            let dimension = min(containerWidth, containerHeight)

                            // Adjust scale factor for split view context
                            let scaleFactor = config.artScaleFactor * 0.9
                            let artSize = dimension * scaleFactor

                            NowPlayingView(size: artSize, scale: scale)
                        }
                        .frame(width: innerGeo.size.width * config.splitViewRatio)
                        .frame(maxHeight: .infinity)

                        // Right Side: Controls & Info
                        let rightPaneWidth = innerGeo.size.width * (1 - config.splitViewRatio)

                        // Context-Aware Scaling for Controls
                        // In landscape, height is the constraint. Adjust scale if needed.
                        // Relaxed constraint (340.0) and allowed slight boost (scale * 1.1) to fill taller container.
                        let landscapeControlScale = min(scale * 1.1, innerGeo.size.height / 340.0)

                        VStack(spacing: (config.controlSpacing * 0.8) * landscapeControlScale) {
                            Spacer()

                            TrackInfoView(scale: landscapeControlScale)

                            // Unified Player Controls (Slider + Buttons)
                            PlayerControlsView(scale: landscapeControlScale, availableWidth: rightPaneWidth)
                                .equatable() // Optimization

                            Spacer()
                        }
                        .frame(width: rightPaneWidth)
                        .frame(maxHeight: .infinity)
                    }
                }
            } else {
                // PORTRAIT LAYOUT (Original VStack)
                VStack(spacing: config.controlSpacing * scale) {
                    // Spacer to clear the floating Header
                    // Header is roughly 44pt + padding.
                    Spacer().frame(height: 50 * scale)

                    Spacer()

                    // Calculate Art Size for Portrait
                    let dimension = min(geometrySize.width, geometrySize.height)
                    let scaleFactor = config.artScaleFactor
                    let artSize = dimension * scaleFactor

                    NowPlayingView(size: artSize, scale: scale)

                    TrackInfoView(scale: scale)

                    // Unified Player Controls (Slider + Buttons)
                    PlayerControlsView(scale: scale, availableWidth: geometrySize.width)
                        .equatable() // Optimization

                    Spacer()
                }
            }

            // MARK: - Global Floating Header
            // Placed in ZStack to stay pinned to top, independent of content layout
            HeaderView(showSlotSelection: $showSlotSelection, scale: scale)
                .frame(maxWidth: .infinity)
                // FIX: Add extra safety margin in Portrait to prevent icons from sticking to the edges
                .padding(.horizontal, isLandscape ? 0 : 20)
        }
        .padding(containerPadding)
    }
}

// MARK: - Preview
#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            // Mock the global background for the preview
            AuroraBackgroundView(isDarkMode: true)
                .edgesIgnoringSafeArea(.all)

            ContentView()
                .environmentObject(AudioManager())
                .environmentObject(ThemeManager())
        }
    }
}
#endif
