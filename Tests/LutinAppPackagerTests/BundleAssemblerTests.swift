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

    /// The app icon can only come from the *source* catalog: `actool` is what
    /// produces `AppIcon.icns` and the icon keys in Info.plist. Handing the
    /// packager SwiftPM's built bundle — the only thing the scripts pass — used
    /// to silently drop both, leaving `CFBundleIconFile` pointing at a file
    /// that was never staged.
    func testCompilesSourceCatalogForTheAppIcon() throws {
        let dir = try Fixtures.makeTempDirectory()
        let binary = dir.appendingPathComponent("LutinApp")
        try Data([0xCA, 0xFE, 0xBA, 0xBE]).write(to: binary)

        let built = dir.appendingPathComponent("Lutin_LutinUI.bundle")
        let builtResources = built.appendingPathComponent("Contents/Resources")
        try FileManager.default.createDirectory(at: builtResources, withIntermediateDirectories: true)
        try Data([0x01]).write(to: builtResources.appendingPathComponent("Assets.car"))

        // The repo's real source catalog, resolved from this file's location.
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let catalog = repoRoot.appendingPathComponent("Sources/LutinUI/Resources/Assets.xcassets")

        let spec = AppBundleSpec(
            binaryURL: binary, resourcesURL: built,
            outputDirectory: dir.appendingPathComponent("out"),
            bundleName: "Lutin", bundleIdentifier: "com.lutin.app",
            shortVersion: "1.0.0", buildNumber: "1", minimumSystemVersion: "15.0",
            assetCatalogURL: catalog)

        let appURL = try BundleAssembler.assemble(spec)
        let fm = FileManager.default
        let res = appURL.appendingPathComponent("Contents/Resources")

        XCTAssertTrue(fm.fileExists(atPath: res.appendingPathComponent("AppIcon.icns").path),
                      "actool extracts AppIcon.icns from the source catalog")
        XCTAssertTrue(fm.fileExists(atPath: res.appendingPathComponent("Assets.car").path))
        XCTAssertTrue(fm.fileExists(atPath: res.appendingPathComponent("Lutin_LutinUI.bundle/Contents/Resources/Assets.car").path),
                      "the module bundle keeps SwiftPM's compiled car")

        let plistURL = appURL.appendingPathComponent("Contents/Info.plist")
        let plist = try PropertyListSerialization.propertyList(
            from: try Data(contentsOf: plistURL), options: [], format: nil) as? [String: Any]
        XCTAssertEqual(plist?["CFBundleIconName"] as? String, "AppIcon",
                       "actool's partial plist carries the icon keys")
    }

    /// A catalog path that does not exist is a packaging mistake, not a reason
    /// to ship an iconless app: fail loudly instead.
    func testRejectsMissingAssetCatalog() throws {
        let dir = try Fixtures.makeTempDirectory()
        let binary = dir.appendingPathComponent("LutinApp")
        try Data([0xCA, 0xFE, 0xBA, 0xBE]).write(to: binary)

        let spec = AppBundleSpec(
            binaryURL: binary,
            resourcesURL: dir.appendingPathComponent("res"),
            outputDirectory: dir.appendingPathComponent("out"),
            bundleName: "Lutin", bundleIdentifier: "com.lutin.app",
            shortVersion: "1.0.0", buildNumber: "1", minimumSystemVersion: "15.0",
            assetCatalogURL: dir.appendingPathComponent("NoSuch.xcassets"))

        XCTAssertThrowsError(try BundleAssembler.assemble(spec)) { error in
            XCTAssertEqual((error as? LutinError)?.code, "app_packager_missing_asset_catalog")
        }
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
