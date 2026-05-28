// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "KeyTicker",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "KeyTicker",
            resources: [.process("Resources")]
        )
    ]
)
