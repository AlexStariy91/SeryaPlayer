import XCTest

@MainActor
extension XCUIApplication {
    /// Launches into an empty in-memory library, English UI, optionally seeded with the bundled fixtures
    /// (Alpha, Bravo, Charlie — short spoken clips).
    static func launchForUITests(seeded: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        if seeded, let fixtures = Bundle(for: LaunchTests.self).url(forResource: "Fixtures", withExtension: nil) {
            app.launchEnvironment["SP_UITEST_SEED_DIR"] = fixtures.path
        }
        app.launch()
        return app
    }
}
