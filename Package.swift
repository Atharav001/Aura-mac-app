// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Aura",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/Defaults.git", from: "9.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "Aura",
            dependencies: [
                .product(name: "Defaults", package: "Defaults"),
            ],
            path: "Aura",
            exclude: [
                "Assets.xcassets",
                "Info.plist",
                "Aura.entitlements",
                "BoringNotch/NOTICE.md",
                // Replace Aura's custom Dynamic Island with Boring Notch ContentView
                "Features/DynamicIsland/NotchView.swift",
                "Features/DynamicIsland/CalendarService.swift",
                "Core/NotchManager/NotchManager.swift",
                // Boring Notch pieces that need Xcode/XPC/Sparkle/Lottie/SkyLight — shimmed instead
                "BoringNotch/XPCHelperClient",
                "BoringNotch/components/Settings",
                "BoringNotch/components/Onboarding",
                "BoringNotch/components/Tips",
                "BoringNotch/components/WhatsNewView.swift",
                "BoringNotch/components/LottieView.swift",
                "BoringNotch/components/Music/LottieAnimationView.swift",
                "BoringNotch/components/Notch/BoringNotchSkyLightWindow.swift",
                "BoringNotch/components/TestView.swift",
                "BoringNotch/observers/FullscreenMediaDetection.swift",
                "BoringNotch/MediaControllers/YouTube Music Controller",
                "BoringNotch/metal",
                "BoringNotch/Shortcuts",
                "BoringNotch/extensions/KeyboardShortcutsHelper.swift",
                "BoringNotch/menu/StatusBarMenu.swift",
            ],
            resources: [
                .copy("Resources/Logos"),
                .copy("Resources/Logos/AppIcon.icns"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .testTarget(
            name: "AuraTests",
            dependencies: ["Aura"],
            path: "AuraTests"
        )
    ]
)
