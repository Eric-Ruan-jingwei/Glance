// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Glance",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Glance", targets: ["Glance"])
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
            linkerSettings: [
                .linkedFramework("Carbon"),
                .linkedFramework("PDFKit"),
                .linkedFramework("ImageIO"),
                .linkedFramework("ServiceManagement")
            ]
        ),
        .executableTarget(
            name: "Glance",
            dependencies: ["GlanceCore"],
            path: "App"
        ),
        .testTarget(
            name: "GlanceCoreTests",
            dependencies: ["GlanceCore"],
            path: "Tests/GlanceCoreTests"
        )
    ]
)
