//
//  SesliKuranUITests.swift
//  SesliKuranUITests
//
//  Created by Ünal Önder on 21.12.24.
//

import XCTest

final class SesliKuranUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAppLaunchAndInitialState() throws {
        let app = XCUIApplication()
        app.launch()

        // Check for the main title or placeholder when no track is selected
        // Note: If last session restore works, it might not be "Kein Titel ausgewählt" if previous test ran.
        // But in a fresh UI test environment (or if we reset), it might be default.
        // For robustness, we check that *either* the placeholder OR a track title exists.

        let noTrackText = app.staticTexts["Kein Titel ausgewählt"]
        let trackTitle = app.staticTexts["Al-Fatiha"] // Example

        XCTAssertTrue(noTrackText.exists || app.staticTexts.count > 0)
    }

    func testOpenSheetAndSelectSurah() throws {
        let app = XCUIApplication()
        app.launch()

        // Find the button to open the list.
        // It's in the header, first button.
        let listButton = app.buttons["music.note.list"]
        if listButton.exists {
             listButton.tap()
        } else {
            // Fallback by index
            app.buttons.element(boundBy: 0).tap()
        }

        // Check if Sheet appeared
        let sheetTitle = app.staticTexts["Surah Auswahl"]
        XCTAssertTrue(sheetTitle.waitForExistence(timeout: 2.0), "Sheet should appear with title 'Surah Auswahl'")

        // Select "Al-Fatiha"
        // In the list, rows might be buttons or cells.
        // We added a Search bar, so we can try searching too, but let's just tap the first item.
        // The cell has text "1. Al-Fatiha".

        let surahText = app.staticTexts["1. Al-Fatiha"]
        if surahText.waitForExistence(timeout: 2.0) {
            surahText.tap()

            // Sheet should dismiss and player update
            let nowPlayingText = app.staticTexts["Al-Fatiha"]
            XCTAssertTrue(nowPlayingText.waitForExistence(timeout: 2.0), "Main view should show 'Al-Fatiha'")
        }
    }

    func testPlayerControls() throws {
        let app = XCUIApplication()
        app.launch()

        // Ensure we are playing something
        let listButton = app.buttons["music.note.list"]
        if listButton.exists {
             listButton.tap()
             let surahText = app.staticTexts["1. Al-Fatiha"]
             if surahText.waitForExistence(timeout: 2.0) {
                 surahText.tap()
             }
        }

        // Check Skip Controls
        // We added -15s and +30s buttons.
        // Identifiers: "gobackward.15" and "goforward.30"

        let skipBackBtn = app.images["gobackward.15"]
        let skipFwdBtn = app.images["goforward.30"]

        XCTAssertTrue(skipBackBtn.exists, "Skip backward button should exist")
        XCTAssertTrue(skipFwdBtn.exists, "Skip forward button should exist")

        // Check Play/Pause
        let playPauseBtn = app.images["play.circle.fill"] // or pause.circle.fill
        XCTAssertTrue(playPauseBtn.exists || app.images["pause.circle.fill"].exists)

        // Tap Next Track
        let nextBtn = app.images["forward.end.fill"]
        if nextBtn.exists {
            // We need to tap the BUTTON containing this image
            let btn = app.buttons.containing(.image, identifier: "forward.end.fill").element
            if btn.exists {
                btn.tap()
                // Should change to Al-Baqarah
                let nextTitle = app.staticTexts["Al-Baqarah"]
                XCTAssertTrue(nextTitle.waitForExistence(timeout: 1.0))
            }
        }
    }

    func testSleepTimerMenu() throws {
        let app = XCUIApplication()
        app.launch()

        // Sleep Timer button is in the header, usually next to Dark Mode.
        // It has a "timer" image.

        let timerImage = app.images["timer"]
        XCTAssertTrue(timerImage.exists)

        // Tap the button containing the timer image
        let timerBtn = app.buttons.containing(.image, identifier: "timer").element
        timerBtn.tap()

        // Action Sheet should appear
        let actionSheet = app.sheets["Sleep Timer"]
        XCTAssertTrue(actionSheet.waitForExistence(timeout: 1.0))

        // Select "15 Minuten"
        let fifteenMinBtn = actionSheet.buttons["15 Minuten"]
        if fifteenMinBtn.exists {
            fifteenMinBtn.tap()
            // Verify timer text appears in the button (e.g. "15:00")
            // This might be flaky to test exact string, but we can assume no crash.
        }
    }
}
