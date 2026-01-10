import SwiftUI
import AVFoundation
import MediaPlayer

// MARK: - Audio Manager (Mission Critical & Zero-Maintenance)
// Architecture: @MainActor isolated for UI safety, NSObject for Delegate conformance.
// Stability: Uses structured concurrency (Tasks) instead of legacy Timers to prevent run-loop crashes.
@MainActor
final class AudioManager: NSObject, ObservableObject, AVAudioPlayerDelegate {

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

    // Background Launch Protection (Ghost Audio Fix)
    // Prevents auto-play when app is launched in background (e.g. by Car Bluetooth)
    private var hasEnteredForeground: Bool = false
    
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

        // Initial State Load (Synchronous)
        // CRITICAL: Must be loaded before UI renders to avoid 'nil' crash on unwraps.
        loadInitialStateSync()
    }
    
    private func loadInitialStateSync() {
        // Load Settings Synchronously
        let settings = PersistenceManager.shared.loadSynchronously()

        self.playbackRate = settings.playbackSpeed

        // Load Last Active Track (Default to 1 if none)
        // Optimization: Use Dictionary O(1) or Safe Fallback
        let lastID = settings.lastActiveTrackID
        let lastTrack = SurahData.getSurah(id: lastID) ?? SurahData.fallbackSurah

        // Prepare the player without auto-playing
        // Note: loadAudio is safe to call here as we are on MainActor and it sets state.
        // APP LAUNCH: Resume from last saved position
        self.loadAudio(track: lastTrack, autoPlay: false, resumePlayback: true)
    }

    // MARK: - Session Configuration (Crash-Proof)
    private func setupSession() {
        // Robust Retry Logic for Audio Session Activation
        // This is crucial for "Crash-Proof" operation if the OS audio daemon is busy.
        var attempt = 0
        let maxAttempts = 3
        var success = false

        // Use A2DP for high quality audio, avoiding low-quality HFP (standard Bluetooth)
        let options: AVAudioSession.CategoryOptions = [.allowBluetoothA2DP]

        while !success && attempt < maxAttempts {
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback, mode: .spokenAudio, options: options)
                try session.setActive(true)
                success = true
            } catch {
                attempt += 1
                print("CRITICAL: Failed to setup audio session (Attempt \(attempt)): \(error)")
            }
        }

        if !success {
            self.errorMessage = "Audio-Hardware konnte nicht initialisiert werden. Bitte Gerät neustarten."
            self.showError = true
        }
    }
    
    // MARK: - Core Playback Logic
    func loadAudio(track: Surah, autoPlay: Bool = true, resumePlayback: Bool = false) {
        // Safe Cleanup
        stopPlayback()

        // CRITICAL FIX: Explicitly unload the old player instance.
        // If the new file is missing, we must NOT keep the old one in memory.
        self.audioPlayer = nil

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

            // Restore Position Logic
            Task {
                let initialTime: TimeInterval

                if resumePlayback {
                    // Restore from Persistence (App Launch)
                    initialTime = await PersistenceManager.shared.getLastPosition(for: track.id)
                } else {
                    // Reset to 0 (Manual Selection / Next / Prev)
                    initialTime = 0
                }

                // Ensure UI updates happen on MainActor (guaranteed by class annotation)
                self.currentTime = initialTime
                self.audioPlayer?.currentTime = initialTime

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

        // Use Optimized Accessor
        if let nextSurah = SurahData.getSurah(id: nextId) {
            // USER NAVIGATION: Always start from 0:00
            loadAudio(track: nextSurah, autoPlay: true, resumePlayback: false)
        } else {
            // End of Playlist: Stop.
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

        // Use Optimized Accessor
        if let prevSurah = SurahData.getSurah(id: prevId) {
            // USER NAVIGATION: Always start from 0:00
            loadAudio(track: prevSurah, autoPlay: true, resumePlayback: false)
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
            Task { @MainActor in
                guard let self = self, self.hasEnteredForeground else { return }
                self.play()
            }
            return .success
        }

        commandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.pause() }
            return .success
        }

        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                guard let self = self, self.hasEnteredForeground else { return }
                self.nextTrack()
            }
            return .success
        }

        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                guard let self = self, self.hasEnteredForeground else { return }
                self.previousTrack()
            }
            return .success
        }

        commandCenter.skipForwardCommand.preferredIntervals = [30]
        commandCenter.skipForwardCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                guard let self = self, self.hasEnteredForeground else { return }
                self.skipForward()
            }
            return .success
        }

        commandCenter.skipBackwardCommand.preferredIntervals = [15]
        commandCenter.skipBackwardCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                guard let self = self, self.hasEnteredForeground else { return }
                self.skipBackward()
            }
            return .success
        }

        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self = self, let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            Task { @MainActor in
                guard self.hasEnteredForeground else { return }
                self.seek(to: event.positionTime)
            }
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
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = Double(duration)
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = Double(currentTime)
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = Double(isPlaying ? playbackRate : 0.0)

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

        // Media Services Reset (Daemon Crash Recovery) - The 0.01% Scenario
        center.addObserver(self,
                           selector: #selector(handleMediaServicesReset),
                           name: AVAudioSession.mediaServicesWereResetNotification,
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

        // Active State (Ghost Audio Fix)
        center.addObserver(self,
                           selector: #selector(handleAppDidBecomeActive),
                           name: UIApplication.didBecomeActiveNotification,
                           object: nil)
    }

    @objc private func handleAppDidBecomeActive() {
        self.hasEnteredForeground = true
    }

    nonisolated @objc private func handleMediaServicesReset(notification: Notification) {
        // Full Reset of Audio Stack
        print("CRITICAL: Media Services Reset Detected. Rebuilding Audio Stack...")

        Task { @MainActor in
            // 1. Tear down existing resources
            self.stopPlayback()
            self.audioPlayer = nil

            // 2. Re-initialize Session
            self.setupSession()
            self.setupRemoteCommandCenter()

            // 3. Restore State if possible
            if let track = self.selectedTrack {
                // Reload without auto-playing to prevent sudden blasting,
                // or autoplay if it was playing?
                // Safe bet: Reload and seek, let user press play.
                // RECOVERY: Attempt to resume position for continuity
                self.loadAudio(track: track, autoPlay: false, resumePlayback: true)

                // If it was playing, maybe we can try to resume after a delay?
                // For safety/Mission Critical, we prefer "Paused & Ready" over "Accidental Noise".
            }
        }
    }

    @objc private func handleAppBackground() {
        // Force save immediately using Background Task to ensure completion
        let app = UIApplication.shared
        var bgTask: UIBackgroundTaskIdentifier = .invalid

        // Ensure robust background task handling
        // Must be called synchronously to guarantee execution time
        bgTask = app.beginBackgroundTask {
            // Expiration Handler: Final safety net
            app.endBackgroundTask(bgTask)
            bgTask = .invalid
        }
        
        // Save Logic
        self.saveCurrentPosition()

        // Wait briefly for the save to hit disk (async queue in PersistenceManager)
        Task {
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s buffer
            
            if bgTask != .invalid {
                app.endBackgroundTask(bgTask)
                bgTask = .invalid
            }
        }
    }
    
    nonisolated @objc private func handleInterruption(notification: Notification) {
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
                // Self-Healing: Treat as corrupt end, skip to next.
                print("Audio finished unsuccessfully. Attempting skip.")
                if self.skipCount < self.maxSkips {
                    self.skipCount += 1
                    self.nextTrack()
                } else {
                    self.isPlaying = false
                    self.stopTasks()
                }
            }
        }
    }
    
    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            print("Decode error: \(String(describing: error))")
            // Graceful Degradation: Skip corrupt file automatically
            if self.skipCount < self.maxSkips {
                self.skipCount += 1
                try? await Task.sleep(nanoseconds: 500_000_000)
                self.nextTrack()
            } else {
                self.isPlaying = false
                self.stopTasks()
                self.errorMessage = "Wiedergabefehler: Datei beschädigt."
                self.showError = true
            }
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