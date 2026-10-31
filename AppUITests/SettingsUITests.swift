import XCTest

final class SettingsUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// The theme choice is persisted: it is still selected after closing and reopening Settings.
    @MainActor
    func testThemeSelectionPersists() {
        let app = XCUIApplication.launchForUITests(seeded: false)

        app.buttons["Settings"].firstMatch.tap()
        let dark = app.segmentedControls.buttons["Dark"]
        XCTAssertTrue(dark.waitForExistence(timeout: 5))
        dark.tap()
        XCTAssertTrue(dark.isSelected)

        app.buttons["Done"].tap()
        app.buttons["Settings"].firstMatch.tap()
        XCTAssertTrue(app.segmentedControls.buttons["Dark"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.segmentedControls.buttons["Dark"].isSelected)
    }
}
