// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Lutin",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "lutin", targets: ["LutinCLIExe"]),
        .executable(name: "lutin-app", targets: ["LutinAppExe"]),
        .executable(name: "lutin-app-packager", targets: ["LutinAppPackagerExe"]),
        .executable(name: "lutin-app-headless", targets: ["LutinAppHeadless"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.6"),
        .package(url: "https://github.com/Halloweedev/keylight-swift.git", from: "0.3.0"),
    ],
    targets: [
        .target(name: "LutinCore"),
        .target(name: "LutinConfig", dependencies: ["LutinCore", "Yams"]),
        .target(name: "LutinRegistry", dependencies: ["LutinCore"]),
        .target(name: "LutinLicense", dependencies: ["LutinCore"]),
        .target(name: "LutinBuilder", dependencies: ["LutinCore", "LutinConfig"]),
        .target(name: "LutinSigning", dependencies: ["LutinCore"]),
        .target(name: "LutinNotarization", dependencies: ["LutinCore"]),
        .target(name: "LutinRender", dependencies: ["LutinCore", "LutinConfig"]),
        .target(name: "LutinRelease", dependencies: [
            "LutinCore", "LutinConfig", "LutinBuilder", "LutinSigning",
            "LutinNotarization", "LutinRender",
        ]),
        .target(name: "LutinCLI", dependencies: [
            "LutinCore", "LutinConfig", "LutinRegistry", "LutinBuilder",
            "LutinSigning", "LutinNotarization", "LutinRelease",
            "LutinIntentBridge",
            .product(name: "ArgumentParser", package: "swift-argument-parser"),
        ]),
        .target(
            name: "LutinIntentBridge",
            dependencies: ["LutinDocument", "LutinConfig"],
            path: "Sources/LutinIntentBridge"
        ),
        .testTarget(
            name: "LutinIntentBridgeTests",
            dependencies: ["LutinIntentBridge", "LutinDocument", "LutinConfig"],
            path: "Tests/LutinIntentBridgeTests"
        ),
        .executableTarget(
            name: "LutinAppHeadless",
            dependencies: ["LutinIntentBridge", "LutinDocument", "LutinConfig"],
            path: "Apps/LutinAppHeadless"
        ),

        // SP4 — GUI
        .target(name: "LutinAppKit", dependencies: ["LutinCore"]),
        .target(name: "LutinDocument", dependencies: [
            "LutinCore", "LutinConfig", "LutinRegistry", "LutinRender",
            "LutinRelease", "LutinSigning", "LutinNotarization",
            "LutinAppKit",
        ]),
        .target(name: "LutinUI", dependencies: [
            "LutinCore", "LutinConfig", "LutinDocument", "LutinAppKit", "LutinRender", "LutinRelease",
            "LutinSigning", "LutinNotarization", "LutinLicense",
            .product(name: "KeylightSDK", package: "keylight-swift"),
        ], resources: [.process("Resources")]),
        .target(name: "LutinAppPackagerCore", dependencies: ["LutinCore", "LutinConfig", "LutinSigning"]),

        .executableTarget(name: "LutinCLIExe", dependencies: ["LutinCLI"], path: "Apps/LutinCLI"),
        .executableTarget(name: "LutinAppExe", dependencies: ["LutinUI"], path: "Apps/LutinApp",
                          exclude: ["lutin.yml", "build"]),
        .executableTarget(name: "LutinAppPackagerExe", dependencies: [
            "LutinAppPackagerCore",
        ], path: "Apps/LutinAppPackager"),

        .target(name: "TestSupport", dependencies: ["LutinCore"], path: "Tests/TestSupport"),
        .testTarget(name: "LutinCoreTests", dependencies: ["LutinCore", "TestSupport"]),
        .testTarget(name: "LutinConfigTests", dependencies: ["LutinConfig", "LutinCore", "TestSupport"]),
        .testTarget(name: "LutinRegistryTests", dependencies: ["LutinRegistry", "LutinCore", "TestSupport"]),
        .testTarget(name: "LutinLicenseTests", dependencies: ["LutinLicense", "LutinCore", "TestSupport"]),
        .testTarget(name: "LutinBuilderTests", dependencies: ["LutinBuilder", "LutinConfig", "LutinCore", "TestSupport"]),
        .testTarget(name: "LutinSigningTests", dependencies: ["LutinSigning", "LutinCore", "TestSupport"]),
        .testTarget(name: "LutinNotarizationTests", dependencies: ["LutinNotarization", "LutinCore", "TestSupport"]),
        .testTarget(name: "LutinRenderTests", dependencies: [
            "LutinRender", "LutinConfig", "LutinCore", "TestSupport"]),
        .testTarget(name: "LutinReleaseTests", dependencies: [
            "LutinRelease", "LutinConfig", "LutinCore", "LutinBuilder", "TestSupport"]),
        .testTarget(name: "LutinCLITests", dependencies: [
            "LutinCLI", "LutinRegistry", "LutinCore", "LutinBuilder", "LutinRelease", "TestSupport"]),

        // SP4 tests
        .testTarget(name: "LutinDocumentTests", dependencies: [
            "LutinDocument", "LutinCore", "LutinConfig", "LutinRegistry", "TestSupport"]),
        .testTarget(name: "LutinUITests", dependencies: [
            "LutinUI", "LutinDocument", "LutinCore", "LutinConfig", "TestSupport"]),
        .testTarget(name: "LutinAppPackagerTests", dependencies: [
            "LutinAppPackagerCore", "LutinCore", "LutinConfig", "TestSupport"]),
    ],
    swiftLanguageModes: [.v5]
)
