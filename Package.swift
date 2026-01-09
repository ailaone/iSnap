// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "iSnap",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "iSnap", targets: ["iSnap"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "iSnap",
            dependencies: [],
            path: "Sources",
            resources: [
                .copy("../Resources/icon.icon"),  // Add your .icon file
                .copy("../Resources/icons"),       // Keep your other icons
                .process("../Resources/Info.plist")
            ]
        )
    ]
)
