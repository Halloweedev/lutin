import XCTest
import TestSupport
import LutinCore
import LutinConfig
@testable import LutinCLI

final class PreviewCommandTests: XCTestCase {
    func testPreviewBuildsMountsAndOpensTheDmg() throws {
        let projectDir = try Fixtures.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: projectDir) }
        let fm = FileManager.default
        try fm.copyItem(at: Fixtures.barryApp,
                        to: projectDir.appendingPathComponent("Barry.app"))
        try fm.copyItem(at: Fixtures.barryConfig,
                        to: projectDir.appendingPathComponent("lutin.yml"))

        let opener = FakeCommandRunner()
        let result = try CommandLogic.preview(
            configURL: projectDir.appendingPathComponent("lutin.yml"),
            opener: opener)

        XCTAssertTrue(fm.fileExists(atPath: result.mountPath))
        XCTAssertTrue(fm.fileExists(atPath: result.dmgPath))
        // Finder was asked to open the mounted volume.
        XCTAssertTrue(opener.invocations.contains {
            $0.executable.hasSuffix("open") && $0.arguments.contains(result.mountPath) })

        // Clean up the volume the preview intentionally left mounted.
        _ = try? ShellCommandRunner().runAllowingFailure(
            "/usr/bin/hdiutil", ["detach", result.mountPath, "-force"])
    }

    func testPreviewDetachesResolvedVersionAndBuildVolumeName() throws {
        let projectDir = try Fixtures.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: projectDir) }
        let fm = FileManager.default
        try fm.copyItem(at: Fixtures.barryApp,
                        to: projectDir.appendingPathComponent("Barry.app"))
        let configURL = projectDir.appendingPathComponent("lutin.yml")
        var config = try LutinConfig.load(from: Fixtures.barryConfig)
        config.output.volumeName = "Barry-${version}-${build}"
        try config.save(to: configURL)

        let opener = FakeCommandRunner()
        let result = try CommandLogic.preview(configURL: configURL, opener: opener)

        XCTAssertTrue(opener.invocations.contains {
            $0.executable.hasSuffix("hdiutil")
                && $0.arguments == ["detach", "/Volumes/Barry-1.0.0-42", "-force"]
        })

        _ = try? ShellCommandRunner().runAllowingFailure(
            "/usr/bin/hdiutil", ["detach", result.mountPath, "-force"])
    }
}
