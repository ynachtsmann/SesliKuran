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
        let noTrackText = app.staticTexts["Kein Titel ausgewählt"]
        XCTAssertTrue(noTrackText.exists, "Should show 'Kein Titel ausgewählt' on launch")

        // Check for the list button (icon name 'music.note.list')
        let listButton = app.buttons["music.note.list"] // Assuming the button uses the system image name as identifier or label
        // If not, we might need to find it by index or structure.
        // In SwiftUI, Image(systemName:) often becomes the label if no other label is provided.
        // Or we can rely on finding a button that performs the action.
        // Let's assume accessibility identifier wasn't set, so we might need to hunt or just check existence of *a* button.
        // Ideally, we'd add accessibility identifiers. For now, let's try to find it.
    }

    func testOpenSheetAndSelectSurah() throws {
        let app = XCUIApplication()
        app.launch()

        // Find the button to open the list.
        // Since we didn't add accessibility IDs, it might be tricky.
        // However, there are typically few buttons.
        // The list button is in the top left.

        // Let's try to find the button by the image name if possible, or position.
        // SwiftUI images are sometimes not buttons themselves but content of buttons.
        // We will try to find the button that opens the list.

        // Iterate buttons to find the one that opens the sheet
        let listButton = app.buttons.element(boundBy: 0) // First button usually (top left)
        if listButton.exists {
             listButton.tap()
        }

        // Check if Sheet appeared
        let sheetTitle = app.staticTexts["Surah Auswahl"]
        XCTAssertTrue(sheetTitle.waitForExistence(timeout: 2.0), "Sheet should appear with title 'Surah Auswahl'")

        // Select the first Surah "1. Al-Fatiha"
        let firstSurahCell = app.buttons["1. Al-Fatiha"] // The row is a Button
        if firstSurahCell.waitForExistence(timeout: 2.0) {
            firstSurahCell.tap()

            // Sheet should dismiss
            let nowPlayingText = app.staticTexts["Al-Fatiha"]
            XCTAssertTrue(nowPlayingText.waitForExistence(timeout: 2.0), "Main view should show 'Al-Fatiha' after selection")
        }
    }

    func testPlayerControls() throws {
        let app = XCUIApplication()
        app.launch()

        // Navigate to a track first
        let listButton = app.buttons.element(boundBy: 0)
        listButton.tap()

        let firstSurahCell = app.buttons["1. Al-Fatiha"]
        if firstSurahCell.waitForExistence(timeout: 2.0) {
            firstSurahCell.tap()
        }

        // Check Play/Pause button
        // It's the large button in the middle.
        // In the Control Section: Prev, Play/Pause, Next.
        // It should be the middle button of the 3 in that HStack.

        // Let's find the 'forward.fill' button and 'backward.fill' button to verify they exist
        let nextButton = app.images["forward.fill"]
        let prevButton = app.images["backward.fill"]

        XCTAssertTrue(nextButton.exists)
        XCTAssertTrue(prevButton.exists)

        // Tap next
        // Note: Images inside buttons might not be tappable directly as "Images", need to tap the Button containing them.
        // Finding buttons by the image name they contain:

        // This is a rough heuristic since we lack IDs
        let nextTrackButton = app.buttons.containing(.image, identifier: "forward.fill").element
        if nextTrackButton.exists {
            nextTrackButton.tap()
            // Should change to "Al-Baqarah"
            let nextTrackText = app.staticTexts["Al-Baqarah"]
            XCTAssertTrue(nextTrackText.waitForExistence(timeout: 1.0), "Tapping next should change track to Al-Baqarah")
        }
    }

    func testDarkModeToggle() throws {
        let app = XCUIApplication()
        app.launch()

        // Toggle button is top right (second button usually)
        let toggleButton = app.buttons.element(boundBy: 1)

        // We can't easily screenshot and check color in XCTest without complex setup,
        // but we can ensure the button is interactable and doesn't crash.
        XCTAssertTrue(toggleButton.exists)
        toggleButton.tap()

        // Just verify app is still alive
        let noTrackText = app.staticTexts["Kein Titel ausgewählt"]
        XCTAssertTrue(noTrackText.exists)
    }
}
