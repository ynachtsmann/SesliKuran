// MARK: - Imports
import Foundation
import AVFoundation
import MediaPlayer
import SwiftUI

// MARK: - Audio Manager Class
@MainActor
class AudioManager: ObservableObject, AVAudioPlayerDelegate {
    // MARK: - Published Properties
    @Published var audioPlayer: AVAudioPlayer?
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var selectedTrack: Surah?
    @Published var isLoading = false
    @Published var playbackRate: Float = 1.0
    @Published var criticalError: AppError?
    
    // MARK: - Private Properties
    private var uiTimer: Timer?
    private var heartbeatTimer: Timer?
    private var skipCount = 0
    private let maxSkips = 3
    
    // MARK: - Initialization
    init() {
        setupAudioSession()
        setupRemoteControls()
        setupLifecycleObservers()
        restoreState()
    }

    // MARK: - Lifecycle Observers
    private func setupLifecycleObservers() {
        NotificationCenter.default.addObserver(self,
                                             selector: #selector(handleAppBackgrounding),
                                             name: UIApplication.didEnterBackgroundNotification,
                                             object: nil)
    }

    @objc private func handleAppBackgrounding() {
        print("AudioManager: App backgrounded, saving state...")
        saveCurrentPosition()
    }

    // MARK: - State Restoration
    private func restoreState() {
        Task {
            let data = await PersistenceManager.shared.load()
            let trackId = data.lastActiveTrackID
            if let track = SurahData.allSurahs.first(where: { $0.id == trackId }) {
                self.selectedTrack = track
                // Load but do not auto-play
                self.loadAudio(track: track, autoPlay: false)

                // Restore position
                let position = await PersistenceManager.shared.getLastPosition(for: trackId)
                self.seek(to: position)

                // Restore Speed
                self.playbackRate = data.playbackSpeed
            }
        }
    }
    
    // MARK: - Audio Session Setup
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            try AVAudioSession.sharedInstance().setActive(true)
            UIApplication.shared.beginReceivingRemoteControlEvents()

