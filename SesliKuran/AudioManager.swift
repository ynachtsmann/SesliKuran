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

    // Scrubbing State (Source of Truth)
    @Published var isScrubbing: Bool = false

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
    private var queueLoadingTask: Task<Void, Never>? // Added for Progressive Loading

    // Background Launch Protection
    private var hasEnteredForeground: Bool = false
    
    // Error Handling State
    private var lastFailedTrackId: Int?

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
        let lastTime = await PersistenceManager.shared.getLastPosition(for: lastID)

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
        // 1. Reset current player and cancel background loading
        stopPlayback()

        self.selectedTrack = track
        self.isLoading = true
        self.errorMessage = nil
        self.showError = false

        // Explicitly reset time and duration to 0 BEFORE checks.
        // This ensures UI cleans up immediately (fixes "hanging timeline").
        self.currentTime = 0
        self.duration = 0

        // 2. Progressive Queue Loading (Audiophile Optimization)
        // Instead of loading all 114 items at once (blocking Main Thread),
        // we load the current track + next 2 immediately to ensure instant playback.
        let startId = track.id
        let initialLoadCount = 3
        let endId = 114
        let initialEndId = min(startId + initialLoadCount - 1, endId)

        var initialItems: [AVPlayerItem] = []

        for id in startId...initialEndId {
            let filename = String(format: "%03d", id)
            if let url = Bundle.main.url(forResource: filename, withExtension: "mp3") {
                let item = AVPlayerItem(url: url)
                item.preferredForwardBufferDuration = 0
                initialItems.append(item)
            } else {
                // Sequential Integrity: Stop building queue if a file is missing.
                // This ensures we don't skip from 002 to 114 if 003 is missing.
                break
            }
        }

        // Integrity Check
        guard !initialItems.isEmpty else {
            self.isLoading = false

            if !silent {
                // Repeated Failure Logic
                if lastFailedTrackId == track.id {
                    self.errorMessage = "Die Audiodatei konnte nach wiederholtem Versuch nicht abgespielt werden."
                } else {
                    self.errorMessage = "Audiodatei nicht gefunden (Bundle Integrity Error)."
                }
                self.lastFailedTrackId = track.id
                self.showError = true
            } else {
                print("Silent Load Failed: Bundle Integrity Error for track \(track.id)")
            }
            return
        }

        // Load Success: Reset Failure Tracking
        self.lastFailedTrackId = nil

        // 3. Initialize Queue Player with Initial Items
        self.player = AVQueuePlayer(items: initialItems)
        self.player?.actionAtItemEnd = .advance
        self.player?.volume = 1.0

        // 4. Setup Observers
        setupObservers()

        // 5. Restore Position
        if startTime > 0 {
             let cmTime = CMTime(seconds: startTime, preferredTimescale: 600)
             self.player?.seek(to: cmTime)
        }

        self.isLoading = false

        // 6. Start Background Loading for Remaining Tracks
        if initialEndId < endId {
            startQueueLoadingTask(from: initialEndId + 1, to: endId)
        }

        // Critical: Explicitly load duration for the current item.
        // The 'itemObserver' might miss the initial item since we just created the player.
        // This ensures the duration is set for the first track (Surah 1/114) even if autoPlay is true.
        if let item = self.player?.currentItem {
            Task {
                let duration = try? await item.asset.load(.duration).seconds
                self.duration = duration ?? 0
                self.updateNowPlayingInfo()
            }
        }

        if autoPlay {
            play()
        } else {
            updateNowPlayingInfo()
        }
    }

    private func startQueueLoadingTask(from startId: Int, to endId: Int) {
        queueLoadingTask = Task.detached(priority: .utility) { [weak self] in
            var backgroundItems: [AVPlayerItem] = []

            for id in startId...endId {
                if Task.isCancelled { return }
                let filename = String(format: "%03d", id)
                if let url = Bundle.main.url(forResource: filename, withExtension: "mp3") {
                    let item = AVPlayerItem(url: url)
                    item.preferredForwardBufferDuration = 0
                    backgroundItems.append(item)
                } else {
                    // Sequential Integrity: Stop building queue if a file is missing.
                    break
                }
            }

            // Append to Player on Main Actor
            let itemsToAppend = backgroundItems
            await MainActor.run { [weak self] in
                guard let self = self, let player = self.player, !Task.isCancelled else { return }

                // Only append if we are still playing the same session
                // The 'queueLoadingTask' is cancelled in 'stopPlayback', so this is safe.
                for item in itemsToAppend {
                    if player.canInsert(item, after: nil) {
                        player.insert(item, after: nil)
                    }
                }
                print("Background Queue Loading Complete: \(startId)-\(endId)")
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
        // Critical: Remove observers FIRST to prevent recursive triggering
        // if removeAllItems triggers an item change observation.
        removeObservers()

        // Safety: Ensure scrubbing state is reset
        cancelScrubbing()

        queueLoadingTask?.cancel() // Stop any background loading
        queueLoadingTask = nil
        player?.pause()
        player?.removeAllItems()
        player = nil
        isPlaying = false

        // Safety Cleanups: ensure UI is not blocked
        isLoading = false

        stopSavePositionTask()
    }

    // MARK: - Navigation
    func nextTrack() {
        // ROBUST NAVIGATION:
        // Works even if player is nil (broken state).
        // Uses selectedTrack ID as the source of truth.

        guard let currentId = selectedTrack?.id else { return }

        // Wraparound Logic: 114 -> 1
        if currentId == 114 {
            if let firstSurah = SurahData.getSurah(id: 1) {
                loadAudio(track: firstSurah, autoPlay: true)
            }
            return
        }

        // Normal Next Logic
        // We do NOT use player.advanceToNextItem() exclusively because
        // we want to be able to navigate even if the current track is broken.

        let nextId = currentId + 1
        let filename = String(format: "%03d", nextId)

        // Check if next file exists
        // LOGIC UPDATE: We do NOT stop if file is missing.
        // We attempt to load it, which will trigger loadAudio -> Error.
        // This updates 'selectedTrack' to the new ID, so the user can press Next AGAIN
        // to skip over the hole.
        if Bundle.main.url(forResource: filename, withExtension: "mp3") == nil {
            print("Next file \(nextId) missing. Proceeding to loadAudio to trigger UI error state.")
        }

        // If player is valid and we are just moving to next item in queue
        // AND the next file actually exists (to prevent player crash)
        if let player = player, player.items().count > 1, Bundle.main.url(forResource: filename, withExtension: "mp3") != nil {
            player.advanceToNextItem()
        } else {
            // Fallback: Force Load (e.g. if player was nil, queue empty, OR file missing)
            if let nextSurah = SurahData.getSurah(id: nextId) {
                loadAudio(track: nextSurah, autoPlay: true)
            }
        }
    }
    
    func previousTrack() {
        guard let current = selectedTrack else { return }
        
        // LOGIC REFINED:
        // We want to "Restart Current" if we are significantly into the track (> 3s),
        // EVEN IF the player is nil (e.g. queue ended because next file missing).
        //
        // Case 1: Player active, time > 3s -> Restart (Seek)
        // Case 2: Player NIL (stopped), time > 3s -> Restart (Reload)
        // Case 3: Time <= 3s -> Go to Previous Track

        let isTimeSubstantial = currentTime > 3

        if isTimeSubstantial {
            if player != nil {
                seek(to: 0)
            } else {
                // Player is dead (e.g. ended), but we want to hear it again.
                loadAudio(track: current, autoPlay: true)
            }
        } else {
            // Go to Previous Track

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

    // MARK: - Scrubbing & Robust Seek (Pause-Seek-Play)
    func startScrubbing() {
        isScrubbing = true
    }

    func endScrubbing(at time: TimeInterval) {
        // Optimistic UI: Set time immediately so UI snaps to target.
        self.currentTime = time

        guard let player = player else {
            // If player is nil, just reset state (safety)
            self.isScrubbing = false
            return
        }

        let wasPlaying = self.isPlaying

        // Protocol: Pause -> Seek -> (Play)
        player.pause()

        let cmTime = CMTime(seconds: time, preferredTimescale: 600)

        player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
            Task { @MainActor in
                // Robust State Reset: MUST happen even if seek was cancelled
                self?.isScrubbing = false

                if finished && wasPlaying {
                    self?.play()
                } else if !finished {
                    // Even if seek didn't finish (e.g. rapid seeks), we should
                    // respect the original intent if possible, or leave it paused.
                    // If wasPlaying was true, we likely want to resume to avoid permanent pause.
                    if wasPlaying {
                        self?.play()
                    }
                }

                self?.updateNowPlayingInfo()
            }
        }
    }
    
    func cancelScrubbing() {
        // Safety Reset: Force scrubbing state to false to unblock UI updates.
        // We do NOT seek here; we assume the scrubbing was aborted (e.g. backgrounding).
        isScrubbing = false
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
                guard let self = self else { return }
                // Critical: Do NOT update currentTime while scrubbing.
                // This prevents the slider from fighting with the player updates.
                if !self.isScrubbing {
                    self.currentTime = time.seconds
                }
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
        // Safety: Reset scrubbing state on track change to prevent sticky slider
        cancelScrubbing()

        guard let item = player?.currentItem else {
            // Queue finished?
            if isPlaying { // If we were playing and now nil, queue ended.
                // Wraparound Logic: End of 114 -> Start of 1
                if let currentId = selectedTrack?.id {
                    if currentId == 114 {
                        if let firstSurah = SurahData.getSurah(id: 1) {
                            loadAudio(track: firstSurah, autoPlay: true)
                            return
                        }
                    } else {
                        // Sequential Check: If queue finished prematurely (not 114),
                        // verify if the next file is missing.
                        let nextId = currentId + 1
                        let filename = String(format: "%03d", nextId)
                        if Bundle.main.url(forResource: filename, withExtension: "mp3") == nil {
                            // Missing file caused queue end
                            errorMessage = "Audiodatei \(nextId) fehlt."
                            showError = true
                        }
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
                // Wait first to avoid double-save on start (since we just loaded)
                // Reduced from 15s to 10s for more frequent crash recovery
                try? await Task.sleep(nanoseconds: 10_000_000_000) // 10s
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
                self.cancelScrubbing()
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
