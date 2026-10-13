// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ScreenCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "ScreenCore", targets: ["ScreenCore"])],
    targets: [
        .target(name: "ScreenCore"),
        .testTarget(name: "ScreenCoreTests", dependencies: ["ScreenCore"]),
    ]
)
