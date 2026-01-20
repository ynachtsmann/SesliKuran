import SwiftUI
import AVFoundation
import MediaPlayer

// MARK: - Audio Manager (Audiophile Engine)
// Architecture: @MainActor isolated for UI safety.
// Core: AVQueuePlayer for Gapless Playback (AAC-LC 256kbps @ 48kHz).
@MainActor
final class AudioManager: NSObject, ObservableObject {

    // MARK: - Published State (UI Drivers)
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var selectedTrack: Surah?
    @Published var playbackRate: Float = 1.0
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    @Published var isLoading: Bool = false

    // Sleep Timer State
    @Published var sleepTimerTimeRemaining: TimeInterval = 0
    @Published var isSleepTimerActive: Bool = false

    // MARK: - Internal Components
    private var player: AVQueuePlayer?

    // Observers
    private var timeObserverToken: Any?
    private var itemObserver: NSKeyValueObservation?
    private var statusObserver: NSKeyValueObservation?

    // Concurrency
    private var sleepTimerTask: Task<Void, Never>?
    private var savePositionTask: Task<Void, Never>?

    // Background Launch Protection
    private var hasEnteredForeground: Bool = false
    
    // MARK: - Initialization
    override init() {
        super.init()
        setupRemoteCommandCenter()
        setupNotifications()
    }

    // MARK: - Asynchronous Preparation
    func prepare() async {
        // Silent Setup: Don't show alerts during splash screen
        await setupSession(silent: true)

        // Restore Settings
        let lastID = await PersistenceManager.shared.getLastPlayedSurahId()
        let speed = await PersistenceManager.shared.getPlaybackSpeed()
        var lastTime = await PersistenceManager.shared.getLastPosition(for: lastID)

        // Smart Resume: If less than 5 seconds, reset to 0 to avoid annoyance
        if lastTime < 5 {
            lastTime = 0
        }

        self.playbackRate = speed

        // Resolve Track
        let lastTrack = SurahData.getSurah(id: lastID) ?? SurahData.fallbackSurah

        // Load Audio Silent (Prepare Queue)
        // Explicitly pass the restored time AND suppress errors
        loadAudio(track: lastTrack, startTime: lastTime, autoPlay: false, silent: true)
    }

    // MARK: - Session Configuration (Audiophile Strict)
    private func setupSession(silent: Bool = false) async {
        let session = AVAudioSession.sharedInstance()
        do {
            // Requirement: Playback category (No mute switch interference)
            // Requirement: Default mode (Flat response, NO spokenAudio/High-Pass)
            try session.setCategory(.playback, mode: .default, options: [])

            // Requirement: 44.1kHz Native Sample Rate (Avoid Resampling)
            try session.setPreferredSampleRate(44100.0)

            try session.setActive(true)
            print("Audio Session: Configured for Audiophile Playback (44.1kHz, .default)")
        } catch {
            print("Audio Session Error: \(error)")
            // Fallback not necessary for strict audiophile app?
            // We proceed, but quality might be compromised by OS.
            if !silent {
                self.errorMessage = "Audio-Hardware konnte nicht konfiguriert werden."
                self.showError = true
            }
        }
    }
    
