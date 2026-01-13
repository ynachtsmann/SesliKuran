import Foundation

// MARK: - App Errors
// Centralized error handling for the entire data layer
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
// Simple, Codable struct representing the entire user state.
struct StorageData: Codable {
    var lastPlayedPositions: [String: TimeInterval] = [:]
    var isDarkMode: Bool = true // Default to Dark Mode (Cyberpunk theme)
    var playbackSpeed: Float = 1.0
    var lastActiveTrackID: Int = 1 // Default to Al-Fatiha
    var favorites: Set<Int> = []

    // Versioning for future migrations (Zero-Maintenance/Future-Proof)
    var version: Int = 1
}

// MARK: - Persistence Manager (High-Performance Actor)
// Guarantees thread safety for state, and offloads I/O to prevent UI hitches.
actor PersistenceManager {
    static let shared = PersistenceManager()

    private let fileName = "user_data.json"

    // In-Memory Source of Truth (Fast Access)
    private var cachedData: StorageData? // Optional to indicate "not loaded"

    // Serial Queue for non-blocking, safe Disk I/O
    private static let saveQueue = DispatchQueue(label: "com.seslikuran.persistence", qos: .utility)

    private init() {
        // Init is lightweight. Data is loaded lazily or via explicit call to ensure main thread safety.
    }

    // MARK: - Helper: File URL
    nonisolated private func fileURL() throws -> URL {
        let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentDirectory.appendingPathComponent("user_data.json")
    }

    // MARK: - Public API (Actor Isolated)

    // Synchronous Load (Startup Only)
    // Bypasses the actor's lock to provide immediate state for app initialization (e.g., Theme).
    // Safe only during init when no writes are occurring.
    nonisolated func loadSynchronously() -> StorageData {
        do {
            let url = try fileURL()
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(StorageData.self, from: data)
        } catch {
            // If file doesn't exist or is corrupt, return defaults silently.
            return StorageData()
        }
    }

    // Optimized: Loads data if needed, otherwise returns cache.
    // Can be called from Background or Main thread safely.
    func load() -> StorageData {
        if let data = cachedData {
            return data
        }

        // Sync Load (First Time Only)
        // Since this is inside an actor, it serializes access.
        // We do a blocking read here because if the app needs data to start, it MUST wait.
        // For a small JSON file, this is negligible (<5ms).
        let fileManager = FileManager.default
        if let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            let url = documentDirectory.appendingPathComponent("user_data.json")
            if fileManager.fileExists(atPath: url.path) {
                do {
                    let data = try Data(contentsOf: url)
                    let decoded = try JSONDecoder().decode(StorageData.self, from: data)
                    self.cachedData = decoded
                    return decoded
                } catch {
                    print("Persistence: Error loading data (\(error)). Using defaults.")
                }
            }
        }

        let defaults = StorageData()
        self.cachedData = defaults
        return defaults
    }

    func updateLastPlayedPosition(trackId: Int, time: TimeInterval) {
        ensureLoaded()
        self.cachedData?.lastPlayedPositions["Audio \(trackId)"] = time
        self.cachedData?.lastActiveTrackID = trackId
        self.scheduleSave()
    }

    func updateTheme(isDarkMode: Bool) {
        ensureLoaded()
        self.cachedData?.isDarkMode = isDarkMode
        self.scheduleSave()
    }

    func updatePlaybackSpeed(_ speed: Float) {
        ensureLoaded()
        self.cachedData?.playbackSpeed = speed
        self.scheduleSave()
    }

    func updateFavorites(favorites: Set<Int>) {
        ensureLoaded()
        self.cachedData?.favorites = favorites
        self.scheduleSave()
    }

    // MARK: - Getters (Granular)
    // Added to support granular access if needed, though load() is preferred.

    func getIsDarkMode() -> Bool {
        return load().isDarkMode
    }

    func getLastPosition(for trackId: Int) -> TimeInterval {
        return load().lastPlayedPositions["Audio \(trackId)"] ?? 0
    }

    func getLastPlayedSurahId() -> Int {
        return load().lastActiveTrackID
    }

    func getPlaybackSpeed() -> Float {
        return load().playbackSpeed
    }

    func getLastActiveTrackID() -> Int {
        return load().lastActiveTrackID
    }

    // MARK: - Internal Helpers

    private func ensureLoaded() {
        if cachedData == nil {
            _ = load()
        }
    }

    // MARK: - Disk I/O Strategy

    private func scheduleSave() {
        guard let data = self.cachedData else { return }

        // Capture a snapshot of the current state
        let snapshot = data

        // Offload the I/O to a background serial queue.
        PersistenceManager.saveQueue.async {
            self.performSave(snapshot)
        }
    }

    // nonisolated allows this to run on the dispatch queue without entering the actor context
    nonisolated private func performSave(_ data: StorageData) {
        do {
            let url = try fileURL()
            let tempUrl = url.appendingPathExtension("tmp")

            let encoded = try JSONEncoder().encode(data)

            // 1. Write to temp file (Atomic)
            // .atomic write already creates a temp file and renames it, but doing it manually
            // gives us explicit control if needed. However, standard .atomic is sufficient.
            // But to be absolutely "Mission Critical", we use the Manual Temp + Replace approach
            // to ensure no half-written files exist at the final URL.
            try encoded.write(to: tempUrl, options: [.atomic, .completeFileProtection])

            // 2. Atomic Swap (Safe Replace)
            if FileManager.default.fileExists(atPath: url.path) {
                _ = try FileManager.default.replaceItemAt(url, withItemAt: tempUrl, backupItemName: nil, options: .usingNewMetadataOnly)
            } else {
                try FileManager.default.moveItem(at: tempUrl, to: url)
            }
        } catch {
            // Silent Fail / Graceful Degradation
            // We log for debugging, but we do not crash or show alerts.
            print("Persistence: Critical Save Error: \(error)")
        }
    }
}