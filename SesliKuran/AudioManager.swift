// MARK: - Imports
import Foundation
import AVFoundation
import MediaPlayer
import Foundation

// MARK: - Audio Manager Class
class AudioManager: ObservableObject {
    // MARK: - Published Properties
    @Published var audioPlayer: AVAudioPlayer?
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var selectedTrack: String?
    @Published var isLoading = false
    @Published var playbackRate: Float = 1.0
    @Published var lastPlayedPositions: [String: TimeInterval] = [:]
    
    // MARK: - Private Properties
    private var timer: Timer?
    private var audioList = (1...115).map { "Audio \($0)" }
    
    // MARK: - Initialization
    init() {
        setupAudioSession()
        setupRemoteControls()
        loadLastPlayedPositions()
    }
    
    // MARK: - Audio Session Setup
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            try AVAudioSession.sharedInstance().setActive(true)
            UIApplication.shared.beginReceivingRemoteControlEvents()
        } catch {
            print("Audio Session Fehler: \(error)")
        }
    }
    
    // MARK: - Remote Controls Setup
    private func setupRemoteControls() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        // Play/Pause
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.playPause()
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.playPause()
            return .success
        }
        
        // Vor/Zurück
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.nextTrack()
            return .success
        }
        
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.previousTrack()
            return .success
        }
        
        // Wiedergabegeschwindigkeit
        commandCenter.changePlaybackRateCommand.isEnabled = true
        commandCenter.changePlaybackRateCommand.supportedPlaybackRates = [0.5, 1.0, 1.5, 2.0]
        commandCenter.changePlaybackRateCommand.addTarget { [weak self] event in
            guard let self = self,
                  let rateCommand = event as? MPChangePlaybackRateCommandEvent else { return .commandFailed }
            self.setPlaybackSpeed(rateCommand.playbackRate)
            return .success
        }
    }
    
    // MARK: - Update Now Playing Info
    private func updateNowPlayingInfo() {
        var nowPlayingInfo = [String: Any]()
        
        nowPlayingInfo[MPMediaItemPropertyTitle] = selectedTrack ?? "Kein Titel"
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
            timer?.invalidate()
            saveCurrentPosition()
        } else {
            player.play()
            setupTimer()
        }
        isPlaying = player.isPlaying
        updateNowPlayingInfo()
    }
    
    func setPlaybackSpeed(_ speed: Float) {
        audioPlayer?.rate = speed
        playbackRate = speed
        updateNowPlayingInfo()
    }
    
    // MARK: - Position Management
    private func saveCurrentPosition() {
        guard let track = selectedTrack else { return }
        lastPlayedPositions[track] = currentTime
        saveLastPlayedPositions()
    }
    
    private func loadLastPlayedPositions() {
        if let saved = UserDefaults.standard.dictionary(forKey: "LastPlayedPositions") as? [String: TimeInterval] {
            lastPlayedPositions = saved
        }
    }
    
    private func saveLastPlayedPositions() {
        UserDefaults.standard.set(lastPlayedPositions, forKey: "LastPlayedPositions")
    }
    
    // MARK: - Navigation Controls
    func nextTrack() {
        saveCurrentPosition()
        isLoading = true
        guard let currentTrack = selectedTrack,
              let currentIndex = audioList.firstIndex(of: currentTrack) else {
            isLoading = false
            return
        }
        
        let nextIndex = (currentIndex + 1) % audioList.count
        selectedTrack = audioList[nextIndex]
        loadAudio(track: selectedTrack!)
    }
    
    func previousTrack() {
        saveCurrentPosition()
        isLoading = true
        guard let currentTrack = selectedTrack,
              let currentIndex = audioList.firstIndex(of: currentTrack) else {
            isLoading = false
            return
        }
        
        let previousIndex = (currentIndex - 1 + audioList.count) % audioList.count
        selectedTrack = audioList[previousIndex]
        loadAudio(track: selectedTrack!)
    }
    
    // MARK: - Audio Loading
    func loadAudio(track: String) {
        isLoading = true
        
        guard let url = Bundle.main.url(forResource: track, withExtension: "mp3") else {
            print("Audio file nicht gefunden: \(track)")
            isLoading = false
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            audioPlayer?.rate = playbackRate
            duration = audioPlayer?.duration ?? 0
            
            if let lastPosition = lastPlayedPositions[track] {
                audioPlayer?.currentTime = lastPosition
                currentTime = lastPosition
            } else {
                currentTime = 0
            }
            
            audioPlayer?.play()
            isPlaying = true
            setupTimer()
            updateNowPlayingInfo()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.isLoading = false
            }
        } catch {
            print("Fehler beim Laden der Audiodatei: \(error)")
            isLoading = false
        }
    }
    
    // MARK: - Seek Control
    func seek(to time: TimeInterval) {
        audioPlayer?.currentTime = time
        currentTime = time
        updateNowPlayingInfo()
    }
    
    // MARK: - Timer Setup
    private func setupTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.audioPlayer else { return }
            self.currentTime = player.currentTime
            self.updateNowPlayingInfo()
        }
    }
    
    // MARK: - Cleanup
    func cleanupUnusedAudioFiles() {
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil)
            let audioFileURLs = fileURLs.filter { $0.pathExtension == "mp3" }
            
            for fileURL in audioFileURLs {
                let fileName = fileURL.lastPathComponent
                if !audioList.contains(fileName.replacingOccurrences(of: ".mp3", with: "")) {
                    try fileManager.removeItem(at: fileURL)
                    print("Gelöschte unbenutzte Audiodatei: \(fileName)")
                }
            }
        } catch {
            print("Fehler beim Bereinigen unbenutzter Audiodateien: \(error)")
        }
    }
    
    deinit {
        saveCurrentPosition()
        timer?.invalidate()
        UIApplication.shared.endReceivingRemoteControlEvents()
        cleanupUnusedAudioFiles()
    }
}

