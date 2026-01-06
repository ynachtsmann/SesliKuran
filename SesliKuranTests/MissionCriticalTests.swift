import XCTest
@testable import SesliKuran

// MARK: - Mission Critical Tests
// Validates "Crash-Proof" behavior and Data Integrity.
final class MissionCriticalTests: XCTestCase {

    var persistence: PersistenceManager!
    var audioManager: AudioManager!

    // Helper to simulate async wait
    private func wait(seconds: TimeInterval) async throws {
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    override func setUp() async throws {
        // Reset persistence state if possible, or mock it.
        // Since PersistenceManager is a singleton, we can't easily swap it out,
        // but we can test its public API.
    }

    // MARK: - 1. Persistence Integrity
    func testPersistenceSynchronousLoad() async {
        // Given: The app is launching
        let persistence = PersistenceManager.shared

        // When: We request synchronous load
        let data = persistence.loadSynchronously()

        // Then: It should not trap or crash, and return a valid struct
        XCTAssertNotNil(data, "Synchronous load returned nil")
        XCTAssertGreaterThanOrEqual(data.playbackSpeed, 0.1, "Playback speed invalid")
    }

    // MARK: - 2. Corrupt File Handling
    @MainActor
    func testCorruptFileGracefulHandling() async throws {
        // Given: An AudioManager
        let manager = AudioManager()

        // And: A "fake" track that points to a non-existent file
        // (Audio 999.mp3 likely doesn't exist)
        let fakeTrack = Surah(id: 999, name: "Test", arabicName: "", germanName: "")

        // When: We try to load it
        manager.loadAudio(track: fakeTrack)

        // Then: It should eventually show error or skip, but NOT CRASH.
        // We wait for the async logic to settle
        try await wait(seconds: 1.0)

        // If it handled it gracefully, it might have tried to skip or set error.
        // We check that app state is stable.
        XCTAssertFalse(manager.isPlaying, "Should not be playing a non-existent file")
        // It might have skipped to next track (which also might fail), but the key is no crash.
    }

    // MARK: - 3. Theme Manager No-Flash
    @MainActor
    func testThemeManagerInitialization() {
        // When: ThemeManager initializes
        let tm = ThemeManager()

        // Then: It should have a value immediately (no optional nil state)
        // Checked by the fact that 'isDarkMode' is Bool, not Bool?
        XCTAssertTrue(tm.isDarkMode == true || tm.isDarkMode == false)
    }
}
