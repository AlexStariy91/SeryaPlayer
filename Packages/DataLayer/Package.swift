// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DataLayer",
    defaultLocalization: "en",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "DataLayer", targets: ["DataLayer"]),
    ],
    dependencies: [
        .package(path: "../Domain"),
        .package(path: "../Shared"),
    ],
    targets: [
        .target(name: "DataLayer", dependencies: ["Domain", "Shared"]),
        .testTarget(name: "DataLayerTests", dependencies: ["DataLayer"]),
    ]
)
