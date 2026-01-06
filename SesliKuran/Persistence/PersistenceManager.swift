import Foundation

// MARK: - App Errors
enum AppError: Error, LocalizedError {
    case fileNotFound(String)
    case fileCorrupt
    case installationDamaged
    case saveFailed
    case decodingFailed
    case unknown

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let filename):
            return "Die Datei '\(filename)' wurde nicht gefunden."
        case .fileCorrupt:
            return "Die Datei ist beschädigt und kann nicht abgespielt werden."
        case .installationDamaged:
            return "Installation beschädigt. Bitte installieren Sie die App neu."
        case .saveFailed:
            return "Fehler beim Speichern der Daten."
        case .decodingFailed:
            return "Fehler beim Laden der gespeicherten Daten."
        case .unknown:
            return "Ein unbekannter Fehler ist aufgetreten."
        }
    }
}

// MARK: - Persistent Data Model
struct StorageData: Codable {
    var lastPlayedPositions: [String: TimeInterval] = [:]
    var isDarkMode: Bool = true // Default to Dark Mode (Cyberpunk theme)
    var playbackSpeed: Float = 1.0
    var lastActiveTrackID: Int = 1 // Default to Al-Fatiha
    var favorites: Set<Int> = []

    // Add versioning for future migrations
    var version: Int = 1
}

// MARK: - Persistence Manager (Atomic Actor)
actor PersistenceManager {
    static let shared = PersistenceManager()

    private let fileName = "user_data.json"

    // Cache the data in memory for fast access
    // This is the Source of Truth.
    private var cachedData: StorageData

    private init() {
        self.cachedData = StorageData()

        // SYNC Load on Init to prevent Race Conditions
        // Since this runs on the Actor's background thread when shared is first accessed,
        // it might block the *caller* briefly if they await it, but it ensures correctness.
        // But `init` is synchronous.
        // We cannot call async functions in init unless in Task.
        // To be SAFE and "Mission Critical", we perform a BLOCKING READ here.
        // For a local JSON file < 50KB, this is < 5ms. Acceptable for startup safety.

        let fileManager = FileManager.default
        if let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            let url = documentDirectory.appendingPathComponent("user_data.json")
            do {
                let data = try Data(contentsOf: url)
                let decoded = try JSONDecoder().decode(StorageData.self, from: data)
                self.cachedData = decoded
            } catch {
                print("Persistence: No saved data found or decoding failed. Using defaults. (\(error))")
            }
        }
    }

    private func fileURL() throws -> URL {
        let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentDirectory.appendingPathComponent(fileName)
    }

    // MARK: - Load
    func load() -> StorageData {
        // Return memory cache immediately
        return self.cachedData
    }

    // MARK: - Save to Disk
    // This is private and called by update methods.
    // It takes a SNAPSHOT of data to save, to avoid race conditions if `cachedData` changes again.
    private func saveToDisk(_ dataToSave: StorageData) {
        do {
            let url = try fileURL()
            let tempUrl = try fileURL().appendingPathExtension("tmp")

            let encoded = try JSONEncoder().encode(dataToSave)

            // 1. Write to temp file
            try encoded.write(to: tempUrl, options: [.atomic, .completeFileProtection])

            // 2. Atomic Swap
            if FileManager.default.fileExists(atPath: url.path) {
                _ = try FileManager.default.replaceItemAt(url, withItemAt: tempUrl, backupItemName: nil, options: .usingNewMetadataOnly)
            } else {
                try FileManager.default.moveItem(at: tempUrl, to: url)
            }
            print("Persistence: Data saved successfully.")
        } catch {
            print("Persistence: Save failed: \(error)")
        }
    }

    // MARK: - Helper Accessors (Thread Safe Updates)

    func updateLastPlayedPosition(trackId: Int, time: TimeInterval) {
        // 1. Update In-Memory State Immediately (Synchronous within Actor)
        self.cachedData.lastPlayedPositions["Audio \(trackId)"] = time
        self.cachedData.lastActiveTrackID = trackId

        // 2. Capture Snapshot
        let snapshot = self.cachedData

        // 3. Fire and Forget Disk Write
        Task {
            self.saveToDisk(snapshot)
        }
    }

    func updateTheme(isDarkMode: Bool) {
        self.cachedData.isDarkMode = isDarkMode
        let snapshot = self.cachedData
        Task {
            self.saveToDisk(snapshot)
        }
    }

    func updatePlaybackSpeed(_ speed: Float) {
        self.cachedData.playbackSpeed = speed
        let snapshot = self.cachedData
        Task {
            self.saveToDisk(snapshot)
        }
    }

    // MARK: - Getters
    func getIsDarkMode() -> Bool {
        return cachedData.isDarkMode
    }

    func getLastActiveTrackID() -> Int {
        return cachedData.lastActiveTrackID
    }

    func getLastPosition(for trackId: Int) -> TimeInterval {
        return cachedData.lastPlayedPositions["Audio \(trackId)"] ?? 0
    }

    func getPlaybackSpeed() -> Float {
        return cachedData.playbackSpeed
    }
}
