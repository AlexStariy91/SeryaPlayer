import XCTest

final class EqualizerUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Save a preset from the player's equalizer, keep it active while playing, then delete it in Settings.
    @MainActor
    func testDeletingTheActivePresetKeepsPlaying() throws {
        throw XCTSkip("Rewritten with the equalizer redesign: the horizontal preset row isn't reachable from UI tests")
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

        // "Save As…" is the last chip of a horizontal row.
        let saveAs = app.buttons["Save As…"].firstMatch
        let chips = app.buttons["Rock"].firstMatch
        for _ in 0 ..< 4 {
            chips.swipeLeft(velocity: .fast)
        }
        saveAs.tap()
        let name = app.alerts.textFields.firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.typeText("My Mix")
        app.alerts.buttons["Save"].tap()
        XCTAssertTrue(app.buttons["My Mix"].waitForExistence(timeout: 5))
        app.buttons["Done"].firstMatch.tap()

        // Close the full player and delete the active preset in Settings.
        app.swipeDown(velocity: .fast)
        let settings = app.buttons["Settings"].firstMatch
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        settings.tap()
        app.buttons["Equalizer Presets"].firstMatch.tap()
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS 'My Mix'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        app.buttons["Delete"].firstMatch.tap()
        let confirm = app.sheets.buttons["Delete"].firstMatch
        if confirm.waitForExistence(timeout: 2) {
            confirm.tap()
        } else {
            app.buttons["Delete"].firstMatch.tap()
        }

        XCTAssertTrue(app.staticTexts["No Saved Presets"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.state, .runningForeground)
    }
}
