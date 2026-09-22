import XCTest
import LutinCore
import LutinConfig
import TestSupport
@testable import LutinAppPackagerCore

final class BundleAssemblerTests: XCTestCase {
    func testAssemblesValidBundleLayout() throws {
        let dir = try Fixtures.makeTempDirectory()
        let binary = dir.appendingPathComponent("LutinApp")
        try Data([0xCA,0xFE,0xBA,0xBE]).write(to: binary)  // fake binary
        let resources = dir.appendingPathComponent("res")
        try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
        let icon = resources.appendingPathComponent("Assets.car")
        try Data([0,0,0,0]).write(to: icon)

        let spec = AppBundleSpec(
            binaryURL: binary,
            resourcesURL: resources,
            outputDirectory: dir.appendingPathComponent("out"),
            bundleName: "Lutin",
            bundleIdentifier: "com.lutin.app",
            shortVersion: "1.0.0",
            buildNumber: "1",
            minimumSystemVersion: "15.0"
        )

        let appURL = try BundleAssembler.assemble(spec)
        XCTAssertEqual(appURL.lastPathComponent, "Lutin.app")
        let contents = appURL.appendingPathComponent("Contents")
        XCTAssertTrue(FileManager.default.fileExists(atPath: contents.appendingPathComponent("MacOS/Lutin").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: contents.appendingPathComponent("Resources/Assets.car").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: contents.appendingPathComponent("Info.plist").path))
    }

    /// The shape both `dev-app.sh` and `release-app.sh` actually hand the
    /// packager: SwiftPM's built `<Package>_<Target>.bundle`, whose compiled
    /// assets live at `Contents/Resources/Assets.car`.
    ///
    /// `Bundle.module`'s generated accessor looks for exactly that bundle
    /// under `Contents/Resources/` of the app, and its lookup ends in a
    /// `fatalError` — so a missing copy crashes the app on the first asset
    /// lookup, before any window appears (issue #2).
    func testStagesBuiltResourceBundleUnderContentsResources() throws {
        let dir = try Fixtures.makeTempDirectory()
        let binary = dir.appendingPathComponent("LutinApp")
        try Data([0xCA, 0xFE, 0xBA, 0xBE]).write(to: binary)

        let built = dir.appendingPathComponent("Lutin_LutinUI.bundle")
        let builtContents = built.appendingPathComponent("Contents")
        let builtResources = builtContents.appendingPathComponent("Resources")
        try FileManager.default.createDirectory(at: builtResources, withIntermediateDirectories: true)
        try Data([0x01]).write(to: builtResources.appendingPathComponent("Assets.car"))
        try Data([0x02]).write(to: builtContents.appendingPathComponent("Info.plist"))
        try FileManager.default.createDirectory(
            at: builtContents.appendingPathComponent("_CodeSignature"),
            withIntermediateDirectories: true)

        let spec = AppBundleSpec(
            binaryURL: binary,
            resourcesURL: built,
            outputDirectory: dir.appendingPathComponent("out"),
            bundleName: "Lutin",
            bundleIdentifier: "com.lutin.app",
            shortVersion: "1.0.0",
            buildNumber: "1",
            minimumSystemVersion: "15.0"
        )

        let appURL = try BundleAssembler.assemble(spec)
        let res = appURL.appendingPathComponent("Contents/Resources")
        let fm = FileManager.default
        let staged = res.appendingPathComponent("Lutin_LutinUI.bundle")

        XCTAssertTrue(fm.fileExists(atPath: staged.appendingPathComponent("Contents/Resources/Assets.car").path),
                      "`Bundle.module` resolves Contents/Resources/Lutin_LutinUI.bundle; it must contain the compiled Assets.car")
        XCTAssertTrue(fm.fileExists(atPath: staged.appendingPathComponent("Contents/Info.plist").path))
        XCTAssertFalse(fm.fileExists(atPath: staged.appendingPathComponent("Contents/_CodeSignature").path),
                       "SwiftPM's build-time signature is not ours to keep")
        XCTAssertTrue(fm.fileExists(atPath: res.appendingPathComponent("Assets.car").path),
                      "the compiled car is also staged at the top level for icon/legacy lookups")
        XCTAssertFalse(fm.fileExists(atPath: res.appendingPathComponent("Contents").path),
                       "the built bundle's inner Contents must not be copied as a loose Resources/Contents")
    }

    func testRejectsMissingBinary() throws {
        let dir = try Fixtures.makeTempDirectory()
        let spec = AppBundleSpec(
            binaryURL: dir.appendingPathComponent("DoesNotExist"),
            resourcesURL: dir,
            outputDirectory: dir.appendingPathComponent("out"),
            bundleName: "Lutin", bundleIdentifier: "com.lutin.app",
            shortVersion: "1.0.0", buildNumber: "1", minimumSystemVersion: "15.0")

        XCTAssertThrowsError(try BundleAssembler.assemble(spec)) { error in
            XCTAssertEqual((error as? LutinError)?.code, "app_packager_missing_binary")
        }
    }
}