            NotificationCenter.default.addObserver(self,
                                                 selector: #selector(handleInterruption),
                                                 name: AVAudioSession.interruptionNotification,
                                                 object: nil)
        } catch {
            print("Audio Session Critical Error: \(error)")
        }
    }
    
    // MARK: - Interruption Handling
    @objc private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        if type == .began {
            if isPlaying {
                audioPlayer?.pause()
                isPlaying = false
                stopTimers()
            }
        } else if type == .ended {
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    audioPlayer?.play()
                    isPlaying = true
                    startTimers()
                }
            }
        }
    }

    // MARK: - Remote Controls Setup
    private func setupRemoteControls() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.playPause()
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.playPause()
            return .success
        }
        
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.nextTrack()
            return .success
        }
        
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.previousTrack()
            return .success
        }
        
        commandCenter.changePlaybackRateCommand.isEnabled = true
        commandCenter.changePlaybackRateCommand.supportedPlaybackRates = [0.5, 1.0, 1.5, 2.0]
        commandCenter.changePlaybackRateCommand.addTarget { [weak self] event in
            guard let self = self,
                  let rateCommand = event as? MPChangePlaybackRateCommandEvent else { return .commandFailed }
            self.setPlaybackSpeed(rateCommand.playbackRate)
            return .success
        }

        // Skip Buttons
        commandCenter.skipForwardCommand.preferredIntervals = [30]
        commandCenter.skipForwardCommand.addTarget { [weak self] _ in
            self?.seek(to: (self?.currentTime ?? 0) + 30)
            return .success
        }

        commandCenter.skipBackwardCommand.preferredIntervals = [15]
        commandCenter.skipBackwardCommand.addTarget { [weak self] _ in
            self?.seek(to: (self?.currentTime ?? 0) - 15)
            return .success
        }
    }
    
    // MARK: - Update Now Playing Info
    private func updateNowPlayingInfo() {
        var nowPlayingInfo = [String: Any]()
        
        nowPlayingInfo[MPMediaItemPropertyTitle] = selectedTrack?.name ?? "Kein Titel"
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? playbackRate : 0.0
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    // MARK: - Playback Controls
    func playPause() {
        guard let player = audioPlayer else { return }
        
        if player.isPlaying {
            player.pause()
            stopTimers()
            saveCurrentPosition()
        } else {
            player.play()
            startTimers()
        }
        isPlaying = player.isPlaying
        updateNowPlayingInfo()
    }
    
    func setPlaybackSpeed(_ speed: Float) {
        audioPlayer?.rate = speed
        playbackRate = speed
        updateNowPlayingInfo()
        Task {
            await PersistenceManager.shared.updatePlaybackSpeed(speed)
        }
    }
    
    // MARK: - Position Management
    private func saveCurrentPosition() {
        guard let track = selectedTrack else { return }
        Task {
            await PersistenceManager.shared.updateLastPlayedPosition(trackId: track.id, time: currentTime)
        }
    }
    
    // MARK: - Navigation Controls
    func nextTrack() {
        saveCurrentPosition()
        guard let currentTrack = selectedTrack else { return }
        
        let currentIndex = currentTrack.id - 1
        let nextIndex = (currentIndex + 1) % SurahData.allSurahs.count
        let nextTrack = SurahData.allSurahs[nextIndex]

        loadAudio(track: nextTrack, autoPlay: true)
    }
    
    func previousTrack() {
        saveCurrentPosition()
        guard let currentTrack = selectedTrack else { return }
        
        let currentIndex = currentTrack.id - 1
        let previousIndex = (currentIndex - 1 + SurahData.allSurahs.count) % SurahData.allSurahs.count
        let prevTrack = SurahData.allSurahs[previousIndex]

        loadAudio(track: prevTrack, autoPlay: true)
    }
    
    // MARK: - Audio Loading (Hardened)
    func loadAudio(track: Surah, autoPlay: Bool = true) {
        isLoading = true
        selectedTrack = track

        // Reset Skip Count on successful user-initiated load
        // But if this is called recursively by skip logic, skipCount is managed there.
        // We need to differentiate? We will reset only if autoPlay is FALSE or explicit.
        // For simplicity: If this call fails, we increment. If success, we reset.

        let filename = "Audio \(track.id)"
        
        // 1. Prioritize Bundle (Offline First)
        var url = Bundle.main.url(forResource: filename, withExtension: "mp3")

        // 2. Fallback to Documents (Legacy/User Added) - Only if not in Bundle
        if url == nil {
            let fileManager = FileManager.default
            if let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
                let documentUrl = documentDirectory.appendingPathComponent("\(filename).mp3")
                if fileManager.fileExists(atPath: documentUrl.path) {
                    url = documentUrl
                }
            }
        }

        guard let validUrl = url else {
            handleLoadError(for: track, error: AppError.fileNotFound(filename))
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: validUrl)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            audioPlayer?.rate = playbackRate
            duration = audioPlayer?.duration ?? 0
            
            // Restore position if available
            Task {
                let lastPos = await PersistenceManager.shared.getLastPosition(for: track.id)
                await MainActor.run {
                    self.audioPlayer?.currentTime = lastPos
                    self.currentTime = lastPos

                    if autoPlay {
                        self.audioPlayer?.play()
                        self.isPlaying = true
                        self.startTimers()
                    }

                    self.updateNowPlayingInfo()
                    self.isLoading = false
                    self.skipCount = 0 // Success reset
                }
            }
        } catch {
            handleLoadError(for: track, error: AppError.fileCorrupt)
        }
    }

    // MARK: - Error Handling & Self-Healing
    private func handleLoadError(for track: Surah, error: AppError) {
        print("Error loading track \(track.id): \(error)")

        if skipCount < maxSkips {
            skipCount += 1
            print("Attempting skip... (\(skipCount)/\(maxSkips))")
            
            // Wait briefly to avoid rapid loop
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.nextTrack()
            }
        } else {
            // Critical Failure
            stopTimers()
            isLoading = false
            isPlaying = false
            criticalError = .installationDamaged
        }
    }
    
    // MARK: - Seek Control
    func seek(to time: TimeInterval) {
        let newTime = max(0, min(time, duration))
        audioPlayer?.currentTime = newTime
        currentTime = newTime
        updateNowPlayingInfo()
    }
    
    // MARK: - Timers
    private func startTimers() {
        stopTimers()

        // UI Timer (10fps is enough for slider)
        uiTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.audioPlayer else { return }
            self.currentTime = player.currentTime
            self.updateNowPlayingInfo() // Keep lockscreen synced
        }

        // Heartbeat Persistence Timer (Every 15s)
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
            self?.saveCurrentPosition()
        }
    }
    
    private func stopTimers() {
        uiTimer?.invalidate()
        heartbeatTimer?.invalidate()
        uiTimer = nil
        heartbeatTimer = nil
    }

    // MARK: - AVAudioPlayerDelegate
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if flag {
            // Play next track automatically
            nextTrack()
        } else {
            // Playback decode error
            if let track = selectedTrack {
                handleLoadError(for: track, error: .fileCorrupt)
            }
        }
    }
    
    // MARK: - Cleanup
    deinit {
        stopTimers()
        NotificationCenter.default.removeObserver(self)
        UIApplication.shared.endReceivingRemoteControlEvents()
    }
}
