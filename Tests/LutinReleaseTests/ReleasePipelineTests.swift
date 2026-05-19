import XCTest
import TestSupport
import LutinCore
import LutinConfig
@testable import LutinRelease

final class ReleasePipelineTests: XCTestCase {
    /// A config pointing at the Barry fixture, output in a temp dir.
    private func makeConfig(signing: Bool, notarization: Bool) -> LutinConfig {
        LutinConfig(
            project: .init(name: "Barry", bundleId: "com.anotheragence.barry"),
            app: .init(path: "./Barry.app"),
            output: .init(directory: "./release", dmgName: "Barry-${version}.dmg",
                          volumeName: "Barry"),
            window: LutinConfig.WindowInfo(width: 680, height: 420, iconSize: 96,
                textSize: 13, showToolbar: false, showSidebar: false),
            background: nil,
            items: [.init(type: "app", id: "app", x: 180, y: 220, label: "Barry"),
                    .init(type: "applications", id: "applications", x: 500, y: 220,
                          label: "Applications")],
            decorations: nil,
            signing: signing ? LutinConfig.SigningInfo(
                enabled: true, identity: "Developer ID Application: Acme (TEAM)",
                hardenedRuntime: true, entitlements: nil, signDmg: true) : nil,
            notarization: notarization ? LutinConfig.NotarizationInfo(
                enabled: true, profile: "lutin-notary", staple: true) : nil,
            sparkle: nil)
    }

    func testBuildPathProducesDmgAndSummary() throws {
        let projectDir = Fixtures.barryProject
        let outDir = try Fixtures.makeTempDirectory()
        addTeardownBlock { try? FileManager.default.removeItem(at: outDir) }
        var config = makeConfig(signing: false, notarization: false)
        config.output.directory = outDir.path

        let result = try ReleasePipeline.run(
            config: config, projectDirectory: projectDir,
            mode: .build, runner: ShellCommandRunner())

        XCTAssertTrue(FileManager.default.fileExists(atPath: result.summary.dmgPath))
        XCTAssertEqual(result.summary.signingStatus, "skipped")
        XCTAssertEqual(result.summary.notarizationStatus, "skipped")
    }

    func testReleasePathSignsAndNotarizesViaRunner() throws {
        let projectDir = Fixtures.barryProject
        let outDir = try Fixtures.makeTempDirectory()
        addTeardownBlock { try? FileManager.default.removeItem(at: outDir) }
        var config = makeConfig(signing: true, notarization: true)
        config.output.directory = outDir.path

        let fake = FakeCommandRunner()
        fake.stub(executable: "/usr/bin/security",
                  result: ShellResult(exitCode: 0,
                    stdout: "Developer ID Application: Acme (TEAM)", stderr: ""))
        fake.stub(executable: "/usr/bin/xcrun",
                  result: ShellResult(exitCode: 0, stdout: "status: Accepted", stderr: ""))

        let result = try ReleasePipeline.run(
            config: config, projectDirectory: projectDir,
            mode: .release, runner: fake, dmgRunner: ShellCommandRunner())

        XCTAssertEqual(result.summary.signingStatus, "signed")
        XCTAssertEqual(result.summary.notarizationStatus, "stapled")
        XCTAssertTrue(fake.invocations.contains { $0.executable.hasSuffix("codesign") })
        XCTAssertTrue(fake.invocations.contains {
            $0.executable.hasSuffix("xcrun") && $0.arguments.first == "notarytool" })
    }

    func testReleaseThrowsInvalidConfigWhenSigningEnabledButIdentityNil() throws {
        let projectDir = Fixtures.barryProject
        let outDir = try Fixtures.makeTempDirectory()
        addTeardownBlock { try? FileManager.default.removeItem(at: outDir) }
        // Build a config with signing.enabled = true but signing.identity = nil.
        var config = LutinConfig(
            project: .init(name: "Barry", bundleId: "com.anotheragence.barry"),
            app: .init(path: "./Barry.app"),
            output: .init(directory: outDir.path, dmgName: "Barry-${version}.dmg",
                          volumeName: "Barry"),
            window: LutinConfig.WindowInfo(width: 680, height: 420, iconSize: 96,
                textSize: 13, showToolbar: false, showSidebar: false),
            background: nil,
            items: [.init(type: "app", id: "app", x: 180, y: 220, label: "Barry"),
                    .init(type: "applications", id: "applications", x: 500, y: 220,
                          label: "Applications")],
            decorations: nil,
            signing: LutinConfig.SigningInfo(
                enabled: true, identity: nil,
                hardenedRuntime: true, entitlements: nil, signDmg: false),
            notarization: nil,
            sparkle: nil)
        config.output.directory = outDir.path

        let fake = FakeCommandRunner()
        XCTAssertThrowsError(
            try ReleasePipeline.run(config: config, projectDirectory: projectDir,
                                    mode: .release, runner: fake,
                                    dmgRunner: ShellCommandRunner())
        ) { error in
            XCTAssertEqual((error as? LutinError)?.code, "invalid_config")
        }
    }

    func testReleaseWithSigningAndNotarizationDisabledStillBuilds() throws {
        let projectDir = Fixtures.barryProject
        let outDir = try Fixtures.makeTempDirectory()
        addTeardownBlock { try? FileManager.default.removeItem(at: outDir) }
        var config = makeConfig(signing: false, notarization: false)
        config.output.directory = outDir.path
        let result = try ReleasePipeline.run(
            config: config, projectDirectory: projectDir,
            mode: .release, runner: ShellCommandRunner())
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.summary.dmgPath))
        XCTAssertEqual(result.summary.signingStatus, "skipped")
        XCTAssertEqual(result.summary.notarizationStatus, "skipped")
    }
}
