// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SettingsFeature",
    defaultLocalization: "en",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "SettingsFeature", targets: ["SettingsFeature"]),
    ],
    dependencies: [
        .package(path: "../Domain"),
        .package(path: "../DesignSystem"),
        // Test-only: used by SettingsFeatureTests for snapshots.
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", exact: "1.17.6"),
    ],
    targets: [
        .target(name: "SettingsFeature", dependencies: ["Domain", "DesignSystem"], resources: [.process("Resources")]),
        .testTarget(
            name: "SettingsFeatureTests",
            dependencies: [
                "SettingsFeature",
                .product(name: "DomainTestSupport", package: "Domain"),
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ]
        ),
    ]
)
