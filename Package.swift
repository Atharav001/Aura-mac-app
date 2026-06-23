// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Aura",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "Aura",
            dependencies: [],
            path: "Aura",
            exclude: ["Assets.xcassets", "Info.plist", "Aura.entitlements"]
        ),
        .testTarget(
            name: "AuraTests",
            dependencies: ["Aura"],
            path: "AuraTests"
        )
    ]
)
