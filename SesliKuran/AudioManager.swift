// MARK: - Imports
import Foundation
import AVFoundation
import MediaPlayer

// MARK: - Audio Manager Class
@MainActor
class AudioManager: ObservableObject {
    // MARK: - Published Properties
    @Published var audioPlayer: AVAudioPlayer?
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var selectedTrack: Surah?
    @Published var isLoading = false
    @Published var playbackRate: Float = 1.0
    @Published var lastPlayedPositions: [String: TimeInterval] = [:]
    @Published var showError = false
    @Published var errorMessage = ""
    
    // MARK: - Private Properties
    private var timer: Timer?
    // Using SurahData.allSurahs now
    
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
        let key = "Audio \(track.id)"
        lastPlayedPositions[key] = currentTime
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
        guard let currentTrack = selectedTrack else {
            isLoading = false
            return
        }
        
        let currentIndex = currentTrack.id - 1
        let nextIndex = (currentIndex + 1) % SurahData.allSurahs.count
        selectedTrack = SurahData.allSurahs[nextIndex]
        loadAudio(track: selectedTrack!)
    }
    
    func previousTrack() {
        saveCurrentPosition()
        isLoading = true
        guard let currentTrack = selectedTrack else {
            isLoading = false
            return
        }
        
        let currentIndex = currentTrack.id - 1
        let previousIndex = (currentIndex - 1 + SurahData.allSurahs.count) % SurahData.allSurahs.count
        selectedTrack = SurahData.allSurahs[previousIndex]
        loadAudio(track: selectedTrack!)
    }
    
    // MARK: - Audio Loading
    func loadAudio(track: Surah) {
        isLoading = true
        selectedTrack = track // Ensure selectedTrack is set

        let filename = "Audio \(track.id)"
        var url: URL?
        
        // 1. Check Bundle
        if let bundleUrl = Bundle.main.url(forResource: filename, withExtension: "mp3") {
            url = bundleUrl
        } else {
            // 2. Check Documents Directory
            let fileManager = FileManager.default
            if let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
                let documentUrl = documentDirectory.appendingPathComponent("\(filename).mp3")
                if fileManager.fileExists(atPath: documentUrl.path) {
                    url = documentUrl
                }
            }
        }

        guard let validUrl = url else {
            print("Audio file nicht gefunden: \(filename).mp3")

            // Stop current playback if it exists and clean up
            if let player = audioPlayer {
                if player.isPlaying {
                    player.stop()
                }
            }

            // Reset player state to avoid "ghost" playback
            audioPlayer = nil
            isPlaying = false
            duration = 0
            currentTime = 0
            timer?.invalidate()
            updateNowPlayingInfo()

            self.errorMessage = "Die Audiodatei 'Audio \(track.id).mp3' für '\(track.name)' wurde nicht gefunden. Bitte fügen Sie die Datei über iTunes File Sharing hinzu oder integrieren Sie sie in das Bundle. (Siehe Anleitung)"
            self.showError = true
            isLoading = false
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: validUrl)
            audioPlayer?.prepareToPlay()
            audioPlayer?.rate = playbackRate
            duration = audioPlayer?.duration ?? 0
            
            let key = "Audio \(track.id)"
            if let lastPosition = lastPlayedPositions[key] {
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
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil)
            let audioFileURLs = fileURLs.filter { $0.pathExtension == "mp3" }
            
            let validFilenames = Set(SurahData.allSurahs.map { "Audio \($0.id).mp3" })

            for fileURL in audioFileURLs {
                let fileName = fileURL.lastPathComponent
                if !validFilenames.contains(fileName) {
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
