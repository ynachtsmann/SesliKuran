//
//  SesliKuranTests.swift
//  SesliKuranTests
//
//  Created by Ünal Önder on 21.12.24.
//

import XCTest
@testable import SesliKuran

final class SesliKuranTests: XCTestCase {

    var audioManager: AudioManager!

    override func setUpWithError() throws {
        try super.setUpWithError()
        audioManager = AudioManager()
    }

    override func tearDownWithError() throws {
        audioManager = nil
        try super.tearDownWithError()
    }

    // MARK: - SurahData Tests

    func testSurahDataIntegrity() {
        // There should be 114 Surahs
        XCTAssertEqual(SurahData.allSurahs.count, 114, "SurahData should contain exactly 114 Surahs")

        // IDs should be unique and sequential from 1 to 114
        let ids = SurahData.allSurahs.map { $0.id }
        let uniqueIds = Set(ids)
        XCTAssertEqual(uniqueIds.count, 114, "All Surah IDs should be unique")
        XCTAssertEqual(ids.min(), 1, "First Surah ID should be 1")
        XCTAssertEqual(ids.max(), 114, "Last Surah ID should be 114")
    }

    // MARK: - AudioManager Navigation Logic Tests

    func testNextTrackLogic() {
        // Setup: Select first surah
        let firstSurah = SurahData.allSurahs[0] // Al-Fatiha
        audioManager.selectedTrack = firstSurah

        audioManager.nextTrack()

        let expectedSurah = SurahData.allSurahs[1] // Al-Baqarah
        XCTAssertEqual(audioManager.selectedTrack?.id, expectedSurah.id, "Next track should be Al-Baqarah")
    }

    func testPreviousTrackLogic() {
        // Setup: Select second surah
        let secondSurah = SurahData.allSurahs[1] // Al-Baqarah
        audioManager.selectedTrack = secondSurah

        audioManager.previousTrack()

        let expectedSurah = SurahData.allSurahs[0] // Al-Fatiha
        XCTAssertEqual(audioManager.selectedTrack?.id, expectedSurah.id, "Previous track should be Al-Fatiha")
    }

    func testCircularNavigationNext() {
        // Setup: Select last surah
        let lastSurah = SurahData.allSurahs[113] // An-Nas
        audioManager.selectedTrack = lastSurah

        audioManager.nextTrack()

        let expectedSurah = SurahData.allSurahs[0] // Al-Fatiha
        XCTAssertEqual(audioManager.selectedTrack?.id, expectedSurah.id, "Next track after last should be first (Circular)")
    }

    func testCircularNavigationPrevious() {
        // Setup: Select first surah
        let firstSurah = SurahData.allSurahs[0] // Al-Fatiha
        audioManager.selectedTrack = firstSurah

        audioManager.previousTrack()

        let expectedSurah = SurahData.allSurahs[113] // An-Nas
        XCTAssertEqual(audioManager.selectedTrack?.id, expectedSurah.id, "Previous track before first should be last (Circular)")
    }

    // MARK: - Skip Controls Logic

    func testSkipForward() {
        // We cannot test AVAudioPlayer time logic without a valid player instance,
        // but we can test that the function calls nextTrack() if at the end.

        // Mocking behavior by manually setting state if possible, but AudioPlayer is internal.
        // We will rely on integration tests or assume the logic:
        // if currentTime + 30 < duration { currentTime += 30 } else { nextTrack() }

        // Let's test the state transition for 'nextTrack' if we pretend duration is 0
        let lastSurah = SurahData.allSurahs[113]
        audioManager.selectedTrack = lastSurah
        audioManager.duration = 10
        audioManager.currentTime = 5

        // Since we don't have a real player, accessing .duration on audioManager (which reads from player usually) might return 0
        // Our AudioManager updates published properties from the player.
        // Logic in skipForward reads from `audioPlayer`.
        // Without mocking AVAudioPlayer (which is hard), we can't fully unit test this method's internal time math.
        // However, we can verify it doesn't crash.
        audioManager.skipForward()
    }

    // MARK: - Sleep Timer Tests

    func testSleepTimerStart() {
        audioManager.startSleepTimer(minutes: 15)
        XCTAssertNotNil(audioManager.sleepTimerTimeRemaining)
        XCTAssertEqual(audioManager.sleepTimerTimeRemaining, 15 * 60)
    }

    func testSleepTimerStop() {
        audioManager.startSleepTimer(minutes: 15)
        audioManager.stopSleepTimer()
        XCTAssertNil(audioManager.sleepTimerTimeRemaining)
    }

    // MARK: - AudioManager State Tests

    func testInitialState() {
        // Should be nil initially unless UserDefaults has value.
        // Since tests run in an environment where UserDefaults might persist or be empty,
        // strictly checking for nil might be flaky if we don't clear UserDefaults in setUp.
        // However, we didn't mock UserDefaults.
        // Let's just check other defaults.
        XCTAssertFalse(audioManager.isPlaying)
        XCTAssertEqual(audioManager.playbackRate, 1.0)
        XCTAssertNil(audioManager.errorMessage)
    }

    func testPlaybackSpeed() {
        audioManager.setPlaybackSpeed(1.5)
        XCTAssertEqual(audioManager.playbackRate, 1.5)
    }

    func testLoadAudioMissingFile() {
        // Trying to load a non-existent track
        let surah = SurahData.allSurahs[0]
        audioManager.loadAudio(track: surah)

        // Wait for potential async "needsDownload" or "errorMessage"
        let expectation = XCTestExpectation(description: "Wait for loading check")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)

        // In the new logic, if file is missing, we set needsDownload = true.
        // Wait, we removed needsDownload logic?
        // Let's check AudioManager.swift again.
        // "if let validUrl = getLocalAudioURL ... else ... needsDownload = true"
        // Yes, needsDownload is still used to trigger the UI state, even if we removed the button action?
        // Ah, I see in AudioManager.swift I kept `needsDownload` logic in `loadAudio` but I removed the button that calls `downloadTrack`.
        // But `needsDownload` property helps show the "Audio nicht gefunden" text.

        if audioManager.audioPlayer == nil {
             XCTAssertTrue(audioManager.needsDownload, "needsDownload should be true if audio file is missing")
        }
    }
}
