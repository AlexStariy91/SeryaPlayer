// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FoldersFeature",
    defaultLocalization: "en",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "FoldersFeature", targets: ["FoldersFeature"]),
    ],
    dependencies: [
        .package(path: "../Domain"),
        .package(path: "../DesignSystem"),
        // Test-only: used by FoldersFeatureTests for snapshots.
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", exact: "1.17.6"),
    ],
    targets: [
        .target(name: "FoldersFeature", dependencies: ["Domain", "DesignSystem"], resources: [.process("Resources")]),
        .testTarget(
            name: "FoldersFeatureTests",
            dependencies: [
                "FoldersFeature",
                .product(name: "DomainTestSupport", package: "Domain"),
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ]
        ),
    ]
)
