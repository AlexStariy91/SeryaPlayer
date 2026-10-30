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
    ],
    targets: [
        .target(name: "EqualizerFeature", dependencies: ["Domain", "DesignSystem"]),
        .testTarget(name: "EqualizerFeatureTests", dependencies: ["EqualizerFeature"]),
    ]
)
