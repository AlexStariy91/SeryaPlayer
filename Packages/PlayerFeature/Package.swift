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
    ],
    targets: [
        .target(name: "PlayerFeature", dependencies: ["Domain", "DesignSystem"]),
        .testTarget(name: "PlayerFeatureTests", dependencies: ["PlayerFeature"]),
    ]
)
