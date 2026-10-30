// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LibraryFeature",
    defaultLocalization: "en",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "LibraryFeature", targets: ["LibraryFeature"]),
    ],
    dependencies: [
        .package(path: "../Domain"),
        .package(path: "../DesignSystem"),
        // Test-only: used by LibraryFeatureTests for snapshots.
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", exact: "1.17.6"),
    ],
    targets: [
        .target(name: "LibraryFeature", dependencies: ["Domain", "DesignSystem"], resources: [.process("Resources")]),
        .testTarget(
            name: "LibraryFeatureTests",
            dependencies: [
                "LibraryFeature",
                .product(name: "DomainTestSupport", package: "Domain"),
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ]
        ),
    ]
)
