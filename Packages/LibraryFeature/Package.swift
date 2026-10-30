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
    ],
    targets: [
        .target(name: "LibraryFeature", dependencies: ["Domain", "DesignSystem"]),
        .testTarget(name: "LibraryFeatureTests", dependencies: ["LibraryFeature"]),
    ]
)