    // MARK: - Core Playback Logic (Queue Construction)
    func loadAudio(track: Surah, startTime: TimeInterval = 0, autoPlay: Bool = true, silent: Bool = false) {
        // 1. Reset current player
        stopPlayback()

        self.selectedTrack = track
        self.isLoading = true
        self.errorMessage = nil
        self.showError = false

        // 2. Build Queue [Selected...114]
        // Requirement: Offline App, Bundle Only, format "%03d.mp3"
        var items: [AVPlayerItem] = []
        let startId = track.id
        let endId = 114

        for id in startId...endId {
            let filename = String(format: "%03d", id)
            if let url = Bundle.main.url(forResource: filename, withExtension: "mp3") {
                let item = AVPlayerItem(url: url)
                // Requirement: preferredForwardBufferDuration = 0 (Local file, zero latency)
                item.preferredForwardBufferDuration = 0
                items.append(item)
            } else {
                // If a file is missing in the middle, the queue simply skips it.
                // We assume bundle integrity is generally good.
            }
        }

        guard !items.isEmpty else {
            self.isLoading = false
            if !silent {
                self.errorMessage = "Audiodatei nicht gefunden (Bundle Integrity Error)."
                self.showError = true
            } else {
                print("Silent Load Failed: Bundle Integrity Error for track \(track.id)")
            }
            return
        }

        // 3. Initialize Queue Player
        self.player = AVQueuePlayer(items: items)
        self.player?.actionAtItemEnd = .advance // Native Gapless
        self.player?.volume = 1.0 // Requirement: Signal Purity

        // 4. Setup Observers
        setupObservers()

        // 5. Restore Position or Play
        if startTime > 0 {
             let cmTime = CMTime(seconds: startTime, preferredTimescale: 600)
             self.player?.seek(to: cmTime)
        }

        self.isLoading = false

        if autoPlay {
            play()
        } else {
            updateNowPlayingInfo()
            // Update UI state for duration/time
             if let item = self.player?.currentItem {
                 // Async duration load
                 Task {
                     let duration = try? await item.asset.load(.duration).seconds
                     self.duration = duration ?? 0
                 }
             }
        }
    }

    // MARK: - Playback Controls
    func play() {
        guard let player = player else { return }
        player.rate = playbackRate // Applies speed AND starts playback (if rate > 0)
        isPlaying = true
        startSavePositionTask()
        updateNowPlayingInfo()
    }

