// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EONControl",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "EONKit"),
        .executableTarget(name: "EONControl", dependencies: ["EONKit"]),
        .testTarget(name: "EONKitTests", dependencies: ["EONKit"]),
    ]
)
