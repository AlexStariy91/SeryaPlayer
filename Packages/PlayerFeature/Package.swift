// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PlayerFeature",
    defaultLocalization: "en",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "PlayerFeature", targets: ["PlayerFeature"]),
    ],
    dependencies: [
        .package(path: "../Domain"),
        .package(path: "../DesignSystem"),
        // Test-only: used by PlayerFeatureTests for snapshots.
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", exact: "1.17.6"),
    ],
    targets: [
        .target(name: "PlayerFeature", dependencies: ["Domain", "DesignSystem"], resources: [.process("Resources")]),
        .testTarget(
            name: "PlayerFeatureTests",
            dependencies: [
                "PlayerFeature",
                .product(name: "DomainTestSupport", package: "Domain"),
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ]
        ),
    ]
)
