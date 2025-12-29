// MARK: - Imports
import Foundation
import AVFoundation
import MediaPlayer

// MARK: - Audio Manager Class
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
    
    // MARK: - Private Properties
    private var timer: Timer?
    
    // MARK: - Initialization
    init() {
        setupAudioSession()
        setupRemoteControls()
        loadLastPlayedPositions()

        // Restore last played track or default to Al-Fatiha
        let lastTrackId = UserDefaults.standard.integer(forKey: "LastPlayedTrackId")
        if lastTrackId > 0, let track = SurahData.allSurahs.first(where: { $0.id == lastTrackId }) {
            loadAudio(track: track, autoPlay: false)
        } else if let firstTrack = SurahData.allSurahs.first {
            // Default to first track (Al-Fatiha) but don't play
            loadAudio(track: firstTrack, autoPlay: false)
        }
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

        // Save current track ID
        UserDefaults.standard.set(track.id, forKey: "LastPlayedTrackId")
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
        guard let currentTrack = selectedTrack else {
            return
        }
        
        let currentIndex = currentTrack.id - 1
        let nextIndex = (currentIndex + 1) % SurahData.allSurahs.count
        loadAudio(track: SurahData.allSurahs[nextIndex])
    }
    
    func previousTrack() {
        saveCurrentPosition()
        guard let currentTrack = selectedTrack else {
            return
        }
        
        let currentIndex = currentTrack.id - 1
        let previousIndex = (currentIndex - 1 + SurahData.allSurahs.count) % SurahData.allSurahs.count
        loadAudio(track: SurahData.allSurahs[previousIndex])
    }
    
    // MARK: - Audio Loading
    func loadAudio(track: Surah, autoPlay: Bool = true) {
        isLoading = true
        selectedTrack = track

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
            print("Audiodatei nicht gefunden: \(filename).mp3")
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
            
            if autoPlay {
                audioPlayer?.play()
                isPlaying = true
                setupTimer()
            } else {
                isPlaying = false
            }

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
                    print("Unbenutzte Audiodatei gelöscht: \(fileName)")
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
