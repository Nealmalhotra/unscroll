// swift-tools-version: 6.0
import PackageDescription

// Machines with only the Command Line Tools (no full Xcode) ship swift-testing
// outside the default search paths. Run `UNSCROLL_CLT=1 swift test` there.
let cltFrameworks = "/Library/Developer/CommandLineTools/Library/Developer/Frameworks"
let cltLibs = "/Library/Developer/CommandLineTools/Library/Developer/usr/lib"
let useCLT = Context.environment["UNSCROLL_CLT"] == "1"

let testSwiftSettings: [SwiftSetting] = useCLT ? [.unsafeFlags(["-F", cltFrameworks])] : []
let testLinkerSettings: [LinkerSetting] = useCLT ? [.unsafeFlags([
    "-F", cltFrameworks,
    "-Xlinker", "-rpath", "-Xlinker", cltFrameworks,
    "-Xlinker", "-rpath", "-Xlinker", cltLibs,
])] : []

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
        .testTarget(
            name: "UnscrollKitTests",
            dependencies: ["UnscrollKit"],
            swiftSettings: testSwiftSettings,
            linkerSettings: testLinkerSettings
        ),
    ]
)
