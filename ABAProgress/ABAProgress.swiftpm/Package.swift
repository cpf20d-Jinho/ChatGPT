// swift-tools-version: 5.9

import PackageDescription
import AppleProductTypes

let package = Package(
    name: "ABAProgress",
    platforms: [
        .iOS("17.0")
    ],
    products: [
        .iOSApplication(
            name: "ABAProgress",
            targets: ["AppModule"],
            bundleIdentifier: "com.abaprogress.universal",
            displayVersion: "0.8.1",
            bundleVersion: "9",
            appIcon: .asset("AppIcon"),
            accentColor: .presetColor(.pink),
            supportedDeviceFamilies: [
                .phone,
                .pad
            ],
            supportedInterfaceOrientations: [
                .portrait,
                .landscapeRight,
                .landscapeLeft
            ]
        )
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            path: "Sources/AppModule",
            resources: [.process("Resources"), .process("Assets.xcassets")]
        )
    ]
)
