// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "CapsaicinKit",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "CapsaicinCore", targets: ["CapsaicinCore"]),
        .library(name: "CapsaicinIPC", targets: ["CapsaicinIPC"]),
        .library(name: "CapsaicinPlatform", targets: ["CapsaicinPlatform"]),
        // ポートの偽物。パッケージのテストとアプリのテストの両方から使うため、テストターゲットではなくライブラリにする。
        .library(name: "CapsaicinCoreTesting", targets: ["CapsaicinCoreTesting"]),
    ],
    targets: [
        .target(name: "CapsaicinCore"),
        .target(name: "CapsaicinIPC", dependencies: ["CapsaicinCore"]),
        .target(name: "CapsaicinPlatform", dependencies: ["CapsaicinCore", "CapsaicinLEDShim"]),
        .target(name: "CapsaicinLEDShim", linkerSettings: [.linkedFramework("IOKit")]),
        .target(name: "CapsaicinCoreTesting", dependencies: ["CapsaicinCore"]),
        .testTarget(name: "CapsaicinCoreTests", dependencies: ["CapsaicinCore", "CapsaicinCoreTesting"]),
        .testTarget(name: "CapsaicinIPCTests", dependencies: ["CapsaicinIPC"]),
        .testTarget(name: "CapsaicinPlatformTests", dependencies: ["CapsaicinPlatform"]),
    ],
    swiftLanguageModes: [.v6],
)
