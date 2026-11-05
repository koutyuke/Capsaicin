// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "CapsaicinKit",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "CapsaicinCore", targets: ["CapsaicinCore"]),
        .library(name: "CapsaicinIPC", targets: ["CapsaicinIPC"]),
        .library(name: "CapsaicinPlatform", targets: ["CapsaicinPlatform"]),
    ],
    targets: [
        .target(name: "CapsaicinCore"),
        .target(name: "CapsaicinIPC"),
        .target(name: "CapsaicinPlatform"),
        .testTarget(name: "CapsaicinCoreTests", dependencies: ["CapsaicinCore"]),
        .testTarget(name: "CapsaicinIPCTests", dependencies: ["CapsaicinIPC"]),
        .testTarget(name: "CapsaicinPlatformTests", dependencies: ["CapsaicinPlatform"]),
    ],
    swiftLanguageModes: [.v6],
)
