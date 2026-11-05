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
        // CLI の引数の検証に、設定のタイマーの範囲（CapsaicinCore が持つ）を使う。
        .target(name: "CapsaicinIPC", dependencies: ["CapsaicinCore"]),
        .target(name: "CapsaicinPlatform", dependencies: ["CapsaicinCore"]),
        .target(name: "CapsaicinCoreTesting", dependencies: ["CapsaicinCore"]),
        .testTarget(name: "CapsaicinCoreTests", dependencies: ["CapsaicinCore", "CapsaicinCoreTesting"]),
        .testTarget(name: "CapsaicinIPCTests", dependencies: ["CapsaicinIPC"]),
        .testTarget(name: "CapsaicinPlatformTests", dependencies: ["CapsaicinPlatform"]),
    ],
    swiftLanguageModes: [.v6],
)
