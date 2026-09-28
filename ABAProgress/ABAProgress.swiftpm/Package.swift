// swift-tools-version: 5.9

import PackageDescription
import AppleProductTypes

let package = Package(
    name: "Easy_ABA",
    platforms: [
        .iOS("17.0")
    ],
    products: [
        .iOSApplication(
            name: "쉬운 ABA",
            targets: ["AppModule"],
            bundleIdentifier: "com.abaprogress.universal",
            displayVersion: "1.1.5",
            bundleVersion: "24",
            appIcon: .asset("AppIcon"),
            accentColor: .asset("AccentColor"),
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
