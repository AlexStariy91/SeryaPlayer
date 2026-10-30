// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EqualizerFeature",
    defaultLocalization: "en",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "EqualizerFeature", targets: ["EqualizerFeature"]),
    ],
    dependencies: [
        .package(path: "../Domain"),
        .package(path: "../DesignSystem"),
        // Test-only: used by EqualizerFeatureTests for snapshots.
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", exact: "1.17.6"),
    ],
    targets: [
        .target(name: "EqualizerFeature", dependencies: ["Domain", "DesignSystem"], resources: [.process("Resources")]),
        .testTarget(
            name: "EqualizerFeatureTests",
            dependencies: [
                "EqualizerFeature",
                .product(name: "DomainTestSupport", package: "Domain"),
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ]
        ),
    ]
)
