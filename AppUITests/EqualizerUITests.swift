import XCTest

final class EqualizerUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Save a preset from the player's equalizer, keep it active while playing, then delete it in Settings.
    @MainActor
    func testDeletingTheActivePresetKeepsPlaying() {
        let app = XCUIApplication.launchForUITests()

        app.buttons["All Tracks"].firstMatch.tap()
        let alpha = app.staticTexts["Alpha"].firstMatch
        XCTAssertTrue(alpha.waitForExistence(timeout: 10))
        alpha.tap()

        // Open the full player from the mini player, then the equalizer.
        let miniPlayer = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Alpha'")).firstMatch
        XCTAssertTrue(miniPlayer.waitForExistence(timeout: 5))
        miniPlayer.tap()
        XCTAssertTrue(app.buttons["Queue"].waitForExistence(timeout: 5))
        sleep(1) // let the zoom transition finish
        app.buttons["Equalizer"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Equalizer"].waitForExistence(timeout: 5))

        // Save the current curve; the new preset becomes the selected chip.
        let saveAs = app.buttons["equalizer.saveAs"]
        XCTAssertTrue(saveAs.waitForExistence(timeout: 5))
        saveAs.tap()
        let name = app.alerts.textFields.firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.typeText("My Mix")
        app.alerts.buttons["Save"].tap()
        let myMix = app.buttons["My Mix"].firstMatch
        XCTAssertTrue(myMix.waitForExistence(timeout: 5))
        XCTAssertTrue(myMix.isSelected)
        app.navigationBars["Equalizer"].buttons["Done"].tap()

        // Close the full player and delete the active preset in Settings.
        XCTAssertTrue(app.navigationBars["Equalizer"].waitForNonExistence(timeout: 5))
        app.buttons["Close Player"].tap()
        let settings = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        settings.tap()
        app.buttons["Equalizer Presets"].firstMatch.tap()
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS 'My Mix'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.swipeLeft()
        let swipeDelete = app.buttons["Delete"].firstMatch
        XCTAssertTrue(swipeDelete.waitForExistence(timeout: 5))
        swipeDelete.tap()
        // The confirmation dialog is an action sheet on iPhone.
        let confirm = app.sheets.buttons["Delete"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()

        XCTAssertTrue(app.staticTexts["No Saved Presets"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.state, .runningForeground)
    }
}
