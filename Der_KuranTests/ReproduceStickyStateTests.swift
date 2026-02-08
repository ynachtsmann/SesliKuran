
import XCTest
@testable import Der_Kuran

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
        // We simulate a resume by passing an explicit start time (e.g. 10.0s)
        audioManager.loadAudio(track: surah1, startTime: 10.0, autoPlay: false)
        audioManager.currentTime = 10.0 // Manually set state to confirm transition

        // When: User manually selects the track again (Default startTime is 0)
        audioManager.loadAudio(track: surah1, autoPlay: false)

        // Wait for potential async state updates (though loadAudio is synchronous in logic, state updates might propagate)
        let expectation = XCTestExpectation(description: "Wait for state stabilization")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Assert: It should be 0 (Start from beginning)
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
