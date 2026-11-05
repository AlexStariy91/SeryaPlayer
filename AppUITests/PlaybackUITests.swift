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
        // Generous: on a loaded CI runner loading the next file took over 5 s (PR #22, 2026-11-03).
        waitForExpectations(timeout: 20)
    }
}

final class PlayerDismissUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// iOS 26: a vertical swipe that starts on the timeline or the volume slider collapses the full player
    /// (the sliders only take horizontal drags), and a horizontal drag still scrubs without closing it.
    @MainActor
    func testSwipeDownFromSlidersClosesPlayer() throws {
        guard #available(iOS 26, *) else {
            throw XCTSkip("The sliders take every drag before iOS 26")
        }
        let app = XCUIApplication.launchForUITests()
        app.buttons["All Tracks"].firstMatch.tap()
        let alpha = app.staticTexts["Alpha"].firstMatch
        XCTAssertTrue(alpha.waitForExistence(timeout: 10))
        alpha.tap()
        let miniPlayer = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Alpha'")).firstMatch
        XCTAssertTrue(miniPlayer.waitForExistence(timeout: 5))
        let close = app.buttons["Close Player"]

        for slider in ["Playback position", "Volume"] {
            if !close.exists {
                miniPlayer.tap()
            }
            XCTAssertTrue(close.waitForExistence(timeout: 5))
            sleep(1) // let the zoom transition finish
            let element = app.descendants(matching: .any)[slider].firstMatch
            XCTAssertTrue(element.exists, slider)

            // Sideways: the slider takes it and the player stays.
            element.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.2))
                .press(forDuration: 0, thenDragTo: element.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.3)))
            XCTAssertFalse(close.waitForNonExistence(timeout: 1), "\(slider): a horizontal drag closed the player")

            // Down: the zoom transition's dismiss pan takes it.
            let start = element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
            start.press(forDuration: 0, thenDragTo: start.withOffset(CGVector(dx: 0, dy: 100)), withVelocity: 1500, thenHoldForDuration: 0)
            XCTAssertTrue(close.waitForNonExistence(timeout: 5), "\(slider): swiping down didn't close the player")
        }
    }
}
