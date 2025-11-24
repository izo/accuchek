// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AccuChekKit",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "AccuChekKit",
            targets: ["AccuChekKit"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "AccuChekKit",
            dependencies: [],
            path: "Sources/AccuChekKit"
        ),
        .testTarget(
            name: "AccuChekKitTests",
            dependencies: ["AccuChekKit"],
            path: "Tests/AccuChekKitTests"
        ),
    ]
)
