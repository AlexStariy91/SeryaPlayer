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
    ],
    targets: [
        .target(name: "FoldersFeature", dependencies: ["Domain", "DesignSystem"]),
        .testTarget(name: "FoldersFeatureTests", dependencies: ["FoldersFeature"]),
    ]
)
