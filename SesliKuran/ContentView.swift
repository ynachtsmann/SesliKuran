// MARK: - Imports
import SwiftUI
import AVFoundation

// MARK: - Main View
struct ContentView: View {
    // MARK: - Properties
    @StateObject private var audioManager = AudioManager()
    @StateObject private var themeManager = ThemeManager()
    @State private var showSlotSelection = false
    @State private var showSleepTimerMenu = false
    @State private var scrollOffset: CGFloat = 0
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            ZStack(alignment: .topLeading) {
                // Hintergrundfarbe
                Group {
                    if themeManager.isDarkMode {
                        LinearGradient(gradient: Gradient(colors: [Color.black, Color.gray.opacity(0.3)]), startPoint: .top, endPoint: .bottom)
                    } else {
                        LinearGradient(gradient: Gradient(colors: [Color.white, Color.blue.opacity(0.1)]), startPoint: .top, endPoint: .bottom)
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
                
                // Loading Overlay
                if audioManager.isLoading {
                    LoadingView()
                        .environmentObject(themeManager)
                        .transition(.opacity)
                }
            }
            .navigationBarHidden(true)
            .preferredColorScheme(themeManager.isDarkMode ? .dark : .light)
            .sheet(isPresented: $showSlotSelection) {
                if #available(iOS 16.0, *) {
                    AudioListView(isShowing: $showSlotSelection) { selectedTrack in
                        audioManager.selectedTrack = selectedTrack
                        audioManager.loadAudio(track: selectedTrack)
                        showSlotSelection = false
                    }
                    .environmentObject(audioManager)
                    .environmentObject(themeManager)
                    .presentationDetents([.medium, .large])
                } else {
                    AudioListView(isShowing: $showSlotSelection) { selectedTrack in
                        audioManager.selectedTrack = selectedTrack
                        audioManager.loadAudio(track: selectedTrack)
                        showSlotSelection = false
                    }
                    .environmentObject(audioManager)
                    .environmentObject(themeManager)
                }
            }
            .alert(isPresented: Binding<Bool>(
                get: { audioManager.errorMessage != nil },
                set: { if !$0 { audioManager.errorMessage = nil } }
            )) {
                Alert(title: Text("Fehler"),
                      message: Text(audioManager.errorMessage ?? "Unbekannter Fehler"),
                      dismissButton: .default(Text("OK")))
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        HStack {
            Button(action: {
                showSlotSelection.toggle()
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
            
            // Sleep Timer
            Button(action: {
                showSleepTimerMenu = true
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "timer")
                        .font(.title2)
                    if let remaining = audioManager.sleepTimerTimeRemaining {
                        Text(timeString(time: remaining))
                            .font(.caption)
                            .monospacedDigit()
                    }
                }
                .foregroundColor(themeManager.isDarkMode ? .white : .blue)
                .padding(10)
                .background(
                    themeManager.isDarkMode ? Color.white.opacity(0.1) : Color.blue.opacity(0.1)
                )
                .clipShape(Capsule())
            }
            .actionSheet(isPresented: $showSleepTimerMenu) {
                ActionSheet(title: Text("Sleep Timer"), buttons: [
                    .default(Text("15 Minuten")) { audioManager.startSleepTimer(minutes: 15) },
                    .default(Text("30 Minuten")) { audioManager.startSleepTimer(minutes: 30) },
                    .default(Text("45 Minuten")) { audioManager.startSleepTimer(minutes: 45) },
                    .default(Text("60 Minuten")) { audioManager.startSleepTimer(minutes: 60) },
                    .destructive(Text("Ausschalten")) { audioManager.stopSleepTimer() },
                    .cancel()
                ])
            }

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
        VStack(spacing: 20) {
            RoundedRectangle(cornerRadius: 25)
                .fill(themeManager.isDarkMode ? Color.white.opacity(0.05) : Color.white)
                .frame(width: 280, height: 280)
                .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
                .overlay(
                    Image(systemName: "music.note")
                        .font(.system(size: 100))
                        .foregroundColor(themeManager.isDarkMode ? .white.opacity(0.8) : .blue.opacity(0.8))
                )
            
            VStack(spacing: 5) {
                if let selectedTrack = audioManager.selectedTrack {
                    Text(selectedTrack.name)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(themeManager.isDarkMode ? .white : .primary)
                        .lineLimit(1)

                    Text(selectedTrack.englishName)
                        .font(.title3)
                        .foregroundColor(themeManager.isDarkMode ? .gray : .secondary)
                } else {
                    Text("Kein Titel ausgewählt")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(themeManager.isDarkMode ? .white : .primary)
                        .lineLimit(1)
                }
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
        VStack(spacing: 30) {
            // Playback Controls
            HStack(spacing: 30) {
                // Previous Track
                Button(action: {
                    let impactMed = UIImpactFeedbackGenerator(style: .medium)
                    impactMed.impactOccurred()
                    audioManager.previousTrack()
                }) {
                    Image(systemName: "backward.end.fill")
                        .font(.title2)
                        .foregroundColor(themeManager.isDarkMode ? .gray : .secondary)
                }

                // Skip Backward 15s
                Button(action: {
                    let impactLight = UIImpactFeedbackGenerator(style: .light)
                    impactLight.impactOccurred()
                    audioManager.skipBackward()
                }) {
                    Image(systemName: "gobackward.15")
                        .font(.title)
                        .foregroundColor(themeManager.isDarkMode ? .white : .blue)
                }

                // Play/Pause
                Button(action: {
                    let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
                    impactHeavy.impactOccurred()
                    audioManager.playPause()
                }) {
                    Image(systemName: audioManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 75))
                        .foregroundColor(themeManager.isDarkMode ? .white : .blue)
                        .shadow(radius: 5)
                }

                // Skip Forward 30s
                Button(action: {
                    let impactLight = UIImpactFeedbackGenerator(style: .light)
                    impactLight.impactOccurred()
                    audioManager.skipForward()
                }) {
                    Image(systemName: "goforward.30")
                        .font(.title)
                        .foregroundColor(themeManager.isDarkMode ? .white : .blue)
                }

                // Next Track
                Button(action: {
                    let impactMed = UIImpactFeedbackGenerator(style: .medium)
                    impactMed.impactOccurred()
                    audioManager.nextTrack()
                }) {
                    Image(systemName: "forward.end.fill")
                        .font(.title2)
                        .foregroundColor(themeManager.isDarkMode ? .gray : .secondary)
                }
            }
            
            // AirPlay
            AirPlayView()
                .frame(width: 44, height: 44)
                .opacity(0.8)
        }
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
