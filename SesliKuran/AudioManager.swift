import SwiftUI
import AVFoundation
import MediaPlayer

// MARK: - Audio Manager (Mission Critical & Zero-Maintenance)
// Architecture: @MainActor isolated for UI safety, NSObject for Delegate conformance.
// Stability: Uses structured concurrency (Tasks) instead of legacy Timers to prevent run-loop crashes.
@MainActor
class AudioManager: NSObject, ObservableObject, AVAudioPlayerDelegate {

    // MARK: - Published State (UI Drivers)
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var selectedTrack: Surah?
    @Published var playbackRate: Float = 1.0
    // REMOVED: isDarkMode (Handled by ThemeManager)
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    @Published var isLoading: Bool = false

    // MARK: - Internal Components
    private var audioPlayer: AVAudioPlayer?

    // Concurrency: Use Tasks instead of Timer for robust lifecycle management
    private var progressTask: Task<Void, Never>?
    private var heartbeatTask: Task<Void, Never>?
    
    // Retry Logic (Self-Healing)
    private var skipCount: Int = 0
    private let maxSkips: Int = 3

    // Sleep Timer
    @Published var sleepTimerTimeRemaining: TimeInterval = 0
    @Published var isSleepTimerActive: Bool = false
    private var sleepTimerTask: Task<Void, Never>?
    
    // MARK: - Initialization
    override init() {
        super.init() // Required for NSObject
        setupSession()
        setupRemoteCommandCenter()
        setupNotifications()

        // Initial State Load (Async)
        Task {
            await loadInitialState()
        }
    }
    
    private func loadInitialState() async {
        // Load Settings from Persistence
        let persistence = PersistenceManager.shared
        let settings = await persistence.load()

        self.playbackRate = settings.playbackSpeed

        // Load Last Active Track (Default to 1 if none)
        let lastID = settings.lastActiveTrackID
        // CORRECTED: Use SurahData.allSurahs
        let lastTrack = SurahData.allSurahs.first(where: { $0.id == lastID }) ?? SurahData.allSurahs[0]

        // Prepare the player without auto-playing
        self.loadAudio(track: lastTrack, autoPlay: false)
    }

