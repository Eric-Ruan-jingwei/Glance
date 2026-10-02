// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Glance",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Glance", targets: ["Glance"]),
        .executable(name: "GlanceFoundationChecks", targets: ["GlanceFoundationChecks"])
    ],
    targets: [
        .target(
            name: "GlanceCore",
            path: "Glance",
            exclude: [
                "Info.plist",
                "Glance.entitlements",
                "Assets.xcassets",
                "AppIcon.icns",
                "Application/AppEntry.swift"
            ],
            swiftSettings: [
                .unsafeFlags(["-enable-testing"], .when(configuration: .debug))
            ]
        ),
        .executableTarget(
            name: "Glance",
            dependencies: ["GlanceCore"],
            path: "App"
        ),
        .executableTarget(
            name: "GlanceFoundationChecks",
            dependencies: ["GlanceCore"],
            path: "Tests/GlanceFoundationChecks"
        )
    ]
)
