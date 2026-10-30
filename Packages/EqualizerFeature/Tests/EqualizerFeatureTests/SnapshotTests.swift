import DesignSystem
import Domain
import DomainTestSupport
@testable import EqualizerFeature
import SnapshotTesting
import SwiftUI
import Testing
import UIKit

/// Reference images are recorded on iPhone 16 / iOS 18.1 at 2x. Delete a reference to re-record it.
/// The suite runs only on the reference simulator (pin it with `SIM_ID=<iPhone 16 udid>`).
@MainActor
@Suite(.enabled(if: SnapshotHost.isReference, "Reference images are recorded on iPhone 16 / iOS 18.1"))
struct SnapshotTests {
    private static let equalizer = EQSettings(isEnabled: true, gains: [4, 3, 1, 0, -1, 0, 1, 3, 4, 5], preamp: -5)

    private func check(
        _ name: String,
        detent: PresentationDetent,
        height: CGFloat,
        file: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line
    ) {
        let deps = TestDependencies(
            userPresets: [EQPreset(name: "My Mix", gains: [3, 2, 0, 0, 0, 0, 0, 1, 2, 3], preamp: -3)],
            equalizer: Self.equalizer
        )
        let view = EqualizerSheet(viewModel: deps.makeViewModel(), detent: detent).tint(AccentPalette.serya.color)
        for (variant, style) in [("light", UIUserInterfaceStyle.light), ("dark", .dark)] {
            let traits = UITraitCollection(traitsFrom: [
                UITraitCollection(userInterfaceStyle: style),
                UITraitCollection(preferredContentSizeCategory: .large),
                UITraitCollection(displayScale: 2),
            ])
            assertSnapshot(
                of: view,
                as: .image(precision: 0.95, perceptualPrecision: 0.9, layout: .fixed(width: 390, height: height), traits: traits),
                named: "\(name)-\(variant)",
                file: file,
                testName: testName,
                line: line
            )
        }
    }

    @Test func medium() {
        check("medium", detent: .medium, height: 420)
    }

    @Test func large() {
        check("large", detent: .large, height: 780)
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
