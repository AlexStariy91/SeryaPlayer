import XCTest

final class SettingsUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// The theme choice is persisted: it is still selected after leaving and reopening the Settings tab.
    @MainActor
    func testThemeSelectionPersists() {
        let app = XCUIApplication.launchForUITests(seeded: false)

        app.tabBars.buttons["Settings"].tap()
        let dark = app.segmentedControls.buttons["Dark"]
        XCTAssertTrue(dark.waitForExistence(timeout: 5))
        dark.tap()
        XCTAssertTrue(dark.isSelected)

        app.tabBars.buttons["Library"].tap()
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.segmentedControls.buttons["Dark"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.segmentedControls.buttons["Dark"].isSelected)
    }
}
