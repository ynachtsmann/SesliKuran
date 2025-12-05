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
                // Background
                BackgroundView(isDarkMode: themeManager.isDarkMode)
                
                // Main Content
                VStack(spacing: 20) {
                    HeaderView(
                        themeManager: themeManager,
                        audioManager: audioManager,
                        showSlotSelection: $showSlotSelection,
                        showSleepTimerMenu: $showSleepTimerMenu
                    )
                    Spacer()
                    NowPlayingCardView(
                        themeManager: themeManager,
                        audioManager: audioManager
                    )
                    PlayerControlsView(
                        themeManager: themeManager,
                        audioManager: audioManager
                    )
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
                AudioListSheet(
                    isShowing: $showSlotSelection,
                    audioManager: audioManager,
                    themeManager: themeManager
                )
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
}

// MARK: - Subviews

struct BackgroundView: View {
    let isDarkMode: Bool

    var body: some View {
        Group {
            if isDarkMode {
                LinearGradient(gradient: Gradient(colors: [Color.black, Color.gray.opacity(0.3)]), startPoint: .top, endPoint: .bottom)
            } else {
                LinearGradient(gradient: Gradient(colors: [Color.white, Color.blue.opacity(0.1)]), startPoint: .top, endPoint: .bottom)
            }
        }
        .edgesIgnoringSafeArea(.all)
    }
}

struct HeaderView: View {
    @ObservedObject var themeManager: ThemeManager
    @ObservedObject var audioManager: AudioManager
    @Binding var showSlotSelection: Bool
    @Binding var showSleepTimerMenu: Bool
    
    var body: some View {
        HStack {
            Button(action: { showSlotSelection.toggle() }) {
                Image(systemName: "music.note.list")
                    .font(.title2)
                    .foregroundColor(themeManager.isDarkMode ? .white : .blue)
                    .padding(10)
                    .background(themeManager.isDarkMode ? Color.white.opacity(0.1) : Color.blue.opacity(0.1))
                    .clipShape(Circle())
            }
            
            Spacer()
            
            Button(action: { showSleepTimerMenu = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "timer")
                        .font(.title2)
                    if let remaining = audioManager.sleepTimerTimeRemaining {
                        Text(formatTime(remaining))
                            .font(.caption)
                            .monospacedDigit()
                    }
                }
                .foregroundColor(themeManager.isDarkMode ? .white : .blue)
                .padding(10)
                .background(themeManager.isDarkMode ? Color.white.opacity(0.1) : Color.blue.opacity(0.1))
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

            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    themeManager.isDarkMode.toggle()
                }
            }) {
                Image(systemName: themeManager.isDarkMode ? "sun.max.fill" : "moon.fill")
                    .font(.title2)
                    .foregroundColor(themeManager.isDarkMode ? .white : .blue)
                    .padding(10)
                    .background(themeManager.isDarkMode ? Color.white.opacity(0.1) : Color.blue.opacity(0.1))
                    .clipShape(Circle())
            }
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct NowPlayingCardView: View {
    @ObservedObject var themeManager: ThemeManager
    @ObservedObject var audioManager: AudioManager

    var body: some View {
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
            
            TimeSliderView(themeManager: themeManager, audioManager: audioManager)
        }
    }
}

struct TimeSliderView: View {
    @ObservedObject var themeManager: ThemeManager
    @ObservedObject var audioManager: AudioManager
    
    var body: some View {
        VStack(spacing: 8) {
            Slider(value: $audioManager.currentTime, in: 0...audioManager.duration) { editing in
                if !editing {
                    audioManager.seek(to: audioManager.currentTime)
                }
            }
            .accentColor(themeManager.isDarkMode ? .white : .blue)
            
            HStack {
                Text(formatTime(audioManager.currentTime))
                Spacer()
                Text(formatTime(audioManager.duration))
            }
            .font(.caption)
            .foregroundColor(themeManager.isDarkMode ? .white.opacity(0.7) : .gray)
        }
        .padding(.horizontal)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct PlayerControlsView: View {
    @ObservedObject var themeManager: ThemeManager
    @ObservedObject var audioManager: AudioManager

    var body: some View {
        VStack(spacing: 30) {
            HStack(spacing: 30) {
                // Previous Track
                Button(action: {
                    hapticFeedback(.medium)
                    audioManager.previousTrack()
                }) {
                    Image(systemName: "backward.end.fill")
                        .font(.title2)
                        .foregroundColor(themeManager.isDarkMode ? .gray : .secondary)
                }

                // Skip Backward 15s
                Button(action: {
                    hapticFeedback(.light)
                    audioManager.skipBackward()
                }) {
                    Image(systemName: "gobackward.15")
                        .font(.title)
                        .foregroundColor(themeManager.isDarkMode ? .white : .blue)
                }

                // Play/Pause
                Button(action: {
                    hapticFeedback(.heavy)
                    audioManager.playPause()
                }) {
                    Image(systemName: audioManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 75))
                        .foregroundColor(themeManager.isDarkMode ? .white : .blue)
                        .shadow(radius: 5)
                }

                // Skip Forward 30s
                Button(action: {
                    hapticFeedback(.light)
                    audioManager.skipForward()
                }) {
                    Image(systemName: "goforward.30")
                        .font(.title)
                        .foregroundColor(themeManager.isDarkMode ? .white : .blue)
                }

                // Next Track
                Button(action: {
                    hapticFeedback(.medium)
                    audioManager.nextTrack()
                }) {
                    Image(systemName: "forward.end.fill")
                        .font(.title2)
                        .foregroundColor(themeManager.isDarkMode ? .gray : .secondary)
                }
            }
            
            AirPlayView()
                .frame(width: 44, height: 44)
                .opacity(0.8)
        }
    }
    
    private func hapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
}

struct AudioListSheet: View {
    @Binding var isShowing: Bool
    @ObservedObject var audioManager: AudioManager
    @ObservedObject var themeManager: ThemeManager

    var body: some View {
        if #available(iOS 16.0, *) {
            AudioListView(isShowing: $isShowing) { selectedTrack in
                audioManager.selectedTrack = selectedTrack
                audioManager.loadAudio(track: selectedTrack)
                isShowing = false
            }
            .environmentObject(audioManager)
            .environmentObject(themeManager)
            .presentationDetents([.medium, .large])
        } else {
            AudioListView(isShowing: $isShowing) { selectedTrack in
                audioManager.selectedTrack = selectedTrack
                audioManager.loadAudio(track: selectedTrack)
                isShowing = false
            }
            .environmentObject(audioManager)
            .environmentObject(themeManager)
        }
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
