// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ElonWatch",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "ElonWatch",
            path: "Sources/ElonWatch",
            resources: [
                .copy("Resources")
            ]
        )
    ]
)
