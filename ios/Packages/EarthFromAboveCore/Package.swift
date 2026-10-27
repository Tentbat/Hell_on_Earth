// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EarthFromAboveCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "EarthFromAboveCore", targets: ["EarthFromAboveCore"])
    ],
    targets: [
        .target(name: "EarthFromAboveCore"),
        .testTarget(name: "EarthFromAboveCoreTests", dependencies: ["EarthFromAboveCore"])
    ]
)
