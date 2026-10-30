// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DesignSystem",
    defaultLocalization: "en",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
    ],
    dependencies: [],
    targets: [
        .target(name: "DesignSystem", dependencies: []),
        .testTarget(name: "DesignSystemTests", dependencies: ["DesignSystem"]),
    ]
)
