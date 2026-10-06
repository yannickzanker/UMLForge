// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "UMLForge",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "UMLForge", targets: ["UMLForge"])
    ],
    targets: [
        .executableTarget(
            name: "UMLForge",
            path: "Sources/UMLForge",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
