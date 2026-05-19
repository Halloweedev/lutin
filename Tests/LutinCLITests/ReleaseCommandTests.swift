import XCTest
import TestSupport
import LutinCore
@testable import LutinCLI

final class ReleaseCommandTests: XCTestCase {
    func testBuildLogicProducesLaidOutDmg() throws {
        let projectDir = try Fixtures.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: projectDir) }
        let fm = FileManager.default
        try fm.copyItem(at: Fixtures.barryApp,
                        to: projectDir.appendingPathComponent("Barry.app"))
        try fm.copyItem(at: Fixtures.barryConfig,
                        to: projectDir.appendingPathComponent("lutin.yml"))

        let result = try CommandLogic.build(
            configURL: projectDir.appendingPathComponent("lutin.yml"), dryRun: false)
        XCTAssertFalse(result.dryRun)
        XCTAssertEqual(result.sha256?.count, 64)
    }

    func testReleaseLogicWithSigningDisabledBuildsAndSummarizes() throws {
        let projectDir = try Fixtures.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: projectDir) }
        let fm = FileManager.default
        try fm.copyItem(at: Fixtures.barryApp,
                        to: projectDir.appendingPathComponent("Barry.app"))
        try fm.copyItem(at: Fixtures.barryConfig,
                        to: projectDir.appendingPathComponent("lutin.yml"))

        let summary = try CommandLogic.release(
            configURL: projectDir.appendingPathComponent("lutin.yml"))
        XCTAssertEqual(summary.signingStatus, "skipped")
        XCTAssertTrue(fm.fileExists(atPath: projectDir
            .appendingPathComponent("release/release-summary.json").path))
    }
}
