import XCTest
import TestSupport
import LutinCore
@testable import LutinBuilder

final class FullBuildTests: XCTestCase {
    private func layout() -> DMGLayout {
        DMGLayout(windowWidth: 680, windowHeight: 420, iconSize: 96, textSize: 13,
                  showSidebar: false, showToolbar: false,
                  placements: [
                    "Barry.app": .init(x: 180, y: 220),
                    "Applications": .init(x: 500, y: 220),
                  ])
    }

    func testFullBuildProducesLaidOutDmg() throws {
        let outDir = try Fixtures.makeTempDirectory()
        let request = BuildRequest(
            appBundle: Fixtures.barryApp,
            outputDirectory: outDir,
            dmgName: "Barry-1.0.0.dmg",
            volumeName: "Barry",
            layout: layout(),
            backgroundImage: Fixtures.barryBackground,
            volumeIcon: nil)
        let result = try DMGBuilder.build(request, dryRun: false)

        let dmg = outDir.appendingPathComponent("Barry-1.0.0.dmg")
        XCTAssertTrue(FileManager.default.fileExists(atPath: dmg.path))
        XCTAssertEqual(result.sha256?.count, 64)

        let mount = try DiskImage.mount(dmg, runner: ShellCommandRunner())
        defer { try? DiskImage.unmount(mount, runner: ShellCommandRunner()) }
        let fm = FileManager.default
        XCTAssertTrue(fm.fileExists(atPath: mount.mountPoint
            .appendingPathComponent("Barry.app").path))
        XCTAssertTrue(fm.fileExists(atPath: mount.mountPoint
            .appendingPathComponent("Applications").path))
        XCTAssertTrue(fm.fileExists(atPath: mount.mountPoint
            .appendingPathComponent(".DS_Store").path))
        XCTAssertTrue(fm.fileExists(atPath: mount.mountPoint
            .appendingPathComponent(".background/background.png").path))
    }

    func testVolumeIconFileIsCopiedIntoTheVolume() throws {
        let outDir = try Fixtures.makeTempDirectory()
        let request = BuildRequest(
            appBundle: Fixtures.barryApp, outputDirectory: outDir,
            dmgName: "Barry.dmg", volumeName: "Barry", layout: layout(),
            backgroundImage: nil, volumeIcon: Fixtures.barryBackground)
        _ = try DMGBuilder.build(request, dryRun: false)
        let mount = try DiskImage.mount(outDir.appendingPathComponent("Barry.dmg"),
                                        runner: ShellCommandRunner())
        defer { try? DiskImage.unmount(mount, runner: ShellCommandRunner()) }
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: mount.mountPoint.appendingPathComponent(".VolumeIcon.icns").path))
    }

    func testMissingBackgroundPathThrows() throws {
        let outDir = try Fixtures.makeTempDirectory()
        let request = BuildRequest(
            appBundle: Fixtures.barryApp, outputDirectory: outDir,
            dmgName: "Barry.dmg", volumeName: "Barry", layout: layout(),
            backgroundImage: outDir.appendingPathComponent("nope.png"),
            volumeIcon: nil)
        XCTAssertThrowsError(try DMGBuilder.build(request, dryRun: false)) { error in
            XCTAssertEqual((error as? LutinError)?.code, "background_not_found")
        }
    }

    func testDryRunWritesNothing() throws {
        let outDir = try Fixtures.makeTempDirectory()
        let request = BuildRequest(
            appBundle: Fixtures.barryApp, outputDirectory: outDir,
            dmgName: "Barry.dmg", volumeName: "Barry", layout: layout(),
            backgroundImage: nil, volumeIcon: nil)
        let result = try DMGBuilder.build(request, dryRun: true)
        XCTAssertTrue(result.dryRun)
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: outDir.appendingPathComponent("Barry.dmg").path))
    }
}
