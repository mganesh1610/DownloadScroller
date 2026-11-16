// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DownloadScroller",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "DownloadScroller", targets: ["DownloadScroller"])],
    targets: [
        .target(name: "DownloadScrollerCore"),
        .executableTarget(
            name: "DownloadScroller",
            dependencies: ["DownloadScrollerCore"],
            exclude: ["Resources"]
        ),
        .testTarget(name: "DownloadScrollerCoreTests", dependencies: ["DownloadScrollerCore"])
    ],
    swiftLanguageModes: [.v5]
)
