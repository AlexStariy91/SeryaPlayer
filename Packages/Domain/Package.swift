// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Domain",
    defaultLocalization: "en",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "Domain", targets: ["Domain"]),
    ],
    dependencies: [],
    targets: [
        .target(name: "Domain", dependencies: []),
        .testTarget(name: "DomainTests", dependencies: ["Domain"]),
    ]
)
