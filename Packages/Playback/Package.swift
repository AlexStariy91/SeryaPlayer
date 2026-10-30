// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Playback",
    defaultLocalization: "en",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "Playback", targets: ["Playback"]),
    ],
    dependencies: [
        .package(path: "../Domain"),
    ],
    targets: [
        .target(name: "Playback", dependencies: ["Domain"]),
        .testTarget(name: "PlaybackTests", dependencies: ["Playback"]),
    ]
)
