// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "UnscrollKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "UnscrollKit", targets: ["UnscrollKit"]),
        .library(name: "UnscrollScreenTime", targets: ["UnscrollScreenTime"]),
    ],
    targets: [
        .target(name: "UnscrollKit"),
        .target(name: "UnscrollScreenTime", dependencies: ["UnscrollKit"]),
        .testTarget(name: "UnscrollKitTests", dependencies: ["UnscrollKit"]),
    ]
)