    func pause() {
        player?.pause()
        isPlaying = false
        saveCurrentPosition()
        stopSavePositionTask()
        updateNowPlayingInfo()
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            // If player exists, play. If not (error state), try reload?
            if player != nil {
                play()
            } else if let track = selectedTrack {
                loadAudio(track: track, autoPlay: true)
            }
        }
        triggerHaptic()
    }

    private func stopPlayback() {
        player?.pause()
        player?.removeAllItems()
        player = nil
        isPlaying = false
        removeObservers()
        stopSavePositionTask()
    }

    // MARK: - Navigation
    func nextTrack() {
        guard let player = player else { return }

        // Wraparound Logic: 114 -> 1
        if selectedTrack?.id == 114 {
            if let firstSurah = SurahData.getSurah(id: 1) {
                loadAudio(track: firstSurah, autoPlay: true)
            }
            return
        }

        // AVQueuePlayer: Advance to next item
        player.advanceToNextItem()
        // The itemObserver will detect the change and update 'selectedTrack'
    }
    
    func previousTrack() {
        guard let current = selectedTrack else { return }
        
        // Logic:
        // Playtime > 3s -> Restart current
        // Playtime <= 3s -> Previous Track (Rebuild Queue)

        if currentTime > 3 {
            seek(to: 0)
        } else {
            // Wraparound Logic: 1 -> 114
            if current.id == 1 {
                if let lastSurah = SurahData.getSurah(id: 114) {
                    loadAudio(track: lastSurah, autoPlay: true)
                }
                return
            }

            let prevId = current.id - 1
            if let prevSurah = SurahData.getSurah(id: prevId) {
                // Rebuild Queue from Prev
                loadAudio(track: prevSurah, autoPlay: true)
            }
        }
    }
    
    func seek(to time: TimeInterval) {
        guard let player = player else { return }
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player.seek(to: cmTime)
        updateNowPlayingInfo()
    }
    
    func skipForward() {
        seek(to: currentTime + 15)
    }

    func skipBackward() {
        seek(to: currentTime - 15)
    }

    func setPlaybackSpeed(_ speed: Float) {
        playbackRate = speed
        if isPlaying {
            player?.rate = speed
        }
        saveCurrentPosition() // Save preference
    }

    // MARK: - Observers & State Management
    private func setupObservers() {
        guard let player = player else { return }

        // 1. Time Observer (High Freq UI Update)
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                self?.currentTime = time.seconds
            }
        }

        // 2. Current Item Observer (Detect Gapless Track Change)
        itemObserver = player.observe(\.currentItem, options: [.new]) { [weak self] player, _ in
            Task { @MainActor in
                self?.handleTrackChange()
            }
        }

        // 3. Status Observer (Ready to Play / Failed)
        statusObserver = player.observe(\.status, options: [.new]) { [weak self] player, _ in
             if player.status == .failed {
                 let error = player.error
                 Task { @MainActor in
                     self?.handleError(error)
                 }
             }
        }
    }

    private func removeObservers() {
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        itemObserver?.invalidate()
        itemObserver = nil
        statusObserver?.invalidate()
        statusObserver = nil
    }

    private func handleTrackChange() {
        guard let item = player?.currentItem else {
            // Queue finished?
            if isPlaying { // If we were playing and now nil, queue ended.
                // Wraparound Logic: End of 114 -> Start of 1
                if selectedTrack?.id == 114 {
                    if let firstSurah = SurahData.getSurah(id: 1) {
                        loadAudio(track: firstSurah, autoPlay: true)
                        return
                    }
                }

                isPlaying = false
                stopSavePositionTask()
            }
            return
        }

        // Extract Surah ID from URL
        if let asset = item.asset as? AVURLAsset {
            let url = asset.url
            let filename = url.lastPathComponent // "001.mp3"
            let idString = filename.replacingOccurrences(of: ".mp3", with: "")
            if let id = Int(idString), let surah = SurahData.getSurah(id: id) {
                // Update UI State
                self.selectedTrack = surah

                // Get Duration (Async)
                Task {
                    let duration = try? await asset.load(.duration).seconds
                    self.duration = duration ?? 0
                    self.updateNowPlayingInfo()
                }
            }
        }
    }

    private func handleError(_ error: Error?) {
        print("AVQueuePlayer Error: \(String(describing: error))")
        isPlaying = false
        stopSavePositionTask()
        errorMessage = "Wiedergabefehler: \(error?.localizedDescription ?? "Unbekannt")"
        showError = true
    }

    // MARK: - Persistence & Sleep Timer
    private func startSavePositionTask() {
        savePositionTask?.cancel()
        savePositionTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 15_000_000_000) // 15s
                self.saveCurrentPosition()
            }
        }
    }

    private func stopSavePositionTask() {
        savePositionTask?.cancel()
        savePositionTask = nil
    }

    func saveCurrentPosition() {
        guard let track = selectedTrack else { return }
        let currentPos = currentTime
        let rate = playbackRate

        Task {
            await PersistenceManager.shared.updateLastPlayedPosition(trackId: track.id, time: currentPos)
            await PersistenceManager.shared.updatePlaybackSpeed(rate)
        }
    }
    
    func startSleepTimer(minutes: Double) {
        stopSleepTimer()
        let seconds = minutes * 60
        sleepTimerTimeRemaining = seconds
        isSleepTimerActive = true

        sleepTimerTask = Task {
            while sleepTimerTimeRemaining > 0 {
                if Task.isCancelled { return }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                sleepTimerTimeRemaining -= 1
            }
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

    // MARK: - Remote Command Center & Info
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
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
             guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
             Task { @MainActor in self?.seek(to: event.positionTime) }
             return .success
        }
    }
    
    private func updateNowPlayingInfo() {
        guard let track = selectedTrack else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        
        var info = [String: Any]()
        info[MPMediaItemPropertyTitle] = track.name
        info[MPMediaItemPropertyArtist] = track.germanName
        info[MPMediaItemPropertyPlaybackDuration] = duration
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? playbackRate : 0.0

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    // MARK: - Notifications
    private func setupNotifications() {
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(handleInterruption), name: AVAudioSession.interruptionNotification, object: nil)
        center.addObserver(self, selector: #selector(handleAppDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    @objc private func handleAppDidBecomeActive() {
        self.hasEnteredForeground = true
    }

    @objc nonisolated private func handleInterruption(notification: Notification) {
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
            @unknown default: break
            }
        }
    }
    
    private func triggerHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}
