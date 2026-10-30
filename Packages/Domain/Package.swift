// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Domain",
    defaultLocalization: "en",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "Domain", targets: ["Domain"]),
        .library(name: "DomainTestSupport", targets: ["DomainTestSupport"]),
    ],
    dependencies: [],
    targets: [
        .target(name: "Domain", dependencies: []),
        // Hand-written in-memory fakes of repositories and services, shared by other packages' tests.
        .target(name: "DomainTestSupport", dependencies: ["Domain"]),
        .testTarget(name: "DomainTests", dependencies: ["Domain", "DomainTestSupport"]),
    ]
)
