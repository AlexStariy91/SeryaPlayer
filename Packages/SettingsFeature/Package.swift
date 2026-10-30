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
    ],
    targets: [
        .target(name: "SettingsFeature", dependencies: ["Domain", "DesignSystem"]),
        .testTarget(name: "SettingsFeatureTests", dependencies: ["SettingsFeature"]),
    ]
)
