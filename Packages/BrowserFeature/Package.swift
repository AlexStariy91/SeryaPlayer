// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BrowserFeature",
    defaultLocalization: "en",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "BrowserFeature", targets: ["BrowserFeature"]),
    ],
    dependencies: [
        .package(path: "../Domain"),
        .package(path: "../DesignSystem"),
    ],
    targets: [
        .target(name: "BrowserFeature", dependencies: ["Domain", "DesignSystem"]),
        .testTarget(name: "BrowserFeatureTests", dependencies: ["BrowserFeature"]),
    ]
)
