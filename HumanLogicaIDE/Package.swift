// swift-tools-version: 5.9
// HumanLogica IDE — A SwiftUI IDE for the Logica Language
// Author: Jared Lewis, 2026

import PackageDescription

let package = Package(
    name: "HumanLogicaIDE",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
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
            path: "Sources/HumanLogicaCore"
        ),
        .executableTarget(
            name: "HumanLogicaIDE",
            dependencies: ["HumanLogicaCore"],
            path: "Sources/HumanLogicaIDE"
        ),
    ]
)
