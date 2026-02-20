// swift-tools-version: 6.0
// HumanLogica IDE — A SwiftUI IDE for the Logica Language
// Author: Jared Lewis, 2026

import PackageDescription

let package = Package(
    name: "HumanLogicaIDE",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
    ],
    products: [
        .library(
            name: "HumanLogicaCore",
            targets: ["HumanLogicaCore"]
        ),
    ],
    targets: [
        .target(
            name: "HumanLogicaCore",
            path: "Sources/HumanLogicaCore",
            swiftSettings: [
                .swiftLanguageMode(.v5),
            ]
        ),
        .executableTarget(
            name: "HumanLogicaIDE",
            dependencies: ["HumanLogicaCore"],
            path: "Sources/HumanLogicaIDE",
            swiftSettings: [
                .swiftLanguageMode(.v5),
            ]
        ),
    ]
)
