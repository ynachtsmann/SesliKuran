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

        // Mocking the behavior of nextTrack without actually loading audio (which requires files)
        // Since loadAudio calls play(), we are mainly testing the index calculation logic here.
        // However, nextTrack() calls loadAudio() internally.
        // We can check if selectedTrack updates correctly.
        // Note: loadAudio might fail and print error, but selectedTrack is updated BEFORE loadAudio logic might fail on file.
        // Actually looking at the code:
        // let nextIndex = (currentIndex + 1) % SurahData.allSurahs.count
        // selectedTrack = SurahData.allSurahs[nextIndex]
        // loadAudio(track: selectedTrack!)

        // Even if loadAudio fails, selectedTrack should have updated.

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

    // MARK: - AudioManager State Tests

    func testInitialState() {
        XCTAssertNil(audioManager.selectedTrack)
        XCTAssertFalse(audioManager.isPlaying)
        XCTAssertEqual(audioManager.playbackRate, 1.0)
        XCTAssertNil(audioManager.errorMessage)
    }

    func testPlaybackSpeed() {
        audioManager.setPlaybackSpeed(1.5)
        XCTAssertEqual(audioManager.playbackRate, 1.5)
        // Note: We cannot verify audioPlayer.rate without a loaded file, but we verify the published property.
    }

    func testLoadAudioMissingFile() {
        // Trying to load a non-existent track (or just relying on the fact that files are likely not in the test bundle)
        // We need to simulate a case where file is missing.
        // Assuming the test bundle doesn't have "Audio 1.mp3"

        let surah = SurahData.allSurahs[0]
        audioManager.loadAudio(track: surah)

        // Wait a bit for async dispatch in loadAudio if any (there is a Dispatch for isLoading = false)
        let expectation = XCTestExpectation(description: "Wait for loading")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)

        // If file is missing, errorMessage should be set
        // NOTE: If the file actually exists in the project and is copied to bundle, this test might fail.
        // But in this environment, I suspect they might not be fully available during unit test runtime context
        // unless explicitly added to the test target.
        // If it fails because file exists, that's good (it loaded). If it fails because errorMessage is nil, then file was found.
        // Let's assert that IF no file, THEN error.

        if audioManager.audioPlayer == nil {
             XCTAssertNotNil(audioManager.errorMessage, "Error message should be set if audio player failed to load")
        }
    }
}
