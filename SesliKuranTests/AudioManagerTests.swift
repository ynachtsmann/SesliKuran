//
//  AudioManagerTests.swift
//  SesliKuranTests
//
//  Created by Jules on 2024-05-23.
//

import XCTest
@testable import SesliKuran

@MainActor
class AudioManagerTests: XCTestCase {

    var audioManager: AudioManager!

    override func setUp() {
        super.setUp()
        audioManager = AudioManager()
    }

    override func tearDown() {
        audioManager = nil
        super.tearDown()
    }

    func testLoadAudioMissingFile() {
        // Given
        // Use a dummy Surah ID that definitely doesn't exist as a file
        let dummySurah = Surah(id: 999, name: "Test Surah", arabicName: "Test", germanName: "Test German")

        // When
        audioManager.loadAudio(track: dummySurah)

        // Then
        XCTAssertTrue(audioManager.showError, "showError should be true when audio file is missing")
        XCTAssertFalse(audioManager.errorMessage.isEmpty, "errorMessage should not be empty")
        XCTAssertNil(audioManager.audioPlayer, "audioPlayer should be nil after loading a missing file")
        XCTAssertFalse(audioManager.isPlaying, "isPlaying should be false")
        XCTAssertEqual(audioManager.duration, 0, "duration should be 0")
        XCTAssertEqual(audioManager.currentTime, 0, "currentTime should be 0")

        // Verify part of the expected error message
        XCTAssertTrue(audioManager.errorMessage.contains("nicht gefunden"), "Error message should mention 'nicht gefunden'")
        XCTAssertTrue(audioManager.errorMessage.contains("iTunes File Sharing"), "Error message should mention 'iTunes File Sharing'")
    }
}
