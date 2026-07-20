// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FlatlineKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "FlatlineKit", targets: ["FlatlineKit"])
    ],
    targets: [
        .target(name: "FlatlineKit"),
        .testTarget(name: "FlatlineKitTests", dependencies: ["FlatlineKit"])
    ]
)
