
import XCTest
@testable import SesliKuran

@MainActor
class ReproduceStickyStateTests: XCTestCase {

    var audioManager: AudioManager!

    override func setUp() {
        super.setUp()
        audioManager = AudioManager()
    }

    override func tearDown() {
        audioManager = nil
        super.tearDown()
    }

    // Test for Issue 1: Restart on Selection
    func testManualSelectionResetsToZero() {
        // Given: A track that exists (Surah 1 is in bundle)
        let surah1 = SurahData.allSurahs[0]

        // Load it once to simulate "Last played position"
        audioManager.loadAudio(track: surah1, autoPlay: false, resumePlayback: true)

        // Simulate playing to 10 seconds
        audioManager.currentTime = 10.0
        // We can't easily mock PersistenceManager in this integration-style test without dependency injection,
        // but we can trust the logic flow we implemented:
        // loadAudio check `resumePlayback`.

        // When: User manually selects the track again (resumePlayback: false)
        audioManager.loadAudio(track: surah1, autoPlay: false, resumePlayback: false)

        // Wait for async restore
        let expectation = XCTestExpectation(description: "Wait for position restore")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Assert: It should be 0.
        XCTAssertEqual(audioManager.currentTime, 0, accuracy: 0.1, "Manual selection should reset time to 0")
    }

    // Test for Issue 2: Sticky State on Missing File
    func testMissingFileUnloadsPlayer() {
        // Given: Surah 1 loaded
        let surah1 = SurahData.allSurahs[0] // Exists
        audioManager.loadAudio(track: surah1, autoPlay: false)

        // Ensure player is loaded
        XCTAssertNotNil(audioManager.value(forKey: "audioPlayer"), "AudioPlayer should be initialized for Surah 1")

        // When: Load a missing track (Surah 999)
        let surahMissing = Surah(id: 999, name: "Missing", arabicName: "", germanName: "")
        audioManager.loadAudio(track: surahMissing, autoPlay: true)

        // Then:
        // 1. Selected Track should be 999
        XCTAssertEqual(audioManager.selectedTrack?.id, 999)

        // 2. Audio Player should be NIL (Unloaded)
        let player = audioManager.value(forKey: "audioPlayer")
        XCTAssertNil(player, "AudioPlayer should be nil (unloaded) when file is missing")
    }
}
