import XCTest

final class LibraryUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testCreatePlaylist() {
        // An empty library shows only the import prompt, so start with tracks.
        let app = XCUIApplication.launchForUITests()

        let playlists = app.buttons["Playlists"].firstMatch
        XCTAssertTrue(playlists.waitForExistence(timeout: 10))
        playlists.tap()
        app.buttons["playlists.new"].tap()

        let name = app.alerts.textFields.firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.typeText("Road Trip")
        app.alerts.buttons["Create"].tap()

        XCTAssertTrue(app.staticTexts["Road Trip"].waitForExistence(timeout: 5))
    }
}
