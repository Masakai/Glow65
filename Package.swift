// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Glow65",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "Core6502", targets: ["Core6502"]),
        .library(name: "Glow65", targets: ["Glow65"]),
        .executable(name: "glow65-cli", targets: ["glow65-cli"]),
        .executable(name: "Glow65App", targets: ["Glow65App"]),
    ],
    targets: [
        .target(name: "Core6502"),
        .target(name: "Glow65", dependencies: ["Core6502"]),
        .executableTarget(name: "glow65-cli", dependencies: ["Glow65"]),
        .executableTarget(name: "Glow65App", dependencies: ["Glow65"]),
        .testTarget(name: "Core6502Tests", dependencies: ["Core6502"]),
        .testTarget(name: "Glow65Tests", dependencies: ["Glow65", "Core6502"]),
    ]
)
