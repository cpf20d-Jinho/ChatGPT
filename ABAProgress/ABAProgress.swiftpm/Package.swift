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
            displayVersion: "0.6.0",
            bundleVersion: "6",
            appIcon: .placeholder(icon: .checkmark),
            accentColor: .presetColor(.blue),
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
            path: "Sources/AppModule"
        )
    ]
)
