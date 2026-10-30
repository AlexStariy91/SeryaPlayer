// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Shared",
    defaultLocalization: "en",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "Shared", targets: ["Shared"]),
    ],
    dependencies: [],
    targets: [
        .target(name: "Shared", dependencies: []),
        .testTarget(name: "SharedTests", dependencies: ["Shared"]),
    ]
)
