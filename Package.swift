// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Lutin",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "lutin", targets: ["LutinCLIExe"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.6"),
    ],
    targets: [
        .target(name: "LutinCore"),
        .target(name: "LutinConfig", dependencies: ["LutinCore", "Yams"]),
        .target(name: "LutinRegistry", dependencies: ["LutinCore"]),
        .target(name: "LutinBuilder", dependencies: ["LutinCore", "LutinConfig"]),
        .target(name: "LutinSigning", dependencies: ["LutinCore"]),
        .target(name: "LutinNotarization", dependencies: ["LutinCore"]),
        .target(name: "LutinRelease", dependencies: [
            "LutinCore", "LutinConfig", "LutinBuilder", "LutinSigning", "LutinNotarization",
        ]),
        .target(name: "LutinCLI", dependencies: [
            "LutinCore", "LutinConfig", "LutinRegistry", "LutinBuilder",
            "LutinSigning", "LutinNotarization", "LutinRelease",
            .product(name: "ArgumentParser", package: "swift-argument-parser"),
        ]),
        .executableTarget(name: "LutinCLIExe", dependencies: ["LutinCLI"], path: "Apps/LutinCLI"),
        .target(name: "TestSupport", path: "Tests/TestSupport"),
        .testTarget(name: "LutinCoreTests", dependencies: ["LutinCore", "TestSupport"]),
        .testTarget(name: "LutinConfigTests", dependencies: ["LutinConfig", "LutinCore", "TestSupport"]),
        .testTarget(name: "LutinRegistryTests", dependencies: ["LutinRegistry", "LutinCore", "TestSupport"]),
        .testTarget(name: "LutinBuilderTests", dependencies: ["LutinBuilder", "LutinConfig", "LutinCore", "TestSupport"]),
        .testTarget(name: "LutinSigningTests", dependencies: ["LutinSigning", "LutinCore", "TestSupport"]),
        .testTarget(name: "LutinNotarizationTests", dependencies: ["LutinNotarization", "LutinCore", "TestSupport"]),
        .testTarget(name: "LutinReleaseTests", dependencies: [
            "LutinRelease", "LutinConfig", "LutinCore", "TestSupport"]),
        .testTarget(name: "LutinCLITests", dependencies: [
            "LutinCLI", "LutinRegistry", "LutinCore", "LutinBuilder", "LutinRelease", "TestSupport"]),
    ]
)
