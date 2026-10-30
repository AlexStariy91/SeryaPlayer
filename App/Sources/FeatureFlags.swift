import Foundation

/// Feature flags. The browser can be turned off in a single build (App Review risk, guideline 5.2.3):
/// build setting `SP_BROWSER_ENABLED` → `SPBrowserEnabled` key in Info.plist.
struct FeatureFlags: Sendable {
    var isBrowserEnabled: Bool

    static let `default` = FeatureFlags(
        isBrowserEnabled: (Bundle.main.object(forInfoDictionaryKey: "SPBrowserEnabled") as? String) == "YES"
    )
}
