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
