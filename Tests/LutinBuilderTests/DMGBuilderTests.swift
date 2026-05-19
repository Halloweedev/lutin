import XCTest
import TestSupport
import LutinConfig
import LutinCore
@testable import LutinBuilder

final class DMGBuilderTests: XCTestCase {
    /// Builds a config pointing at the Barry fixture, with output in a temp dir.
    private func makeRequest() throws -> (BuildRequest, URL) {
        let outDir = try Fixtures.makeTempDirectory()
        let request = BuildRequest(
            appBundle: Fixtures.barryApp,
            outputDirectory: outDir,
            dmgName: "Barry-1.0.0.dmg",
            volumeName: "Barry",
            layout: DMGLayout(windowWidth: 600, windowHeight: 400, iconSize: 96, textSize: 13,
                              showSidebar: false, showToolbar: false, placements: [:]),
            backgroundImage: nil,
            volumeIcon: nil)
        return (request, outDir)
    }

    func testDryRunReportsStepsAndWritesNothing() throws {
        let (request, outDir) = try makeRequest()
        let result = try DMGBuilder.build(request, dryRun: true)
        XCTAssertTrue(result.dryRun)
        XCTAssertFalse(result.plannedSteps.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: outDir.appendingPathComponent("Barry-1.0.0.dmg").path))
    }

    func testBuildProducesMountableDmg() throws {
        let (request, outDir) = try makeRequest()
        let result = try DMGBuilder.build(request, dryRun: false)
        let dmg = outDir.appendingPathComponent("Barry-1.0.0.dmg")
        XCTAssertTrue(FileManager.default.fileExists(atPath: dmg.path))
        XCTAssertEqual(result.dmgPath?.lastPathComponent, "Barry-1.0.0.dmg")
        XCTAssertGreaterThan(result.sizeBytes ?? 0, 0)
        XCTAssertEqual(result.sha256?.count, 64)
    }

    func testMissingAppThrows() throws {
        let (_, outDir) = try makeRequest()
        let request = BuildRequest(
            appBundle: Fixtures.examplesDirectory.appendingPathComponent("Ghost.app"),
            outputDirectory: outDir, dmgName: "Ghost.dmg", volumeName: "Ghost",
            layout: DMGLayout(windowWidth: 600, windowHeight: 400, iconSize: 96, textSize: 13,
                              showSidebar: false, showToolbar: false, placements: [:]),
            backgroundImage: nil, volumeIcon: nil)
        XCTAssertThrowsError(try DMGBuilder.build(request, dryRun: false)) { error in
            XCTAssertEqual((error as? LutinError)?.code, "app_bundle_invalid")
        }
    }
}
