import XCTest

final class PlaybackUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Import (seeded on launch) → play from All Tracks → skip to the next track in the mini player.
    @MainActor
    func testPlayAndSkipToNextTrack() {
        let app = XCUIApplication.launchForUITests()

        app.buttons["All Tracks"].firstMatch.tap()
        let alpha = app.staticTexts["Alpha"].firstMatch
        XCTAssertTrue(alpha.waitForExistence(timeout: 10), "seeded tracks were not imported")
        alpha.tap()

        let next = app.buttons["Next Track"].firstMatch
        XCTAssertTrue(next.waitForExistence(timeout: 5), "mini player didn't appear")
        XCTAssertTrue(app.buttons["Pause"].firstMatch.exists, "playback didn't start")

        // "Bravo" is listed in All Tracks; once it plays, the mini player shows it too.
        let bravo = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'Bravo'"))
        let before = bravo.count
        next.tap()
        expectation(for: NSPredicate(format: "count > %d", before), evaluatedWith: bravo)
        waitForExpectations(timeout: 5)
    }
}