    // MARK: - Session Configuration (Crash-Proof)
    private func setupSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.allowBluetooth, .allowBluetoothA2DP])
            try session.setActive(true)
        } catch {
            print("CRITICAL: Failed to setup audio session: \(error)")
            // In a mission-critical app, we might show a fatal error dialog here,
            // but for now we log it. The app should still try to function.
        }
    }
    
    // MARK: - Core Playback Logic
    func loadAudio(track: Surah, autoPlay: Bool = true) {
        // Safe Cleanup
        stopPlayback()

        self.selectedTrack = track
        self.isLoading = true
        self.errorMessage = nil
        self.showError = false

        let filename = "Audio \(track.id)"

        // Robust File Resolution Strategy
        // 1. Check Bundle (ReadOnly, Built-in)
        var fileURL = Bundle.main.url(forResource: filename, withExtension: "mp3")

        // 2. Check Documents (User Imported via iTunes/Finder)
        if fileURL == nil {
            if let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                let docURL = docDir.appendingPathComponent("\(filename).mp3")
                if FileManager.default.fileExists(atPath: docURL.path) {
                    fileURL = docURL
                }
            }
        }

        guard let validURL = fileURL else {
            handleLoadError(error: .fileNotFound(filename))
            return
        }

        // Attempt Load
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: validURL)
            audioPlayer?.delegate = self // NOW VALID due to NSObject conformance
            audioPlayer?.enableRate = true
            audioPlayer?.rate = playbackRate
            audioPlayer?.prepareToPlay()

            duration = audioPlayer?.duration ?? 0

            // Restore Position
            Task {
                let savedTime = await PersistenceManager.shared.getLastPosition(for: track.id)

                // Ensure UI updates happen on MainActor (guaranteed by class annotation)
                self.currentTime = savedTime
                self.audioPlayer?.currentTime = savedTime

                if autoPlay {
                    self.play()
                } else {
                    self.updateNowPlayingInfo()
                }

                self.isLoading = false
                self.skipCount = 0 // Reset error counter on success
            }

        } catch {
            handleLoadError(error: .fileCorrupt)
        }
    }

    func play() {
        guard let player = audioPlayer else { return }
        player.play()
        isPlaying = true
        startTasks()
        updateNowPlayingInfo()
    }

    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        stopTasks() // Conserves resources
        updateNowPlayingInfo()
        
        // Save immediately on pause
        saveCurrentPosition()
    }

    func togglePlayPause() {
        isPlaying ? pause() : play()
        triggerHaptic()
    }

    private func stopPlayback() {
        audioPlayer?.stop()
        isPlaying = false
        stopTasks()
        // Do not nil out audioPlayer immediately if we want to keep metadata,
        // but here we are usually loading a new one.
    }

    // MARK: - Task Management (Modern "Timers")
    private func startTasks() {
        // Cancel existing to prevent duplicates
        stopTasks()
        
        // 1. UI Progress Update (High Frequency)
        progressTask = Task {
            while !Task.isCancelled {
                if let player = self.audioPlayer, player.isPlaying {
                    self.currentTime = player.currentTime
                    // No need to update NowPlayingInfo every 0.1s, strictly UI binding
                }
                // Sleep 0.1s (100ms)
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
        
        // 2. Persistence Heartbeat (Low Frequency)
        heartbeatTask = Task {
            while !Task.isCancelled {
                // Sleep 15s
                try? await Task.sleep(nanoseconds: 15_000_000_000)
                self.saveCurrentPosition()
            }
        }
    }

    private func stopTasks() {
        progressTask?.cancel()
        progressTask = nil
        heartbeatTask?.cancel()
        heartbeatTask = nil
    }

    // MARK: - Persistence
    func saveCurrentPosition() {
        guard let track = selectedTrack else { return }
        let currentPos = currentTime
        let rate = playbackRate

        Task {
            // Fire and forget safe save
            await PersistenceManager.shared.updateLastPlayedPosition(trackId: track.id, time: currentPos)
            await PersistenceManager.shared.updatePlaybackSpeed(rate)
            // Note: Theme is handled by ThemeManager
        }
    }

    // MARK: - Navigation
    func nextTrack() {
        guard let current = selectedTrack else { return }
        let nextId = current.id + 1
        // CORRECTED: Use SurahData.allSurahs
        if let nextSurah = SurahData.allSurahs.first(where: { $0.id == nextId }) {
            loadAudio(track: nextSurah, autoPlay: true)
        } else {
            // End of Playlist: Loop to start or stop?
            // Standard behavior: Stop or Loop to 1. Let's loop to 1 for continuous play if desired,
            // or just stop. Given "Zero-Maintenance", stopping is safer than infinite loops.
            // But user might want continuous. Let's Stop.
            isPlaying = false
            stopTasks()
        }
    }
    
    func previousTrack() {
        guard let current = selectedTrack else { return }
        
        // If played more than 3 seconds, restart track
        if currentTime > 3 {
            seek(to: 0)
            return
        }
        
        let prevId = current.id - 1
        // CORRECTED: Use SurahData.allSurahs
        if let prevSurah = SurahData.allSurahs.first(where: { $0.id == prevId }) {
            loadAudio(track: prevSurah, autoPlay: true)
        }
    }
    
    func seek(to time: TimeInterval) {
        guard let player = audioPlayer else { return }
        let newTime = max(0, min(time, duration))
        player.currentTime = newTime
        currentTime = newTime
        updateNowPlayingInfo()
    }
    
    func skipForward() {
        seek(to: currentTime + 30)
    }

    func skipBackward() {
        seek(to: currentTime - 15)
    }

    func setPlaybackSpeed(_ speed: Float) {
        playbackRate = speed
        audioPlayer?.rate = speed
        saveCurrentPosition() // Save preference
    }
    
    // MARK: - Error Handling
    private func handleLoadError(error: AppError) {
        print("AudioManager Error: \(error.localizedDescription)")

        // Self-Healing: Attempt to skip to next track if one fails
        if skipCount < maxSkips {
            skipCount += 1
            // Use Task.sleep for delay
            Task {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
                self.nextTrack()
            }
        } else {
            // Give up
            self.isLoading = false
            self.isPlaying = false
            self.errorMessage = error.localizedDescription
            self.showError = true
            stopTasks()
        }
    }
    
    // MARK: - Sleep Timer
    func startSleepTimer(minutes: Double) {
        stopSleepTimer()
        let seconds = minutes * 60
        sleepTimerTimeRemaining = seconds
        isSleepTimerActive = true

        sleepTimerTask = Task {
            while sleepTimerTimeRemaining > 0 {
                if Task.isCancelled { return }
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1s
                sleepTimerTimeRemaining -= 1
            }
            // Timer Finished
            self.pause()
            self.isSleepTimerActive = false
        }
    }
    
    func stopSleepTimer() {
        sleepTimerTask?.cancel()
        sleepTimerTask = nil
        isSleepTimerActive = false
        sleepTimerTimeRemaining = 0
    }
    
    // MARK: - Haptics
    private func triggerHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    // MARK: - Remote Command Center (Lock Screen)
    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.play() }
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.pause() }
            return .success
        }

        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.nextTrack() }
            return .success
        }

        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.previousTrack() }
            return .success
        }
        
        commandCenter.skipForwardCommand.preferredIntervals = [30]
        commandCenter.skipForwardCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.skipForward() }
            return .success
        }

        commandCenter.skipBackwardCommand.preferredIntervals = [15]
        commandCenter.skipBackwardCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.skipBackward() }
            return .success
        }

        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self = self, let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            Task { @MainActor in self.seek(to: event.positionTime) }
            return .success
        }
    }
    
    private func updateNowPlayingInfo() {
        guard let track = selectedTrack else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }

        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = track.name
        nowPlayingInfo[MPMediaItemPropertyArtist] = track.germanName
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? playbackRate : 0.0

        // Add Artwork if we had it. For now text only.

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    // MARK: - Notifications (Interruption & Lifecycle Handling)
    private func setupNotifications() {
        let center = NotificationCenter.default

        // Interruption
        center.addObserver(self,
                           selector: #selector(handleInterruption),
                           name: AVAudioSession.interruptionNotification,
                           object: nil)

        // Lifecycle (App Background/Termination)
        // Ensure data is saved when app goes to background
        center.addObserver(self,
                           selector: #selector(handleAppBackground),
                           name: UIApplication.didEnterBackgroundNotification,
                           object: nil)

        center.addObserver(self,
                           selector: #selector(handleAppBackground),
                           name: UIApplication.willTerminateNotification,
                           object: nil)
    }

    @objc private func handleAppBackground() {
        // Force save immediately
        Task { @MainActor in
            self.saveCurrentPosition()
        }
    }
    
    @objc private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        Task { @MainActor in
            switch type {
            case .began:
                self.pause()
            case .ended:
                if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                    let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                    if options.contains(.shouldResume) {
                        self.play()
                    }
                }
            @unknown default:
                break
            }
        }
    }

    // MARK: - AVAudioPlayerDelegate
    // This method is called by the system on a background thread usually, or main thread.
    // We mark it 'nonisolated' so it satisfies the protocol requirements without assuming MainActor.
    // Then we Task { @MainActor } to safely update state.
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            if flag {
                self.nextTrack()
            } else {
                // Playback finished but failed?
                // Could be corrupt data mid-stream.
                // We treat it as an error but maybe just stop.
                self.isPlaying = false
                self.stopTasks()
            }
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            print("Decode error: \(String(describing: error))")
            self.isPlaying = false
            self.stopTasks()
            self.errorMessage = "Wiedergabefehler"
            self.showError = true
        }
    }
    
    deinit {
        // Even though Tasks cancel automatically if stored in properties when the class dies,
        // it's good practice to be explicit.
        progressTask?.cancel()
        heartbeatTask?.cancel()
        sleepTimerTask?.cancel()
        NotificationCenter.default.removeObserver(self)
    }
}
