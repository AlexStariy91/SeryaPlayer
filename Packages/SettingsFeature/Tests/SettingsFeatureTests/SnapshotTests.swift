import DesignSystem
import Domain
import DomainTestSupport
@testable import SettingsFeature
import SnapshotTesting
import SwiftUI
import Testing
import UIKit

/// Reference images are recorded on iPhone 16 / iOS 18.1 at 2x. Delete a reference to re-record it.
/// The suite runs only on the reference simulator (pin it with `SIM_ID=<iPhone 16 udid>`).
@MainActor
@Suite(.enabled(if: SnapshotHost.isReference, "Reference images are recorded on iPhone 16 / iOS 18.1"))
struct SnapshotTests {
    @Test func settings() async {
        let deps = TestDependencies(settings: AppSettings(theme: .dark, accentColorID: "teal"))
        _ = try? await deps.files.importFile(from: URL(fileURLWithPath: "/a.mp3"))
        deps.artwork.setCacheSize(2_400_000)
        let model = deps.makeViewModel(appInfo: AppInfo(name: "SeryaPlayer", version: "1.0", build: "1"))
        await model.refreshSizes()

        let view = SettingsView(viewModel: model) { Text(verbatim: "Presets") }
            .tint(AccentPalette.option(id: "teal").color)
            .environment(\.locale, Locale(identifier: "en_US"))
        for (variant, style) in [("light", UIUserInterfaceStyle.light), ("dark", .dark)] {
            let traits = UITraitCollection(traitsFrom: [
                UITraitCollection(userInterfaceStyle: style),
                UITraitCollection(preferredContentSizeCategory: .large),
                UITraitCollection(displayScale: 2),
            ])
            assertSnapshot(
                of: view,
                as: .image(precision: 0.95, perceptualPrecision: 0.9, layout: .fixed(width: 390, height: 844), traits: traits),
                named: variant
            )
        }
    }
}

enum SnapshotHost {
    /// iPhone 16 (`iPhone17,3`) on iOS 18.1.
    static var isReference: Bool {
        ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] == "iPhone17,3"
            && ProcessInfo.processInfo.operatingSystemVersion.majorVersion == 18
            && ProcessInfo.processInfo.operatingSystemVersion.minorVersion == 1
    }
}
