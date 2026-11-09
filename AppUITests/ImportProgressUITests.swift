import XCTest

final class ImportProgressUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// With an import running and progress ticks arriving: the ring replaces "+" on Library home, quick taps on
    /// "All Tracks" push and pop without a crash, and "+" comes back once the import ends.
    @MainActor
    func testRingReplacesPlusDuringImportAndSurvivesQuickNavigation() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        let fixtures = try XCTUnwrap(Bundle(for: LaunchTests.self).url(forResource: "Fixtures", withExtension: nil))
        app.launchEnvironment["SP_UITEST_SEED_DIR"] = fixtures.path
        app.launchEnvironment["SP_UITEST_HOLD_IMPORT"] = "1"
        app.launch()

        let ring = app.descendants(matching: .any)["library.importProgress"]
        let plus = app.buttons["library.import"]
        XCTAssertTrue(ring.waitForExistence(timeout: 10), "the ring should be shown while the import runs")
        XCTAssertFalse(plus.exists, "the ring takes the place of \"+\"")

        let allTracks = app.buttons["library.allTracks"]
        XCTAssertTrue(allTracks.waitForExistence(timeout: 20), "the library did not fill during the import")
        // Resolved once; two taps fire back to back, like a fast double tap.
        let frame = allTracks.frame
        let point = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: frame.midX, dy: frame.midY))
        point.tap()
        point.tap()

        XCTAssertTrue(app.navigationBars["All Tracks"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.state, .runningForeground)
        // The second tap lands on the pushed screen's search field; close the search again.
        let closeSearch = app.buttons.matching(NSPredicate(format: "label IN {'Close', 'Cancel'}")).firstMatch
        if closeSearch.waitForExistence(timeout: 2) {
            closeSearch.tap()
        }
        XCTAssertTrue(app.descendants(matching: .any)["library.importProgress"].exists, "pushed screens keep a ring next to their buttons")

        app.navigationBars["All Tracks"].buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Library"].waitForExistence(timeout: 5))

        XCTAssertTrue(plus.waitForExistence(timeout: 40), "\"+\" should return when the import ends")
        XCTAssertFalse(ring.exists)
        XCTAssertEqual(app.state, .runningForeground)
    }
}
