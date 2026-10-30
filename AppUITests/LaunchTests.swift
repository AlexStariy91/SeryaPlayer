import XCTest

final class LaunchTests: XCTestCase {
    @MainActor
    func testLaunchShowsTabs() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Library"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Folders"].exists)
        XCTAssertTrue(app.tabBars.buttons["Browser"].exists)
    }
}
