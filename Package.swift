// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Bookworm",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Bookworm",
            path: "Sources/Bookworm",
            resources: [.copy("Assets")]
        )
    ]
)
